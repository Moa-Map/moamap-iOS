import Foundation
import Testing
@testable import MoaMap

@MainActor
struct ModerationViewModelTests {
    private let reports = ReportRepositoryStub()
    private let blocks = BlockRepositoryStub()

    private func viewModel() -> (ModerationViewModel, BlockedUserStore) {
        let store = BlockedUserStore(repository: blocks)
        return (ModerationViewModel(reportRepository: reports, blockedUsers: store), store)
    }

    @Test func 신고하면_팝업을_닫고_접수_토스트를_띄운다() async {
        let (sut, _) = viewModel()
        let target = ReportTarget.placeComment(placeID: 3, commentID: 5)
        sut.askReport(target, title: "댓글 신고하기")
        #expect(sut.prompt == .report(target, title: "댓글 신고하기"))
        sut.report(reason: .other, detail: "광고예요")
        #expect(sut.submitting)
        await sut.task?.value
        #expect(reports.sent.map(\.target) == [target])
        #expect(reports.sent.first?.reason == .other)
        #expect(reports.sent.first?.detail == "광고예요")
        #expect(sut.prompt == nil)
        #expect(sut.toast == ToastMessage(text: "신고가 접수됐어요"))
        #expect(!sut.submitting)
    }

    @Test func 신고가_거절되면_팝업을_닫고_체크_없이_안내한다() async {
        reports.report = { _ in throw NetworkError.server(code: "PLACE_019", statusCode: 409, message: "이미 신고한 댓글입니다.") }
        let (sut, _) = viewModel()
        sut.askReport(.placeComment(placeID: 3, commentID: 5), title: "댓글 신고하기")
        sut.report(reason: .spam, detail: nil)
        await sut.task?.value
        #expect(sut.prompt == nil)
        #expect(sut.toast == .failure("이미 신고했어요"))
    }

    @Test func 차단하면_바로_가릴_사람에_넣고_닉네임으로_알린다() async {
        let (sut, store) = viewModel()
        sut.askBlock(userID: 7, nickname: "모아")
        sut.confirmBlock()
        await sut.task?.value
        #expect(blocks.blocked == [7])
        #expect(store.ids == [7])
        #expect(sut.prompt == nil)
        #expect(sut.toast == ToastMessage(text: "모아님을 차단했어요"))
    }

    @Test func 차단에_실패하면_가리지_않는다() async {
        blocks.block = { _ in throw NetworkError.connection(.notConnectedToInternet) }
        let (sut, store) = viewModel()
        sut.askBlock(userID: 7, nickname: nil)
        sut.confirmBlock()
        await sut.task?.value
        #expect(store.ids.isEmpty)
        #expect(sut.toast == .failure("네트워크에 연결할 수 없어요"))
    }

    @Test func 보내는_동안에는_닫거나_다른_팝업을_열지_않는다() async {
        let (sut, _) = viewModel()
        sut.askBlock(userID: 7, nickname: "모아")
        sut.confirmBlock()
        sut.dismiss()
        sut.askReport(.user(userID: 7), title: "신고하기")
        #expect(sut.prompt == .block(userID: 7, nickname: "모아"))
        await sut.task?.value
        #expect(blocks.blocked == [7])
    }

    @Test func 팝업이_없으면_보내지_않는다() {
        let (sut, _) = viewModel()
        sut.report(reason: .spam, detail: nil)
        sut.confirmBlock()
        #expect(sut.task == nil)
        #expect(reports.sent.isEmpty)
    }

    @Test func 다른_일의_결과도_같은_토스트로_띄우고_비운다() {
        let (sut, _) = viewModel()
        sut.notify(ToastMessage(text: "댓글을 삭제했어요"))
        #expect(sut.toast == ToastMessage(text: "댓글을 삭제했어요"))
        sut.consumeToast()
        #expect(sut.toast == nil)
    }
}
