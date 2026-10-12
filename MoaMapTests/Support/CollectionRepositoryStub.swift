@testable import MoaMap

@MainActor
final class CollectionRepositoryStub: CollectionRepository {
    var fetch: (CollectionMapType) async throws -> [MyMap] = { _ in [] }
    private(set) var calls: [CollectionMapType] = []

    func fetchMyMaps(type: CollectionMapType) async throws -> [MyMap] {
        calls.append(type)
        return try await fetch(type)
    }

    var updateOrder: (CollectionMapType, [Int64]) async throws -> Void = { _, _ in }
    private(set) var orders: [(type: CollectionMapType, mapIDs: [Int64])] = []

    func updateMapOrder(type: CollectionMapType, mapIDs: [Int64]) async throws {
        orders.append((type, mapIDs))
        try await updateOrder(type, mapIDs)
    }

    var join: (String) async throws -> Void = { _ in }
    private(set) var joinedCodes: [String] = []

    func joinByInviteCode(_ inviteCode: String) async throws {
        joinedCodes.append(inviteCode)
        try await join(inviteCode)
    }

    var uploadCover: (UploadImage) async throws -> String = { _ in "https://cdn.example.com/cover.jpg" }
    private(set) var uploadedCovers: [UploadImage] = []

    func uploadCoverImage(_ image: UploadImage) async throws -> String {
        uploadedCovers.append(image)
        return try await uploadCover(image)
    }

    var create: (NewMap) async throws -> CreatedMap = { _ in CreatedMap(id: 1, inviteCode: nil) }
    private(set) var createdMaps: [NewMap] = []

    func createMap(_ newMap: NewMap) async throws -> CreatedMap {
        createdMaps.append(newMap)
        return try await create(newMap)
    }

    var update: (Int64, MapUpdate) async throws -> Void = { _, _ in }
    private(set) var updates: [(mapID: Int64, update: MapUpdate)] = []

    func updateMap(mapID: Int64, _ update: MapUpdate) async throws {
        updates.append((mapID, update))
        try await self.update(mapID, update)
    }
}
