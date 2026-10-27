import Foundation

/// 내가 차단한 사람 한 명.
nonisolated struct BlockedUser: Identifiable, Equatable, Sendable {
    let id: Int64
    /// 비어 오면 nil 이다.
    let nickname: String?
    let profileImageURL: URL?
}
