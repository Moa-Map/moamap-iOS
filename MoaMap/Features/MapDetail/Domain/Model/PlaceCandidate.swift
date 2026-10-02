import Foundation

/// 카카오에서 찾은 장소 후보. 아직 우리 지도에 없고 id 도 카카오 것이다.
nonisolated struct PlaceCandidate: Identifiable, Equatable, Sendable {
    let kakaoPlaceID: String
    let name: String
    let address: String?
    let roadAddress: String?
    let latitude: Double
    let longitude: Double
    /// `"음식점 > 카페"` 같은 분류 경로.
    let category: String?
    /// 카카오맵 웹페이지. 서버의 `sourceUrl` 로 보낸다.
    let placeURL: String?

    var id: String { kakaoPlaceID }

    /// 도로명을 우선한다. 둘 다 없으면 빈 문자열.
    var displayAddress: String { roadAddress ?? address ?? "" }
}

/// 등록 폼이 모은 값.
nonisolated struct NewPlace: Equatable, Sendable {
    let candidate: PlaceCandidate
    let tags: [String]
    let memo: String
    /// 업로드가 끝난 뒤의 접근 URL.
    let photoURLs: [String]
}
