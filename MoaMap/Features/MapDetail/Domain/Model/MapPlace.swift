import Foundation

/// 지도에 등록된 장소 한 건. 미리보기 목록과 상세 화면 마커가 함께 쓴다.
nonisolated struct MapPlace: Identifiable, Equatable, Sendable {
    let id: Int64
    let name: String
    /// 도로명 주소를 우선 쓰고 없으면 지번 주소. 둘 다 없으면 빈 문자열.
    let address: String
    let latitude: Double
    let longitude: Double
    /// 등록할 때 붙인 사진. 순서대로 온다.
    let photoURLs: [URL]
    /// 등록자가 적은 한 줄 설명.
    var description = ""
    /// 카카오 분류 경로. `"음식점 > 카페 > 커피전문점"` 처럼 온다.
    var category = ""
    var reviewCount = 0
    var kakaoPlaceID = ""
    var likeCount = 0
    var liked = false
    /// 장소를 가져온 인스타그램 게시물.
    var instagramURL: URL?
}

nonisolated extension MapPlace {
    /// 목록 썸네일·마커에 쓰는 대표 사진. 첫 장이다.
    var photoURL: URL? { photoURLs.first }

    /// 분류 경로의 마지막 토막. `"커피전문점"`
    var categoryLabel: String {
        category.split(separator: ">").last?.trimmingCharacters(in: .whitespaces) ?? ""
    }
}

/// 하트를 누르거나 취소한 뒤 서버가 확정한 상태.
nonisolated struct PlaceLike: Equatable, Sendable {
    let liked: Bool
    let likeCount: Int
}
