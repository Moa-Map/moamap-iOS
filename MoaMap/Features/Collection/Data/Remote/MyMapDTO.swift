import Foundation

nonisolated struct MyMapPageResponse: Decodable, Sendable {
    let content: [MyMapResponse]?
}

nonisolated struct MyMapResponse: Decodable, Sendable {
    let id: Int64
    let name: String?
    let imageUrl: String?
    let type: String?
    let memberCount: Int?
    let placeCount: Int?
    let personal: Bool?

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
            personal: personal ?? false
        )
    }
}
