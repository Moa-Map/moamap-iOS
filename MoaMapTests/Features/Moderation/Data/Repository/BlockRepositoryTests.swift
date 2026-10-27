import Foundation
import Testing
@testable import MoaMap

@MainActor
struct BlockRepositoryTests {
    private final class Log: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [URLRequest] = []
        func add(_ request: URLRequest) { lock.withLock { items.append(request) } }
        var requests: [URLRequest] { lock.withLock { items } }
    }

    private func repository(_ log: Log, status: Int = 200, body: String = #"{"success":true,"data":null}"#) throws -> BlockRepositoryImpl {
        let client = APIClient(configuration: try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"])) { request in
            log.add(request)
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil))
            return (Data(body.utf8), response)
        }
        return BlockRepositoryImpl(client: client)
    }

    @Test func 차단_목록을_읽고_빈_값은_비운다() async throws {
        let log = Log()
        let sut = try repository(log, body: #"""
        {"success":true,"data":[
        {"userId":3,"nickname":" 모아 ","profileImageUrl":"https://p","blockedAt":"2026-10-27T01:02:03.123456Z"},
        {"userId":4,"nickname":" ","profileImageUrl":""},
        {"userId":5}]}
        """#)
        let users = try await sut.fetchBlockedUsers()
        #expect(users == [
            BlockedUser(id: 3, nickname: "모아", profileImageURL: URL(string: "https://p")),
            BlockedUser(id: 4, nickname: nil, profileImageURL: nil),
            BlockedUser(id: 5, nickname: nil, profileImageURL: nil)
        ])
        let request = try #require(log.requests.first)
        #expect(request.httpMethod == "GET")
        #expect(request.url?.path == "/api/v1/users/me/blocks")
    }

    @Test func 차단은_POST_해제는_DELETE_로_보낸다() async throws {
        let log = Log()
        let sut = try repository(log)
        try await sut.block(userID: 7)
        try await sut.unblock(userID: 7)
        #expect(log.requests.map(\.httpMethod) == ["POST", "DELETE"])
        #expect(log.requests.map(\.url?.path) == ["/api/v1/users/7/blocks", "/api/v1/users/7/blocks"])
    }

    @Test func 나를_차단하면_서버_코드를_그대로_던진다() async throws {
        let sut = try repository(Log(), status: 400, body: #"{"success":false,"error":{"code":"USER_026","status":400}}"#)
        await #expect(throws: NetworkError.server(code: "USER_026", statusCode: 400)) {
            try await sut.block(userID: 1)
        }
    }
}
