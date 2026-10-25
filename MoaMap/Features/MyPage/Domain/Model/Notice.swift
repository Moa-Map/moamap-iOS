import Foundation

nonisolated struct Notice: Equatable, Identifiable, Sendable {
    let id: Int64
    let title: String
    let content: String
    /// 서버 값을 읽지 못했으면 nil 이고 화면은 날짜를 빼고 그린다.
    let createdAt: Date?
}

nonisolated struct NoticePage: Equatable, Sendable {
    let notices: [Notice]
    let isLast: Bool
}
