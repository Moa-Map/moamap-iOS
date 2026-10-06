import Foundation

/// 인스타그램 게시물 URL 판정. 캡션 추출과 공유 링크 판정이 같은 기준을 본다.
nonisolated enum InstagramURL {
    private static let hosts: Set<String> = ["instagram.com", "www.instagram.com", "m.instagram.com"]

    /// 게시물·릴스 URL 이면 shortcode 를 준다. 호스트를 먼저 보고 경로 전체를 맞춰 다른 사이트 주소를 거른다.
    static func shortcode(of url: String) -> String? {
        // `URL` 은 인코딩되지 않은 한글이 섞이면 실패해 직접 가른다.
        guard let parts = url.trimmingCharacters(in: .whitespacesAndNewlines)
            .firstMatch(of: /^(?i:https?):\/\/([^\/?#]+)([^?#]*)/) else { return nil }
        let host = parts.1.lowercased().split(separator: ":", maxSplits: 1).first.map(String.init) ?? ""
        guard hosts.contains(host) else { return nil }
        return String(parts.2).wholeMatch(of: /\/(?:p|reel|reels|tv)\/([A-Za-z0-9_-]+)\/?/).map { String($0.1) }
    }
}
