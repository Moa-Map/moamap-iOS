import Foundation

/// 프로필 편집 화면이 쓰는 내 정보.
nonisolated struct MyProfile: Equatable, Sendable {
    let id: Int64
    let nickname: String
    /// 소셜 로그인이 정하는 값이라 화면에서 고칠 수 없다.
    let email: String
    let profileImageURL: URL?
    let introduction: String
}
