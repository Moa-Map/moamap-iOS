import Foundation
import Testing
@testable import MoaMap

@Suite(.timeLimit(.minutes(1)))
struct AuthSessionTests {
    private let old = AuthToken(accessToken: "old", refreshToken: "refresh")
    private let new = AuthToken(accessToken: "new", refreshToken: "rotated")

    private func client(session: AuthSession, transport: @escaping APIClient.Transport) throws -> APIClient {
        APIClient(configuration: try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"]), authSession: session, transport: transport)
    }

    private func response(_ request: URLRequest, status: Int) throws -> (Data, URLResponse) {
        let url = try #require(request.url)
        return (Data(), try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)))
    }

    @Test
    func 갱신된_토큰을_저장한_후_원래_요청을_재시도한다() async throws {
        let tokens = MemoryAuthTokenStore(old)
        let users = MemoryCurrentUserStore(42)
        let refresher = RefreshProbe(.success(new))
        let session = AuthSession(tokenStore: tokens, currentUserStore: users, refresher: refresher, events: SessionEvents())
        let recorder = AuthRequestRecorder()
        let subject = try client(session: session) { request in
            await recorder.record(request)
            #expect(request.httpMethod == "POST")
            #expect(request.httpBody == Data("body".utf8))
            #expect(request.url?.query == "page=2")
            return try response(request, status: request.value(forHTTPHeaderField: "Authorization") == "Bearer new" ? 200 : 401)
        }
        _ = try await subject.send(APIRequest(path: ["maps"], method: .post, queryItems: [URLQueryItem(name: "page", value: "2")], jsonBody: Data("body".utf8)))
        #expect(await recorder.headers == ["Bearer old", "Bearer new"])
        #expect(try tokens.load() == new)
        #expect(try users.load() == 42)
        #expect(await refresher.receivedTokens == ["refresh"])
    }

    @Test(arguments: [
        ["api", "v1", "auth", "kakao", "login"],
        ["api", "v1", "auth", "apple", "nonce"],
        ["api", "v1", "auth", "apple", "login"],
        ["api", "v1", "auth", "token", "refresh"]
    ])
    func 로그인과_갱신에는_토큰을_붙이거나_재시도하지_않는다(path: [String]) async throws {
        let refresher = RefreshProbe(.success(new))
        let session = AuthSession(tokenStore: MemoryAuthTokenStore(old), currentUserStore: MemoryCurrentUserStore(), refresher: refresher, events: SessionEvents())
        let subject = try client(session: session) { request in
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            return try response(request, status: 401)
        }
        await #expect(throws: NetworkError.http(statusCode: 401)) { try await subject.send(APIRequest(path: path)) }
        #expect(await refresher.receivedTokens.isEmpty)
    }

    @Test(arguments: [true, false])
    func 토큰이_없거나_재시도도_401이면_추가_갱신하지_않는다(hasToken: Bool) async throws {
        let refresher = RefreshProbe(.success(new))
        let session = AuthSession(tokenStore: MemoryAuthTokenStore(hasToken ? old : nil), currentUserStore: MemoryCurrentUserStore(), refresher: refresher, events: SessionEvents())
        let recorder = AuthRequestRecorder()
        let subject = try client(session: session) { request in
            await recorder.record(request)
            return try response(request, status: 401)
        }
        await #expect(throws: NetworkError.http(statusCode: 401)) { try await subject.send(APIRequest(path: ["maps"])) }
        #expect(await recorder.headers.count == (hasToken ? 2 : 1))
        #expect(await refresher.receivedTokens.count == (hasToken ? 1 : 0))
    }

    @Test
    func 갱신_거부는_토큰과_신원을_지우고_나중에_구독해도_만료를_전달한다() async throws {
        let tokens = MemoryAuthTokenStore(old)
        let users = MemoryCurrentUserStore(42)
        let events = SessionEvents()
        let session = AuthSession(tokenStore: tokens, currentUserStore: users, refresher: RefreshProbe(.rejected), events: events)
        let credentials = try #require(await session.credentials())
        #expect(try await session.refresh(for: credentials) == nil)
        #expect(try tokens.load() == nil)
        #expect(try users.load() == nil)
        var iterator = events.sessionExpired.makeAsyncIterator()
        #expect(await iterator.next() != nil)
    }

    @Test
    func 일시적_실패는_세션을_유지하고_다음_요청에서_다시_갱신한다() async throws {
        let tokens = MemoryAuthTokenStore(old)
        let users = MemoryCurrentUserStore(42)
        let refresher = RefreshProbe(.failed)
        let session = AuthSession(tokenStore: tokens, currentUserStore: users, refresher: refresher, events: SessionEvents())
        let credentials = try #require(await session.credentials())
        #expect(try await session.refresh(for: credentials) == nil)
        #expect(try await session.refresh(for: credentials) == nil)
        #expect(try tokens.load() == old)
        #expect(try users.load() == 42)
        #expect(await refresher.receivedTokens.count == 2)
    }

    @Test
    func 동시에_만료된_요청은_한번만_갱신한다() async throws {
        let gate = AsyncGate()
        let tokens = MemoryAuthTokenStore(old)
        let refresher = RefreshProbe(.success(new), release: gate)
        let session = AuthSession(tokenStore: tokens, currentUserStore: MemoryCurrentUserStore(), refresher: refresher, events: SessionEvents())
        let credentials = try #require(await session.credentials())
        let first = Task { try await session.refresh(for: credentials) }
        await refresher.started.wait()
        let others = (0..<20).map { _ in Task { try await session.refresh(for: credentials) } }
        await gate.open()
        #expect(try await first.value == "new")
        for task in others { #expect(try await task.value == "new") }
        #expect(await refresher.receivedTokens == ["refresh"])
    }

    @Test
    func 취소된_요청은_결과를_반환하지_않고_공유_갱신은_다른_요청에_사용한다() async throws {
        let gate = AsyncGate()
        let refresher = RefreshProbe(.success(new), release: gate)
        let session = AuthSession(tokenStore: MemoryAuthTokenStore(old), currentUserStore: MemoryCurrentUserStore(), refresher: refresher, events: SessionEvents())
        let credentials = try #require(await session.credentials())
        let cancelled = Task { try await session.refresh(for: credentials) }
        await refresher.started.wait()
        cancelled.cancel()
        let other = Task { try await session.refresh(for: credentials) }
        await gate.open()
        await #expect(throws: CancellationError.self) { try await cancelled.value }
        #expect(try await other.value == "new")
        #expect(await refresher.receivedTokens.count == 1)
    }

    @Test(arguments: [TokenRefreshResult.success(AuthToken(accessToken: "new", refreshToken: "rotated")), .rejected])
    func 갱신_중_바뀐_세션을_이전_결과로_덮거나_삭제하지_않는다(result: TokenRefreshResult) async throws {
        let gate = AsyncGate()
        let tokens = MemoryAuthTokenStore(old)
        let refresher = RefreshProbe(result, release: gate)
        let session = AuthSession(tokenStore: tokens, currentUserStore: MemoryCurrentUserStore(42), refresher: refresher, events: SessionEvents())
        let credentials = try #require(await session.credentials())
        let task = Task { try await session.refresh(for: credentials) }
        await refresher.started.wait()
        let replacement = AuthToken(accessToken: "other-user", refreshToken: "other-refresh")
        try tokens.save(replacement)
        await gate.open()
        #expect(try await task.value == nil)
        #expect(try tokens.load() == replacement)
    }

    @Test
    func 신원_삭제가_실패해도_토큰을_삭제하고_만료를_전달한다() async throws {
        let tokens = MemoryAuthTokenStore(old)
        let events = SessionEvents()
        let session = AuthSession(tokenStore: tokens, currentUserStore: FailingCurrentUserStore(), refresher: RefreshProbe(.rejected), events: events)
        let credentials = try #require(await session.credentials())
        await #expect(throws: FailingCurrentUserStore.StorageFailure.self) { try await session.refresh(for: credentials) }
        #expect(try tokens.load() == nil)
        // 기존 구현에서는 이 검증부터 실패하므로 이벤트 대기로 테스트를 붙잡지 않는다.
        guard try tokens.load() == nil else { return }
        var iterator = events.sessionExpired.makeAsyncIterator()
        #expect(await iterator.next() != nil)
    }

    @Test
    func 갱신_자체의_취소도_세션을_보존하고_요청까지_전달한다() async throws {
        let tokens = MemoryAuthTokenStore(old)
        let users = MemoryCurrentUserStore(42)
        let session = AuthSession(tokenStore: tokens, currentUserStore: users, refresher: CancelledTokenRefresher(), events: SessionEvents())
        let recorder = AuthRequestRecorder()
        let subject = try client(session: session) { request in
            await recorder.record(request)
            return try response(request, status: 401)
        }
        await #expect(throws: CancellationError.self) { try await subject.send(APIRequest(path: ["maps"])) }
        #expect(try tokens.load() == old)
        #expect(try users.load() == 42)
        #expect(await recorder.headers.count == 1)
    }

    @Test
    func 이전_계정의_요청을_새_계정의_토큰으로_재전송하지_않는다() async throws {
        let tokens = MemoryAuthTokenStore(old)
        let users = MemoryCurrentUserStore(42)
        let session = AuthSession(tokenStore: tokens, currentUserStore: users, refresher: RefreshProbe(.success(new)), events: SessionEvents())
        let recorder = AuthRequestRecorder()
        let subject = try client(session: session) { request in
            await recorder.record(request)
            // 최초 요청이 전송된 뒤 다른 계정으로 로그인하고 나서 401이 도착한다.
            try tokens.clear()
            try tokens.save(AuthToken(accessToken: "other-user", refreshToken: "other-refresh"))
            try users.save(userId: 99)
            return try response(request, status: 401)
        }
        await #expect(throws: NetworkError.http(statusCode: 401)) { try await subject.send(APIRequest(path: ["maps"], method: .post)) }
        #expect(await recorder.headers == ["Bearer old"])
        #expect(try users.load() == 99)
    }

    @Test
    func 같은_세션에서_다른_요청이_갱신한_토큰으로는_재시도한다() async throws {
        let tokens = MemoryAuthTokenStore(old)
        let refresher = RefreshProbe(.success(new))
        let session = AuthSession(tokenStore: tokens, currentUserStore: MemoryCurrentUserStore(42), refresher: refresher, events: SessionEvents())
        let credentials = try #require(await session.credentials())
        let recorder = AuthRequestRecorder()
        let subject = try client(session: session) { request in
            await recorder.record(request)
            if request.value(forHTTPHeaderField: "Authorization") == "Bearer old" {
                _ = try await session.refresh(for: credentials)
                return try response(request, status: 401)
            }
            return try response(request, status: 200)
        }
        _ = try await subject.send(APIRequest(path: ["maps"]))
        #expect(await recorder.headers == ["Bearer old", "Bearer new"])
        #expect(await refresher.receivedTokens == ["refresh"])
    }
}
