import Foundation
import Testing
@testable import MoaMap

@MainActor
struct ReportRepositoryTests {
    private final class Log: @unchecked Sendable {
        private let lock = NSLock()
        private var items: [URLRequest] = []
        func add(_ request: URLRequest) { lock.withLock { items.append(request) } }
        var requests: [URLRequest] { lock.withLock { items } }
    }

    private func repository(_ log: Log, status: Int = 201, body: String = #"{"success":true,"data":{"reportId":1}}"#) throws -> ReportRepositoryImpl {
        let client = APIClient(configuration: try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"])) { request in
            log.add(request)
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil))
            return (Data(body.utf8), response)
        }
        return ReportRepositoryImpl(client: client)
    }

    private static func body(_ request: URLRequest) throws -> [String: String] {
        let data = try #require(request.httpBody)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
    }

    @Test(arguments: [
        (ReportTarget.place(placeID: 3), "/api/v1/places/3/reports"),
        (.placeComment(placeID: 3, commentID: 5), "/api/v1/places/3/comments/5/reports"),
        (.map(mapID: 7), "/api/v1/maps/7/reports"),
        (.mapPost(mapID: 7, postID: 8), "/api/v1/maps/7/posts/8/reports"),
        (.mapPostComment(mapID: 7, postID: 8, commentID: 9), "/api/v1/maps/7/posts/8/comments/9/reports"),
        (.user(userID: 11), "/api/v1/users/11/reports")
    ])
    func 대상마다_맞는_주소로_보낸다(target: ReportTarget, path: String) async throws {
        let log = Log()
        try await repository(log).report(target, reason: .spam, detail: nil)
        let request = try #require(log.requests.first)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == path)
        #expect(try Self.body(request) == ["reason": "SPAM"])
    }

    @Test func 내용은_앞뒤_공백을_지우고_보낸다() async throws {
        let log = Log()
        try await repository(log).report(.user(userID: 1), reason: .other, detail: "  사칭 계정이에요 \n")
        let request = try #require(log.requests.first)
        #expect(try Self.body(request) == ["reason": "OTHER", "detail": "사칭 계정이에요"])
    }

    @Test func 공백뿐인_내용은_보내지_않는다() async throws {
        let log = Log()
        try await repository(log).report(.place(placeID: 1), reason: .falseInfo, detail: "  ")
        let request = try #require(log.requests.first)
        #expect(try Self.body(request) == ["reason": "FALSE_INFO"])
    }

    @Test func 서버가_거절하면_코드를_그대로_던진다() async throws {
        let sut = try repository(Log(), status: 409, body: #"{"success":false,"error":{"code":"MAP_026","status":409,"message":"이미 신고했습니다."}}"#)
        await #expect(throws: NetworkError.server(code: "MAP_026", statusCode: 409, message: "이미 신고했습니다.")) {
            try await sut.report(.map(mapID: 1), reason: .abuse, detail: nil)
        }
    }
}
