import Foundation
import Observation

nonisolated struct MapIntroUiState: Equatable, Sendable {
    /// 목록에 보여 줄 장소 수.
    static let previewPlaceCount = 4

    var map: MapLoadState = .loading
    /// 지도에 찍을 장소 전부. 목록은 앞의 몇 개만 쓴다.
    var places: [MapPlace] = []
    var joining = false
    /// 한 번 보여주고 지우는 실패 안내.
    var errorMessage: String?
    /// 참여가 끝났다. 화면이 이 신호를 보고 상세로 넘어간다.
    var joined = false

    var previewPlaces: ArraySlice<MapPlace> { places.prefix(Self.previewPlaceCount) }
    var hasMorePlaces: Bool { places.count > Self.previewPlaceCount }
}

@MainActor @Observable
final class MapIntroViewModel {
    let mapID: Int64
    private(set) var uiState = MapIntroUiState()
    private(set) var loadTask: Task<Void, Never>?
    private(set) var joinTask: Task<Void, Never>?

    private let repository: any MapDetailRepository

    init(mapID: Int64, repository: any MapDetailRepository) {
        self.mapID = mapID
        self.repository = repository
    }

    /// 화면이 보일 때마다 다시 읽는다. 미리보기에서 참여하고 돌아오면 참여하기 버튼이 낡기 때문이다.
    func refresh() {
        load(keepCurrent: uiState.map.map != nil)
    }

    func retry() {
        load(keepCurrent: false)
    }

    func consumeErrorMessage() {
        uiState.errorMessage = nil
    }

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
                self?.uiState.joined = true
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                self?.uiState.joining = false
                self?.uiState.errorMessage = MapDetailMessage.userMessage(for: error, fallback: MapDetailMessage.joinFailed)
            }
        }
    }

    /// 장소만 실패해도 화면은 띄운다. 그 섹션만 비운다.
    private func load(keepCurrent: Bool) {
        loadTask?.cancel()
        if !keepCurrent { uiState.map = .loading }
        loadTask = Task { [weak self, repository, mapID] in
            defer { if !Task.isCancelled { self?.loadTask = nil } }
            let placesTask = Task { try? await repository.fetchPlaces(mapID: mapID) }
            let map: MapLoadState?
            do {
                map = .loaded(try await repository.fetchMapDetail(mapID: mapID))
            } catch {
                // 새로 읽다 실패했는데 보여 줄 지도가 있으면 지우지 않는다.
                map = keepCurrent ? nil : .failed(MapDetailMessage.userMessage(for: error, fallback: MapDetailMessage.loadFailed))
            }
            let loadedPlaces = await withTaskCancellationHandler {
                await placesTask.value
            } onCancel: {
                placesTask.cancel()
            }
            guard !Task.isCancelled, let self else { return }
            if let map { self.uiState.map = map }
            if let loadedPlaces { self.uiState.places = loadedPlaces }
        }
    }
}
