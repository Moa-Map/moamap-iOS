import Foundation
import Testing
@testable import MoaMap

@MainActor
struct TermsAgreementViewModelTests {
    private func loaded(_ repository: TermsRepositoryStub, auth: LoginRepositoryStub = LoginRepositoryStub()) async -> TermsAgreementViewModel {
        let sut = TermsAgreementViewModel(repository: repository, authRepository: auth)
        sut.load()
        await sut.loadTask?.value
        return sut
    }

    @Test func 미동의_필수_약관과_보기_전용_약관을_나눠_그린다() async {
        let sut = await loaded(TermsRepositoryStub())
        #expect(sut.uiState.content == .loaded(
            pending: [TermsRepositoryStub.service, TermsRepositoryStub.age],
            viewOnly: [TermsRepositoryStub.policy]
        ))
        #expect(!sut.uiState.allChecked)
    }

    @Test func 불러오기에_실패하면_다시_시도할_수_있다() async {
        let repository = TermsRepositoryStub()
        repository.terms = { throw NetworkError.connection(.notConnectedToInternet) }
        let sut = await loaded(repository)
        #expect(sut.uiState.content == .failed(TermsAgreementViewModel.loadFailureMessage))

        repository.terms = { [TermsRepositoryStub.policy] }
        sut.load()
        await sut.loadTask?.value
        #expect(sut.uiState.pendingTerms.count == 2)
    }

    @Test func 모두_체크하고_보내면_동의를_마친다() async {
        let repository = TermsRepositoryStub()
        let sut = await loaded(repository)
        var agreedCalls = 0

        sut.submit { agreedCalls += 1 }
        #expect(repository.agreements.isEmpty)

        sut.checkAll()
        #expect(sut.uiState.allChecked)
        sut.submit { agreedCalls += 1 }
        #expect(sut.uiState.isSubmitting)
        await sut.loadTask?.value

        #expect(repository.agreements == [[1, 2]])
        #expect(agreedCalls == 1)
        #expect(!sut.uiState.isSubmitting)
    }

    @Test func 하나씩_체크하고_모두_동의를_다시_누르면_해제된다() async {
        let sut = await loaded(TermsRepositoryStub())
        sut.toggle(TermsRepositoryStub.service)
        #expect(!sut.uiState.allChecked)
        sut.toggle(TermsRepositoryStub.age)
        #expect(sut.uiState.allChecked)
        sut.toggleAll()
        #expect(sut.uiState.checkedIDs.isEmpty)
    }

    @Test func 그사이_약관이_개정되면_다시_불러와_체크를_초기화한다() async {
        let repository = TermsRepositoryStub()
        let sut = await loaded(repository)
        sut.checkAll()
        repository.agreeHandler = { _ in throw NetworkError.server(code: "USER_023", statusCode: 409, message: "원문") }
        repository.status = { TermAgreementStatus(needsAgreement: true, pendingTerms: [TermsRepositoryStub.age]) }
        var agreedCalls = 0

        sut.submit { agreedCalls += 1 }
        await sut.loadTask?.value
        // 다시 불러오기는 409 를 받은 뒤 새 작업으로 돈다.
        await sut.loadTask?.value

        #expect(agreedCalls == 0)
        #expect(repository.statusCalls == 2)
        #expect(sut.uiState.content == .loaded(pending: [TermsRepositoryStub.age], viewOnly: [TermsRepositoryStub.policy]))
        #expect(sut.uiState.checkedIDs.isEmpty)
        #expect(sut.uiState.notice == "약관이 바뀌어 다시 확인해 주세요")
        #expect(!sut.uiState.isSubmitting)
    }

    @Test func 그_밖의_실패는_원문_없이_안내하고_머문다() async {
        let repository = TermsRepositoryStub()
        let sut = await loaded(repository)
        sut.checkAll()
        repository.agreeHandler = { _ in throw NetworkError.server(code: "COMMON_005", statusCode: 500, message: "원문") }
        var agreedCalls = 0

        sut.submit { agreedCalls += 1 }
        await sut.loadTask?.value

        #expect(agreedCalls == 0)
        #expect(sut.uiState.notice == TermsAgreementViewModel.submitFailureMessage)
        #expect(sut.uiState.notice?.contains("COMMON_005") == false)
        #expect(sut.uiState.notice?.contains("원문") == false)
        #expect(sut.uiState.allChecked)
        #expect(!sut.uiState.isSubmitting)
    }

    @Test func 뒤로_가면_로그아웃하고_로그인으로_돌아간다() async {
        let auth = LoginRepositoryStub()
        let sut = await loaded(TermsRepositoryStub(), auth: auth)
        var loggedOutCalls = 0

        sut.leave { loggedOutCalls += 1 }
        #expect(sut.uiState.isLeaving)
        await sut.loadTask?.value

        #expect(auth.logoutCalls == 1)
        #expect(loggedOutCalls == 1)
    }
}
