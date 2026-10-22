import Foundation
import Testing
@testable import MoaMap

@MainActor
struct TermsGateViewModelTests {
    @Test func 동의가_필요하면_동의_화면으로_보낸다() async {
        let repository = TermsRepositoryStub()
        let auth = LoginRepositoryStub()
        let sut = TermsGateViewModel(repository: repository, authRepository: auth)
        sut.check()
        #expect(sut.state == .checking)
        await sut.loadTask?.value
        #expect(sut.state == .needsAgreement)
    }

    @Test func 동의가_필요없으면_통과한다() async {
        let repository = TermsRepositoryStub()
        let auth = LoginRepositoryStub()
        repository.status = { TermAgreementStatus(needsAgreement: false, pendingTerms: []) }
        let sut = TermsGateViewModel(repository: repository, authRepository: auth)
        sut.check()
        await sut.loadTask?.value
        #expect(sut.state == .passed)
    }

    @Test func 확인에_실패하면_원문_없이_안내하고_다시_시도할_수_있다() async {
        let repository = TermsRepositoryStub()
        let auth = LoginRepositoryStub()
        repository.status = { throw NetworkError.server(code: "COMMON_005", statusCode: 500, message: "원문") }
        let sut = TermsGateViewModel(repository: repository, authRepository: auth)
        sut.check()
        await sut.loadTask?.value
        #expect(sut.state == .failed("약관 동의 여부를 확인하지 못했어요"))

        repository.status = { TermAgreementStatus(needsAgreement: false, pendingTerms: []) }
        sut.check()
        await sut.loadTask?.value
        #expect(sut.state == .passed)
        #expect(repository.statusCalls == 2)
    }

    @Test func 네트워크가_끊겨도_실패로_남는다() async {
        let repository = TermsRepositoryStub()
        let auth = LoginRepositoryStub()
        repository.status = { throw NetworkError.connection(.notConnectedToInternet) }
        let sut = TermsGateViewModel(repository: repository, authRepository: auth)
        sut.check()
        await sut.loadTask?.value
        #expect(sut.state.failureMessage != nil)
    }

    @Test(arguments: [NetworkError.http(statusCode: 401), .server(code: "AUTH_001", statusCode: 401)])
    func 갱신이_거절돼_세션이_비었으면_로그인으로_보낸다(error: NetworkError) async {
        let repository = TermsRepositoryStub()
        let auth = LoginRepositoryStub()
        auth.session = false
        repository.status = { throw error }
        let sut = TermsGateViewModel(repository: repository, authRepository: auth)
        sut.check()
        await sut.loadTask?.value
        #expect(sut.state == .unauthorized)
    }

    @Test func 갱신이_일시_장애로_끝난_401_은_세션을_두고_다시_시도하게_한다() async {
        let repository = TermsRepositoryStub()
        let auth = LoginRepositoryStub()
        auth.session = true
        repository.status = { throw NetworkError.http(statusCode: 401) }
        let sut = TermsGateViewModel(repository: repository, authRepository: auth)
        sut.check()
        await sut.loadTask?.value
        #expect(sut.state == .failed(TermsGateViewModel.failureMessage))
        #expect(auth.logoutCalls == 0)

        repository.status = { TermAgreementStatus(needsAgreement: false, pendingTerms: []) }
        sut.check()
        await sut.loadTask?.value
        #expect(sut.state == .passed)
    }

    @Test func 초기화하면_진행_중인_확인이_상태를_덮지_않는다() async {
        let repository = TermsRepositoryStub()
        let auth = LoginRepositoryStub()
        let release = AsyncGate()
        repository.status = {
            await release.wait()
            return TermAgreementStatus(needsAgreement: true, pendingTerms: [])
        }
        let sut = TermsGateViewModel(repository: repository, authRepository: auth)
        sut.check()
        let pending = sut.loadTask
        sut.reset()
        await release.open()
        await pending?.value
        #expect(sut.state == .idle)
    }
}
