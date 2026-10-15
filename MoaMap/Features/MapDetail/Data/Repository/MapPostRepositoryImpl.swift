import Foundation

@MainActor
final class MapPostRepositoryImpl: MapPostRepository {
    /// 서버 기본값과 같다.
    nonisolated static let pageSize = 20

    private let client: APIClient
    private let timeZone: TimeZone

    init(client: APIClient, timeZone: TimeZone) {
        self.client = client
        self.timeZone = timeZone
    }

    func fetchPosts(mapID: Int64, page: Int, sort: MapPostSort) async throws -> MapPostPage {
        let request = APIRequest(
            path: ["api", "v1", "maps", String(mapID), "posts"],
            queryItems: [
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(Self.pageSize)),
                // 최신순도 보낸다. 서버 기본값이 바뀌어도 화면의 선택과 어긋나지 않는다.
                URLQueryItem(name: "sort", value: sort == .latest ? "createdAt,desc" : "createdAt,asc")
            ]
        )
        let response = try await client.send(request, as: MapPostPageResponse.self)
        let content = response.content ?? []
        return MapPostPage(
            posts: content.map { $0.toDomain(timeZone: timeZone) },
            // 빈 페이지도 끝으로 본다. `last` 가 잘못 와도 스크롤할 때마다 헛조회가 반복되지 않는다.
            isLast: response.last ?? true || content.isEmpty
        )
    }
}
