import AppKit
import Foundation
import WebKit

final class SuggestEditsOpener: NSObject, WKNavigationDelegate {
    var onProgress: ((Int, Int) -> Void)?
    var onFinished: (() -> Void)?

    private let urls: [URL]
    private let webView = WKWebView()
    private var currentIndex = 0
    private var openedCount = 0

    init(urls: [URL]) {
        self.urls = urls
        super.init()
        webView.navigationDelegate = self
    }

    func start() {
        loadNext()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.openSuggestEditsLink()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        moveToNextPage()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        moveToNextPage()
    }

    private func loadNext() {
        guard currentIndex < urls.count else {
            onFinished?()
            return
        }

        var request = URLRequest(url: urls[currentIndex])
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        webView.load(request)
    }

    private func openSuggestEditsLink() {
        let script = """
        (() => {
            const matchesText = element => {
                const text = [
                    element.innerText,
                    element.textContent,
                    element.getAttribute('aria-label'),
                    element.getAttribute('title')
                ].filter(Boolean).join(' ').replace(/\\s+/g, ' ').trim();

                return /suggest\\s+edits/i.test(text);
            };

            const elements = Array.from(document.querySelectorAll('a, button, [role="button"]'));
            const match = elements.find(matchesText);
            if (!match) return null;

            const link = match.closest('a[href]') || match.querySelector('a[href]');
            return link?.href || null;
        })();
        """

        webView.evaluateJavaScript(script) { result, error in
            defer {
                self.moveToNextPage()
            }

            if let error {
                print("Suggest Edits lookup error:", error)
                return
            }

            guard let urlString = result as? String,
                  let url = URL(string: urlString) else {
                return
            }

            self.openedCount += 1
            self.onProgress?(self.openedCount, self.urls.count)
            NSWorkspace.shared.open(url)
        }
    }

    private func moveToNextPage() {
        currentIndex += 1

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.loadNext()
        }
    }
}
