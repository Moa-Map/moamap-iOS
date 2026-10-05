@testable import MoaMap

@MainActor
final class OfficialMapRepositoryStub: OfficialMapRepository {
    var fetch: () async throws -> [OfficialMap] = { [] }
    private(set) var fetchCalls = 0

    func fetchOfficialMaps() async throws -> [OfficialMap] {
        fetchCalls += 1
        return try await fetch()
    }
}
