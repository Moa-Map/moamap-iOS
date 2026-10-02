import Foundation

nonisolated struct KakaoKeywordSearchResponse: Decodable, Sendable {
    let documents: [KakaoPlaceResponse]?
}

/// 카카오 키워드 검색 결과 한 건. 사진은 오지 않는다.
nonisolated struct KakaoPlaceResponse: Decodable, Sendable {
    let id: String?
    let placeName: String?
    let addressName: String?
    let roadAddressName: String?
    /// 경도. 숫자가 아니라 문자열로 온다.
    let x: String?
    /// 위도.
    let y: String?
    let categoryName: String?
    let placeUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, x, y
        case placeName = "place_name"
        case addressName = "address_name"
        case roadAddressName = "road_address_name"
        case categoryName = "category_name"
        case placeUrl = "place_url"
    }

    /// `x` 가 경도, `y` 가 위도다. 뒤집으면 마커가 중국 근처에 선다.
    /// 등록 필수값이 없는 항목은 후보로 삼지 않는다. 고른 뒤에야 막히면 이유를 알 수 없다.
    func toCandidate() -> PlaceCandidate? {
        guard let id = id.nonBlank, let name = placeName.nonBlank,
              let longitude = x.flatMap(Double.init), (-180...180).contains(longitude),
              let latitude = y.flatMap(Double.init), (-90...90).contains(latitude) else { return nil }
        return PlaceCandidate(
            kakaoPlaceID: id, name: name, address: addressName.nonBlank, roadAddress: roadAddressName.nonBlank,
            latitude: latitude, longitude: longitude, category: categoryName.nonBlank, placeURL: placeUrl.nonBlank
        )
    }
}

nonisolated struct PlacePhotoUploadURLRequest: Encodable, Sendable {
    struct File: Encodable, Sendable {
        let contentType: String
        let fileSize: Int
    }

    let mapId: Int64
    let files: [File]
}

nonisolated struct PlacePhotoUploadURLResponse: Decodable, Sendable {
    let uploadUrl: String?
    let fileUrl: String?
}

private nonisolated extension Optional where Wrapped == String {
    var nonBlank: String? {
        guard let self, !self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return self
    }
}
