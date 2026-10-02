@MainActor
protocol PlaceReviewRepository {
    /// 장소에 달린 댓글 전부. 최신 글이 앞에 온다.
    func fetchReviews(placeID: Int64) async throws -> [PlaceReview]
    /// 지도 멤버만 쓸 수 있다. 사진이 있으면 먼저 올린 뒤 작성한다.
    func createReview(placeID: Int64, content: String, photo: UploadImage?) async throws
    /// 글만 보낸다. 서버는 보내지 않은 필드를 그대로 두어 사진은 남는다.
    func updateReview(placeID: Int64, reviewID: Int64, content: String) async throws
    func deleteReview(placeID: Int64, reviewID: Int64) async throws
}
