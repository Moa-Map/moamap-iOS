import Foundation
import Testing
@testable import MoaMap

@MainActor
struct LogoutRepositoryTests {
    private actor RequestLog {
        private(set) var paths: [String] = []
        private(set) var bodies: [[String: String]] = []
        func record(_ request: URLRequest) throws {
            paths.append(request.url?.path ?? "")
            if let body = request.httpBody {
                bodies.append(try JSONSerialization.jsonObject(with: body) as? [String: String] ?? [:])
            }
        }
    }

    private func repository(
        statusCode: Int = 200,
        log: RequestLog = RequestLog(),
        tokens: any AuthTokenStore,
        users: any CurrentUserStore,
        kakaoLogout: @escaping () async throws -> Void = {}
    ) throws -> AuthRepositoryImpl {
        let client = APIClient(configuration: try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"])) { request in
            try await log.record(request)
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil))
            return (Data(), response)
        }
        return AuthRepositoryImpl(
            client: client, kakaoLogin: { "" }, kakaoLogout: kakaoLogout,
            tokenStore: tokens, currentUserStore: users
        )
    }

    @Test func 서버에_리프레시_토큰을_보내고_세션을_지운다() async throws {
        let log = RequestLog()
        let tokens = MemoryAuthTokenStore(AuthToken(accessToken: "access", refreshToken: "refresh"))
        let users = MemoryCurrentUserStore(42)
        var kakaoCalls = 0
        let sut = try repository(log: log, tokens: tokens, users: users) { kakaoCalls += 1 }

        try await sut.logout()

        #expect(await log.paths == ["/api/v1/auth/logout"])
        #expect(await log.bodies == [["refreshToken": "refresh"]])
        #expect(kakaoCalls == 1)
        #expect(try tokens.load() == nil)
        #expect(try users.load() == nil)
    }

    @Test func 서버와_카카오_로그아웃이_실패해도_세션을_지운다() async throws {
        let tokens = MemoryAuthTokenStore(AuthToken(accessToken: "access", refreshToken: "refresh"))
        let users = MemoryCurrentUserStore(42)
        let sut = try repository(statusCode: 500, tokens: tokens, users: users) {
            throw URLError(.notConnectedToInternet)
        }

        try await sut.logout()

        #expect(try tokens.load() == nil)
        #expect(try users.load() == nil)
    }

    @Test func 토큰이_없으면_서버에_요청하지_않는다() async throws {
        let log = RequestLog()
        let users = MemoryCurrentUserStore(42)
        let sut = try repository(log: log, tokens: MemoryAuthTokenStore(), users: users)

        try await sut.logout()

        #expect(await log.paths.isEmpty)
        #expect(try users.load() == nil)
    }

    @Test func 로컬_세션을_지우지_못하면_실패를_알린다() async throws {
        let sut = try repository(tokens: ClearFailingTokenStore(), users: MemoryCurrentUserStore(42))
        await #expect(throws: LoginStorageFailure.self) { try await sut.logout() }
    }
}

nonisolated private struct ClearFailingTokenStore: AuthTokenStore {
    func load() throws -> AuthToken? { AuthToken(accessToken: "access", refreshToken: "refresh") }
    func save(_ token: AuthToken) throws {}
    func clear() throws { throw LoginStorageFailure() }
}
