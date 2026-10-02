import Foundation
import Testing
@testable import MoaMap

struct KakaoMapLinkTests {
    @Test func 장소_id_가_있으면_앱과_웹_장소_화면을_연다() {
        #expect(KakaoMapLink.appURL(kakaoPlaceID: " 123 ")?.absoluteString == "kakaomap://place?id=123")
        #expect(KakaoMapLink.webURL(kakaoPlaceID: "123", placeName: "카페")?.absoluteString == "https://place.map.kakao.com/123")
    }

    @Test func 장소_id_가_없으면_이름으로_찾는다() {
        #expect(KakaoMapLink.appURL(kakaoPlaceID: "") == nil)
        #expect(KakaoMapLink.webURL(kakaoPlaceID: "", placeName: " 커피 나무/1 ")?.absoluteString
            == "https://map.kakao.com/link/search/%EC%BB%A4%ED%94%BC%20%EB%82%98%EB%AC%B4%2F1")
    }
}
