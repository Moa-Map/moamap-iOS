import Foundation
import Observation

/// 공유로 들어온 링크를 화면이 꺼내 갈 때까지 하나 보관한다. 로그인 전에 받은 것도 남는다.
@MainActor @Observable
final class SharedLinkInbox {
    private(set) var pending: SharedLink?

    /// 공유 주소면 판정해서 보관한다.
    @discardableResult
    func receive(_ url: URL) -> Bool {
        guard let text = ShareDeepLink.sharedText(from: url) else { return false }
        pending = SharedLinkParser.parse(text)
        return true
    }

    func take() -> SharedLink? {
        defer { pending = nil }
        return pending
    }
}
