@MainActor
protocol CollectionRepository {
    func fetchMyMaps(type: CollectionMapType) async throws -> [MyMap]
    func joinByInviteCode(_ inviteCode: String) async throws
}
