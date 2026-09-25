@MainActor
protocol ExploreRepository {
    func fetchRecommendedMaps(size: Int) async throws -> [MapSummary]
    func fetchCommunityMaps(sort: MapSortOrder, page: Int, size: Int) async throws -> MapPage
    func fetchMyNickname() async throws -> String?
}
