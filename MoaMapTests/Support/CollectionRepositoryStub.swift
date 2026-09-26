@testable import MoaMap

@MainActor
final class CollectionRepositoryStub: CollectionRepository {
    var fetch: (CollectionMapType) async throws -> [MyMap] = { _ in [] }
    private(set) var calls: [CollectionMapType] = []

    func fetchMyMaps(type: CollectionMapType) async throws -> [MyMap] {
        calls.append(type)
        return try await fetch(type)
    }
}
