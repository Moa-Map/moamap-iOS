import Foundation

@MainActor
final class CollectionRepositoryImpl: CollectionRepository {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func fetchMyMaps(type: CollectionMapType) async throws -> [MyMap] {
        let request = APIRequest(
            path: ["api", "v1", "maps", "me"],
            queryItems: [
                URLQueryItem(name: "type", value: type == .community ? "COMMUNITY" : "PRIVATE"),
                URLQueryItem(name: "size", value: "20")
            ]
        )
        let response = try await client.send(request, as: MyMapPageResponse.self)
        return (response.content ?? []).map { $0.toDomain() }
    }

    func joinByInviteCode(_ inviteCode: String) async throws {
        let request = APIRequest(
            path: ["api", "v1", "maps", "join"],
            method: .post,
            jsonBody: try JSONEncoder().encode(JoinByInviteCodeRequest(inviteCode: inviteCode.trimmingCharacters(in: .whitespaces)))
        )
        try await client.sendWithoutResponse(request)
    }
}
