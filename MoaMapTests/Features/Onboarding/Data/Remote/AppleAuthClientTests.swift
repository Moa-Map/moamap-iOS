import AuthenticationServices
import Foundation
import Testing
@testable import MoaMap

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct AppleAuthClientTests {
    @Test func nonce를_인증창에_그대로_전달하고_결과를_반환한다() async throws {
        let session = AppleAuthorizationSessionStub()
        session.onStart = { _, completion in
            completion(.success(AppleLoginCredential(identityToken: "identity", authorizationCode: "code", fullName: nil)))
        }
        let sut = AppleAuthClient(makeSession: { session })
        let credential = try await sut.login(nonce: "server-nonce")
        #expect(session.nonces == ["server-nonce"])
        #expect(credential.identityToken == "identity")
        #expect(credential.authorizationCode == "code")
        #expect(credential.fullName == nil)
    }

    @Test func 사용자_취소를_그대로_전달한다() async {
        let session = AppleAuthorizationSessionStub()
        session.onStart = { _, completion in completion(.failure(LoginError.cancelled)) }
        let sut = AppleAuthClient(makeSession: { session })
        await #expect(throws: LoginError.cancelled) { try await sut.login(nonce: "nonce") }
    }

    @Test func 표시할_창이_없으면_오류를_전달한다() async {
        let sut = AppleAuthClient(makeSession: { throw LoginError.notConfigured })
        await #expect(throws: LoginError.notConfigured) { try await sut.login(nonce: "nonce") }
    }

    @Test func 작업_취소는_인증창을_닫고_늦은_콜백을_무시한다() async {
        let session = AppleAuthorizationSessionStub()
        let started = AsyncGate()
        var callback: AppleAuthorizationSession.Completion?
        session.onStart = { _, completion in
            callback = completion
            Task { await started.open() }
        }
        let sut = AppleAuthClient(makeSession: { session })
        let task = Task {
            do { return try await sut.login(nonce: "nonce") }
            catch { await started.open(); throw error }
        }
        await started.wait()
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(session.cancelCount == 1)
        callback?(.success(AppleLoginCredential(identityToken: "late", authorizationCode: "late", fullName: nil)))
        callback?(.failure(LoginError.cancelled))
    }

    @Test func 이전_요청의_늦은_콜백은_새_인증에_영향을_주지_않는다() async throws {
        let old = AppleAuthorizationSessionStub()
        let current = AppleAuthorizationSessionStub()
        let started = AsyncGate()
        var oldCallback: AppleAuthorizationSession.Completion?
        old.onStart = { _, completion in
            oldCallback = completion
            Task { await started.open() }
        }
        var sessions = [old, current]
        let sut = AppleAuthClient(makeSession: { sessions.removeFirst() })
        let task = Task {
            do { return try await sut.login(nonce: "old") }
            catch { await started.open(); throw error }
        }
        await started.wait()
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        current.onStart = { _, completion in
            oldCallback?(.success(AppleLoginCredential(identityToken: "old", authorizationCode: "old", fullName: nil)))
            completion(.success(AppleLoginCredential(identityToken: "new", authorizationCode: "new", fullName: nil)))
            completion(.failure(LoginError.cancelled))
        }
        let credential = try await sut.login(nonce: "new")
        #expect(credential.identityToken == "new")
        #expect(current.cancelCount == 0)
    }

    @Test func 이미_취소된_작업은_인증창을_만들지_않는다() async {
        let release = AsyncGate()
        let sut = AppleAuthClient(makeSession: {
            Issue.record("취소된 요청의 인증창 생성")
            return AppleAuthorizationSessionStub()
        })
        let task = Task { await release.wait(); return try await sut.login(nonce: "nonce") }
        task.cancel()
        await release.open()
        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test func Apple_요청은_원문_nonce와_이름_이메일_scope를_포함한다() {
        let request = SystemAppleAuthorizationSession.makeRequest(nonce: "server-issued-nonce")
        #expect(request.nonce == "server-issued-nonce")
        #expect(Set(request.requestedScopes ?? []) == Set([.fullName, .email]))
    }

    @Test(arguments: [nil, PersonNameComponents(), PersonNameComponents(givenName: "Taylor")])
    func Apple_응답을_서버에_전달할_문자열로_변환한다(name: PersonNameComponents?) throws {
        let result = try SystemAppleAuthorizationSession.credential(
            identityToken: Data("identity".utf8), authorizationCode: Data("code".utf8), fullName: name
        )
        #expect(result.identityToken == "identity")
        #expect(result.authorizationCode == "code")
        #expect(result.fullName == (name?.givenName == nil ? nil : "Taylor"))
    }

    @Test(arguments: [nil, Data(), Data([0xff])])
    func 누락되거나_UTF8이_아닌_인증정보를_거부한다(data: Data?) {
        #expect(throws: LoginError.invalidResponse) {
            try SystemAppleAuthorizationSession.credential(identityToken: data, authorizationCode: Data("code".utf8), fullName: nil)
        }
        #expect(throws: LoginError.invalidResponse) {
            try SystemAppleAuthorizationSession.credential(identityToken: Data("identity".utf8), authorizationCode: data, fullName: nil)
        }
    }

    @Test func Apple_사용자_취소를_로그인_취소로_변환한다() {
        let error = SystemAppleAuthorizationSession.loginError(ASAuthorizationError(.canceled))
        #expect(error as? LoginError == .cancelled)
        let failed = SystemAppleAuthorizationSession.loginError(ASAuthorizationError(.failed))
        #expect((failed as? ASAuthorizationError)?.code == .failed)
    }
}

@MainActor
private final class AppleAuthorizationSessionStub: AppleAuthorizationSession {
    var onStart: (String, @escaping Completion) -> Void = { _, _ in }
    private(set) var nonces: [String] = []
    private(set) var cancelCount = 0

    func start(nonce: String, completion: @escaping Completion) {
        nonces.append(nonce)
        onStart(nonce, completion)
    }
    func cancel() { cancelCount += 1 }
}
