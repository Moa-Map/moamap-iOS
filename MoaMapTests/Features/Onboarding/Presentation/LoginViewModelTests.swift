import Foundation
import Testing
@testable import MoaMap

@MainActor
struct LoginViewModelTests {
    @Test func 중복_로그인을_막고_성공_상태를_반영한다() async {
        let repository = LoginRepositoryStub()
        let release = AsyncGate()
        repository.login = { await release.wait() }
        let sut = LoginViewModel(repository: repository)
        sut.loginWithKakao()
        let first = sut.loadTask
        sut.loginWithKakao()
        #expect(sut.uiState == .loading)
        await release.open()
        await first?.value
        #expect(repository.calls == 1)
        #expect(sut.uiState == .authenticated)
    }

    @Test func 사용자_취소는_오류없이_다시_시도할_수_있다() async {
        let repository = LoginRepositoryStub()
        repository.login = { throw LoginError.cancelled }
        let sut = LoginViewModel(repository: repository)
        sut.loginWithKakao()
        await sut.loadTask?.value
        #expect(sut.uiState == .idle)
        repository.login = {}
        sut.loginWithKakao()
        await sut.loadTask?.value
        #expect(sut.uiState == .authenticated)
    }

    @Test func 서버_오류_원문을_노출하지_않는다() async {
        let repository = LoginRepositoryStub()
        repository.login = { throw NetworkError.server(code: "COMMON_005", statusCode: 500) }
        let sut = LoginViewModel(repository: repository)
        sut.loginWithKakao()
        await sut.loadTask?.value
        guard case .failed(let message) = sut.uiState else { Issue.record("오류 상태가 필요하다"); return }
        #expect(!message.isEmpty)
        #expect(!message.contains("COMMON_005"))
        #expect(!message.contains("500"))
        sut.dismissError()
        #expect(sut.uiState == .idle)
    }

    @Test func 취소된_이전_요청이_새로운_상태를_덮지_않는다() async {
        let repository = LoginRepositoryStub()
        let started = AsyncGate()
        let release = AsyncGate()
        repository.login = { await started.open(); await release.wait() }
        let sut = LoginViewModel(repository: repository)
        sut.loginWithKakao()
        let old = sut.loadTask
        await started.wait()
        sut.cancelLogin()
        repository.login = { throw LoginError.invalidResponse }
        sut.loginWithKakao()
        await sut.loadTask?.value
        let latest = sut.uiState
        await release.open()
        await old?.value
        #expect(sut.uiState == latest)
        guard case .failed = latest else { Issue.record("새 요청의 실패 상태가 필요하다"); return }
    }

    @Test func 저장된_세션을_복원하고_만료시_로그인으로_돌아온다() {
        let repository = LoginRepositoryStub()
        repository.session = true
        let sut = LoginViewModel(repository: repository)
        sut.restoreSession()
        #expect(sut.uiState == .authenticated)
        sut.sessionExpired()
        #expect(sut.uiState == .idle)
    }
}

@MainActor
final class LoginRepositoryStub: AuthRepository {
    var login: () async throws -> Void = {}
    var session = false
    private(set) var calls = 0
    func loginWithKakao() async throws { calls += 1; try await login() }
    func loginWithApple() async throws { calls += 1; try await login() }
    func hasSession() throws -> Bool { session }
}
