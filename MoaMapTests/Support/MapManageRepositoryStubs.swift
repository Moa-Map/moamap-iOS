import Foundation
@testable import MoaMap

@MainActor
final class MapActivityRepositoryStub: MapActivityRepository {
    var activities: (Int64) async throws -> [MapActivity] = { _ in [] }
    private(set) var fetchCalls = 0

    func fetchActivities(mapID: Int64) async throws -> [MapActivity] {
        fetchCalls += 1
        return try await activities(mapID)
    }
}

@MainActor
final class PendingPlaceRepositoryStub: PendingPlaceRepository {
    var pending: (Int64) async throws -> [PendingPlace] = { _ in [] }
    var action: (Int64) async throws -> Void = { _ in }
    private(set) var approved: [Int64] = []
    private(set) var rejected: [Int64] = []

    func fetchPendingPlaces(mapID: Int64) async throws -> [PendingPlace] {
        try await pending(mapID)
    }

    func approve(placeID: Int64) async throws {
        approved.append(placeID)
        try await action(placeID)
    }

    func reject(placeID: Int64) async throws {
        rejected.append(placeID)
        try await action(placeID)
    }
}

extension PendingPlace {
    static func fixture(id: Int64) -> PendingPlace {
        PendingPlace(id: id, placeName: "장소 \(id)", requesterName: "모아", requesterImageURL: nil, requestedAt: nil)
    }
}
