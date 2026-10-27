import Foundation
import Observation

nonisolated enum MapPostCalendarLoadState: Equatable, Sendable {
    case idle
    case loading
    case failed(String)
}

nonisolated struct MapPostCalendarUiState: Equatable, Sendable {
    /// 열기 전에는 nil 이다.
    var month: CalendarMonth?
    var selectedDay: CalendarDay?
    /// 지금까지 받은 게시물 전부, 최신순. 서버에 월별 조회가 없어 최신 글부터 이어 받는다.
    var posts: [MapPost] = []
    var load: MapPostCalendarLoadState = .idle
}

/// 로그 탭 달력 형식. 카드 형식과 목록을 나눠 갖지 않는다. 늘 최신순이고 달의 시작까지 이어 받는다.
@MainActor @Observable
final class MapPostCalendarViewModel {
    /// 서버가 `last` 를 잘못 내려도 끝없이 받지 않는다. 한 페이지가 20개라 1000개까지다.
    nonisolated static let maxPages = 50

    let mapID: Int64
    private(set) var uiState = MapPostCalendarUiState()
    private(set) var loadTask: Task<Void, Never>?

    private var nextPage = 0
    private var endReached = false
    private var started = false
    private let repository: any MapPostRepository
    private let timeZone: TimeZone
    private let now: () -> Date

    init(mapID: Int64, repository: any MapPostRepository, timeZone: TimeZone, now: @escaping () -> Date) {
        self.mapID = mapID
        self.repository = repository
        self.timeZone = timeZone
        self.now = now
    }

    /// 처음 열면 오늘이 있는 달을 보여주고 오늘을 고른다.
    func open() {
        guard !started else { return }
        started = true
        let today = CalendarDay.of(now(), timeZone: timeZone)
        uiState.month = today.calendarMonth
        uiState.selectedDay = today
        loadUntilCovered()
    }

    func showPreviousMonth() {
        guard let month = uiState.month else { return }
        changeMonth(month.previous())
    }

    func showNextMonth() {
        guard let month = uiState.month else { return }
        changeMonth(month.next())
    }

    func selectDay(_ day: CalendarDay) { uiState.selectedDay = day }

    func retry() { loadUntilCovered() }

    /// 새 글이 올라왔다. 받아 둔 것을 버리고 보던 달부터 다시 받는다. 열기 전이면 할 일이 없다.
    func refresh() {
        guard started else { return }
        loadTask?.cancel()
        nextPage = 0
        endReached = false
        uiState.posts = []
        loadUntilCovered()
    }

    /// 날짜별 칸 사진. 차단한 사람의 게시물은 뺀다.
    func coverPhotos(hiding authors: Set<Int64> = []) -> [Int: URL] {
        guard let month = uiState.month else { return [:] }
        return uiState.posts.hiding(authors: authors).coverPhotos(in: month, timeZone: timeZone)
    }

    func selectedDayPosts(hiding authors: Set<Int64> = []) -> [MapPost] {
        guard let day = uiState.selectedDay else { return [] }
        return uiState.posts.hiding(authors: authors).posts(on: day, timeZone: timeZone)
    }

    func dateLabel(of date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy. MM. dd."
        return formatter.string(from: date)
    }

    /// 달을 넘기면 그 달 1일을 고른다. 이전 달의 날짜를 들고 가면 아래 목록이 다른 달 글을 보여준다.
    private func changeMonth(_ month: CalendarMonth) {
        uiState.month = month
        uiState.selectedDay = month.day(1)
        loadUntilCovered()
    }

    /// 보고 있는 달 1일보다 오래된 글이 나올 때까지 이어 받는다. 이미 받아 뒀으면 부르지 않는다.
    private func loadUntilCovered() {
        guard let month = uiState.month else { return }
        loadTask?.cancel()
        if isCovered(month) {
            uiState.load = .idle
            return
        }
        uiState.load = .loading
        loadTask = Task { [weak self, repository, mapID] in
            var pages = 0
            do {
                while let self, !self.isCovered(month), pages < Self.maxPages {
                    let page = try await repository.fetchPosts(mapID: mapID, page: self.nextPage, sort: .latest)
                    try Task.checkCancellation()
                    self.nextPage += 1
                    self.endReached = page.isLast
                    // 받는 사이 새 글이 올라오면 페이지 경계가 밀려 앞 페이지의 글이 한 번 더 온다.
                    let known = Set(self.uiState.posts.map(\.id))
                    self.uiState.posts += page.posts.filter { !known.contains($0.id) }
                    pages += 1
                }
                self?.uiState.load = .idle
            } catch {
                guard !Task.isCancelled, !(error is CancellationError) else { return }
                self?.uiState.load = .failed(
                    MapDetailMessage.userMessage(for: error, fallback: MapPostListViewModel.loadFailedMessage)
                )
            }
        }
    }

    /// 시각이 있는 가장 오래된 글이 이 달 1일보다 이르면 그 뒤는 모두 이전 달이다.
    private func isCovered(_ month: CalendarMonth) -> Bool {
        if endReached { return true }
        guard let oldest = uiState.posts.last(where: { $0.createdAt != nil })?.createdAt else { return false }
        return oldest < month.startDate(in: timeZone)
    }
}
