import Foundation

nonisolated struct MyMapPageResponse: Decodable, Sendable {
    let content: [MyMapResponse]?
    let last: Bool?
}

nonisolated struct MyMapResponse: Decodable, Sendable {
    let id: Int64
    let name: String?
    let imageUrl: String?
    let type: String?
    let memberCount: Int?
    let placeCount: Int?
    let personal: Bool?
    let myRole: String?

    func toDomain() -> MyMap {
        let hasName = name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let image = imageUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
        return MyMap(
            id: id,
            title: hasName ? (name ?? "이름 없는 지도") : "이름 없는 지도",
            imageURL: image.flatMap { $0.isEmpty ? nil : URL(string: $0) },
            memberCount: memberCount ?? 0,
            placeCount: placeCount ?? 0,
            official: type == "OFFICIAL",
            personal: personal ?? false,
            role: MapRole(serverValue: myRole)
        )
    }
}

nonisolated struct MapOrderUpdateRequest: Encodable, Sendable {
    let type: String
    let mapIds: [Int64]
}

nonisolated struct JoinByInviteCodeRequest: Encodable, Sendable {
    let inviteCode: String
}

nonisolated struct MapCreateRequest: Encodable, Sendable {
    let name: String
    let description: String?
    let imageUrl: String?
    let visibility: String
    let tags: [String]?

    /// 빈 값은 보내지 않는다. 빈 문자열·빈 목록이 그대로 저장되지 않게 한다.
    init(_ newMap: NewMap) {
        name = newMap.name.trimmingCharacters(in: .whitespacesAndNewlines)
        description = newMap.description.nonBlank
        imageUrl = newMap.imageURL?.nonBlank
        visibility = newMap.visibility == .public ? "PUBLIC" : "PRIVATE"
        tags = newMap.tags.isEmpty ? nil : newMap.tags
    }
}

/// 빠진 값은 서버가 비운다. 설명·사진을 지우려는 게 아니면 원래 값을 담아 보낸다.
nonisolated struct MapUpdateRequest: Encodable, Sendable {
    let name: String
    let description: String?
    let imageUrl: String?
    let tags: [String]

    init(_ update: MapUpdate) {
        name = update.name.trimmingCharacters(in: .whitespacesAndNewlines)
        description = update.description.nonBlank
        imageUrl = update.imageURL?.nonBlank
        tags = update.tags
    }
}

nonisolated struct CreatedMapResponse: Decodable, Sendable {
    let id: Int64
    let inviteCode: String?

    func toDomain() -> CreatedMap {
        CreatedMap(id: id, inviteCode: inviteCode?.nonBlank)
    }
}

nonisolated struct CoverUploadURLRequest: Encodable, Sendable {
    let contentType: String
    let fileSize: Int
}

nonisolated struct CoverUploadURLResponse: Decodable, Sendable {
    let uploadUrl: String?
    let fileUrl: String?
}

private extension String {
    nonisolated var nonBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
