import Foundation

nonisolated struct BannerResponse: Decodable, Sendable {
    let bannerId: Int64?
    let imageUrl: String?
}

nonisolated extension BannerResponse {
    /// 식별자나 이미지 주소가 없으면 그릴 것이 없어 버린다.
    func toDomain() -> Banner? {
        guard let bannerId, let imageUrl, !imageUrl.isEmpty, let url = URL(string: imageUrl) else { return nil }
        return Banner(id: bannerId, imageURL: url)
    }
}
