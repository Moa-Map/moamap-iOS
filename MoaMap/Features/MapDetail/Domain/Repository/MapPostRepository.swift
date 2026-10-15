@MainActor
protocol MapPostRepository {
    /// `page` 는 0 부터 센다. 커뮤니티 지도는 누구나, 프라이빗 지도는 멤버만 볼 수 있다.
    func fetchPosts(mapID: Int64, page: Int, sort: MapPostSort) async throws -> MapPostPage
}
