@testable import MoaMap

@MainActor
final class FootTrafficRepositoryStub: FootTrafficRepository {
    var fetch: () async throws -> [DensityArea] = { [] }
    private(set) var fetchCalls = 0

    func fetchDensityAreas() async throws -> [DensityArea] {
        fetchCalls += 1
        return try await fetch()
    }
}
