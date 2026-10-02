import Foundation

/// 카카오맵에서 장소를 연다. 앱이 있으면 앱, 없으면 웹이다.
nonisolated enum KakaoMapLink {
    static func appURL(kakaoPlaceID: String) -> URL? {
        let id = kakaoPlaceID.trimmingCharacters(in: .whitespaces)
        return id.isEmpty ? nil : URL(string: "kakaomap://place?id=\(id)")
    }

    /// 장소 id 가 비어 있으면 이름으로 찾는다. 버튼이 아무 일도 하지 않으면 고장처럼 보인다.
    static func webURL(kakaoPlaceID: String, placeName: String) -> URL? {
        let id = kakaoPlaceID.trimmingCharacters(in: .whitespaces)
        if !id.isEmpty { return URL(string: "https://place.map.kakao.com/\(id)") }
        let name = placeName.trimmingCharacters(in: .whitespaces)
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))) ?? ""
        return URL(string: "https://map.kakao.com/link/search/\(name)")
    }
}
