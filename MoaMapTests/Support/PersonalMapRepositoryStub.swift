import Foundation
@testable import MoaMap

@MainActor
final class PersonalMapRepositoryStub: PersonalMapRepository {
    var add: (Int64) async throws -> Void = { _ in }
    private(set) var addCalls = 0

    func addPlace(placeID: Int64) async throws {
        addCalls += 1
        try await add(placeID)
    }
}
