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
        #expect(sut.uiState == .loading(.kakao))
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

    @Test(arguments: [LoginProvider.kakao, .apple])
    func 로그인_수단을_구분하고_인증_중_다른_로그인도_막는다(provider: LoginProvider) async {
        let repository = LoginRepositoryStub()
        let release = AsyncGate()
        repository.login = { await release.wait() }
        let sut = LoginViewModel(repository: repository)
        start(provider, on: sut)
        let pending = sut.loadTask
        #expect(sut.uiState == .loading(provider))
        #expect(sut.uiState.loadingProvider == provider)
        sut.loginWithKakao()
        sut.loginWithApple()
        await release.open()
        await pending?.value
        #expect(repository.kakaoCalls == (provider == .kakao ? 1 : 0))
        #expect(repository.appleCalls == (provider == .apple ? 1 : 0))
        #expect(sut.uiState == .authenticated)
        #expect(sut.uiState.loadingProvider == nil)
        #expect(sut.loadTask == nil)
        sut.loginWithApple()
        sut.loginWithKakao()
        #expect(repository.calls == 1)
    }

    @Test func Apple_사용자_취소_후_다시_로그인할_수_있다() async {
        let repository = LoginRepositoryStub()
        repository.login = { throw LoginError.cancelled }
        let sut = LoginViewModel(repository: repository)
        sut.loginWithApple()
        await sut.loadTask?.value
        #expect(sut.uiState == .idle)
        #expect(sut.loadTask == nil)
        repository.login = {}
        sut.loginWithApple()
        await sut.loadTask?.value
        #expect(repository.appleCalls == 2)
        #expect(sut.uiState == .authenticated)
    }

    @Test(arguments: [
        NetworkError.http(statusCode: 401),
        .server(code: "USER_008", statusCode: 401),
        .http(statusCode: 503),
        .server(code: "USER_009", statusCode: 503)
    ])
    func Apple_인증실패와_일시적_장애를_구분해_안내한다(error: NetworkError) async {
        let repository = LoginRepositoryStub()
        repository.login = { throw error }
        let sut = LoginViewModel(repository: repository)
        sut.loginWithApple()
        await sut.loadTask?.value
        guard case .failed(let message) = sut.uiState else { Issue.record("오류 안내 필요"); return }
        switch error {
        case .http(401), .server(_, 401): #expect(message.contains("다시 로그인"))
        default: #expect(message.contains("잠시 후"))
        }
        #expect(message.contains("Apple"))
        #expect(!message.contains("USER_"))
        #expect(!message.contains("401"))
        #expect(!message.contains("503"))
        sut.dismissError()
        #expect(sut.uiState == .idle)
    }

    @Test func Apple_일반_실패를_카카오_오류로_표시하지_않는다() async {
        let repository = LoginRepositoryStub()
        repository.login = { throw LoginError.invalidResponse }
        let sut = LoginViewModel(repository: repository)
        sut.loginWithApple()
        await sut.loadTask?.value
        guard case .failed(let message) = sut.uiState else { Issue.record("오류 안내 필요"); return }
        #expect(message.contains("Apple"))
        #expect(!message.contains("카카오"))
    }

    @Test func Apple_네트워크_실패는_연결_확인을_안내한다() async {
        let repository = LoginRepositoryStub()
        repository.login = { throw NetworkError.connection(.notConnectedToInternet) }
        let sut = LoginViewModel(repository: repository)
        sut.loginWithApple()
        await sut.loadTask?.value
        guard case .failed(let message) = sut.uiState else { Issue.record("오류 안내 필요"); return }
        #expect(message.contains("네트워크"))
    }

    @Test func 취소된_Apple_요청이_새_카카오_로그인_상태를_덮지_않는다() async {
        let repository = LoginRepositoryStub()
        let started = AsyncGate()
        let release = AsyncGate()
        repository.login = { await started.open(); await release.wait() }
        let sut = LoginViewModel(repository: repository)
        sut.loginWithApple()
        let old = sut.loadTask
        await started.wait()
        sut.cancelLogin()
        #expect(sut.uiState == .idle)
        repository.login = { throw LoginError.invalidResponse }
        sut.loginWithKakao()
        await sut.loadTask?.value
        let latest = sut.uiState
        await release.open()
        await old?.value
        #expect(repository.appleCalls == 1)
        #expect(repository.kakaoCalls == 1)
        #expect(sut.uiState == latest)
        guard case .failed = latest else { Issue.record("새 요청의 실패 상태 필요"); return }
    }

    @Test func Apple_인증_중_세션_만료는_작업을_취소하고_대기로_돌아온다() async {
        let repository = LoginRepositoryStub()
        let started = AsyncGate()
        let release = AsyncGate()
        repository.login = { await started.open(); await release.wait() }
        let sut = LoginViewModel(repository: repository)
        sut.loginWithApple()
        let pending = sut.loadTask
        await started.wait()
        sut.sessionExpired()
        #expect(pending?.isCancelled == true)
        #expect(sut.loadTask == nil)
        #expect(sut.uiState == .idle)
        await release.open()
        await pending?.value
        #expect(sut.uiState == .idle)
    }

    private func start(_ provider: LoginProvider, on model: LoginViewModel) {
        switch provider {
        case .kakao: model.loginWithKakao()
        case .apple: model.loginWithApple()
        }
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
    private(set) var kakaoCalls = 0
    private(set) var appleCalls = 0
    var calls: Int { kakaoCalls + appleCalls }
    func loginWithKakao() async throws { kakaoCalls += 1; try await login() }
    func loginWithApple() async throws { appleCalls += 1; try await login() }
    func hasSession() throws -> Bool { session }
}
