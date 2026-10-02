import Foundation

/// GET api/v1/maps/official 응답 항목. 쓰지 않는 필드는 선언하지 않는다.
nonisolated struct OfficialMapResponse: Decodable, Sendable {
    let id: Int64?
    let name: String?
    let description: String?
    let imageUrl: String?
    let joined: Bool?
}

nonisolated struct OfficialMapPageResponse: Decodable, Sendable {
    let content: [OfficialMapResponse]?
}

nonisolated extension OfficialMapResponse {
    /// 이름 없는 지도는 서버 데이터가 깨진 경우다. 카드가 빈 줄로 보이지 않게 자리를 채운다.
    static let untitled = "이름 없는 지도"

    /// 식별자가 없으면 열 수 없어 버린다.
    func toDomain() -> OfficialMap? {
        guard let id else { return nil }
        let title = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return OfficialMap(
            id: id,
            title: title.isEmpty ? Self.untitled : title,
            description: description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            imageURL: imageUrl.flatMap { $0.isEmpty ? nil : URL(string: $0) },
            joined: joined ?? false
        )
    }
}
