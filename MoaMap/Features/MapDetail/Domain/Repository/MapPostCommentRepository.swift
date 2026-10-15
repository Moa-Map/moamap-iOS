/// 로그 탭 게시물의 댓글. 게시물 상세를 열 때만 쓴다.
@MainActor
protocol MapPostCommentRepository {
    /// 오래된 것부터 전부. 작성자 이름·사진을 붙여 준다.
    func fetchComments(mapID: Int64, postID: Int64) async throws -> [MapPostComment]
    /// 남긴 댓글을 돌려준다. 내 댓글이라 작성자 이름·사진은 채우지 않는다.
    func createComment(mapID: Int64, postID: Int64, content: String) async throws -> MapPostComment
}
