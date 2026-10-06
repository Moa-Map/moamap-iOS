import Foundation

/// 공유 확장이 앱을 여는 주소. `moamap://share?text=<공유 글>`.
nonisolated enum ShareDeepLink {
    private static let scheme = "moamap"
    private static let host = "share"
    private static let textItem = "text"

    /// 확장의 `ShareViewController.appURL(text:)` 와 같은 규칙.
    static func url(text: String) -> URL? {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+#?/")
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "\(scheme)://\(host)?\(textItem)=\(encoded)")
    }

    static func sharedText(from url: URL) -> String? {
        guard url.scheme == scheme, url.host() == host else { return nil }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        return items?.first { $0.name == textItem }?.value ?? ""
    }
}
