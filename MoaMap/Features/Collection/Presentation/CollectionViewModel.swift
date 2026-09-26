import Foundation
import Observation

@MainActor @Observable
final class CollectionViewModel {
    private(set) var uiState = CollectionUiState()
    // 취소는 오류 상태로 바꾸지 않고 호출자에게 전파한다.
    private(set) var loadTasks: [CollectionMapType: Task<Void, any Error>] = [:]
    var loadTask: Task<Void, any Error>? { loadTasks[uiState.selectedTab] }

    private var requestedTabs: Set<CollectionMapType> = []
    private let repository: any CollectionRepository

    init(repository: any CollectionRepository) {
        self.repository = repository
    }

    func loadIfNeeded() {
        guard !requestedTabs.contains(uiState.selectedTab) else { return }
        load(uiState.selectedTab)
    }

    func selectTab(_ type: CollectionMapType) {
        guard type != uiState.selectedTab else { return }
        uiState.selectedTab = type
        loadIfNeeded()
    }

    func retry() {
        load(uiState.selectedTab)
    }

    /// 화면 재진입 시 현재 목록은 유지하며 갱신하고, 다른 탭은 다음 선택 때 갱신한다.
    func refresh() {
        requestedTabs = requestedTabs.intersection([uiState.selectedTab])
        load(uiState.selectedTab, keepCurrent: true)
    }

    private func load(_ type: CollectionMapType, keepCurrent: Bool = false) {
        loadTasks[type]?.cancel()
        requestedTabs.insert(type)
        if !keepCurrent || uiState.state(of: type) == .idle {
            uiState.setState(.loading, for: type)
        }
        loadTasks[type] = Task { [weak self, repository] in
            defer {
                if !Task.isCancelled { self?.loadTasks[type] = nil }
            }
            do {
                let maps = try await repository.fetchMyMaps(type: type)
                try Task.checkCancellation()
                self?.uiState.setState(.loaded(maps), for: type)
            } catch {
                try Task.checkCancellation()
                if error is CancellationError { throw error }
                guard let self else { return }
                if keepCurrent, case .loaded = uiState.state(of: type) { return }
                uiState.setState(.failed("지도 목록을 불러오지 못했어요"), for: type)
            }
        }
    }
}
