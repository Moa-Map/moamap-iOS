import Foundation

@MainActor
final class ExploreRepositoryImpl: ExploreRepository {
    private let client: APIClient

    init(client: APIClient) {
        self.client = client
    }

    func fetchRecommendedMaps(size: Int) async throws -> [MapSummary] {
        let request = APIRequest(
            path: ["api", "v1", "maps", "recommendations"],
            queryItems: [URLQueryItem(name: "size", value: String(size))]
        )
        let response = try await client.send(request, as: [MapRecommendationResponse].self)
        return response.compactMap { $0.toDomain() }
    }

    func fetchCommunityMaps(sort: MapSortOrder, page: Int, size: Int) async throws -> MapPage {
        let request = APIRequest(
            path: ["api", "v1", "maps"],
            queryItems: [
                URLQueryItem(name: "sort", value: sort.queryValue),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size))
            ]
        )
        let response = try await client.send(request, as: MapPageResponse.self)
        let maps = (response.content ?? []).compactMap { $0.toDomain() }
        // last 가 없으면 더 받을 수 없는 것으로 보고 반복 요청을 막는다.
        return MapPage(maps: maps, isLast: response.last ?? true)
    }

    func fetchMyNickname() async throws -> String? {
        let request = APIRequest(path: ["api", "v1", "users", "me"])
        let nickname = try await client.send(request, as: MyPageResponse.self).nickname?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return nickname?.isEmpty == false ? nickname : nil
    }
}

private nonisolated extension MapSortOrder {
    var queryValue: String {
        switch self {
        case .popular: "POPULAR"
        case .latest: "LATEST"
        }
    }
}
