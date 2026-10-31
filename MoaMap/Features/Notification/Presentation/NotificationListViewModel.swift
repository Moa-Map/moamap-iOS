import Foundation
import Observation

/// 첫 페이지 상태. 다음 페이지 실패는 `PagingState` 로 따로 둔다.
nonisolated enum NotificationListState: Equatable, Sendable {
    case loading
    case loaded([UserNotification])
    case failed(String)
}

nonisolated struct NotificationListUiState: Equatable, Sendable {
    var list: NotificationListState = .loading
    var paging: PagingState = .idle

    var notifications: [UserNotification] {
        if case .loaded(let notifications) = list { notifications } else { [] }
    }
}

@MainActor @Observable
final class NotificationListViewModel {
    nonisolated static let pageSize = 20
    nonisolated static let loadFailedMessage = "알림을 불러오지 못했어요"
    nonisolated static let offlineMessage = "네트워크에 연결할 수 없어요"

    private(set) var uiState = NotificationListUiState()
    /// 첫 페이지·다음 페이지가 한 자리를 쓴다.
    private(set) var loadTask: Task<Void, Never>?
    private(set) var readTask: Task<Void, Never>?
    private(set) var readAllTask: Task<Void, Never>?

    /// 다음에 받을 페이지 번호.
    private var nextPage = 0
    private let repository: any NotificationRepository
    private let timeZone: TimeZone
    private let now: () -> Date

    init(repository: any NotificationRepository, timeZone: TimeZone, now: @escaping () -> Date) {
        self.repository = repository
        self.timeZone = timeZone
        self.now = now
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
                let result = try await repository.fetchNotifications(page: page, size: Self.pageSize)
                try Task.checkCancellation()
                self?.appendPage(result, pageNumber: page)
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                self?.uiState.paging = .failed
            }
        }
    }

    /// 화면을 바로 읽음으로 바꾸고 서버에 알린다. 실패해도 되돌리지 않는다 - 이미 다른 화면으로 넘어간 뒤라
    /// 보이지 않고, 다음에 열면 서버 상태로 돌아온다.
    func open(_ notification: UserNotification) -> NotificationDestination? {
        if !notification.read {
            setRead { $0.id == notification.id }
            readTask = Task { [repository] in
                try? await repository.markRead(id: notification.id)
            }
        }
        return notification.destination
    }

    /// 화면을 먼저 바꾸고, 실패하면 안 읽었던 알림을 되돌린다. 그 사이 붙은 다음 페이지는 그대로 둔다.
    func markAllRead() {
        let unreadIDs = Set(uiState.notifications.filter { !$0.read }.map(\.id))
        guard !unreadIDs.isEmpty else { return }
        setRead { _ in true }
        readAllTask = Task { [weak self, repository] in
            do {
                try await repository.markAllRead()
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                self?.setUnread(unreadIDs)
            }
        }
    }

    func timeLabel(of date: Date?) -> String? {
        date.map { NotificationTimeLabel.text($0, now: now(), timeZone: timeZone) }
    }

    private func setRead(where predicate: (UserNotification) -> Bool) {
        guard case .loaded(var notifications) = uiState.list else { return }
        for index in notifications.indices where !notifications[index].read && predicate(notifications[index]) {
            notifications[index].read = true
        }
        uiState.list = .loaded(notifications)
    }

    private func setUnread(_ ids: Set<Int64>) {
        guard case .loaded(var notifications) = uiState.list else { return }
        for index in notifications.indices where ids.contains(notifications[index].id) {
            notifications[index].read = false
        }
        uiState.list = .loaded(notifications)
    }

    private func loadFirstPage() {
        uiState = NotificationListUiState()
        nextPage = 0
        loadTask?.cancel()
        loadTask = Task { [weak self, repository] in
            defer { if !Task.isCancelled { self?.loadTask = nil } }
            do {
                let result = try await repository.fetchNotifications(page: 0, size: Self.pageSize)
                try Task.checkCancellation()
                self?.nextPage = 1
                self?.uiState.list = .loaded(result.notifications)
                self?.uiState.paging = result.isLast ? .end : .idle
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                self?.uiState.list = .failed(Self.message(for: error))
            }
        }
    }

    private func appendPage(_ page: NotificationPage, pageNumber: Int) {
        nextPage = pageNumber + 1
        // 받는 사이 새 알림이 생기면 페이지 경계가 밀려 앞 페이지의 알림이 한 번 더 온다.
        let current = uiState.notifications
        let known = Set(current.map(\.id))
        uiState.list = .loaded(current + page.notifications.filter { !known.contains($0.id) })
        uiState.paging = page.isLast ? .end : .idle
    }

    nonisolated static func message(for error: any Error) -> String {
        if case .connection = error as? NetworkError { return offlineMessage }
        return loadFailedMessage
    }
}
