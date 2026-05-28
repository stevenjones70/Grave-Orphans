import Foundation
import WebKit

struct BrowserTab: Identifiable {
    let id: String
    var title: String
    var currentURL: String
    var lastAccessed: Date
    var webView: WKWebView?
    var navigationDelegate: TabNavigationDelegate?
}
