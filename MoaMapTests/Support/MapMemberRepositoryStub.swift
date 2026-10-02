import Foundation
@testable import MoaMap

@MainActor
final class MapMemberRepositoryStub: MapMemberRepository {
    var members: (Int64) async throws -> [MapMember] = { _ in [] }
    var grant: (Int64) async throws -> Void = { _ in }
    private(set) var fetchCalls = 0
    private(set) var grantCalls = 0

    func fetchMembers(mapID: Int64) async throws -> [MapMember] {
        fetchCalls += 1
        return try await members(mapID)
    }

    func grantAdmin(mapID: Int64, userID: Int64) async throws {
        grantCalls += 1
        try await grant(userID)
    }
}

extension MapMember {
    static func fixture(id: Int64, role: MapRole = .member) -> MapMember {
        MapMember(id: id, name: "멤버 \(id)", imageURL: nil, role: role, placeCount: 0)
    }
}
