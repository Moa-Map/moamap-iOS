import Foundation

nonisolated struct MapPostPageResponse: Decodable, Sendable {
    let content: [MapPostResponse]?
    let last: Bool?
}

/// 작성자는 식별자만 온다.
nonisolated struct MapPostResponse: Decodable, Sendable {
    let id: Int64
    let userId: Int64?
    let content: String?
    let imageUrls: [String]?
    let placeTags: [MapPostPlaceTagResponse]?
    let createdAt: String?

    /// 빈 사진 주소와 빈 장소 이름은 뺀다. 남기면 카드가 빈 사진과 빈 알약을 그린다.
    func toDomain(timeZone: TimeZone) -> MapPost {
        MapPost(
            id: id,
            authorID: userId ?? 0,
            content: content ?? "",
            imageURLs: (imageUrls ?? []).compactMap { raw in
                let url = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                return url.isEmpty ? nil : URL(string: url)
            },
            placeNames: (placeTags ?? []).compactMap { tag in
                let name = tag.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return name.isEmpty ? nil : name
            },
            createdAt: ServerDateTime.parse(createdAt, timeZone: timeZone)
        )
    }
}

/// `name` 은 태그한 시점의 이름이라 장소 이름이 바뀌어도 그대로다.
nonisolated struct MapPostPlaceTagResponse: Decodable, Sendable {
    let placeId: Int64?
    let name: String?
}

/// `placeTags` 는 서버가 검증하지 않고 받은 이름을 그대로 저장한다.
nonisolated struct MapPostCreateRequest: Encodable, Sendable {
    let content: String
    let imageUrls: [String]
    let placeTags: [MapPostPlaceTagRequest]
}

nonisolated struct MapPostPlaceTagRequest: Encodable, Sendable {
    let placeId: Int64
    let name: String
}

/// 한 장씩 발급한다.
nonisolated struct MapPostPhotoUploadURLRequest: Encodable, Sendable {
    let contentType: String
    let fileSize: Int
}

nonisolated struct MapPostPhotoUploadURLResponse: Decodable, Sendable {
    let uploadUrl: String?
    let fileUrl: String?
}
