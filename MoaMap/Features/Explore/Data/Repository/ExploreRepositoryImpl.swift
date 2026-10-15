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

    func fetchCommunityMaps(tag: String?, sort: MapSortOrder, page: Int, size: Int) async throws -> MapPage {
        var queryItems = [
            URLQueryItem(name: "sort", value: sort.queryValue),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "size", value: String(size))
        ]
        if let tag { queryItems.append(URLQueryItem(name: "tag", value: tag)) }
        return try await fetchPage(APIRequest(path: ["api", "v1", "maps"], queryItems: queryItems))
    }

    /// 정렬은 보내지 않는다. 서버 기본(인기순)을 따른다.
    func searchMaps(keyword: String, page: Int, size: Int) async throws -> MapPage {
        let request = APIRequest(
            path: ["api", "v1", "maps", "search"],
            queryItems: [
                URLQueryItem(name: "keyword", value: keyword),
                URLQueryItem(name: "page", value: String(page)),
                URLQueryItem(name: "size", value: String(size))
            ]
        )
        return try await fetchPage(request)
    }

    func fetchMyNickname() async throws -> String? {
        let request = APIRequest(path: ["api", "v1", "users", "me"])
        let nickname = try await client.send(request, as: MyPageResponse.self).nickname?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return nickname?.isEmpty == false ? nickname : nil
    }

    private func fetchPage(_ request: APIRequest) async throws -> MapPage {
        let response = try await client.send(request, as: MapPageResponse.self)
        let maps = (response.content ?? []).compactMap { $0.toDomain() }
        // last 가 없으면 더 받을 수 없는 것으로 보고 반복 요청을 막는다.
        return MapPage(maps: maps, isLast: response.last ?? true)
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
