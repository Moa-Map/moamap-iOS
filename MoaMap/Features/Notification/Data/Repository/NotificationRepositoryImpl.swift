import Foundation

@MainActor
final class NotificationRepositoryImpl: NotificationRepository {
    private let client: APIClient

    init(client: APIClient) { self.client = client }

    func fetchNotifications(page: Int, size: Int) async throws -> NotificationPage {
        let request = APIRequest(
            path: ["api", "v1", "notifications"],
            queryItems: [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size))
            ]
        )
        let response = try await client.send(request, as: NotificationPageResponse.self)
        let content = response.content ?? []
        // 빈 페이지도 끝으로 본다. `last` 가 잘못 와도 헛조회가 반복되지 않는다.
        return NotificationPage(
            notifications: content.map { $0.toDomain() },
            isLast: response.last ?? true || content.isEmpty
        )
    }

    func markRead(id: Int64) async throws {
        try await client.sendWithoutResponse(
            APIRequest(path: ["api", "v1", "notifications", String(id), "read"], method: .patch)
        )
    }

    func markAllRead() async throws {
        try await client.sendWithoutResponse(
            APIRequest(path: ["api", "v1", "notifications", "read-all"], method: .patch)
        )
    }
}
