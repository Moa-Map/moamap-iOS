import Foundation
import Observation

nonisolated struct MapActivityUiState: Equatable, Sendable {
    var loading = true
    var activities: [MapActivity] = []
    var errorMessage: String?
}

/// 지도 관리의 활동 내역. 화면을 처음 열 때만 읽는다.
@MainActor @Observable
final class MapActivityViewModel {
    let mapID: Int64
    private(set) var uiState = MapActivityUiState()
    private(set) var loadTask: Task<Void, Never>?
    private var started = false

    private let repository: any MapActivityRepository
    private let now: () -> Date

    init(mapID: Int64, repository: any MapActivityRepository, now: @escaping () -> Date) {
        self.mapID = mapID
        self.repository = repository
        self.now = now
    }

    func loadOnce() {
        guard !started else { return }
        started = true
        load()
    }

    func retry() {
        started = true
        uiState.loading = true
        uiState.errorMessage = nil
        load()
    }

    func relativeTime(of date: Date?) -> String {
        date.map { RelativeTimeLabel.text(from: $0, now: now()) } ?? ""
    }

    private func load() {
        loadTask?.cancel()
        loadTask = Task { [weak self, repository, mapID] in
            let next: MapActivityUiState
            do {
                next = MapActivityUiState(loading: false, activities: try await repository.fetchActivities(mapID: mapID))
            } catch {
                guard !(error is CancellationError) else { return }
                next = MapActivityUiState(loading: false, errorMessage: MapManageMessage.activityMessage(for: error))
            }
            guard !Task.isCancelled else { return }
            self?.uiState = next
        }
    }
}

nonisolated struct PendingRequestUiState: Equatable, Sendable {
    var loading = true
    var requests: [PendingPlace] = []
    var errorMessage: String?
    /// 수락·거절이 오가는 중. 두 번 눌러도 서버에는 한 번만 간다.
    var processing = false
    var actionErrorMessage: String?
    /// 수락한 수. 늘어나면 지도가 새 장소를 다시 읽는다. 거절은 지도를 바꾸지 않는다.
    var approvedCount = 0
}

/// 장소 등록 요청 수락·거절. 방장·관리자에게만 보인다.
@MainActor @Observable
final class PendingRequestViewModel {
    let mapID: Int64
    private(set) var uiState = PendingRequestUiState()
    private(set) var loadTask: Task<Void, Never>?
    private(set) var actionTask: Task<Void, Never>?
    private var started = false

    private let repository: any PendingPlaceRepository

    init(mapID: Int64, repository: any PendingPlaceRepository) {
        self.mapID = mapID
        self.repository = repository
    }

    func loadOnce() {
        guard !started else { return }
        started = true
        load()
    }

    func retry() {
        guard !uiState.processing else { return }
        started = true
        uiState.loading = true
        uiState.errorMessage = nil
        load()
    }

    func approve(placeID: Int64) {
        process(placeID: placeID, approved: true) { [repository] in try await repository.approve(placeID: placeID) }
    }

    func reject(placeID: Int64) {
        process(placeID: placeID, approved: false) { [repository] in try await repository.reject(placeID: placeID) }
    }

    func consumeActionError() {
        uiState.actionErrorMessage = nil
    }

    func consumeLoadError() {
        uiState.errorMessage = nil
    }

    /// 처리한 요청은 목록을 다시 받지 않고 그 자리에서 뺀다.
    private func process(placeID: Int64, approved: Bool, _ body: @escaping () async throws -> Void) {
        guard !uiState.processing else { return }
        // 늦게 도착한 목록이 처리 결과를 덮지 못하게 진행 중인 조회를 버린다.
        loadTask?.cancel()
        uiState.processing = true
        uiState.actionErrorMessage = nil
        actionTask = Task { [weak self] in
            do {
                try await body()
                try Task.checkCancellation()
                guard let self else { return }
                self.uiState.processing = false
                self.uiState.loading = false
                self.uiState.requests.removeAll { $0.id == placeID }
                if approved { self.uiState.approvedCount += 1 }
            } catch {
                guard !(error is CancellationError), let self else { return }
                self.uiState.processing = false
                self.uiState.actionErrorMessage = MapDetailMessage.userMessage(for: error, fallback: MapManageMessage.actionFailed)
            }
        }
    }

    private func load() {
        loadTask?.cancel()
        loadTask = Task { [weak self, repository, mapID] in
            do {
                let requests = try await repository.fetchPendingPlaces(mapID: mapID)
                try Task.checkCancellation()
                self?.uiState.loading = false
                self?.uiState.requests = requests
                self?.uiState.errorMessage = nil
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                self?.uiState.loading = false
                self?.uiState.errorMessage = MapDetailMessage.userMessage(for: error, fallback: MapManageMessage.pendingLoadFailed)
            }
        }
    }
}

nonisolated enum MapManageMessage {
    static let activityLoadFailed = "활동 내역을 불러오지 못했어요"
    static let notMember = "지도에 참여해야 활동 내역을 볼 수 있어요"
    static let pendingLoadFailed = "장소 등록 요청을 불러오지 못했어요"
    static let actionFailed = "요청을 처리하지 못했어요"

    static func activityMessage(for error: any Error) -> String {
        if case .server(code: "PLACE_002", _, _) = error as? NetworkError { return notMember }
        return MapDetailMessage.userMessage(for: error, fallback: activityLoadFailed)
    }
}

nonisolated enum MapLogText {
    static let unknownUser = "알 수 없는 사용자"

    static func message(for activity: MapActivity) -> String {
        switch activity.type {
        case .placeAdded:
            activity.placeName.map { "‘\($0)’ \(objectParticle($0)) 추가했어요" } ?? "장소를 추가했어요"
        case .placeRemoved:
            activity.placeName.map { "‘\($0)’ \(objectParticle($0)) 지도에서 삭제했어요" } ?? "장소를 지도에서 삭제했어요"
        case .reviewCreated:
            activity.placeName.map { "‘\($0)’ 에 댓글을 남겼어요" } ?? "댓글을 남겼어요"
        }
    }

    static func message(for request: PendingPlace) -> String {
        request.placeName.map { "‘\($0)’ \(objectParticle($0)) 이 지도에 추가하고 싶어요" } ?? "장소를 이 지도에 추가하고 싶어요"
    }

    /// 마지막 글자에 받침이 있으면 "을", 없거나 한글이 아니면 "를".
    static func objectParticle(_ word: String) -> String {
        guard let scalar = word.unicodeScalars.last, (0xAC00...0xD7A3).contains(scalar.value) else { return "를" }
        return (scalar.value - 0xAC00) % 28 == 0 ? "를" : "을"
    }
}

nonisolated extension MapDetail {
    /// 프라이빗 지도는 권한이 나뉘지 않아 수락·거절할 사람이 없다.
    var canReviewRequests: Bool { type == .community && (role == .owner || role == .admin) }
}
