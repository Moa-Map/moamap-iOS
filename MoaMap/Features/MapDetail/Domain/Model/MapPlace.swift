import Foundation

/// 지도에 등록된 장소 한 건. 미리보기 목록과 상세 화면 마커가 함께 쓴다.
nonisolated struct MapPlace: Identifiable, Equatable, Sendable {
    let id: Int64
    let name: String
    /// 도로명 주소를 우선 쓰고 없으면 지번 주소. 둘 다 없으면 빈 문자열.
    let address: String
    let latitude: Double
    let longitude: Double
    let photoURL: URL?
    /// 등록자가 적은 한 줄 설명.
    var description = ""
    /// 카카오 분류 경로. `"음식점 > 카페 > 커피전문점"` 처럼 온다.
    var category = ""
    var reviewCount = 0
    var kakaoPlaceID = ""
    var likeCount = 0
    var liked = false
}
