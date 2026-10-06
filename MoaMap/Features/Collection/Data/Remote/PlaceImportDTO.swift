import Foundation

nonisolated struct InstagramExtractRequest: Encodable, Sendable {
    let url: String
    /// 캡션 전문. 서버 필수값이다.
    let description: String
}

nonisolated struct PlaceCandidateResponse: Decodable, Sendable {
    let kakaoPlaceId: String?
    let name: String?
    let category: String?
    let address: String?
    let roadAddress: String?
    let lat: Double?
    let lng: Double?
    let sourceUrl: String?
}

nonisolated struct MapShareExtractRequest: Encodable, Sendable {
    let url: String
}

nonisolated struct MapShareExtractResponse: Decodable, Sendable {
    /// NAVER_MAP, KAKAO_MAP, GOOGLE_MAP
    let source: String?
    /// 카카오 장소와 다시 맞춘 항목. 맞추지 못한 `unmatched` 는 등록할 수 없어 읽지 않는다.
    let matched: [MapSharePlaceCandidateResponse]?
}

nonisolated struct MapSharePlaceCandidateResponse: Decodable, Sendable {
    let kakaoPlaceId: String?
    let name: String?
    let category: String?
    let address: String?
    let roadAddress: String?
    let lat: Double?
    let lng: Double?
    let description: String?
    let sourceUrl: String?
    let sourceType: String?
}

nonisolated struct PlaceBulkCreateRequest: Encodable, Sendable {
    /// 서버가 한 요청에 받는 장소 수.
    static let maxPlaces = 100

    let mapId: Int64
    let places: [PlaceBulkItem]
}

/// 단건 등록 요청에서 `mapId` 만 뺀 모양. 빈 값은 보내지 않는다.
nonisolated struct PlaceBulkItem: Encodable, Sendable {
    let name: String
    let address: String?
    let roadAddress: String?
    let lat: Double
    let lng: Double
    let category: String?
    let kakaoPlaceId: String
    let sourceType: String
    let sourceUrl: String?
    let description: String?
    let tags: [String]?
    let photoUrls: [String]?

    init(_ entry: EditedPlace, photoURLs: [String]) {
        let place = entry.place
        name = place.name
        address = place.address
        roadAddress = place.roadAddress
        lat = place.latitude
        lng = place.longitude
        category = place.category
        // 고를 수 있었던 장소만 들어온다.
        kakaoPlaceId = place.kakaoPlaceID ?? ""
        sourceType = place.sourceType
        sourceUrl = place.sourceURL
        // 편집 화면의 메모가 곧 설명이다. 외부 지도에서 온 메모도 이 값으로 들어온다.
        let memo = entry.edit.memo.trimmingCharacters(in: .whitespacesAndNewlines)
        description = memo.isEmpty ? nil : memo
        tags = entry.edit.tags.isEmpty ? nil : entry.edit.tags
        photoUrls = photoURLs.isEmpty ? nil : photoURLs
    }
}

nonisolated struct PlaceBulkCreateResponse: Decodable, Sendable {
    let results: [PlaceBulkResult]?
}

nonisolated struct PlaceBulkResult: Decodable, Sendable {
    /// CREATED, DUPLICATE, FAILED
    let status: String?
}

nonisolated extension PlaceCandidateResponse {
    func toDomain(index: Int) -> ImportedPlace {
        ImportedPlace(
            id: kakaoPlaceId.nonBlank ?? "candidate-\(index)",
            name: name ?? "",
            address: address,
            roadAddress: roadAddress,
            latitude: lat ?? 0,
            longitude: lng ?? 0,
            category: category,
            kakaoPlaceID: kakaoPlaceId,
            // 이 응답에는 출처가 없다. 이 경로로 온 후보는 전부 릴스에서 나왔다.
            sourceType: "INSTAGRAM",
            sourceURL: sourceUrl
        )
    }
}

nonisolated extension MapSharePlaceCandidateResponse {
    func toDomain(index: Int, fallbackSource: String?) -> ImportedPlace {
        ImportedPlace(
            id: kakaoPlaceId.nonBlank ?? "candidate-\(index)",
            name: name ?? "",
            address: address,
            roadAddress: roadAddress,
            latitude: lat ?? 0,
            longitude: lng ?? 0,
            category: category,
            description: description,
            kakaoPlaceID: kakaoPlaceId,
            // 리스트 전체가 한 지도에서 나와, 비어 있으면 응답 최상단의 출처로 채운다.
            sourceType: sourceType.nonBlank ?? fallbackSource ?? "",
            sourceURL: sourceUrl
        )
    }
}

private nonisolated extension Optional where Wrapped == String {
    var nonBlank: String? {
        guard let self, !self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return self
    }
}
