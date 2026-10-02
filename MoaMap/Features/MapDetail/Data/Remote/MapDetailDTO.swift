import Foundation

nonisolated struct MapDetailResponse: Decodable, Sendable {
    let id: Int64
    let name: String?
    let description: String?
    let imageUrl: String?
    let type: String?
    let ownerId: Int64?
    let tags: [String]?
    let memberCount: Int?
    let placeCount: Int?
    let joined: Bool?
    let personal: Bool?
    let myRole: String?
    let inviteCode: String?
}

nonisolated struct PlacePageResponse: Decodable, Sendable {
    let content: [PlaceResponse]?
    let last: Bool?
}

nonisolated struct PlaceResponse: Decodable, Sendable {
    let id: Int64
    let name: String?
    let address: String?
    let roadAddress: String?
    let lat: Double?
    let lng: Double?
    let category: String?
    let kakaoPlaceId: String?
    let description: String?
    let commentCount: Int?
    let likeCount: Int?
    let likedByMe: Bool?
    let photoUrls: [String]?
}

nonisolated struct PlaceLikeResponse: Decodable, Sendable {
    let likeCount: Int?
    let liked: Bool?
}

nonisolated struct UserProfileResponse: Decodable, Sendable {
    let id: Int64?
    let nickname: String?
}

nonisolated extension MapDetailResponse {
    /// 모르는 종류는 커뮤니티로 본다. 서버가 종류를 늘려도 화면은 열려야 한다.
    func toDomain(ownerName: String?) -> MapDetail {
        MapDetail(
            id: id,
            title: name.nonBlank ?? "이름 없는 지도",
            description: description.nonBlank,
            imageURL: imageUrl.nonBlank.flatMap(URL.init(string:)),
            ownerName: ownerName.nonBlank,
            type: MapType(serverValue: type),
            role: MapRole(serverValue: myRole),
            tags: (tags ?? []).filter { $0.nonBlank != nil },
            memberCount: memberCount ?? 0,
            placeCount: placeCount ?? 0,
            joined: joined ?? false,
            personal: personal ?? false,
            inviteCode: inviteCode.nonBlank
        )
    }
}

nonisolated extension PlaceResponse {
    /// 좌표가 없으면 지도에 찍을 수 없어 버린다.
    func toDomain() -> MapPlace? {
        guard let lat, let lng else { return nil }
        return MapPlace(
            id: id,
            name: name.nonBlank ?? "이름 없는 장소",
            address: roadAddress.nonBlank ?? address.nonBlank ?? "",
            latitude: lat,
            longitude: lng,
            photoURL: photoUrls?.lazy.compactMap { $0.nonBlank }.first.flatMap(URL.init(string:)),
            description: description.nonBlank ?? "",
            category: category.nonBlank ?? "",
            reviewCount: commentCount ?? 0,
            kakaoPlaceID: kakaoPlaceId?.trimmingCharacters(in: .whitespaces) ?? "",
            likeCount: likeCount ?? 0,
            liked: likedByMe ?? false
        )
    }
}

private nonisolated extension MapType {
    init(serverValue: String?) {
        self = switch serverValue {
        case "PRIVATE": .private
        case "OFFICIAL": .official
        default: .community
        }
    }
}

nonisolated extension MapRole {
    /// 모르는 값은 권한이 없는 쪽으로 본다.
    init(serverValue: String?) {
        self = switch serverValue {
        case "OWNER": .owner
        case "ADMIN": .admin
        case "MEMBER": .member
        default: .none
        }
    }
}

private nonisolated extension Optional where Wrapped == String {
    var nonBlank: String? {
        guard let self, !self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return self
    }
}

private nonisolated extension String {
    var nonBlank: String? { Optional(self).nonBlank }
}
