import Foundation
@testable import MoaMap

@MainActor
final class MapDetailRepositoryStub: MapDetailRepository {
    var detail: (Int64) async throws -> MapDetail = { MapDetail.fixture(id: $0) }
    var places: (Int64) async throws -> [MapPlace] = { _ in [] }
    var join: (Int64) async throws -> Void = { _ in }
    private(set) var detailCalls = 0
    private(set) var placeCalls = 0
    private(set) var joinCalls = 0

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
}

extension MapDetail {
    static func fixture(id: Int64 = 1, title: String = "지도", joined: Bool = false, type: MapType = .community) -> MapDetail {
        MapDetail(
            id: id, title: title, description: nil, imageURL: nil, ownerName: nil, type: type, role: .none,
            tags: [], memberCount: 1, placeCount: 0, joined: joined, personal: false, inviteCode: nil
        )
    }
}

extension MapPlace {
    static func fixture(id: Int64) -> MapPlace {
        MapPlace(id: id, name: "장소 \(id)", address: "", latitude: 37.5, longitude: 127.0, photoURL: nil)
    }
}
