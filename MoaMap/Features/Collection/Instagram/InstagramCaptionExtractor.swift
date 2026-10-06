import Foundation

nonisolated enum CaptionResult: Equatable, Sendable {
    case success(String)
    /// 로그인 필요·비공개라 이 방식으로는 읽을 수 없다.
    case blocked
    /// 링크가 잘못됐거나 캡션을 찾지 못했다.
    case unavailable
    /// 인스타그램에 닿지 못했다.
    case network
}

nonisolated protocol CaptionExtractor: Sendable {
    func extract(_ url: String) async throws -> CaptionResult
}

/// 공개 게시물·릴스의 캡션을 읽는다.
///
/// 일반 페이지는 캡션을 비워 내려줘서, 캡션이 그대로 담기는 임베드 페이지를 크롤러 User-Agent 로 읽는다.
nonisolated struct InstagramCaptionExtractor: CaptionExtractor {
    private static let crawlerUserAgent = "facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)"
    private static let timeout: TimeInterval = 15

    private let transport: APIClient.Transport

    init(transport: @escaping APIClient.Transport) {
        self.transport = transport
    }

    func extract(_ url: String) async throws -> CaptionResult {
        guard let shortcode = InstagramURL.shortcode(of: url),
              let embedURL = URL(string: "https://www.instagram.com/p/\(shortcode)/embed/captioned/") else {
            return .unavailable
        }
        var request = URLRequest(url: embedURL, timeoutInterval: Self.timeout)
        request.setValue(Self.crawlerUserAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("ko-KR,ko;q=0.9,en;q=0.8", forHTTPHeaderField: "Accept-Language")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await transport(request)
        } catch let error as URLError {
            if error.code == .cancelled || Task.isCancelled { throw CancellationError() }
            return .network
        }
        try Task.checkCancellation()

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        let html = String(decoding: data, as: UTF8.self)
        if let caption = Self.caption(in: html) { return .success(caption) }
        if html.contains("loginForm") || html.contains("login_required") || status == 401 || status == 403 {
            return .blocked
        }
        return .unavailable
    }

    /// `class="Caption"` 블록에서 댓글 앞까지를 본문으로 읽는다.
    static func caption(in html: String) -> String? {
        guard let start = html.range(of: "class=\"Caption\""),
              let open = html[start.upperBound...].firstIndex(of: ">") else { return nil }
        let from = html.index(after: open)
        let end = html.range(of: "class=\"CaptionComments\"", range: from..<html.endIndex)?.lowerBound
            ?? html.range(of: "</div>", range: from..<html.endIndex)?.lowerBound
        guard let end else { return nil }
        return clean(String(html[from..<end]))
    }

    /// 작성자 링크는 지우고 해시태그·멘션 링크는 글자만 남긴다.
    private static func clean(_ captionHTML: String) -> String? {
        var text = captionHTML
            .replacing(/(?s)<a class="CaptionUsername".*?<\/a>/, with: "")
            .replacing(/(?s)<a[^>]*>(.*?)<\/a>/) { String($0.1) }
            .replacing(/(?i)<br\s*\/?>/, with: "\n")
            .replacing(/<[^>]+>/, with: "")
            .replacing(/<[^>]*$/, with: "")
            .replacing(/\n{3,}/, with: "\n\n")
        for (entity, character) in [
            ("&quot;", "\""), ("&#039;", "'"), ("&#39;", "'"), ("&lt;", "<"), ("&gt;", ">"), ("&nbsp;", " "), ("&amp;", "&")
        ] {
            text = text.replacingOccurrences(of: entity, with: character)
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
