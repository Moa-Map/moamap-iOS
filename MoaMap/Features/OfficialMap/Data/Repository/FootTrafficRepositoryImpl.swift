import Foundation

@MainActor
final class FootTrafficRepositoryImpl: FootTrafficRepository {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func fetchDensityAreas() async throws -> [DensityArea] {
        let base = ["api", "v1", "maps", "official", "foot-traffic"]
        async let areas = client.send(APIRequest(path: base + ["areas"]), as: [FootTrafficAreaResponse].self)
        async let congestions = client.send(APIRequest(path: base + ["congestion"]), as: [CongestionResponse].self)
        var congestionByCode: [String: CongestionResponse] = [:]
        for congestion in try await congestions {
            guard let code = congestion.footTrafficAreaCd else { continue }
            congestionByCode[code] = congestion
        }
        return try await areas.compactMap { $0.toDomain(congestion: $0.footTrafficAreaCd.flatMap { congestionByCode[$0] }) }
    }
}
