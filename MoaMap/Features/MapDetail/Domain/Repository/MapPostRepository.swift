@MainActor
protocol MapPostRepository {
    /// `page` 는 0 부터 센다. 커뮤니티 지도는 누구나, 프라이빗 지도는 멤버만 볼 수 있다.
    func fetchPosts(mapID: Int64, page: Int, sort: MapPostSort) async throws -> MapPostPage
    /// 게시물 하나. 목록과 같은 모양이다. 지워졌으면 404.
    func fetchPost(mapID: Int64, postID: Int64) async throws -> MapPost
    /// 고른 순서대로 올린 주소를 돌려준다. 하나라도 형식·크기에 걸리면 아무것도 올리지 않고 던진다.
    func uploadPhotos(mapID: Int64, photos: [UploadImage]) async throws -> [String]
    /// 지도 멤버만 쓸 수 있다.
    func createPost(mapID: Int64, post: NewMapPost) async throws
}
