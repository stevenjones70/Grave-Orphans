import Foundation
import WebKit

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

final class SuggestEditsOpener: NSObject, WKNavigationDelegate, WKUIDelegate {
    var onProgress: ((Int, Int) -> Void)?
    var onFinished: (() -> Void)?

    private let urls: [URL]
    private let webView = WKWebView()
    private var currentIndex = 0
    private var openedCount = 0
    private var phase = Phase.memorialPage

    private enum Phase {
        case memorialPage
        case suggestEditsPage
    }

    init(urls: [URL]) {
        self.urls = urls
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
    }

    func start() {
        loadNext()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            switch self.phase {
            case .memorialPage:
                self.openSuggestEditsOrRequestToManage()
            case .suggestEditsPage:
                self.openRequestToManage()
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        moveToNextPage()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        moveToNextPage()
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard navigationAction.targetFrame == nil,
              let url = navigationAction.request.url else {
            return nil
        }

        switch phase {
        case .memorialPage:
            phase = .suggestEditsPage
            webView.load(noCacheRequest(for: url))
        case .suggestEditsPage:
            openRequestToManageURL(url.absoluteString)
        }

        return nil
    }

    private func loadNext() {
        guard currentIndex < urls.count else {
            onFinished?()
            return
        }

        var request = URLRequest(url: urls[currentIndex])
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        phase = .memorialPage
        webView.load(request)
    }

    private func openSuggestEditsOrRequestToManage() {
        let script = """
        (() => {
            const textFor = element => {
                return [
                    element.innerText,
                    element.textContent,
                    element.getAttribute('aria-label'),
                    element.getAttribute('title')
                ].filter(Boolean).join(' ').replace(/\\s+/g, ' ').trim();
            };

            const elements = Array.from(document.querySelectorAll('a, button, [role="button"]'));

            const findElement = regex => elements.find(element => regex.test(textFor(element)));
            const linkFor = element => {
                const link = element?.closest('a[href]') || element?.querySelector('a[href]');
                return link?.href || null;
            };

            const requestToManage = findElement(/request\\s+to\\s+manage/i);
            const requestToManageLink = linkFor(requestToManage);
            if (requestToManageLink) {
                return { kind: 'request', href: requestToManageLink };
            }

            const suggestEdits = findElement(/suggest\\s+edits/i);
            const suggestEditsLink = linkFor(suggestEdits);
            if (suggestEditsLink) {
                return { kind: 'suggest', href: suggestEditsLink };
            }

            if (suggestEdits) {
                suggestEdits.click();
                return { kind: 'clicked' };
            }

            return null;
        })();
        """

        webView.evaluateJavaScript(script) { result, error in
            if let error {
                print("Suggest Edits lookup error:", error)
                self.moveToNextPage()
                return
            }

            guard let action = result as? [String: Any],
                  let kind = action["kind"] as? String else {
                self.moveToNextPage()
                return
            }

            switch kind {
            case "request":
                self.openRequestToManageURL(action["href"] as? String)
            case "suggest":
                guard let urlString = action["href"] as? String,
                      let url = URL(string: urlString) else {
                    self.moveToNextPage()
                    return
                }

                self.phase = .suggestEditsPage
                self.webView.load(self.noCacheRequest(for: url))
            case "clicked":
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.openRequestToManage()
                }
            default:
                self.moveToNextPage()
            }
        }
    }

    private func openRequestToManage() {
        let script = """
        (() => {
            const matchesText = element => {
                const text = [
                    element.innerText,
                    element.textContent,
                    element.getAttribute('aria-label'),
                    element.getAttribute('title')
                ].filter(Boolean).join(' ').replace(/\\s+/g, ' ').trim();

                return /request\\s+to\\s+manage/i.test(text);
            };

            const elements = Array.from(document.querySelectorAll('a, button, [role="button"]'));
            const match = elements.find(matchesText);
            if (!match) return null;

            const link = match.closest('a[href]') || match.querySelector('a[href]');
            if (link?.href) {
                return { kind: 'href', href: link.href };
            }

            match.click();
            return { kind: 'clicked' };
        })();
        """

        webView.evaluateJavaScript(script) { result, error in
            if let error {
                print("Request to Manage lookup error:", error)
                self.moveToNextPage()
                return
            }

            guard let action = result as? [String: Any],
                  let kind = action["kind"] as? String else {
                self.moveToNextPage()
                return
            }

            switch kind {
            case "href":
                self.openRequestToManageURL(action["href"] as? String)
            case "clicked":
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.openCurrentRequestPageOrMoveOn()
                }
            default:
                self.moveToNextPage()
            }
        }
    }

    private func openCurrentRequestPageOrMoveOn() {
        guard let currentURL = webView.url else {
            moveToNextPage()
            return
        }

        openRequestToManageURL(currentURL.absoluteString)
    }

    private func openRequestToManageURL(_ urlString: String?) {
        guard let urlString,
              let url = URL(string: urlString) else {
            moveToNextPage()
            return
        }

        openedCount += 1
        onProgress?(openedCount, urls.count)
        openExternalURL(url)
        moveToNextPage()
    }

    private func noCacheRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        return request
    }

    private func moveToNextPage() {
        currentIndex += 1

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.loadNext()
        }
    }

    private func openExternalURL(_ url: URL) {
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #elseif os(iOS)
        UIApplication.shared.open(url)
        #endif
    }
}
