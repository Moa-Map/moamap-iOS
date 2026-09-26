@MainActor
protocol CollectionRepository {
    func fetchMyMaps(type: CollectionMapType) async throws -> [MyMap]
}
