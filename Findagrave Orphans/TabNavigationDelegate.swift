import Foundation
import WebKit

final class TabNavigationDelegate: NSObject, WKNavigationDelegate {
    var onTitleChanged: ((String) -> Void)?

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let script = "document.title || document.querySelector('h1')?.innerText || ''"

        webView.evaluateJavaScript(script) { result, _ in
            let pageTitle = (result as? String) ?? webView.title ?? ""
            let fallbackTitle = webView.url.map(Self.titleFallback(for:)) ?? "Tab"
            let title = Self.cleanTitle(pageTitle, fallback: fallbackTitle)

            DispatchQueue.main.async {
                self.onTitleChanged?(title)
            }
        }
    }

    nonisolated private static func cleanTitle(_ title: String, fallback: String) -> String {
        let cleaned = title
            .replacingOccurrences(of: " - Find a Grave Memorial", with: "")
            .replacingOccurrences(of: " | Find a Grave", with: "")
            .replacingOccurrences(of: " - Find a Grave", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? fallback : cleaned
    }

    nonisolated static func titleFallback(for url: URL) -> String {
        let pathParts = url.pathComponents.filter { $0 != "/" }

        if let memorialIndex = pathParts.firstIndex(of: "memorial"),
           pathParts.indices.contains(memorialIndex + 2) {
            return pathParts[(memorialIndex + 2)...]
                .joined(separator: " ")
                .replacingOccurrences(of: "-", with: " ")
                .capitalized
        }

        if let lastPart = pathParts.last, !lastPart.isEmpty {
            return lastPart
                .replacingOccurrences(of: "-", with: " ")
                .capitalized
        }

        return url.host ?? "Tab"
    }
}
