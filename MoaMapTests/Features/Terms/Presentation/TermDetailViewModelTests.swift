import Foundation
import Testing
@testable import MoaMap

@MainActor
struct TermDetailViewModelTests {
    @Test func 전문을_불러온다() async {
        let sut = TermDetailViewModel(termID: 1, repository: TermsRepositoryStub())
        sut.load()
        await sut.loadTask?.value
        guard case .loaded(let detail) = sut.uiState else { Issue.record("불러온 상태가 필요하다"); return }
        #expect(detail.content == "# 약관 1")
    }

    @Test func 오프라인이면_연결_안내를_띄운다() async {
        let repository = TermsRepositoryStub()
        repository.detail = { _ in throw NetworkError.connection(.notConnectedToInternet) }
        let sut = TermDetailViewModel(termID: 1, repository: repository)
        sut.load()
        await sut.loadTask?.value
        #expect(sut.uiState == .failed("네트워크에 연결할 수 없어요"))
    }

    @Test func 그_밖의_실패는_원문_없이_안내한다() async {
        let repository = TermsRepositoryStub()
        repository.detail = { _ in throw NetworkError.server(code: "USER_020", statusCode: 404, message: "원문") }
        let sut = TermDetailViewModel(termID: 9, repository: repository)
        sut.load()
        await sut.loadTask?.value
        #expect(sut.uiState == .failed("약관을 불러오지 못했어요"))
    }
}
