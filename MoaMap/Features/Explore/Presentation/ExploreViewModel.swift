import Foundation
import Observation

/// 커뮤니티 목록만의 상태. 공식지도는 독립적으로 갱신한다.
nonisolated enum ExploreUiState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failed(String)
}

@MainActor @Observable
final class ExploreViewModel {
    /// 인기순 앞에서부터 이만큼만 보여 준다. 정렬과 나머지는 「전체보기」에서 본다.
    static let communityMapCount = 3
    /// 앞에서부터 이만큼만 보여 준다. 나머지는 「전체보기」(공식지도 목록)에서 본다.
    static let officialMapCount = 5

    private(set) var uiState: ExploreUiState = .idle
    private(set) var communityMaps: [MapSummary] = []
    private(set) var officialState: OfficialMapListState = .loading
    private(set) var loadTask: Task<Void, Never>?
    private(set) var officialTask: Task<Void, Never>?

    private let repository: any ExploreRepository
    private let officialMapRepository: any OfficialMapRepository

    init(repository: any ExploreRepository, officialMapRepository: any OfficialMapRepository) {
        self.repository = repository
        self.officialMapRepository = officialMapRepository
    }

    /// 화면이 보일 때마다 부른다. 지도에 참여하거나 나가고 돌아오면 목록과 참여 여부가 바뀐다.
    /// 처음이면 전부 읽고, 그다음은 보던 목록을 둔 채 다시 읽는다.
    func refresh() {
        switch uiState {
        case .idle:
            load()
        case .loading:
            return
        case .loaded:
            loadCommunity(keepCurrent: true)
            refreshOfficial()
        case .failed:
            loadCommunity(keepCurrent: false)
            refreshOfficial()
        }
    }

    /// 아직 받기 전이면 진행 중인 요청을 끊지 않는다. 느린 네트워크에서 로딩이 끝나지 않는 것을 막는다.
    private func refreshOfficial() {
        if officialState.isLoaded {
            loadOfficial(keepCurrent: true)
        } else if officialTask == nil {
            loadOfficial(keepCurrent: false)
        }
    }

    func load() {
        cancelTasks()
        retryCommunity()
        retryOfficial()
    }

    /// 재시도는 공식지도 요청에 영향을 주지 않는다.
    func retryCommunity() {
        loadCommunity(keepCurrent: false)
    }

    func retryOfficial() {
        loadOfficial(keepCurrent: false)
    }

    /// `keepCurrent` 면 로딩으로 되돌리지 않고, 실패해도 보던 목록을 지우지 않는다.
    private func loadCommunity(keepCurrent: Bool) {
        loadTask?.cancel()
        if !keepCurrent { uiState = .loading }
        loadTask = Task { [weak self, repository] in
            defer { if !Task.isCancelled { self?.loadTask = nil } }
            do {
                let page = try await repository.fetchCommunityMaps(
                    tag: nil, sort: .popular, page: 0, size: Self.communityMapCount
                )
                try Task.checkCancellation()
                self?.communityMaps = page.maps
                self?.uiState = .loaded
            } catch {
                guard !Task.isCancelled, !(error is CancellationError), !keepCurrent else { return }
                self?.uiState = .failed(Self.message(for: error))
            }
        }
    }

    /// `keepCurrent` 의 뜻은 커뮤니티와 같다.
    private func loadOfficial(keepCurrent: Bool) {
        officialTask?.cancel()
        if !keepCurrent { officialState = .loading }
        officialTask = Task { [weak self, officialMapRepository] in
            defer { if !Task.isCancelled { self?.officialTask = nil } }
            do {
                let maps = try await officialMapRepository.fetchOfficialMaps()
                try Task.checkCancellation()
                self?.officialState = .loaded(Array(maps.prefix(Self.officialMapCount)))
            } catch {
                guard !Task.isCancelled, !(error is CancellationError), !keepCurrent else { return }
                self?.officialState = .failed(OfficialMapListViewModel.loadFailedMessage)
            }
        }
    }

    func cancelTasks() {
        loadTask?.cancel()
        loadTask = nil
        officialTask?.cancel()
        officialTask = nil
    }

    private static func message(for error: any Error) -> String {
        (error as? NetworkError)?.userMessage ?? "지도를 불러오지 못했어요. 다시 시도해 주세요."
    }
}

private extension OfficialMapListState {
    var isLoaded: Bool {
        if case .loaded = self { return true }
        return false
    }
}
