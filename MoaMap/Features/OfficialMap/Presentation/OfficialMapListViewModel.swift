import Foundation
import Observation

nonisolated enum OfficialMapListState: Equatable, Sendable {
    case loading
    case loaded([OfficialMap])
    case failed(String)
}

@MainActor @Observable
final class OfficialMapListViewModel {
    nonisolated static let loadFailedMessage = "공식지도를 불러오지 못했어요"

    private(set) var uiState: OfficialMapListState = .loading
    private(set) var loadTask: Task<Void, Never>?

    private let repository: any OfficialMapRepository

    init(repository: any OfficialMapRepository) { self.repository = repository }

    /// 화면이 보일 때 부른다. 지도에 참여하거나 나가고 돌아오면 참여 여부가 바뀌었을 수 있다.
    func refresh() {
        guard case .loaded = uiState else {
            if loadTask == nil { load(keepCurrent: false) }
            return
        }
        load(keepCurrent: true)
    }

    func retry() { load(keepCurrent: false) }

    /// - Parameter keepCurrent: true 면 보던 목록을 지우지 않고, 실패해도 그대로 둔다.
    private func load(keepCurrent: Bool) {
        loadTask?.cancel()
        if !keepCurrent { uiState = .loading }
        loadTask = Task { [weak self, repository] in
            defer { if !Task.isCancelled { self?.loadTask = nil } }
            do {
                let maps = try await repository.fetchOfficialMaps()
                try Task.checkCancellation()
                self?.uiState = .loaded(maps)
            } catch {
                guard !Task.isCancelled, !(error is CancellationError), !keepCurrent else { return }
                self?.uiState = .failed(Self.loadFailedMessage)
            }
        }
    }
}
