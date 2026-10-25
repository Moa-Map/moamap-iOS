import Foundation

/// 로그인하지 않아도 받는다.
@MainActor
final class NoticeRepositoryImpl: NoticeRepository {
    private let client: APIClient

    init(client: APIClient) { self.client = client }

    func fetchNotices(page: Int, size: Int) async throws -> NoticePage {
        let request = APIRequest(
            path: ["api", "v1", "notices"],
            queryItems: [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size))
            ]
        )
        let response = try await client.send(request, as: NoticePageResponse.self)
        let content = response.content ?? []
        // 빈 페이지도 끝으로 본다. `last` 가 잘못 와도 헛조회가 반복되지 않는다.
        return NoticePage(notices: content.map { $0.toDomain() }, isLast: response.last ?? true || content.isEmpty)
    }

    func fetchNotice(id: Int64) async throws -> Notice {
        let request = APIRequest(path: ["api", "v1", "notices", String(id)])
        return try await client.send(request, as: NoticeResponse.self).toDomain()
    }
}
