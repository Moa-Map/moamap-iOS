import Foundation

/// 지도 로그 탭의 게시물 한 건.
nonisolated struct MapPost: Identifiable, Equatable, Sendable {
    let id: Int64
    let authorID: Int64
    /// 서버가 비워 보내면 빈 문자열이다.
    let content: String
    /// 올린 순서 그대로다. 빈 주소는 뺀다.
    let imageURLs: [URL]
    /// 태그된 장소 이름. 올린 순서 그대로이고 빈 이름은 뺀다.
    let placeNames: [String]
    let createdAt: Date?
}

nonisolated enum MapPostSort: Sendable {
    /// 서버 기본값이다.
    case latest
    case oldest
}

nonisolated struct MapPostPage: Equatable, Sendable {
    let posts: [MapPost]
    /// 더 받을 페이지가 없다.
    let isLast: Bool
}
