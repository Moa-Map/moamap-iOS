import Foundation
import Testing
@testable import MoaMap

@MainActor
struct SettingsViewModelTests {
    @Test func 설정_화면의_ViewModel이_해제되어도_로그인으로_돌아간다() async {
        let repository = LoginRepositoryStub()
        repository.session = true
        let loginViewModel = LoginViewModel(repository: repository)
        loginViewModel.restoreSession()
        let started = AsyncGate()
        let release = AsyncGate()
        repository.logoutHandler = {
            await started.open()
            await release.wait()
        }
        var sut: SettingsViewModel? = SettingsViewModel(repository: repository)
        weak var releasedViewModel = sut
        sut?.logout { loginViewModel.returnToLogin() }
        let pending = sut?.loadTask
        await started.wait()

        sut = nil
        #expect(releasedViewModel == nil)
        #expect(loginViewModel.uiState == .authenticated)
        await release.open()
        await pending?.value

        #expect(loginViewModel.uiState == .idle)
    }

    @Test func 로그아웃에_성공하면_로그인으로_보낼_상태가_된다() async {
        let repository = LoginRepositoryStub()
        let sut = SettingsViewModel(repository: repository)
        sut.logout()
        await sut.loadTask?.value
        #expect(sut.uiState == .loggedOut)
    }

    @Test func 로그아웃에_실패하면_로그인으로_보내지_않고_원문을_숨긴다() async {
        let repository = LoginRepositoryStub()
        repository.logoutHandler = { throw NetworkError.server(code: "COMMON_005", statusCode: 500) }
        let sut = SettingsViewModel(repository: repository)
        var completionCalls = 0
        sut.logout { completionCalls += 1 }
        await sut.loadTask?.value
        #expect(completionCalls == 0)
        guard case .failed(let message) = sut.uiState else { Issue.record("오류 상태가 필요하다"); return }
        #expect(!message.isEmpty)
        #expect(!message.contains("COMMON_005"))
        sut.dismissError()
        #expect(sut.uiState == .idle)
    }

    @Test func 진행_중이거나_끝난_로그아웃은_다시_요청하지_않는다() async {
        let repository = LoginRepositoryStub()
        let release = AsyncGate()
        repository.logoutHandler = { await release.wait() }
        let sut = SettingsViewModel(repository: repository)
        var completionCalls = 0
        sut.logout { completionCalls += 1 }
        let first = sut.loadTask
        sut.logout { completionCalls += 1 }
        #expect(sut.uiState == .loggingOut)
        await release.open()
        await first?.value
        sut.logout { completionCalls += 1 }
        #expect(repository.logoutCalls == 1)
        #expect(completionCalls == 1)
        #expect(sut.uiState == .loggedOut)
    }

    @Test func 실패_후_다시_시도할_수_있다() async {
        let repository = LoginRepositoryStub()
        repository.logoutHandler = { throw URLError(.notConnectedToInternet) }
        let sut = SettingsViewModel(repository: repository)
        sut.logout()
        await sut.loadTask?.value
        repository.logoutHandler = {}
        sut.logout()
        await sut.loadTask?.value
        #expect(repository.logoutCalls == 2)
        #expect(sut.uiState == .loggedOut)
    }
}
