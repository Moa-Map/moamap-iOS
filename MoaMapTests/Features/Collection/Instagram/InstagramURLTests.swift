import Testing
@testable import MoaMap

struct InstagramURLTests {
    @Test(arguments: [
        ("https://www.instagram.com/reel/ABC123_x-y/", "ABC123_x-y"),
        ("https://www.instagram.com/p/A1/", "A1"),
        ("https://www.instagram.com/reels/A2/", "A2"),
        ("https://www.instagram.com/tv/A3/", "A3"),
        ("https://instagram.com/reel/ABC123", "ABC123"),
        ("https://www.instagram.com/reel/DEF456/?igsh=MXAzYnk1ZQ%3D%3D", "DEF456"),
        ("https://m.instagram.com/p/GHI789/", "GHI789"),
        ("  HTTPS://WWW.INSTAGRAM.COM:443/reel/JKL012/  ", "JKL012")
    ])
    func 게시물과_릴스_링크에서_shortcode_를_뽑는다(url: String, shortcode: String) {
        #expect(InstagramURL.shortcode(of: url) == shortcode)
    }

    @Test(arguments: [
        "https://www.instagram.com/moamap_official/",
        "https://www.instagram.com/stories/moamap/123456/",
        "https://evil.com/reel/ABC123/",
        "https://instagram.com.evil.com/reel/ABC123/",
        "https://evil.com/?next=/reel/ABC123/",
        "javascript://www.instagram.com/reel/ABC123/",
        "www.instagram.com/reel/ABC123/",
        "",
        "그냥 텍스트"
    ])
    func 게시물_링크가_아니면_거절한다(url: String) {
        #expect(InstagramURL.shortcode(of: url) == nil)
    }
}
