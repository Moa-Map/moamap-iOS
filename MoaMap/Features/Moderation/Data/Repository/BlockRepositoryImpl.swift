import Foundation

@MainActor
final class BlockRepositoryImpl: BlockRepository {
    private let client: APIClient

    init(client: APIClient) { self.client = client }

    func fetchBlockedUsers() async throws -> [BlockedUser] {
        let request = APIRequest(path: ["api", "v1", "users", "me", "blocks"])
        return try await client.send(request, as: [BlockedUserResponse].self).map { $0.toDomain() }
    }

    func block(userID: Int64) async throws {
        try await client.sendWithoutResponse(APIRequest(path: path(userID), method: .post))
    }

    func unblock(userID: Int64) async throws {
        try await client.sendWithoutResponse(APIRequest(path: path(userID), method: .delete))
    }

    private func path(_ userID: Int64) -> [String] {
        ["api", "v1", "users", String(userID), "blocks"]
    }
}
