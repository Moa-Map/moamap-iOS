import Foundation

@MainActor
final class ReportRepositoryImpl: ReportRepository {
    private let client: APIClient

    init(client: APIClient) { self.client = client }

    func report(_ target: ReportTarget, reason: ReportReason, detail: String?) async throws {
        let detail = detail?.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = ReportRequest(reason: reason.rawValue, detail: detail?.isEmpty == false ? detail : nil)
        let request = APIRequest(path: Self.path(target), method: .post, jsonBody: try JSONEncoder().encode(body))
        try await client.sendWithoutResponse(request)
    }

    private static func path(_ target: ReportTarget) -> [String] {
        let base = ["api", "v1"]
        let rest: [String] = switch target {
        case .place(let placeID):
            ["places", String(placeID)]
        case .placeComment(let placeID, let commentID):
            ["places", String(placeID), "comments", String(commentID)]
        case .map(let mapID):
            ["maps", String(mapID)]
        case .mapPost(let mapID, let postID):
            ["maps", String(mapID), "posts", String(postID)]
        case .mapPostComment(let mapID, let postID, let commentID):
            ["maps", String(mapID), "posts", String(postID), "comments", String(commentID)]
        case .user(let userID):
            ["users", String(userID)]
        }
        return base + rest + ["reports"]
    }
}
