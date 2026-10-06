import Foundation

/// 공유받은 글을 장소 가져오기에 쓸 수 있는지 판정한 결과.
nonisolated enum SharedLink: Equatable, Sendable {
    case supported(url: String, source: PlaceImportSource)
    case unsupported
}

/// 공유 글에서 첫 URL 을 뽑고, 호스트로 인스타그램·지도를 가른다.
nonisolated enum SharedLinkParser {
    static let unsupportedMessage = "인스타그램과 네이버·카카오·구글 지도 링크만 가져올 수 있어요"

    static func parse(_ text: String?) -> SharedLink {
        guard let text, let url = firstURL(in: text), let source = source(of: url) else { return .unsupported }
        return .supported(url: url, source: source)
    }

    private static let trailingPunctuation: Set<Character> = [".", ",", ";", ":", "!", "?", ")", "]", "}", ">", "\"", "'"]

    /// 서버가 받는 것보다 넓게 잡는다. 지도 링크인데 서버가 못 읽으면 서버 안내가 뜨는 편이 낫다.
    private static let mapShareDomains = ["naver.me", "map.naver.com", "place.naver.com", "kko.to", "kko.kakao.com", "map.kakao.com"]
    private static let googleDomains = ["goo.gl", "google.com", "google.co.kr"]

    private static func firstURL(in text: String) -> String? {
        guard let match = text.firstMatch(of: /(?i:https?):\/\/\S+/) else { return nil }
        var url = String(match.0)
        while let last = url.last, trailingPunctuation.contains(last) { url.removeLast() }
        return url
    }

    private static func source(of url: String) -> PlaceImportSource? {
        if InstagramURL.shortcode(of: url) != nil { return .instagram }
        // `URL` 은 인코딩되지 않은 한글에서 실패해 직접 가른다.
        guard let parts = url.firstMatch(of: /^(?i:https?):\/\/([^\/?#]+)([^?#]*)/) else { return nil }
        let host = parts.1.lowercased().split(separator: ":", maxSplits: 1).first.map(String.init) ?? ""
        let path = String(parts.2)
        if mapShareDomains.contains(where: { isHost(host, under: $0) }) { return .mapShare }
        // 구글은 도메인을 여러 서비스가 나눠 써 지도 경로만 받는다.
        if googleDomains.contains(where: { isHost(host, under: $0) }), host.hasPrefix("maps.") || path.hasPrefix("/maps") {
            return .mapShare
        }
        return nil
    }

    private static func isHost(_ host: String, under domain: String) -> Bool {
        host == domain || host.hasSuffix(".\(domain)")
    }
}
