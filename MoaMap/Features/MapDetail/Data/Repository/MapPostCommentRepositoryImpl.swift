import Foundation

@MainActor
final class MapPostCommentRepositoryImpl: MapPostCommentRepository {
    /// 장소 댓글과 같은 값이다.
    private static let pageSize = 100
    /// 서버가 `last` 를 잘못 내려도 끝없이 받지 않는다.
    private static let maxPages = 20

    private let client: APIClient
    private let timeZone: TimeZone

    init(client: APIClient, timeZone: TimeZone) {
        self.client = client
        self.timeZone = timeZone
    }

    func fetchComments(mapID: Int64, postID: Int64) async throws -> [MapPostComment] {
        var responses: [MapPostCommentResponse] = []
        for page in 0..<Self.maxPages {
            let request = APIRequest(
                path: path(mapID: mapID, postID: postID),
                queryItems: [
                    URLQueryItem(name: "page", value: String(page)),
                    URLQueryItem(name: "size", value: String(Self.pageSize)),
                    // 대화처럼 오래된 것이 위다. 서버 기본값과 같지만 바뀌어도 화면과 어긋나지 않게 보낸다.
                    URLQueryItem(name: "sort", value: "createdAt,asc")
                ]
            )
            let response = try await client.send(request, as: MapPostCommentPageResponse.self)
            let content = response.content ?? []
            responses += content
            if response.last ?? true || content.isEmpty { break }
        }
        let profiles = try await AuthorProfiles.fetch(responses.compactMap(\.userId), client: client)
        return responses.map { $0.toDomain(author: $0.userId.flatMap { profiles[$0] }, timeZone: timeZone) }
    }

    func createComment(mapID: Int64, postID: Int64, content: String) async throws -> MapPostComment {
        let request = APIRequest(
            path: path(mapID: mapID, postID: postID),
            method: .post,
            jsonBody: try JSONEncoder().encode(MapPostCommentCreateRequest(content: content))
        )
        return try await client.send(request, as: MapPostCommentResponse.self).toDomain(author: nil, timeZone: timeZone)
    }

    private func path(mapID: Int64, postID: Int64) -> [String] {
        ["api", "v1", "maps", String(mapID), "posts", String(postID), "comments"]
    }
}
