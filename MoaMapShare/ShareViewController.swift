import UIKit
import UniformTypeIdentifiers

/// 화면 없이 공유받은 글을 모아 본 앱으로 넘기고 닫는다.
final class ShareViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        Task {
            let text = await sharedText()
            guard let url = Self.appURL(text: text) else { finish(); return }
            openContainingApp(url) { self.finish() }
        }
    }

    /// 링크 첨부를 앞에 둔다. 앱은 첫 URL 을 쓴다.
    private func sharedText() async -> String {
        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        var urls: [String] = []
        var texts: [String] = []
        for item in items {
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
                    urls.append(url.absoluteString)
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                          let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String {
                    texts.append(text)
                }
            }
            if let text = item.attributedContentText?.string, !text.isEmpty { texts.append(text) }
        }
        return (urls + texts).joined(separator: "\n")
    }

    /// `ShareDeepLink.url(text:)` 와 같은 규칙.
    private static func appURL(text: String) -> URL? {
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "&=+#?/")
        guard let encoded = text.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
        return URL(string: "moamap://share?text=\(encoded)")
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    /// 열기가 끝난 뒤에 확장을 닫아야 열기가 취소되지 않는다.
    private func openContainingApp(_ url: URL, completion: @escaping () -> Void) {
        var responder: UIResponder? = self
        while let current = responder {
            if let application = current as? UIApplication {
                application.open(url, options: [:]) { _ in completion() }
                return
            }
            responder = current.next
        }
        completion()
    }
}
