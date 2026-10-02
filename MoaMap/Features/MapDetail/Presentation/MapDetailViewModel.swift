import Foundation
import Observation

nonisolated struct MapDetailUiState: Equatable, Sendable {
    var map: MapLoadState = .loading
    /// 마커로 그릴 장소. 조회에 실패하면 직전 목록을 둔다.
    var places: [MapPlace] = []
    /// 참여·나가기 요청 진행 중. 버튼을 두 번 누르지 못하게 막는다.
    var actionInProgress = false
    /// 한 번 보여주고 지우는 실패 안내.
    var errorMessage: String?
    /// 나가기가 끝났다. 화면이 이 신호를 보고 이전 화면으로 돌아간다.
    var left = false
    /// 이 화면에서 참여했는지. 뒤로 갈 때 미리보기 화면을 건너뛰는 데 쓴다.
    var joinedHere = false

    var roleBadge: String? { map.map?.roleBadge }
    var canJoin: Bool { map.map?.canJoin ?? false }
    var showsMenu: Bool { map.map?.showsMenu ?? false }
    var canLeave: Bool { map.map?.canLeaveFromMenu ?? false }
    var leaveOutcome: LeaveOutcome? { map.map?.leaveOutcome }
    var inviteCode: String? { map.map?.shareableInviteCode }
    var canAddPlace: Bool { map.map?.canAddPlace ?? false }
    var isOfficial: Bool { map.map?.type == .official }
    /// 메뉴가 없는 공식지도는 상단바에 나가기 글자를 둔다.
    var showsLeaveButton: Bool { isOfficial && map.map?.topBarAction == .leave }
}

@MainActor @Observable
final class MapDetailViewModel {
    let mapID: Int64
    private(set) var uiState = MapDetailUiState()
    private(set) var loadTask: Task<Void, Never>?
    private(set) var actionTask: Task<Void, Never>?
    private(set) var likeTask: Task<Void, Never>?
    /// 응답 순서가 뒤바뀌면 화면이 서버와 달라져 같은 장소는 한 번에 하나만 보낸다.
    private var likesInFlight: Set<Int64> = []

    private let repository: any MapDetailRepository

    init(mapID: Int64, repository: any MapDetailRepository) {
        self.mapID = mapID
        self.repository = repository
    }

    /// 처음이거나 오류에서 다시 읽는다.
    func retry() {
        uiState.map = .loading
        refresh()
    }

    /// 화면은 채워 둔 채로 다시 읽는다. 로딩으로 되돌리면 제목이 깜빡인다.
    func refresh() {
        loadTask?.cancel()
        loadTask = Task { [weak self] in
            defer { if !Task.isCancelled { self?.loadTask = nil } }
            await self?.load()
        }
    }

    func consumeErrorMessage() {
        uiState.errorMessage = nil
    }

    /// 참여해도 화면은 떠나지 않는다. 역할과 인원이 함께 바뀌어 상세를 다시 읽는다.
    func join() {
        runAction(failure: MapDetailMessage.joinFailed) { [weak self, repository, mapID] in
            try await repository.joinMap(mapID: mapID)
            try Task.checkCancellation()
            self?.uiState.actionInProgress = false
            self?.uiState.joinedHere = true
            self?.refresh()
            await self?.loadTask?.value
        }
    }

    /// 프라이빗 지도에 혼자 남은 방장은 서버가 탈퇴를 막아 지도 삭제로 대신한다.
    func leave() {
        guard let map = uiState.map.map, map.topBarAction == .leave else { return }
        runAction(failure: MapDetailMessage.leaveFailed) { [weak self, repository, mapID] in
            if map.leavingDeletesMap {
                try await repository.deleteMap(mapID: mapID)
            } else {
                try await repository.leaveMap(mapID: mapID)
            }
            try Task.checkCancellation()
            self?.uiState.actionInProgress = false
            self?.uiState.joinedHere = false
            if map.staysAfterLeaving {
                self?.refresh()
                await self?.loadTask?.value
            } else {
                self?.uiState.left = true
            }
        }
    }

    /// 화면에 먼저 반영하고 서버 응답으로 확정한다. 실패하면 되돌린다.
    func toggleLike(placeID: Int64) {
        guard uiState.map.map?.joined == true else {
            uiState.errorMessage = MapDetailMessage.likeNeedsJoin
            return
        }
        guard let before = uiState.places.first(where: { $0.id == placeID }),
              likesInFlight.insert(placeID).inserted else { return }
        let liked = !before.liked
        updatePlace(placeID) { place in
            place.liked = liked
            place.likeCount = max(place.likeCount + (liked ? 1 : -1), 0)
        }
        likeTask = Task { [weak self, repository] in
            defer { self?.likesInFlight.remove(placeID) }
            do {
                let confirmed = try await repository.setPlaceLiked(placeID: placeID, liked: liked)
                self?.updatePlace(placeID) { place in
                    place.liked = confirmed.liked
                    place.likeCount = confirmed.likeCount
                }
            } catch {
                self?.updatePlace(placeID) { place in
                    place.liked = before.liked
                    place.likeCount = before.likeCount
                }
                guard !(error is CancellationError) else { return }
                self?.uiState.errorMessage = MapDetailMessage.userMessage(for: error, fallback: MapDetailMessage.likeFailed)
            }
        }
    }

    private func updatePlace(_ placeID: Int64, _ change: (inout MapPlace) -> Void) {
        guard let index = uiState.places.firstIndex(where: { $0.id == placeID }) else { return }
        change(&uiState.places[index])
    }

    /// 진행 중이면 무시하고, 아니면 잠근 채 돌린다.
    private func runAction(failure: String, _ body: @escaping @MainActor () async throws -> Void) {
        guard !uiState.actionInProgress else { return }
        uiState.actionInProgress = true
        uiState.errorMessage = nil
        actionTask = Task { [weak self] in
            defer { if !Task.isCancelled { self?.actionTask = nil } }
            do {
                try await body()
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                self?.uiState.actionInProgress = false
                self?.uiState.errorMessage = MapDetailMessage.userMessage(for: error, fallback: failure)
            }
        }
    }

    /// 지도와 장소를 나란히 읽는다. 한쪽이 실패해도 다른 쪽은 살린다.
    private func load() async {
        let placesTask = Task { [repository, mapID] in try? await repository.fetchPlaces(mapID: mapID) }
        let map: MapLoadState
        do {
            map = .loaded(try await repository.fetchMapDetail(mapID: mapID))
        } catch {
            map = .failed(MapDetailMessage.userMessage(for: error, fallback: MapDetailMessage.loadFailed))
        }
        let places = await withTaskCancellationHandler {
            await placesTask.value
        } onCancel: {
            placesTask.cancel()
        }
        guard !Task.isCancelled else { return }
        uiState.map = map
        if let places { uiState.places = places }
    }
}
