import Foundation
import Observation

nonisolated enum RestroomDetailState: Equatable, Sendable {
    case loading
    case loaded(RestroomDetail)
    case failed
}

nonisolated struct RestroomMapUiState: Equatable, Sendable {
    var restrooms: [RestroomMarker] = []
    /// 화면 안 화장실이 서버 한도를 넘어 일부만 왔는지.
    var truncated = false
    /// 마지막 조회가 실패했는지. 지도를 움직이면 다시 읽는다.
    var loadFailed = false
    /// 누른 화장실. 지도를 옮겨 목록에서 빠져도 카드는 남는다.
    var selected: RestroomMarker?
    /// `selected` 의 자세한 정보. 고른 화장실이 없으면 nil.
    var detail: RestroomDetailState?
}

/// 공중화장실 지도. 카메라가 멈출 때마다 보이는 범위의 화장실을 다시 읽는다.
/// 전국 수만 곳이라 한 번에 받지 않는다. 서버가 범위당 최대 500곳을 주고, 넘으면 화면이 확대를 안내한다.
@MainActor @Observable
final class RestroomMapViewModel {
    private(set) var uiState = RestroomMapUiState()
    private(set) var loadTask: Task<Void, Never>?
    private(set) var detailTask: Task<Void, Never>?

    /// 마지막으로 읽은 범위. 카메라가 그대로인데 지도가 다시 멈춘 경우(다시 그리기 등)를 거른다.
    private var loadedBounds: ViewportBounds?

    private let repository: any RestroomRepository

    init(repository: any RestroomRepository) { self.repository = repository }

    /// 카메라가 멈췄다. 새 범위면 앞선 조회를 버리고 다시 읽는다.
    func onCameraIdle(_ bounds: ViewportBounds) {
        guard bounds != loadedBounds else { return }
        loadedBounds = bounds
        loadTask?.cancel()
        loadTask = Task { [weak self, repository] in
            defer { if !Task.isCancelled { self?.loadTask = nil } }
            do {
                let result = try await repository.fetchRestrooms(in: bounds)
                try Task.checkCancellation()
                self?.uiState.restrooms = result.restrooms
                self?.uiState.truncated = result.truncated
                self?.uiState.loadFailed = false
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                // 같은 자리에서 다시 멈춰도 다시 읽게 비운다.
                self?.loadedBounds = nil
                self?.uiState.loadFailed = true
            }
        }
    }

    /// 마커를 눌렀다. 같은 화장실을 다시 누르면 실패했던 상세만 다시 읽는다.
    func selectRestroom(id: Int64) {
        if uiState.selected?.id == id, uiState.detail != .failed { return }
        guard let marker = uiState.restrooms.first(where: { $0.id == id })
            ?? uiState.selected.flatMap({ $0.id == id ? $0 : nil }) else { return }
        uiState.selected = marker
        uiState.detail = .loading
        detailTask?.cancel()
        detailTask = Task { [weak self, repository] in
            defer { if !Task.isCancelled { self?.detailTask = nil } }
            let detail: RestroomDetailState
            do {
                detail = .loaded(try await repository.fetchRestroom(id: id))
            } catch {
                detail = .failed
            }
            guard !Task.isCancelled else { return }
            self?.uiState.detail = detail
        }
    }

    /// 빈 곳을 눌렀다. 카드를 닫는다.
    func clearSelection() {
        detailTask?.cancel()
        detailTask = nil
        uiState.selected = nil
        uiState.detail = nil
    }
}
