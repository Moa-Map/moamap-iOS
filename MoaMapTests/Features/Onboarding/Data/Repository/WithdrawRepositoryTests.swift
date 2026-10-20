import Foundation
import Testing
@testable import MoaMap

@MainActor
struct WithdrawRepositoryTests {
    private actor RequestLog {
        private(set) var requests: [String] = []
        func record(_ request: URLRequest) {
            requests.append("\(request.httpMethod ?? "") \(request.url?.path ?? "")")
        }
    }

    private func repository(
        statusCode: Int = 200,
        body: String = #"{"success":true}"#,
        log: RequestLog = RequestLog(),
        tokens: any AuthTokenStore,
        users: any CurrentUserStore,
        providers: any LoginProviderStore = MemoryLoginProviderStore(.kakao),
        kakaoUnlink: @escaping () async throws -> Void = {}
    ) throws -> AuthRepositoryImpl {
        let client = APIClient(configuration: try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"])) { request in
            await log.record(request)
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: nil))
            return (Data(body.utf8), response)
        }
        return AuthRepositoryImpl(
            client: client, kakaoLogin: { "" }, kakaoUnlink: kakaoUnlink,
            tokenStore: tokens, currentUserStore: users, loginProviderStore: providers
        )
    }

    @Test func 카카오를_끊고_서버에서_탈퇴한_뒤_세션을_지운다() async throws {
        let log = RequestLog()
        let tokens = MemoryAuthTokenStore(AuthToken(accessToken: "access", refreshToken: "refresh"))
        let users = MemoryCurrentUserStore(42)
        let providers = MemoryLoginProviderStore(.kakao)
        var events: [String] = []
        let sut = try repository(log: log, tokens: tokens, users: users, providers: providers) {
            events.append("unlink")
            #expect(await log.requests.isEmpty)
        }

        try await sut.withdraw()

        #expect(events == ["unlink"])
        #expect(await log.requests == ["DELETE /api/v1/users/me"])
        #expect(try tokens.load() == nil)
        #expect(try users.load() == nil)
        #expect(try providers.load() == nil)
    }

    @Test func Apple_세션이면_카카오_연결을_끊지_않고_탈퇴한다() async throws {
        let log = RequestLog()
        let tokens = MemoryAuthTokenStore(AuthToken(accessToken: "access", refreshToken: "refresh"))
        let users = MemoryCurrentUserStore(42)
        var unlinkCalls = 0
        let sut = try repository(log: log, tokens: tokens, users: users, providers: MemoryLoginProviderStore(.apple)) {
            unlinkCalls += 1
            throw URLError(.notConnectedToInternet)
        }

        try await sut.withdraw()

        #expect(unlinkCalls == 0)
        #expect(await log.requests == ["DELETE /api/v1/users/me"])
        #expect(try tokens.load() == nil)
    }

    @Test func 로그인_수단을_모르는_세션은_카카오_연결을_끊어_본다() async throws {
        let tokens = MemoryAuthTokenStore(AuthToken(accessToken: "access", refreshToken: "refresh"))
        var unlinkCalls = 0
        let sut = try repository(tokens: tokens, users: MemoryCurrentUserStore(42), providers: MemoryLoginProviderStore()) {
            unlinkCalls += 1
        }

        try await sut.withdraw()

        #expect(unlinkCalls == 1)
        #expect(try tokens.load() == nil)
    }

    @Test func 없는_회원이면_이미_탈퇴된_것으로_보고_세션을_지운다() async throws {
        let tokens = MemoryAuthTokenStore(AuthToken(accessToken: "access", refreshToken: "refresh"))
        let users = MemoryCurrentUserStore(42)
        let sut = try repository(
            statusCode: 404, body: #"{"success":false,"error":{"code":"USER_003","message":"회원을 찾을 수 없습니다."}}"#,
            tokens: tokens, users: users
        )

        try await sut.withdraw()

        #expect(try tokens.load() == nil)
        #expect(try users.load() == nil)
    }

    @Test func 서버_탈퇴가_실패하면_세션을_남긴다() async throws {
        let token = AuthToken(accessToken: "access", refreshToken: "refresh")
        let tokens = MemoryAuthTokenStore(token)
        let users = MemoryCurrentUserStore(42)
        let sut = try repository(
            statusCode: 500, body: #"{"success":false,"error":{"code":"COMMON_005","message":"서버 오류"}}"#,
            tokens: tokens, users: users
        )

        await #expect(throws: NetworkError.self) { try await sut.withdraw() }

        #expect(try tokens.load() == token)
        #expect(try users.load() == 42)
    }

    @Test func 카카오가_이미_끊겼으면_서버_탈퇴를_이어간다() async throws {
        let log = RequestLog()
        let tokens = MemoryAuthTokenStore(AuthToken(accessToken: "access", refreshToken: "refresh"))
        let users = MemoryCurrentUserStore(42)
        let kakao = KakaoAuthClient(isTalkAvailable: { false }, talkLogin: { _ in }, accountLogin: { _ in },
                                    unlink: { $0(.failure(KakaoUnlinkError.alreadyUnlinked)) })
        let sut = try repository(log: log, tokens: tokens, users: users) { try await kakao.unlink() }

        try await sut.withdraw()

        #expect(await log.requests == ["DELETE /api/v1/users/me"])
        #expect(try tokens.load() == nil)
    }

    @Test func 카카오_연결_끊기가_일시_오류면_서버를_부르지_않고_세션을_남긴다() async throws {
        let log = RequestLog()
        let token = AuthToken(accessToken: "access", refreshToken: "refresh")
        let tokens = MemoryAuthTokenStore(token)
        let users = MemoryCurrentUserStore(42)
        let sut = try repository(log: log, tokens: tokens, users: users) { throw URLError(.notConnectedToInternet) }

        await #expect(throws: URLError.self) { try await sut.withdraw() }

        #expect(await log.requests.isEmpty)
        #expect(try tokens.load() == token)
        #expect(try users.load() == 42)
    }
}
