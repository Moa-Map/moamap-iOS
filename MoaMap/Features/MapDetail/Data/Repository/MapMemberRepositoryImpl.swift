import Foundation

@MainActor
final class MapMemberRepositoryImpl: MapMemberRepository {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    /// 페이지를 나누지 않고 한 번에 내려온다.
    func fetchMembers(mapID: Int64) async throws -> [MapMember] {
        let response = try await client.send(
            APIRequest(path: ["api", "v1", "maps", String(mapID), "members"]),
            as: MapMemberListResponse.self
        )
        return (response.members ?? []).map { $0.toDomain() }
    }

    func grantAdmin(mapID: Int64, userID: Int64) async throws {
        let request = APIRequest(
            path: ["api", "v1", "maps", String(mapID), "members", String(userID), "role"],
            method: .put,
            jsonBody: try JSONEncoder().encode(MapMemberRoleUpdateRequest(role: "ADMIN"))
        )
        try await client.sendWithoutResponse(request)
    }
}
