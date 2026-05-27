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
    private let maxConcurrentPages: Int
    private var nextIndex = 0
    private var finishedCount = 0
    private var openedCount = 0
    private var workers: [ObjectIdentifier: Worker] = [:]

    private enum Phase {
        case memorialPage
        case suggestEditsPage
    }

    private final class Worker {
        let webView = WebViewFactory.makeWebView()
        var phase = Phase.memorialPage
        var index = 0
    }

    init(urls: [URL], maxConcurrentPages: Int) {
        self.urls = urls
        self.maxConcurrentPages = max(1, maxConcurrentPages)
        super.init()
    }

    func start() {
        let workerCount = min(maxConcurrentPages, urls.count)

        for _ in 0..<workerCount {
            startWorker()
        }

        if urls.isEmpty {
            onFinished?()
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let worker = worker(for: webView) else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            switch worker.phase {
            case .memorialPage:
                self.openSuggestEditsOrRequestToManage(worker)
            case .suggestEditsPage:
                self.openRequestToManage(worker)
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finishPage(for: webView)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        finishPage(for: webView)
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard navigationAction.targetFrame == nil,
              let url = navigationAction.request.url,
              let worker = worker(for: webView) else {
            return nil
        }

        switch worker.phase {
        case .memorialPage:
            worker.phase = .suggestEditsPage
            webView.load(noCacheRequest(for: url))
        case .suggestEditsPage:
            openRequestToManageURL(url.absoluteString, worker: worker)
        }

        return nil
    }

    private func startWorker() {
        guard nextIndex < urls.count else {
            return
        }

        let worker = Worker()
        worker.index = nextIndex
        nextIndex += 1
        workers[ObjectIdentifier(worker.webView)] = worker
        worker.webView.navigationDelegate = self
        worker.webView.uiDelegate = self
        loadCurrentPage(on: worker)
    }

    private func loadCurrentPage(on worker: Worker) {
        var request = URLRequest(url: urls[worker.index])
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        worker.phase = .memorialPage
        worker.webView.load(request)
    }

    private func openSuggestEditsOrRequestToManage(_ worker: Worker) {
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

        worker.webView.evaluateJavaScript(script) { result, error in
            if let error {
                print("Suggest Edits lookup error:", error)
                self.finishPage(worker)
                return
            }

            guard let action = result as? [String: Any],
                  let kind = action["kind"] as? String else {
                self.finishPage(worker)
                return
            }

            switch kind {
            case "request":
                self.openRequestToManageURL(action["href"] as? String, worker: worker)
            case "suggest":
                guard let urlString = action["href"] as? String,
                      let url = URL(string: urlString) else {
                    self.finishPage(worker)
                    return
                }

                worker.phase = .suggestEditsPage
                worker.webView.load(self.noCacheRequest(for: url))
            case "clicked":
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self.openRequestToManage(worker)
                }
            default:
                self.finishPage(worker)
            }
        }
    }

    private func openRequestToManage(_ worker: Worker) {
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

        worker.webView.evaluateJavaScript(script) { result, error in
            if let error {
                print("Request to Manage lookup error:", error)
                self.finishPage(worker)
                return
            }

            guard let action = result as? [String: Any],
                  let kind = action["kind"] as? String else {
                self.finishPage(worker)
                return
            }

            switch kind {
            case "href":
                self.openRequestToManageURL(action["href"] as? String, worker: worker)
            case "clicked":
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    self.openCurrentRequestPageOrMoveOn(worker)
                }
            default:
                self.finishPage(worker)
            }
        }
    }

    private func openCurrentRequestPageOrMoveOn(_ worker: Worker) {
        guard let currentURL = worker.webView.url else {
            finishPage(worker)
            return
        }

        openRequestToManageURL(currentURL.absoluteString, worker: worker)
    }

    private func openRequestToManageURL(_ urlString: String?, worker: Worker) {
        guard let urlString,
              let url = URL(string: urlString) else {
            finishPage(worker)
            return
        }

        openedCount += 1
        onProgress?(openedCount, urls.count)
        openExternalURL(url)
        finishPage(worker)
    }

    private func noCacheRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        return request
    }

    private func finishPage(for webView: WKWebView) {
        guard let worker = worker(for: webView) else {
            return
        }

        finishPage(worker)
    }

    private func finishPage(_ worker: Worker) {
        finishedCount += 1

        if nextIndex < urls.count {
            worker.index = nextIndex
            nextIndex += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.loadCurrentPage(on: worker)
            }
        } else {
            workers.removeValue(forKey: ObjectIdentifier(worker.webView))
            worker.webView.stopLoading()

            if finishedCount >= urls.count {
                onFinished?()
            }
        }
    }

    private func worker(for webView: WKWebView) -> Worker? {
        workers[ObjectIdentifier(webView)]
    }

    private func openExternalURL(_ url: URL) {
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #elseif os(iOS)
        UIApplication.shared.open(url)
        #endif
    }
}
