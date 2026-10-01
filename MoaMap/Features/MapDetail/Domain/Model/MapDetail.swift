import Foundation

/// 지도 미리보기와 상세 화면이 함께 쓰는 지도 한 건.
nonisolated struct MapDetail: Identifiable, Equatable, Sendable {
    let id: Int64
    let title: String
    let description: String?
    let imageURL: URL?
    /// 제작자 닉네임. 조회에 실패하면 nil 이고 화면에서 그 줄을 숨긴다.
    let ownerName: String?
    let type: MapType
    let role: MapRole
    let tags: [String]
    let memberCount: Int
    let placeCount: Int
    let joined: Bool
    /// 가입할 때 자동으로 생기는 "나만의 지도". 서버가 PRIVATE 로 내려줘 `type` 으로는 못 가린다.
    let personal: Bool
    /// 참여자에게만 내려오는 프라이빗 지도 초대 코드.
    let inviteCode: String?
}

nonisolated enum MapType: Sendable {
    case community
    case `private`
    case official
}

/// 지도 안에서의 내 역할.
nonisolated enum MapRole: Sendable {
    case owner
    case admin
    case member
    case none
}

nonisolated extension MapDetail {
    /// 지도명 아래 역할 배지. 프라이빗·공식 지도는 역할이 뜻을 갖지 않아 띄우지 않는다.
    var roleBadge: String? {
        guard type == .community else { return nil }
        return switch role {
        case .owner: "방장"
        case .admin: "관리자"
        case .member: "멤버"
        case .none: nil
        }
    }

    /// 상단바에 참여하기를 띄울지. 서버의 참여 API 는 공개 지도 전용이고 프라이빗은 초대 코드로만 합류한다.
    var canJoin: Bool {
        !joined && !personal && type != .private
    }
}
