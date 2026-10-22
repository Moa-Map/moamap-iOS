import Foundation

/// 모음 탭에 표시하는 내가 참여한 지도.
nonisolated struct MyMap: Identifiable, Equatable, Sendable {
    let id: Int64
    let title: String
    let imageURL: URL?
    let memberCount: Int
    let placeCount: Int
    let official: Bool
    let personal: Bool
    /// 내 역할. 목록 응답에 없으면 `.none`.
    var role: MapRole = .none
}

/// 모음 카드 사진 모서리에 다는 내 역할 뱃지.
nonisolated enum MapRoleBadge: Sendable {
    case owner
    case admin
}

nonisolated extension MyMap {
    /// 방장·관리자만 단다. 공식지도에는 달지 않는다.
    var roleBadge: MapRoleBadge? {
        if official { return nil }
        return switch role {
        case .owner: .owner
        case .admin: .admin
        case .member, .none: nil
        }
    }
}

nonisolated enum CollectionMapType: CaseIterable, Sendable {
    case community
    case `private`
}
