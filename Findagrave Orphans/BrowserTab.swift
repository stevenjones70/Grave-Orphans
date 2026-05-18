import Foundation
import WebKit

struct BrowserTab: Identifiable {
    let id: String
    var title: String
    var webView: WKWebView
    var navigationDelegate: TabNavigationDelegate
}
