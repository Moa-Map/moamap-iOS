import Foundation
import Observation

nonisolated struct MapDetailUiState: Equatable, Sendable {
    var map: MapLoadState = .loading
    /// 마커로 그릴 장소. 조회에 실패하면 직전 목록을 둔다.
    var places: [MapPlace] = []
    /// 참여 요청 진행 중. 버튼을 두 번 누르지 못하게 막는다.
    var joining = false
    /// 한 번 보여주고 지우는 실패 안내.
    var errorMessage: String?
    /// 이 화면에서 참여했는지. 뒤로 갈 때 미리보기 화면을 건너뛰는 데 쓴다.
    var joinedHere = false

    var roleBadge: String? { map.map?.roleBadge }
    var canJoin: Bool { map.map?.canJoin ?? false }
}

@MainActor @Observable
final class MapDetailViewModel {
    let mapID: Int64
    private(set) var uiState = MapDetailUiState()
    private(set) var loadTask: Task<Void, Never>?
    private(set) var joinTask: Task<Void, Never>?

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
        guard !uiState.joining else { return }
        uiState.joining = true
        uiState.errorMessage = nil
        joinTask = Task { [weak self, repository, mapID] in
            defer { if !Task.isCancelled { self?.joinTask = nil } }
            do {
                try await repository.joinMap(mapID: mapID)
                try Task.checkCancellation()
                self?.uiState.joining = false
                self?.uiState.joinedHere = true
                self?.refresh()
                await self?.loadTask?.value
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                self?.uiState.joining = false
                self?.uiState.errorMessage = MapDetailMessage.userMessage(for: error, fallback: MapDetailMessage.joinFailed)
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
