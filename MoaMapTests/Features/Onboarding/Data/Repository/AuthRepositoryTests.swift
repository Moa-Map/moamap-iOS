import Foundation
import Testing
@testable import MoaMap

@MainActor
struct AuthRepositoryTests {
    private func repository(
        body: String,
        tokens: any AuthTokenStore,
        users: any CurrentUserStore,
        login: @escaping () async throws -> String = { "kakao-token" }
    ) throws -> AuthRepositoryImpl {
        let client = APIClient(configuration: try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"])) { request in
            #expect(request.url?.path == "/api/v1/auth/kakao/login")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            let payload = try JSONSerialization.jsonObject(with: #require(request.httpBody)) as? [String: String]
            #expect(payload == ["kakaoAccessToken": "kakao-token"])
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (Data(body.utf8), response)
        }
        return AuthRepositoryImpl(client: client, kakaoLogin: login, tokenStore: tokens, currentUserStore: users)
    }

    @Test func 로그인_응답의_신원과_토큰을_저장한다() async throws {
        let tokens = MemoryAuthTokenStore()
        let users = MemoryCurrentUserStore()
        let sut = try repository(body: #"{"success":true,"data":{"userId":42,"accessToken":"access","refreshToken":"refresh","isNewUser":true}}"#, tokens: tokens, users: users)
        try await sut.loginWithKakao()
        #expect(try users.load() == 42)
        #expect(try tokens.load() == AuthToken(accessToken: "access", refreshToken: "refresh"))
        #expect(try sut.hasSession())
    }

    @Test(arguments: [
        #"{"userId":0,"accessToken":"a","refreshToken":"r"}"#,
        #"{"accessToken":"a","refreshToken":"r"}"#,
        #"{"userId":42,"accessToken":"","refreshToken":"r"}"#,
        #"{"userId":42,"accessToken":"a","refreshToken":null}"#
    ])
    func 불완전한_로그인_응답을_저장하지_않는다(data: String) async throws {
        let tokens = MemoryAuthTokenStore()
        let users = MemoryCurrentUserStore()
        let sut = try repository(body: "{\"success\":true,\"data\":\(data)}", tokens: tokens, users: users)
        await #expect(throws: LoginError.invalidResponse) { try await sut.loginWithKakao() }
        #expect(try tokens.load() == nil)
        #expect(try users.load() == nil)
    }

    @Test func 토큰_저장_실패시_부분_저장을_정리한다() async throws {
        let users = MemoryCurrentUserStore()
        let sut = try repository(body: #"{"success":true,"data":{"userId":42,"accessToken":"a","refreshToken":"r"}}"#, tokens: LoginFailingTokenStore(), users: users)
        await #expect(throws: LoginStorageFailure.self) { try await sut.loginWithKakao() }
        #expect(try users.load() == nil)
        #expect(try !sut.hasSession())
    }

    @Test func 사용자_저장_실패시_토큰을_저장하지_않는다() async throws {
        let tokens = MemoryAuthTokenStore()
        let sut = try repository(body: #"{"success":true,"data":{"userId":42,"accessToken":"a","refreshToken":"r"}}"#, tokens: tokens, users: FailingCurrentUserStore())
        await #expect(throws: (any Error).self) { try await sut.loginWithKakao() }
        #expect(try tokens.load() == nil)
    }

    @Test func 신원_없는_기존_토큰은_로그인_세션이_아니다() throws {
        let sut = try repository(body: "{}", tokens: MemoryAuthTokenStore(AuthToken(accessToken: "a", refreshToken: "r")), users: MemoryCurrentUserStore())
        #expect(try !sut.hasSession())
    }

    @Test func 취소된_카카오_응답은_서버에_전달하지_않는다() async throws {
        let started = AsyncGate()
        let release = AsyncGate()
        let tokens = MemoryAuthTokenStore()
        let sut = try repository(body: #"{"success":true,"data":{"userId":42,"accessToken":"a","refreshToken":"r"}}"#, tokens: tokens, users: MemoryCurrentUserStore()) {
            await started.open()
            await release.wait()
            return "kakao-token"
        }
        let task = Task { try await sut.loginWithKakao() }
        await started.wait()
        task.cancel()
        await release.open()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(try tokens.load() == nil)
    }
}

nonisolated struct LoginStorageFailure: Error {}
nonisolated struct LoginFailingTokenStore: AuthTokenStore {
    func load() throws -> AuthToken? { nil }
    func save(_ token: AuthToken) throws { throw LoginStorageFailure() }
    func clear() throws {}
}
