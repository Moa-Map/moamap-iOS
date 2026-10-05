@testable import MoaMap

@MainActor
final class CollectionRepositoryStub: CollectionRepository {
    var fetch: (CollectionMapType) async throws -> [MyMap] = { _ in [] }
    private(set) var calls: [CollectionMapType] = []

    func fetchMyMaps(type: CollectionMapType) async throws -> [MyMap] {
        calls.append(type)
        return try await fetch(type)
    }

    var join: (String) async throws -> Void = { _ in }
    private(set) var joinedCodes: [String] = []

    func joinByInviteCode(_ inviteCode: String) async throws {
        joinedCodes.append(inviteCode)
        try await join(inviteCode)
    }
}
