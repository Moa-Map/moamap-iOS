import Foundation
import Testing
@testable import MoaMap

@MainActor
struct SharedLinkInboxTests {
    @Test func 공유_주소를_판정해_보관하고_꺼내면_비운다() throws {
        let sut = SharedLinkInbox()
        let url = try #require(ShareDeepLink.url(text: "네이버 지도\nhttps://naver.me/xAbCdEf"))
        #expect(sut.receive(url))
        #expect(sut.take() == .supported(url: "https://naver.me/xAbCdEf", source: .mapShare))
        #expect(sut.pending == nil)
        #expect(sut.take() == nil)
    }

    @Test func 빈_공유도_안내로_이어진다() throws {
        let sut = SharedLinkInbox()
        #expect(sut.receive(try #require(URL(string: "moamap://share"))))
        #expect(sut.take() == .unsupported)
    }

    @Test func 공유_주소가_아니면_받지_않는다() throws {
        let sut = SharedLinkInbox()
        #expect(!sut.receive(try #require(URL(string: "kakao1234://oauth?code=x"))))
        #expect(sut.pending == nil)
    }

    @Test func 새_공유가_오면_이전_것을_덮는다() throws {
        let sut = SharedLinkInbox()
        sut.receive(try #require(ShareDeepLink.url(text: "오늘 여기 갈래?")))
        sut.receive(try #require(ShareDeepLink.url(text: "https://kko.to/0FyvknIfua")))
        #expect(sut.take() == .supported(url: "https://kko.to/0FyvknIfua", source: .mapShare))
    }
}
