import Foundation

nonisolated struct MapSummaryResponse: Decodable, Sendable {
    let id: Int64?
    let name: String?
    let imageUrl: String?
    let tags: [String]?
    let memberCount: Int?
    let placeCount: Int?
}

nonisolated struct MapPageResponse: Decodable, Sendable {
    let content: [MapSummaryResponse]?
    let last: Bool?
}

nonisolated struct MapRecommendationResponse: Decodable, Sendable {
    let id: Int64?
    let name: String?
    let imageUrl: String?
    let tags: [String]?
    let memberCount: Int?
}

nonisolated struct MyPageResponse: Decodable, Sendable {
    let nickname: String?
}

nonisolated extension MapSummaryResponse {
    /// 식별자나 이름이 없는 항목은 화면에 그릴 수 없어 버린다.
    func toDomain() -> MapSummary? {
        MapSummary(id: id, name: name, imageUrl: imageUrl, tags: tags, memberCount: memberCount, placeCount: placeCount ?? 0)
    }
}

nonisolated extension MapRecommendationResponse {
    func toDomain() -> MapSummary? {
        MapSummary(id: id, name: name, imageUrl: imageUrl, tags: tags, memberCount: memberCount, placeCount: nil)
    }
}

private nonisolated extension MapSummary {
    init?(id: Int64?, name: String?, imageUrl: String?, tags: [String]?, memberCount: Int?, placeCount: Int?) {
        guard let id, let name, !name.isEmpty else { return nil }
        self.init(
            id: id,
            title: name,
            imageURL: imageUrl.flatMap { $0.isEmpty ? nil : URL(string: $0) },
            tags: tags ?? [],
            memberCount: memberCount ?? 0,
            placeCount: placeCount
        )
    }
}
