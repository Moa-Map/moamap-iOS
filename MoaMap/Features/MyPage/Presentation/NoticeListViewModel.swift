import Foundation
import Observation

/// 첫 페이지 상태. 다음 페이지 실패는 `PagingState` 로 따로 둔다.
nonisolated enum NoticeListState: Equatable, Sendable {
    case loading
    case loaded([Notice])
    case failed(String)
}

nonisolated struct NoticeListUiState: Equatable, Sendable {
    var list: NoticeListState = .loading
    var paging: PagingState = .idle

    var notices: [Notice] {
        if case .loaded(let notices) = list { notices } else { [] }
    }
}

@MainActor @Observable
final class NoticeListViewModel {
    nonisolated static let pageSize = 20
    nonisolated static let loadFailedMessage = "공지사항을 불러오지 못했어요"
    nonisolated static let offlineMessage = "네트워크에 연결할 수 없어요"

    private(set) var uiState = NoticeListUiState()
    /// 첫 페이지·다음 페이지가 한 자리를 쓴다.
    private(set) var loadTask: Task<Void, Never>?

    /// 다음에 받을 페이지 번호.
    private var nextPage = 0
    private let repository: any NoticeRepository
    private let timeZone: TimeZone

    init(repository: any NoticeRepository, timeZone: TimeZone) {
        self.repository = repository
        self.timeZone = timeZone
    }

    func load() { loadFirstPage() }

    func retry() { loadFirstPage() }

    /// 첫 페이지를 받기 전이나 실패했으면 부르지 않는다. 둘째 페이지만 붙는 것을 막는다.
    func loadMore() {
        guard case .loaded = uiState.list, uiState.paging == .idle || uiState.paging == .failed else { return }
        let page = nextPage
        uiState.paging = .loading
        loadTask?.cancel()
        loadTask = Task { [weak self, repository] in
            defer { if !Task.isCancelled { self?.loadTask = nil } }
            do {
                let result = try await repository.fetchNotices(page: page, size: Self.pageSize)
                try Task.checkCancellation()
                self?.appendPage(result, pageNumber: page)
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                self?.uiState.paging = .failed
            }
        }
    }

    func dateLabel(of date: Date?) -> String? {
        NoticeDateLabel.text(date, timeZone: timeZone)
    }

    private func loadFirstPage() {
        uiState = NoticeListUiState()
        nextPage = 0
        loadTask?.cancel()
        loadTask = Task { [weak self, repository] in
            defer { if !Task.isCancelled { self?.loadTask = nil } }
            do {
                let result = try await repository.fetchNotices(page: 0, size: Self.pageSize)
                try Task.checkCancellation()
                self?.nextPage = 1
                self?.uiState.list = .loaded(result.notices)
                self?.uiState.paging = result.isLast ? .end : .idle
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                self?.uiState.list = .failed(Self.message(for: error))
            }
        }
    }

    private func appendPage(_ page: NoticePage, pageNumber: Int) {
        nextPage = pageNumber + 1
        // 받는 사이 새 공지가 올라오면 페이지 경계가 밀려 앞 페이지의 공지가 한 번 더 온다.
        let current = uiState.notices
        let known = Set(current.map(\.id))
        uiState.list = .loaded(current + page.notices.filter { !known.contains($0.id) })
        uiState.paging = page.isLast ? .end : .idle
    }

    nonisolated static func message(for error: any Error) -> String {
        if case .connection = error as? NetworkError { return offlineMessage }
        return loadFailedMessage
    }
}

/// 등록일. 기기 시간대 기준 `2026.10.20`.
nonisolated enum NoticeDateLabel {
    static func text(_ date: Date?, timeZone: TimeZone) -> String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter.string(from: date)
    }
}
