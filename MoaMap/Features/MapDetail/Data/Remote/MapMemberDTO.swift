import Foundation

nonisolated struct MapMemberListResponse: Decodable, Sendable {
    let members: [MapMemberResponse]?
}

nonisolated struct MapMemberResponse: Decodable, Sendable {
    let userId: Int64
    let nickname: String?
    let profileImageUrl: String?
    let role: String?
    let placeCount: Int?

    func toDomain() -> MapMember {
        let name = nickname?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let image = profileImageUrl?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return MapMember(
            id: userId,
            // 탈퇴했거나 프로필을 못 읽은 사람.
            name: name.isEmpty ? "알 수 없는 사용자" : name,
            imageURL: image.isEmpty ? nil : URL(string: image),
            role: MapRole(serverValue: role),
            placeCount: placeCount
        )
    }
}

nonisolated struct MapMemberRoleUpdateRequest: Encodable, Sendable {
    let role: String
}
