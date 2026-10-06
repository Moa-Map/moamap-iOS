import Testing
@testable import MoaMap

struct SharedLinkParserTests {
    private func supported(_ text: String) -> (url: String, source: PlaceImportSource)? {
        if case .supported(let url, let source) = SharedLinkParser.parse(text) { (url, source) } else { nil }
    }

    @Test func 인스타그램_릴스는_쿼리까지_그대로_인스타그램으로_간다() {
        let link = supported("https://www.instagram.com/reel/ABC123/?igsh=MXAzYnk1ZQ%3D%3D")
        #expect(link?.source == .instagram)
        #expect(link?.url == "https://www.instagram.com/reel/ABC123/?igsh=MXAzYnk1ZQ%3D%3D")
    }

    @Test func 앞에_글이_붙은_지도_공유도_URL_만_뽑는다() {
        #expect(supported("네이버 지도\nhttps://naver.me/xAbCdEf")?.url == "https://naver.me/xAbCdEf")
        #expect(supported("카카오맵에서 확인하세요 https://kko.to/0FyvknIfua")?.source == .mapShare)
        #expect(supported("성수동 카페\nhttps://maps.app.goo.gl/AbCdEfGhIjK")?.source == .mapShare)
    }

    @Test(arguments: [
        "https://naver.me/xAbCdEf",
        "https://map.naver.com/p/entry/place/1234567",
        "https://m.map.naver.com/pt/1234567",
        "https://pages.map.naver.com/save-pages/web/detail-list/abc",
        "https://place.naver.com/restaurant/1234567/home",
        "https://m.place.naver.com/restaurant/1234567/home",
        "https://kko.to/0FyvknIfua",
        "https://kko.kakao.com/AbCdEfGh",
        "https://map.kakao.com/?target=other&folderid=23211144",
        "https://applink.map.kakao.com/open?page=bookmark&folderid=1",
        "https://m.map.kakao.com/actions/detailMapView?id=1234567",
        "https://place.map.kakao.com/1234567",
        "https://maps.app.goo.gl/AbCdEfGhIjK",
        "https://maps.google.com/?cid=1234567",
        "https://goo.gl/maps/AbCdEfGhIjK",
        "https://www.google.com/maps/place/성수동",
        "https://google.co.kr/maps/place/성수동",
        "https://www.google.com/maps/place/서울숲/@37.5,127.0,17z",
    ])
    func 지도_도메인은_서브도메인까지_인정한다(url: String) {
        #expect(supported(url)?.source == .mapShare)
    }

    @Test(arguments: [
        "https://map.naver.com.evil.com/path",
        "https://evil.com/map.kakao.com",
        "https://notgoo.gl/maps/abc",
        "https://www.google.com/search?q=성수동",
        "https://www.instagram.com/moamap_official/",
        "https://youtu.be/AbCdEfGh",
        "https://example.com/place/1",
        "오늘 여기 갈래?",
        "",
    ])
    func 지원하지_않는_공유는_거절한다(text: String) {
        #expect(SharedLinkParser.parse(text) == .unsupported)
    }

    @Test func 없는_글은_거절한다() {
        #expect(SharedLinkParser.parse(nil) == .unsupported)
    }

    @Test func URL_끝에_붙은_문장부호는_뗀다() {
        #expect(supported("여기 어때? (https://naver.me/xAbCdEf)")?.url == "https://naver.me/xAbCdEf")
        #expect(supported("여기야. https://naver.me/xAbCdEf.")?.url == "https://naver.me/xAbCdEf")
    }

    @Test func 여러_URL_이면_첫_번째를_쓴다() {
        #expect(supported("https://naver.me/xAbCdEf 그리고 https://kko.kakao.com/AbCdEfGh")?.url == "https://naver.me/xAbCdEf")
    }
}
