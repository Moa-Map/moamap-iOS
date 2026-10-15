import Foundation
import Observation

/// 첫 페이지 상태. 다음 페이지 실패는 `paging` 으로 따로 둔다. 받은 카드는 그대로 두고 끝에만 다시 시도를 붙인다.
nonisolated enum MapPostListState: Equatable, Sendable {
    case loading
    case loaded([MapPost])
    case failed(String)
}

nonisolated struct MapPostListUiState: Equatable, Sendable {
    var sort: MapPostSort = .latest
    /// 조회 전에도 로딩이다. 탭을 여는 순간 빈 상태가 한 프레임 스치지 않는다.
    var list: MapPostListState = .loading
    var paging: PagingState = .idle

    var posts: [MapPost] {
        if case .loaded(let posts) = list { posts } else { [] }
    }
}

/// 지도 로그 탭의 게시물 목록. 로그 탭을 열 때만 읽는다.
@MainActor @Observable
final class MapPostListViewModel {
    nonisolated static let loadFailedMessage = "게시물을 불러오지 못했어요"

    let mapID: Int64
    private(set) var uiState = MapPostListUiState()
    /// 첫 페이지와 다음 페이지가 한 자리를 쓴다. 정렬을 바꾸면 이전 정렬의 응답을 버린다.
    private(set) var loadTask: Task<Void, Never>?

    /// 다음에 받을 페이지 번호.
    private var nextPage = 0
    private var started = false
    private let repository: any MapPostRepository

    init(mapID: Int64, repository: any MapPostRepository) {
        self.mapID = mapID
        self.repository = repository
    }

    /// 탭을 오갈 때마다 다시 읽지 않는다.
    func loadOnce() {
        guard !started else { return }
        loadFirstPage()
    }

    func retry() { loadFirstPage() }

    func selectSort(_ sort: MapPostSort) {
        guard sort != uiState.sort else { return }
        uiState.sort = sort
        loadFirstPage()
    }

    /// 첫 페이지를 받기 전이나 실패했으면 부르지 않는다. 둘째 페이지만 붙는 것을 막는다.
    func loadMore() {
        guard case .loaded = uiState.list, uiState.paging == .idle || uiState.paging == .failed else { return }
        let sort = uiState.sort
        let page = nextPage
        uiState.paging = .loading
        loadTask?.cancel()
        loadTask = Task { [weak self, repository, mapID] in
            do {
                let result = try await repository.fetchPosts(mapID: mapID, page: page, sort: sort)
                try Task.checkCancellation()
                self?.appendPage(result, pageNumber: page)
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                self?.uiState.paging = .failed
            }
        }
    }

    private func loadFirstPage() {
        started = true
        let sort = uiState.sort
        uiState.list = .loading
        uiState.paging = .idle
        nextPage = 0
        loadTask?.cancel()
        loadTask = Task { [weak self, repository, mapID] in
            do {
                let result = try await repository.fetchPosts(mapID: mapID, page: 0, sort: sort)
                try Task.checkCancellation()
                self?.nextPage = 1
                self?.uiState.list = .loaded(result.posts)
                self?.uiState.paging = result.isLast ? .end : .idle
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                self?.uiState.list = .failed(MapDetailMessage.userMessage(for: error, fallback: Self.loadFailedMessage))
            }
        }
    }

    private func appendPage(_ page: MapPostPage, pageNumber: Int) {
        nextPage = pageNumber + 1
        // 받는 사이 새 글이 올라오면 페이지 경계가 밀려 앞 페이지의 글이 한 번 더 온다.
        let current = uiState.posts
        let known = Set(current.map(\.id))
        uiState.list = .loaded(current + page.posts.filter { !known.contains($0.id) })
        uiState.paging = page.isLast ? .end : .idle
    }
}
