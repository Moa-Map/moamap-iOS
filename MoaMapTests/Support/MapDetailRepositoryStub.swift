import Foundation
@testable import MoaMap

@MainActor
final class MapDetailRepositoryStub: MapDetailRepository {
    var detail: (Int64) async throws -> MapDetail = { MapDetail.fixture(id: $0) }
    var places: (Int64) async throws -> [MapPlace] = { _ in [] }
    var join: (Int64) async throws -> Void = { _ in }
    var leave: (Int64) async throws -> Void = { _ in }
    var delete: (Int64) async throws -> Void = { _ in }
    var like: (Int64, Bool) async throws -> PlaceLike = { _, liked in PlaceLike(liked: liked, likeCount: liked ? 1 : 0) }
    private(set) var detailCalls = 0
    private(set) var placeCalls = 0
    private(set) var joinCalls = 0
    private(set) var leaveCalls = 0
    private(set) var deleteCalls = 0
    private(set) var likeCalls = 0

    func fetchMapDetail(mapID: Int64) async throws -> MapDetail {
        detailCalls += 1
        return try await detail(mapID)
    }

    func fetchPlaces(mapID: Int64) async throws -> [MapPlace] {
        placeCalls += 1
        return try await places(mapID)
    }

    func joinMap(mapID: Int64) async throws {
        joinCalls += 1
        try await join(mapID)
    }

    func leaveMap(mapID: Int64) async throws {
        leaveCalls += 1
        try await leave(mapID)
    }

    func deleteMap(mapID: Int64) async throws {
        deleteCalls += 1
        try await delete(mapID)
    }

    func setPlaceLiked(placeID: Int64, liked: Bool) async throws -> PlaceLike {
        likeCalls += 1
        return try await like(placeID, liked)
    }
}

extension MapDetail {
    static func fixture(
        id: Int64 = 1, title: String = "지도", joined: Bool = false, type: MapType = .community, role: MapRole = .none
    ) -> MapDetail {
        MapDetail(
            id: id, title: title, description: nil, imageURL: nil, ownerName: nil, type: type, role: role,
            tags: [], memberCount: 1, placeCount: 0, joined: joined, personal: false, inviteCode: nil
        )
    }
}

extension MapPlace {
    static func fixture(id: Int64) -> MapPlace {
        MapPlace(id: id, name: "장소 \(id)", address: "", latitude: 37.5, longitude: 127.0, photoURL: nil)
    }
}
