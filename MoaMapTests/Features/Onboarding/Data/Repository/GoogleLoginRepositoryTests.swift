import Foundation
import Testing
@testable import MoaMap

@MainActor
struct GoogleLoginRepositoryTests {
    private func repository(
        tokens: any AuthTokenStore = MemoryAuthTokenStore(),
        users: any CurrentUserStore = MemoryCurrentUserStore(),
        providers: any LoginProviderStore = MemoryLoginProviderStore(),
        login: @escaping () async throws -> String = { "google-id-token" }
    ) throws -> AuthRepositoryImpl {
        let client = APIClient(configuration: try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"])) { request in
            #expect(request.url?.path == "/api/v1/auth/google/login")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            let payload = try JSONSerialization.jsonObject(with: #require(request.httpBody)) as? [String: String]
            #expect(payload == ["idToken": "google-id-token"])
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil))
            return (Data(#"{"success":true,"data":{"userId":42,"accessToken":"access","refreshToken":"refresh","isNewUser":true}}"#.utf8), response)
        }
        return AuthRepositoryImpl(client: client, kakaoLogin: { throw LoginError.notConfigured },
                                  googleLogin: login, tokenStore: tokens, currentUserStore: users,
                                  loginProviderStore: providers)
    }

    @Test func ID_토큰을_서버에_보내고_세션을_저장한다() async throws {
        let tokens = MemoryAuthTokenStore()
        let users = MemoryCurrentUserStore()
        let providers = MemoryLoginProviderStore()
        let sut = try repository(tokens: tokens, users: users, providers: providers)
        try await sut.loginWithGoogle()
        #expect(try providers.load() == .google)
        #expect(try users.load() == 42)
        #expect(try tokens.load() == AuthToken(accessToken: "access", refreshToken: "refresh"))
        #expect(try sut.hasSession())
    }

    @Test func 빈_ID_토큰은_서버에_보내지_않는다() async throws {
        let tokens = MemoryAuthTokenStore()
        let sut = try repository(tokens: tokens) { "" }
        await #expect(throws: LoginError.invalidResponse) { try await sut.loginWithGoogle() }
        #expect(try tokens.load() == nil)
    }

    @Test func 사용자_취소를_그대로_전달한다() async throws {
        let sut = try repository { throw LoginError.cancelled }
        await #expect(throws: LoginError.cancelled) { try await sut.loginWithGoogle() }
    }

    @Test func 취소된_구글_응답은_서버에_전달하지_않는다() async throws {
        let started = AsyncGate()
        let release = AsyncGate()
        let tokens = MemoryAuthTokenStore()
        let sut = try repository(tokens: tokens) {
            await started.open()
            await release.wait()
            return "google-id-token"
        }
        let task = Task { try await sut.loginWithGoogle() }
        await started.wait()
        task.cancel()
        await release.open()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(try tokens.load() == nil)
    }
}
