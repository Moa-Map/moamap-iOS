import Foundation
import Testing
@testable import MoaMap

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct AppleLoginRepositoryTests {
    private let nonce = "abcdefghijklmnopqrstuvwxyz0123456789ABCDEFG"
    private let success = #"{"success":true,"data":{"userId":42,"accessToken":"access","refreshToken":"refresh","tokenType":"Bearer","expiresIn":1800,"refreshTokenExpiresIn":1209600,"isNewUser":true}}"#

    private func repository(
        transport: @escaping APIClient.Transport,
        tokens: any AuthTokenStore = MemoryAuthTokenStore(),
        users: any CurrentUserStore = MemoryCurrentUserStore(),
        authorize: @escaping (String) async throws -> AppleLoginCredential
    ) throws -> AuthRepositoryImpl {
        let client = APIClient(configuration: try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"]), transport: transport)
        return AuthRepositoryImpl(client: client, kakaoLogin: { throw LoginError.notConfigured },
                                  appleLogin: authorize, tokenStore: tokens, currentUserStore: users)
    }

    @Test(arguments: ["홍길동", nil])
    func 서버_nonce를_그대로_전달하고_로그인_결과를_저장한다(name: String?) async throws {
        let requests = AppleRequestLog()
        let tokens = MemoryAuthTokenStore()
        let users = MemoryCurrentUserStore()
        let nonce = nonce
        let body = success
        let sut = try repository(transport: { request in
            await requests.append(request)
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            if request.url?.path == "/api/v1/auth/apple/nonce" {
                #expect(request.httpBody == nil)
                return try appleResponse(request, body: "{\"success\":true,\"data\":{\"nonce\":\"\(nonce)\",\"expiresIn\":300}}")
            }
            #expect(request.url?.path == "/api/v1/auth/apple/login")
            let payload = try JSONSerialization.jsonObject(with: #require(request.httpBody)) as? [String: String]
            var expected = ["identityToken": "identity", "authorizationCode": "code", "nonce": nonce]
            expected["fullName"] = name
            #expect(payload == expected)
            return try appleResponse(request, body: body)
        }, tokens: tokens, users: users) { received in
            #expect(received == nonce)
            return AppleLoginCredential(identityToken: "identity", authorizationCode: "code", fullName: name)
        }
        try await sut.loginWithApple()
        #expect(await requests.paths == ["/api/v1/auth/apple/nonce", "/api/v1/auth/apple/login"])
        #expect(try tokens.load() == AuthToken(accessToken: "access", refreshToken: "refresh"))
        #expect(try users.load() == 42)
        #expect(try sut.hasSession())
    }

    @Test(arguments: [401, 503])
    func nonce_발급_실패시_Apple_인증을_시작하지_않는다(status: Int) async throws {
        let sut = try repository(transport: { request in
            try appleResponse(request, status: status, body: "")
        }) { _ in
            Issue.record("nonce 발급 실패 후 인증을 시작하면 안 된다")
            throw LoginError.invalidResponse
        }
        await #expect(throws: NetworkError.http(statusCode: status)) { try await sut.loginWithApple() }
        #expect(try !sut.hasSession())
    }

    @Test(arguments: ["", "bad-nonce"])
    func 잘못된_nonce로_인증을_시작하지_않는다(value: String) async throws {
        let sut = try repository(transport: { request in
            try appleResponse(request, body: "{\"success\":true,\"data\":{\"nonce\":\"\(value)\",\"expiresIn\":300}}")
        }) { _ in
            Issue.record("유효하지 않은 nonce")
            throw LoginError.cancelled
        }
        await #expect(throws: LoginError.invalidResponse) { try await sut.loginWithApple() }
    }

    @Test func 사용자_취소_후_재시도는_nonce부터_다시_발급한다() async throws {
        let requests = AppleRequestLog()
        let nonce = nonce
        let sut = try repository(transport: { request in
            await requests.append(request)
            return try appleResponse(request, body: "{\"success\":true,\"data\":{\"nonce\":\"\(nonce)\",\"expiresIn\":300}}")
        }) { _ in throw LoginError.cancelled }
        for _ in 0..<2 {
            await #expect(throws: LoginError.cancelled) { try await sut.loginWithApple() }
        }
        #expect(await requests.paths == ["/api/v1/auth/apple/nonce", "/api/v1/auth/apple/nonce"])
        #expect(try !sut.hasSession())
    }

    @Test func 취소된_Apple_응답은_서버로_전달하지_않는다() async throws {
        let started = AsyncGate()
        let release = AsyncGate()
        let requests = AppleRequestLog()
        let nonce = nonce
        let sut = try repository(transport: { request in
            await requests.append(request)
            return try appleResponse(request, body: "{\"success\":true,\"data\":{\"nonce\":\"\(nonce)\",\"expiresIn\":300}}")
        }) { _ in
            await started.open()
            await release.wait()
            return AppleLoginCredential(identityToken: "identity", authorizationCode: "code", fullName: nil)
        }
        let task = Task {
            do { try await sut.loginWithApple() }
            catch { await started.open(); throw error }
        }
        await started.wait()
        task.cancel()
        await release.open()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(await requests.paths == ["/api/v1/auth/apple/nonce"])
        #expect(try !sut.hasSession())
    }

    @Test(arguments: [true, false])
    func 필수_Apple_인증정보가_비어있으면_로그인_API를_호출하지_않는다(emptyIdentity: Bool) async throws {
        let requests = AppleRequestLog()
        let nonce = nonce
        let sut = try repository(transport: { request in
            await requests.append(request)
            return try appleResponse(request, body: "{\"success\":true,\"data\":{\"nonce\":\"\(nonce)\",\"expiresIn\":300}}")
        }) { _ in
            AppleLoginCredential(identityToken: emptyIdentity ? "" : "identity",
                                 authorizationCode: emptyIdentity ? "code" : "", fullName: nil)
        }
        await #expect(throws: LoginError.invalidResponse) { try await sut.loginWithApple() }
        #expect(await requests.paths == ["/api/v1/auth/apple/nonce"])
    }

    @Test(arguments: [401, 503])
    func 로그인_서버_실패시_세션을_저장하거나_자동_재시도하지_않는다(status: Int) async throws {
        let requests = AppleRequestLog()
        let nonce = nonce
        let sut = try repository(transport: { request in
            await requests.append(request)
            if request.url?.path.hasSuffix("nonce") == true {
                return try appleResponse(request, body: "{\"success\":true,\"data\":{\"nonce\":\"\(nonce)\",\"expiresIn\":300}}")
            }
            return try appleResponse(request, status: status, body: "")
        }) { _ in AppleLoginCredential(identityToken: "identity", authorizationCode: "code", fullName: nil) }
        await #expect(throws: NetworkError.http(statusCode: status)) { try await sut.loginWithApple() }
        #expect(await requests.paths == ["/api/v1/auth/apple/nonce", "/api/v1/auth/apple/login"])
        #expect(try !sut.hasSession())
    }

    @Test func 저장_실패시_부분_세션을_정리한다() async throws {
        let users = MemoryCurrentUserStore()
        let nonce = nonce
        let body = success
        let sut = try repository(transport: { request in
            try appleResponse(request, body: request.url?.path.hasSuffix("nonce") == true
                              ? "{\"success\":true,\"data\":{\"nonce\":\"\(nonce)\",\"expiresIn\":300}}" : body)
        }, tokens: LoginFailingTokenStore(), users: users) { _ in
            AppleLoginCredential(identityToken: "identity", authorizationCode: "code", fullName: nil)
        }
        await #expect(throws: LoginStorageFailure.self) { try await sut.loginWithApple() }
        #expect(try users.load() == nil)
    }
}

private nonisolated func appleResponse(_ request: URLRequest, status: Int = 200, body: String) throws -> (Data, URLResponse) {
    let url = try #require(request.url)
    let response = try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil))
    return (Data(body.utf8), response)
}

private actor AppleRequestLog {
    private(set) var paths: [String] = []
    func append(_ request: URLRequest) { paths.append(request.url?.path ?? "") }
}
