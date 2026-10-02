import Foundation

/// 장소 한 건 조회 응답. 다른 지도로 옮길 때 필요한 값만 받는다.
nonisolated struct PlaceDetailResponse: Decodable, Sendable {
    let id: Int64
    let name: String?
    let address: String?
    let roadAddress: String?
    let lat: Double?
    let lng: Double?
    let category: String?
    let kakaoPlaceId: String?
    let sourceType: String?
    let sourceUrl: String?
    let description: String?
    let tags: [String]?
    let photoUrls: [String]?
}

nonisolated struct PlaceCreateRequest: Encodable, Sendable {
    let name: String
    let address: String?
    let roadAddress: String?
    let lat: Double
    let lng: Double
    let category: String?
    let kakaoPlaceId: String
    /// KAKAO_SEARCH, INSTAGRAM
    let sourceType: String
    let sourceUrl: String?
    let description: String?
    let mapId: Int64
    let tags: [String]?
    let photoUrls: [String]?
}

nonisolated struct PlaceCopyError: Error {}

nonisolated extension PlaceDetailResponse {
    /// 사진은 올린 주소를 그대로 쓴다. 카카오 장소 id 는 서버 필수값이라 없으면 옮기지 않는다.
    func copyRequest(mapID: Int64) throws -> PlaceCreateRequest {
        guard let kakaoID = kakaoPlaceId.nonBlank, let lat, let lng else { throw PlaceCopyError() }
        let photos = (photoUrls ?? []).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return PlaceCreateRequest(
            name: name ?? "",
            address: address.nonBlank,
            roadAddress: roadAddress.nonBlank,
            lat: lat,
            lng: lng,
            category: category.nonBlank,
            kakaoPlaceId: kakaoID,
            // 출처가 비어 있는 옛 장소는 카카오 검색으로 등록된 것으로 본다.
            sourceType: sourceType.nonBlank ?? "KAKAO_SEARCH",
            sourceUrl: sourceUrl.nonBlank,
            description: description.nonBlank,
            mapId: mapID,
            tags: tags.flatMap { $0.isEmpty ? nil : $0 },
            photoUrls: photos.isEmpty ? nil : photos
        )
    }
}

private nonisolated extension Optional where Wrapped == String {
    var nonBlank: String? {
        guard let self, !self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return self
    }
}
