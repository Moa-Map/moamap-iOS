import Foundation

/// 장소에 달린 댓글 한 건. 사진만 남기고 글은 비워 둘 수 있다.
nonisolated struct PlaceReview: Identifiable, Equatable, Sendable {
    let id: Int64
    let authorID: Int64
    /// 닉네임을 못 얻으면 nil 이다.
    let authorName: String?
    let content: String
    /// 서버가 한 장까지만 받지만 목록으로 내려온다.
    var imageURLs: [URL] = []
    /// 서버 값이 없거나 못 읽으면 nil 이다.
    var createdAt: Date?
}

nonisolated extension PlaceReview {
    /// 로그인한 사람을 모르면 아무것도 내 것으로 보지 않는다. 잘못 보면 서버가 거절할 버튼이 뜬다.
    func isMine(_ myUserID: Int64?) -> Bool {
        myUserID != nil && authorID == myUserID
    }
}
