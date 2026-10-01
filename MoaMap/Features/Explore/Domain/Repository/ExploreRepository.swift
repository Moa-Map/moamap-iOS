@MainActor
protocol ExploreRepository {
    func fetchRecommendedMaps(size: Int) async throws -> [MapSummary]
    /// `tag` 가 nil 이면 전체. 그 외에는 태그가 정확히 일치하는 지도만 온다.
    func fetchCommunityMaps(tag: String?, sort: MapSortOrder, page: Int, size: Int) async throws -> MapPage
    func fetchMyNickname() async throws -> String?
}
