import Foundation
import Testing
@testable import MoaMap

@MainActor
struct KakaoAuthClientTests {
    @Test func 카카오톡_미설치시_계정_로그인을_사용한다() async throws {
        let sut = KakaoAuthClient(isTalkAvailable: { false }, talkLogin: { _ in Issue.record("톡을 열면 안 된다") }, accountLogin: { $0(.success("account")) })
        #expect(try await sut.login() == "account")
    }

    @Test func 카카오톡_실패시_계정_로그인으로_전환한다() async throws {
        let sut = KakaoAuthClient(isTalkAvailable: { true }, talkLogin: { $0(.failure(LoginError.invalidResponse)) }, accountLogin: { $0(.success("account")) })
        #expect(try await sut.login() == "account")
    }

    @Test func 사용자_취소시_다른_로그인창을_열지_않는다() async {
        let sut = KakaoAuthClient(isTalkAvailable: { true }, talkLogin: { $0(.failure(LoginError.cancelled)) }, accountLogin: { _ in Issue.record("취소 후 계정 로그인을 열면 안 된다") })
        await #expect(throws: LoginError.cancelled) { try await sut.login() }
    }

    @Test func 작업_취소를_즉시_전파하고_늦은_콜백을_무시한다() async {
        var callback: KakaoAuthClient.Completion?
        let started = AsyncGate()
        let sut = KakaoAuthClient(isTalkAvailable: { true }, talkLogin: {
            callback = $0
            Task { await started.open() }
        }, accountLogin: { _ in Issue.record("Task 취소 후 폴백하면 안 된다") })
        let task = Task { try await sut.login() }
        await started.wait()
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        callback?(.success("late"))
        callback?(.success("duplicate"))
    }
}
