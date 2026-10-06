import Foundation
import Testing
@testable import MoaMap

struct ShareDeepLinkTests {
    @Test(arguments: [
        "네이버 지도\nhttps://naver.me/xAbCdEf",
        "https://map.kakao.com/?target=other&folderid=23211144#top",
        "https://www.instagram.com/reel/ABC123/?igsh=MXAzYnk1ZQ%3D%3D",
        "a+b=c 서울숲 ?/",
        "",
    ])
    func 만든_주소를_풀면_원문이_나온다(text: String) throws {
        let url = try #require(ShareDeepLink.url(text: text))
        #expect(ShareDeepLink.sharedText(from: url) == text)
    }

    @Test func 확장과_같은_형식이다() throws {
        let url = try #require(ShareDeepLink.url(text: "a&b"))
        #expect(url.absoluteString == "moamap://share?text=a%26b")
    }

    @Test func 글_항목이_없으면_빈_글이다() throws {
        #expect(ShareDeepLink.sharedText(from: try #require(URL(string: "moamap://share"))) == "")
    }

    @Test(arguments: ["kakao1234://oauth?code=x", "moamap://other?text=x", "https://naver.me/x"])
    func 공유_주소가_아니면_무시한다(string: String) throws {
        #expect(ShareDeepLink.sharedText(from: try #require(URL(string: string))) == nil)
    }
}
