import Foundation
import Testing
@testable import MoaMap

@MainActor
struct MapPostCalendarViewModelTests {
    private let today = utcDate(2026, 8, 20)

    private func viewModel(_ pages: [MapPostPage], failingPage: Int? = nil) -> (MapPostCalendarViewModel, MapPostRepositoryStub) {
        let repository = MapPostRepositoryStub()
        repository.pages = [.latest: pages]
        repository.failingPage = failingPage
        let sut = MapPostCalendarViewModel(mapID: 7, repository: repository, timeZone: calendarUTC, now: { today })
        return (sut, repository)
    }

    @Test func 처음_열면_오늘이_있는_달을_보여주고_오늘을_고른다() async {
        let (sut, _) = viewModel([])
        sut.open()
        await sut.loadTask?.value
        #expect(sut.uiState.month == CalendarMonth(year: 2026, month: 8))
        #expect(sut.uiState.selectedDay == CalendarDay(year: 2026, month: 8, day: 20))
    }

    @Test func 오늘은_주입한_시간대로_정한다() {
        let repository = MapPostRepositoryStub()
        let lastNight = utcDate(2026, 8, 31, hour: 20)
        let sut = MapPostCalendarViewModel(
            mapID: 7, repository: repository, timeZone: TimeZone(identifier: "Asia/Seoul")!, now: { lastNight }
        )
        sut.open()
        #expect(sut.uiState.selectedDay == CalendarDay(year: 2026, month: 9, day: 1))
    }

    @Test func 이_달보다_오래된_글이_나올_때까지만_최신순으로_이어_받는다() async {
        let (sut, repository) = viewModel([
            MapPostPage(posts: [calendarPost(5, utcDate(2026, 8, 20)), calendarPost(4, utcDate(2026, 8, 10))], isLast: false),
            MapPostPage(posts: [calendarPost(3, utcDate(2026, 8, 2)), calendarPost(2, utcDate(2026, 7, 30))], isLast: false),
            MapPostPage(posts: [calendarPost(1, utcDate(2026, 7, 1))], isLast: true)
        ])
        sut.open()
        #expect(sut.uiState.load == .loading)
        await sut.loadTask?.value
        #expect(repository.requests == [.init(page: 0, sort: .latest), .init(page: 1, sort: .latest)])
        #expect(sut.uiState.posts.map(\.id) == [5, 4, 3, 2])
        #expect(sut.uiState.load == .idle)
    }

    @Test func 이전_달로_가면_그_달_1일을_고르고_필요한_만큼_더_받는다() async {
        let (sut, repository) = viewModel([
            MapPostPage(posts: [calendarPost(3, utcDate(2026, 8, 5)), calendarPost(2, utcDate(2026, 7, 25))], isLast: false),
            MapPostPage(posts: [calendarPost(1, utcDate(2026, 6, 30))], isLast: false)
        ])
        sut.open()
        await sut.loadTask?.value
        #expect(repository.requests.count == 1)

        sut.showPreviousMonth()
        await sut.loadTask?.value
        #expect(sut.uiState.month == CalendarMonth(year: 2026, month: 7))
        #expect(sut.uiState.selectedDay == CalendarDay(year: 2026, month: 7, day: 1))
        #expect(repository.requests.map(\.page) == [0, 1])
        #expect(sut.uiState.posts.map(\.id) == [3, 2, 1])
    }

    @Test func 이미_받아_둔_달로_돌아오면_다시_받지_않는다() async {
        let (sut, repository) = viewModel([
            MapPostPage(posts: [calendarPost(2, utcDate(2026, 8, 5)), calendarPost(1, utcDate(2026, 6, 1))], isLast: false)
        ])
        sut.open()
        await sut.loadTask?.value
        sut.showPreviousMonth()
        await sut.loadTask?.value
        sut.showNextMonth()
        await sut.loadTask?.value
        #expect(repository.requests.count == 1)
        #expect(sut.uiState.month == CalendarMonth(year: 2026, month: 8))
    }

    @Test func 마지막_페이지를_받았으면_이전_달로_가도_더_부르지_않는다() async {
        let (sut, repository) = viewModel([MapPostPage(posts: [calendarPost(1, utcDate(2026, 8, 5))], isLast: true)])
        sut.open()
        await sut.loadTask?.value
        sut.showPreviousMonth()
        await sut.loadTask?.value
        #expect(repository.requests.count == 1)
        #expect(sut.uiState.load == .idle)
    }

    @Test func 해를_넘겨_이전_달로_간다() async {
        let (sut, _) = viewModel([])
        sut.open()
        for _ in 0..<8 { sut.showPreviousMonth() }
        await sut.loadTask?.value
        #expect(sut.uiState.month == CalendarMonth(year: 2025, month: 12))
        #expect(sut.uiState.selectedDay == CalendarDay(year: 2025, month: 12, day: 1))
    }

    @Test func 두_번_열어도_한_번만_받는다() async {
        let (sut, repository) = viewModel([])
        sut.open()
        sut.open()
        await sut.loadTask?.value
        #expect(repository.requests.count == 1)
    }

    @Test func 날짜를_고르면_그날_게시물만_보여준다() async {
        let (sut, _) = viewModel([MapPostPage(posts: [
            calendarPost(3, utcDate(2026, 8, 20), photo: "https://cdn/20.jpg"),
            calendarPost(2, utcDate(2026, 8, 3)),
            calendarPost(1, utcDate(2026, 7, 1))
        ], isLast: true)])
        sut.open()
        await sut.loadTask?.value
        #expect(sut.selectedDayPosts().map(\.id) == [3])
        #expect(sut.coverPhotos() == [20: URL(string: "https://cdn/20.jpg")!])

        sut.selectDay(CalendarDay(year: 2026, month: 8, day: 3))
        #expect(sut.uiState.selectedDay == CalendarDay(year: 2026, month: 8, day: 3))
        #expect(sut.selectedDayPosts().map(\.id) == [2])
    }

    @Test func 못_받으면_안내를_남기고_재시도하면_이어_받는다() async {
        let (sut, repository) = viewModel(
            [MapPostPage(posts: [calendarPost(1, utcDate(2026, 7, 1))], isLast: true)], failingPage: 0
        )
        sut.open()
        await sut.loadTask?.value
        #expect(sut.uiState.load == .failed(MapPostListViewModel.loadFailedMessage))

        repository.failingPage = nil
        sut.retry()
        await sut.loadTask?.value
        #expect(sut.uiState.load == .idle)
        #expect(sut.uiState.posts.map(\.id) == [1])
    }

    @Test func 새_게시물이_올라오면_처음부터_다시_받는다() async {
        let (sut, repository) = viewModel([MapPostPage(posts: [calendarPost(1, utcDate(2026, 7, 1))], isLast: true)])
        sut.open()
        await sut.loadTask?.value
        repository.pages = [.latest: [
            MapPostPage(posts: [calendarPost(2, utcDate(2026, 8, 20)), calendarPost(1, utcDate(2026, 7, 1))], isLast: true)
        ]]
        sut.refresh()
        await sut.loadTask?.value
        #expect(repository.requests.map(\.page) == [0, 0])
        #expect(sut.uiState.posts.map(\.id) == [2, 1])
    }

    @Test func 달력을_열기_전에는_새로고침해도_받지_않는다() async {
        let (sut, repository) = viewModel([])
        sut.refresh()
        await sut.loadTask?.value
        #expect(repository.requests.isEmpty)
    }

    @Test func 날짜는_점으로_적는다() {
        let (sut, _) = viewModel([])
        #expect(sut.dateLabel(of: utcDate(2026, 8, 5)) == "2026. 08. 05.")
        #expect(sut.dateLabel(of: nil) == nil)
    }
}
