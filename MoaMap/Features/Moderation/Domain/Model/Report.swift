import Foundation

/// 사용자가 고르는 신고 사유. 값은 서버와 같다. 서버 전용 `BLOCKED` 는 넣지 않는다.
nonisolated enum ReportReason: String, CaseIterable, Sendable {
    case spam = "SPAM"
    case abuse = "ABUSE"
    case sexual = "SEXUAL"
    case privacy = "PRIVACY"
    case falseInfo = "FALSE_INFO"
    /// 서버가 내용을 꼭 받는다.
    case other = "OTHER"
}

/// 신고할 수 있는 것. 대상마다 받는 서비스가 다르다.
nonisolated enum ReportTarget: Hashable, Sendable {
    case place(placeID: Int64)
    case placeComment(placeID: Int64, commentID: Int64)
    case map(mapID: Int64)
    case mapPost(mapID: Int64, postID: Int64)
    case mapPostComment(mapID: Int64, postID: Int64, commentID: Int64)
    case user(userID: Int64)
}
