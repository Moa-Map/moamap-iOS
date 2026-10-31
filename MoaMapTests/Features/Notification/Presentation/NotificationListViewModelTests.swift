import Foundation
import Testing
@testable import MoaMap

@MainActor
struct NotificationListViewModelTests {
    private typealias Stub = NotificationRepositoryStub

    private func makeSUT(_ repository: NotificationRepositoryStub) -> NotificationListViewModel {
        NotificationListViewModel(repository: repository, timeZone: .gmt, now: { Date(timeIntervalSince1970: 30) })
    }

    @Test func 첫_쪽을_20개씩_받는다() async {
        let repository = Stub()
        let sut = makeSUT(repository)
        sut.load()
        await sut.loadTask?.value
        #expect(sut.uiState.list == .loaded([Stub.notification(1)]))
        #expect(sut.uiState.paging == .end)
        #expect(repository.pageRequests.map(\.page) == [0])
        #expect(repository.pageRequests.map(\.size) == [20])
    }

    @Test func 다음_쪽을_붙이고_겹친_알림은_뺀다() async {
        let repository = Stub()
        repository.page = { page, _ in
            page == 0
                ? NotificationPage(notifications: [Stub.notification(3), Stub.notification(2)], isLast: false)
                : NotificationPage(notifications: [Stub.notification(2), Stub.notification(1)], isLast: true)
        }
        let sut = makeSUT(repository)
        sut.load()
        await sut.loadTask?.value
        sut.loadMore()
        await sut.loadTask?.value
        #expect(sut.uiState.notifications.map(\.id) == [3, 2, 1])
        #expect(sut.uiState.paging == .end)
        sut.loadMore()
        #expect(repository.pageRequests.map(\.page) == [0, 1])
    }

    @Test func 다음_쪽이_실패하면_목록은_두고_다시_시도할_수_있다() async {
        let repository = Stub()
        repository.page = { page, _ in
            if page == 1 { throw NetworkError.http(statusCode: 500) }
            return NotificationPage(notifications: [Stub.notification(1)], isLast: false)
        }
        let sut = makeSUT(repository)
        sut.load()
        await sut.loadTask?.value
        sut.loadMore()
        await sut.loadTask?.value
        #expect(sut.uiState.paging == .failed)
        #expect(sut.uiState.notifications.map(\.id) == [1])
        sut.loadMore()
        await sut.loadTask?.value
        #expect(repository.pageRequests.map(\.page) == [0, 1, 1])
    }

    @Test func 첫_쪽이_실패하면_서버_문구_대신_안내하고_다음_쪽은_부르지_않는다() async {
        let repository = Stub()
        repository.page = { _, _ in throw NetworkError.server(code: "COMMON_005", statusCode: 500, message: "원문") }
        let sut = makeSUT(repository)
        sut.load()
        await sut.loadTask?.value
        #expect(sut.uiState.list == .failed("알림을 불러오지 못했어요"))
        sut.loadMore()
        #expect(repository.pageRequests.count == 1)
    }

    @Test func 오프라인이면_연결_안내를_띄운다() async {
        let repository = Stub()
        repository.page = { _, _ in throw NetworkError.connection(.notConnectedToInternet) }
        let sut = makeSUT(repository)
        sut.load()
        await sut.loadTask?.value
        #expect(sut.uiState.list == .failed("네트워크에 연결할 수 없어요"))
    }

    @Test func 안_읽은_알림을_누르면_바로_읽음으로_바꾸고_갈_곳을_돌려준다() async {
        let repository = Stub()
        let sut = makeSUT(repository)
        sut.load()
        await sut.loadTask?.value
        let destination = sut.open(Stub.notification(1))
        #expect(destination == .map(mapID: 10))
        #expect(sut.uiState.notifications.map(\.read) == [true])
        await sut.readTask?.value
        #expect(repository.readIDs == [1])
    }

    @Test func 읽음_요청이_실패해도_되돌리지_않는다() async {
        let repository = Stub()
        repository.read = { _ in throw NetworkError.http(statusCode: 500) }
        let sut = makeSUT(repository)
        sut.load()
        await sut.loadTask?.value
        _ = sut.open(Stub.notification(1))
        await sut.readTask?.value
        #expect(sut.uiState.notifications.map(\.read) == [true])
    }

    @Test func 이미_읽은_알림은_서버에_다시_알리지_않는다() async {
        let repository = Stub()
        let read = Stub.notification(1, read: true)
        repository.page = { _, _ in NotificationPage(notifications: [read], isLast: true) }
        let sut = makeSUT(repository)
        sut.load()
        await sut.loadTask?.value
        _ = sut.open(read)
        #expect(sut.readTask == nil)
        #expect(repository.readIDs.isEmpty)
    }

    @Test func 모두_읽음이_실패하면_안_읽었던_알림만_되돌린다() async {
        let repository = Stub()
        repository.page = { _, _ in
            NotificationPage(notifications: [Stub.notification(2), Stub.notification(1, read: true)], isLast: true)
        }
        repository.readAll = { throw NetworkError.http(statusCode: 500) }
        let sut = makeSUT(repository)
        sut.load()
        await sut.loadTask?.value
        sut.markAllRead()
        #expect(sut.uiState.notifications.map(\.read) == [true, true])
        await sut.readAllTask?.value
        #expect(sut.uiState.notifications.map(\.read) == [false, true])
        #expect(repository.readAllCount == 1)
    }

    @Test func 안_읽은_알림이_없으면_모두_읽음을_보내지_않는다() async {
        let repository = Stub()
        repository.page = { _, _ in NotificationPage(notifications: [Stub.notification(1, read: true)], isLast: true) }
        let sut = makeSUT(repository)
        sut.load()
        await sut.loadTask?.value
        sut.markAllRead()
        #expect(sut.readAllTask == nil)
        #expect(repository.readAllCount == 0)
    }

    @Test func 시각은_주입한_지금을_기준으로_적고_없으면_뺀다() {
        let sut = makeSUT(Stub())
        #expect(sut.timeLabel(of: Date(timeIntervalSince1970: 0)) == "방금")
        #expect(sut.timeLabel(of: nil) == nil)
    }
}
