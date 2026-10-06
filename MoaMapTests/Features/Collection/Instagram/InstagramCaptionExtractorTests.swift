import Foundation
import Testing
@testable import MoaMap

struct InstagramCaptionExtractorTests {
    private func extractor(
        html: String = "", status: Int = 200,
        inspect: @escaping @Sendable (URLRequest) -> Void = { _ in }
    ) -> InstagramCaptionExtractor {
        InstagramCaptionExtractor { request in
            inspect(request)
            let url = try #require(request.url)
            let response = try #require(HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil))
            return (Data(html.utf8), response)
        }
    }

    @Test func 임베드_페이지를_크롤러로_요청한다() async throws {
        let sut = extractor { request in
            #expect(request.url?.absoluteString == "https://www.instagram.com/p/ABC123/embed/captioned/")
            #expect(request.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("facebookexternalhit") == true)
        }
        _ = try await sut.extract("https://www.instagram.com/reel/ABC123/?igsh=x")
    }

    @Test func 캡션_본문만_남기고_태그와_엔티티를_정리한다() async throws {
        let html = #"""
        <div class="Caption"><a class="CaptionUsername" href="/moa">moa</a><br/>성수 &amp; 카페<br>
        <a href="/explore/tags/카페">#카페</a> &quot;추천&quot;<div class="CaptionComments">댓글</div></div>
        """#
        #expect(try await extractor(html: html).extract("https://www.instagram.com/p/A1/") == .success("성수 & 카페\n\n#카페 \"추천\""))
    }

    @Test func 로그인을_요구하면_막힌_것으로_본다() async throws {
        #expect(try await extractor(html: "<form id=\"loginForm\"></form>").extract("https://www.instagram.com/p/A1/") == .blocked)
        #expect(try await extractor(status: 403).extract("https://www.instagram.com/p/A1/") == .blocked)
    }

    @Test func 캡션이_없거나_게시물_링크가_아니면_읽지_못한다() async throws {
        #expect(try await extractor(html: "<div></div>").extract("https://www.instagram.com/p/A1/") == .unavailable)
        #expect(try await extractor { _ in Issue.record("요청하면 안 된다") }.extract("https://example.com") == .unavailable)
    }

    @Test func 연결에_실패하면_네트워크_문제로_본다() async throws {
        let sut = InstagramCaptionExtractor { _ in throw URLError(.timedOut) }
        #expect(try await sut.extract("https://www.instagram.com/p/A1/") == .network)
    }

    @Test func 요청_취소를_전파한다() async throws {
        let sut = InstagramCaptionExtractor { _ in throw URLError(.cancelled) }
        await #expect(throws: CancellationError.self) { try await sut.extract("https://www.instagram.com/p/A1/") }
    }
}
