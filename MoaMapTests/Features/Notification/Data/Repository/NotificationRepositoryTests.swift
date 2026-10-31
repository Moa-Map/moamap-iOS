import Foundation
import Testing
@testable import MoaMap

private final class RequestLog: @unchecked Sendable {
    private let lock = NSLock()
    private var items: [URLRequest] = []
    var requests: [URLRequest] { lock.withLock { items } }
    func append(_ request: URLRequest) { lock.withLock { items.append(request) } }
}

@MainActor
struct NotificationRepositoryTests {
    private func client(body: String, status: Int = 200, log: RequestLog) throws -> APIClient {
        APIClient(configuration: try APIConfiguration(infoDictionary: ["BASE_URL": "https://example.com/"])) { request in
            log.append(request)
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil))
            return (Data(body.utf8), response)
        }
    }

    @Test func 알림_목록을_쪽_번호와_크기로_받고_종류와_시각을_읽는다() async throws {
        let log = RequestLog()
        let sut = NotificationRepositoryImpl(client: try client(body: #"""
        {"success":true,"data":{"content":[
          {"notificationId":3,"type":"MAP_POST_COMMENTED","message":"댓글","targetType":"MAP_POST","targetId":9,"mapId":4,
           "read":false,"createdAt":"2026-10-20T15:00:00Z"},
          {"notificationId":2,"type":"NEW_THING","message":null,"targetId":null,"mapId":null,"read":true,"createdAt":"잘못된 값"}
        ],"last":false}}
        """#, log: log))
        let page = try await sut.fetchNotifications(page: 1, size: 20)
        #expect(page.isLast == false)
        #expect(page.notifications == [
            UserNotification(
                id: 3, kind: .mapPostCommented, message: "댓글", targetID: 9, mapID: 4, read: false,
                createdAt: Date(timeIntervalSince1970: 1_792_508_400)
            ),
            UserNotification(id: 2, kind: .unknown, message: "", targetID: nil, mapID: nil, read: true, createdAt: nil)
        ])
        let url = try #require(log.requests.first?.url)
        #expect(url.path == "/api/v1/notifications")
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        #expect(query == [URLQueryItem(name: "page", value: "1"), URLQueryItem(name: "size", value: "20")])
    }

    @Test func 빈_쪽은_끝으로_본다() async throws {
        let sut = NotificationRepositoryImpl(
            client: try client(body: #"{"success":true,"data":{"content":[],"last":false}}"#, log: RequestLog())
        )
        #expect(try await sut.fetchNotifications(page: 3, size: 20).isLast)
    }

    @Test func 하나_읽음과_모두_읽음은_PATCH_로_보낸다() async throws {
        let log = RequestLog()
        let sut = NotificationRepositoryImpl(client: try client(body: #"{"success":true,"data":null}"#, log: log))
        try await sut.markRead(id: 7)
        try await sut.markAllRead()
        #expect(log.requests.map(\.httpMethod) == ["PATCH", "PATCH"])
        #expect(log.requests.map(\.url?.path) == ["/api/v1/notifications/7/read", "/api/v1/notifications/read-all"])
    }

    @Test func 남의_알림은_404_를_던진다() async throws {
        let sut = NotificationRepositoryImpl(client: try client(
            body: #"{"success":false,"error":{"code":"NOTIFICATION_001","status":404,"message":"없음"}}"#, status: 404,
            log: RequestLog()
        ))
        await #expect(throws: NetworkError.server(code: "NOTIFICATION_001", statusCode: 404, message: "없음")) {
            try await sut.markRead(id: 7)
        }
    }
}
