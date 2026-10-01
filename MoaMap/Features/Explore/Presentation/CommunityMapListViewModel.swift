import Foundation
import Observation

/// 첫 페이지 상태. 다음 페이지 실패는 `PagingState` 로 따로 둔다.
nonisolated enum CommunityMapListState: Equatable, Sendable {
    case loading
    case loaded([MapSummary])
    case failed(String)
}

nonisolated enum PagingState: Equatable, Sendable {
    case idle
    case loading
    case failed
    /// 마지막 페이지까지 받았다.
    case end
}

nonisolated struct CommunityMapListUiState: Equatable, Sendable {
    /// 칩으로 보여 줄 태그. 「전체」는 화면이 앞에 붙인다.
    var tags: [String] = []
    /// nil 이면 「전체」.
    var selectedTag: String?
    var sort: MapSortOrder = .popular
    var list: CommunityMapListState = .loading
    var paging: PagingState = .idle

    var maps: [MapSummary] {
        if case .loaded(let maps) = list { maps } else { [] }
    }
}

@MainActor @Observable
final class CommunityMapListViewModel {
    nonisolated static let pageSize = 20
    /// 칩 줄이 끝없이 길어지지 않게 많이 쓰인 것부터 자른다.
    nonisolated static let maxTagChips = 10

    private(set) var uiState = CommunityMapListUiState()
    /// 첫 페이지·다음 페이지·다시 읽기가 한 자리를 쓴다. 조건을 바꾸면 이전 응답을 버린다.
    private(set) var loadTask: Task<Void, Never>?

    /// 다음에 받을 페이지 번호. 0 이면 아직 한 페이지도 받지 못했다.
    private var nextPage = 0
    private let repository: any ExploreRepository

    init(repository: any ExploreRepository) { self.repository = repository }

    /// 화면이 보일 때 부른다. 돌아왔으면 참여 여부가 바뀌었을 수 있어 받아 둔 만큼을 한 번에 다시 읽는다.
    func refresh() {
        guard nextPage > 0 else {
            if loadTask == nil { loadFirstPage() }
            return
        }
        let tag = uiState.selectedTag
        let sort = uiState.sort
        let size = nextPage * Self.pageSize
        if uiState.paging == .loading { uiState.paging = .idle }
        loadTask?.cancel()
        loadTask = Task { [weak self, repository] in
            defer { if !Task.isCancelled { self?.loadTask = nil } }
            do {
                let page = try await repository.fetchCommunityMaps(tag: tag, sort: sort, page: 0, size: size)
                try Task.checkCancellation()
                self?.uiState.list = .loaded(page.maps)
                self?.uiState.paging = page.isLast ? .end : .idle
            } catch {
                // 보던 목록은 지우지 않는다.
            }
        }
    }

    func retry() { loadFirstPage() }

    func selectTag(_ tag: String?) {
        guard tag != uiState.selectedTag else { return }
        uiState.selectedTag = tag
        loadFirstPage()
    }

    func selectSort(_ sort: MapSortOrder) {
        guard sort != uiState.sort else { return }
        uiState.sort = sort
        loadFirstPage()
    }

    /// 첫 페이지를 받기 전이나 실패했으면 부르지 않는다. 둘째 페이지만 붙는 것을 막는다.
    func loadMore() {
        guard case .loaded = uiState.list, uiState.paging == .idle || uiState.paging == .failed else { return }
        let tag = uiState.selectedTag
        let sort = uiState.sort
        let page = nextPage
        uiState.paging = .loading
        loadTask?.cancel()
        loadTask = Task { [weak self, repository] in
            defer { if !Task.isCancelled { self?.loadTask = nil } }
            do {
                let result = try await repository.fetchCommunityMaps(tag: tag, sort: sort, page: page, size: Self.pageSize)
                try Task.checkCancellation()
                self?.appendPage(result, pageNumber: page)
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                self?.uiState.paging = .failed
            }
        }
    }

    private func loadFirstPage() {
        let tag = uiState.selectedTag
        let sort = uiState.sort
        uiState.list = .loading
        uiState.paging = .idle
        nextPage = 0
        loadTask?.cancel()
        loadTask = Task { [weak self, repository] in
            defer { if !Task.isCancelled { self?.loadTask = nil } }
            do {
                let page = try await repository.fetchCommunityMaps(tag: tag, sort: sort, page: 0, size: Self.pageSize)
                try Task.checkCancellation()
                self?.applyFirstPage(page, tag: tag)
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                self?.uiState.list = .failed(Self.message(for: error))
            }
        }
    }

    private func applyFirstPage(_ page: MapPage, tag: String?) {
        nextPage = 1
        uiState.list = .loaded(page.maps)
        uiState.paging = page.isLast ? .end : .idle
        // 서버에 태그 목록 API 가 없어 거르지 않은 첫 페이지에서 한 번만 만든다.
        if uiState.tags.isEmpty, tag == nil {
            uiState.tags = Self.tagsByFrequency(page.maps)
        }
    }

    private func appendPage(_ page: MapPage, pageNumber: Int) {
        nextPage = pageNumber + 1
        // 받는 사이 새 지도가 생기면 페이지 경계가 밀려 앞 페이지의 지도가 한 번 더 온다.
        let current = uiState.maps
        let known = Set(current.map(\.id))
        uiState.list = .loaded(current + page.maps.filter { !known.contains($0.id) })
        uiState.paging = page.isLast ? .end : .idle
    }

    /// 많이 쓰인 순. 같은 수면 먼저 나온 태그가 앞이다.
    nonisolated static func tagsByFrequency(_ maps: [MapSummary], limit: Int = maxTagChips) -> [String] {
        var counts: [String: Int] = [:]
        var order: [String] = []
        for tag in maps.flatMap(\.tags) {
            if counts[tag] == nil { order.append(tag) }
            counts[tag, default: 0] += 1
        }
        let ranked = order.enumerated().sorted { lhs, rhs in
            let (l, r) = (counts[lhs.element] ?? 0, counts[rhs.element] ?? 0)
            return l != r ? l > r : lhs.offset < rhs.offset
        }
        return ranked.prefix(limit).map(\.element)
    }

    private static func message(for error: any Error) -> String {
        (error as? NetworkError)?.userMessage ?? "지도 목록을 불러오지 못했어요"
    }
}
