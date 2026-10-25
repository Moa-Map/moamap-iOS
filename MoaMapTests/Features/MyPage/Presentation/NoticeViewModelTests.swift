import Foundation
import Testing
@testable import MoaMap

@MainActor
struct NoticeListViewModelTests {
    private let seoul = TimeZone(identifier: "Asia/Seoul")!

    @Test func 첫_쪽을_20개씩_받는다() async {
        let repository = NoticeRepositoryStub()
        let sut = NoticeListViewModel(repository: repository, timeZone: seoul)
        sut.load()
        await sut.loadTask?.value
        #expect(sut.uiState.list == .loaded([NoticeRepositoryStub.notice(1)]))
        #expect(sut.uiState.paging == .end)
        #expect(repository.pageRequests.map(\.page) == [0])
        #expect(repository.pageRequests.map(\.size) == [20])
    }

    @Test func 다음_쪽을_붙이고_겹친_공지는_뺀다() async {
        let repository = NoticeRepositoryStub()
        repository.page = { page, _ in
            page == 0
                ? NoticePage(notices: [NoticeRepositoryStub.notice(3), NoticeRepositoryStub.notice(2)], isLast: false)
                : NoticePage(notices: [NoticeRepositoryStub.notice(2), NoticeRepositoryStub.notice(1)], isLast: true)
        }
        let sut = NoticeListViewModel(repository: repository, timeZone: seoul)
        sut.load()
        await sut.loadTask?.value
        sut.loadMore()
        await sut.loadTask?.value
        #expect(sut.uiState.notices.map(\.id) == [3, 2, 1])
        #expect(sut.uiState.paging == .end)
        sut.loadMore()
        #expect(repository.pageRequests.map(\.page) == [0, 1])
    }

    @Test func 다음_쪽이_실패하면_목록은_두고_다시_시도할_수_있다() async {
        let repository = NoticeRepositoryStub()
        repository.page = { page, _ in
            if page == 1 { throw NetworkError.http(statusCode: 500) }
            return NoticePage(notices: [NoticeRepositoryStub.notice(1)], isLast: false)
        }
        let sut = NoticeListViewModel(repository: repository, timeZone: seoul)
        sut.load()
        await sut.loadTask?.value
        sut.loadMore()
        await sut.loadTask?.value
        #expect(sut.uiState.paging == .failed)
        #expect(sut.uiState.notices.map(\.id) == [1])
        sut.loadMore()
        await sut.loadTask?.value
        #expect(repository.pageRequests.map(\.page) == [0, 1, 1])
    }

    @Test func 첫_쪽이_실패하면_안내하고_다음_쪽은_부르지_않는다() async {
        let repository = NoticeRepositoryStub()
        repository.page = { _, _ in throw NetworkError.server(code: "COMMON_005", statusCode: 500, message: "원문") }
        let sut = NoticeListViewModel(repository: repository, timeZone: seoul)
        sut.load()
        await sut.loadTask?.value
        #expect(sut.uiState.list == .failed("공지사항을 불러오지 못했어요"))
        sut.loadMore()
        #expect(repository.pageRequests.count == 1)
    }

    @Test func 오프라인이면_연결_안내를_띄운다() async {
        let repository = NoticeRepositoryStub()
        repository.page = { _, _ in throw NetworkError.connection(.notConnectedToInternet) }
        let sut = NoticeListViewModel(repository: repository, timeZone: seoul)
        sut.load()
        await sut.loadTask?.value
        #expect(sut.uiState.list == .failed("네트워크에 연결할 수 없어요"))
    }

    @Test func 날짜는_기기_시간대로_적고_없으면_뺀다() {
        let sut = NoticeListViewModel(repository: NoticeRepositoryStub(), timeZone: seoul)
        // 2026-10-20T15:00:00Z 는 서울 21일 0시다.
        #expect(sut.dateLabel(of: Date(timeIntervalSince1970: 1_792_508_400)) == "2026.10.21")
        #expect(sut.dateLabel(of: nil) == nil)
    }
}

@MainActor
struct NoticeDetailViewModelTests {
    @Test func 공지를_다시_읽는다() async {
        let sut = NoticeDetailViewModel(noticeID: 5, repository: NoticeRepositoryStub(), timeZone: .gmt)
        sut.load()
        await sut.loadTask?.value
        #expect(sut.uiState == .loaded(NoticeRepositoryStub.notice(5)))
    }

    @Test func 지워진_공지는_삭제_안내를_띄운다() async {
        let repository = NoticeRepositoryStub()
        repository.detail = { _ in throw NetworkError.server(code: "USER_011", statusCode: 404, message: "원문") }
        let sut = NoticeDetailViewModel(noticeID: 5, repository: repository, timeZone: .gmt)
        sut.load()
        await sut.loadTask?.value
        #expect(sut.uiState == .failed("삭제된 공지사항이에요"))
    }

    @Test func 그_밖의_실패는_원문_없이_안내한다() async {
        let repository = NoticeRepositoryStub()
        repository.detail = { _ in throw NetworkError.server(code: "COMMON_005", statusCode: 500, message: "원문") }
        let sut = NoticeDetailViewModel(noticeID: 5, repository: repository, timeZone: .gmt)
        sut.load()
        await sut.loadTask?.value
        #expect(sut.uiState == .failed("공지사항을 불러오지 못했어요"))
    }
}
