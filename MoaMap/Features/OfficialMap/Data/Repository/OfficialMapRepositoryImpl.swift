import Foundation

@MainActor
final class OfficialMapRepositoryImpl: OfficialMapRepository {
    /// 서버 기본값과 같다. 공식지도는 몇 개뿐이라 첫 페이지만 쓴다.
    static let pageSize = 20

    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func fetchOfficialMaps() async throws -> [OfficialMap] {
        let request = APIRequest(
            path: ["api", "v1", "maps", "official"],
            queryItems: [URLQueryItem(name: "size", value: String(Self.pageSize))]
        )
        let response = try await client.send(request, as: OfficialMapPageResponse.self)
        return (response.content ?? []).compactMap { $0.toDomain() }
    }
}
