import SwiftUI
import WebKit

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct SavedLink: Identifiable, Codable {
    let id: UUID
    var name: String
    var url: String
}

struct ContentView: View {
    @State private var urlString = ""
    @State private var savedLinks: [SavedLink] = []
    @State private var tabs: [BrowserTab] = []
    @State private var selectedTabID: String?
    @State private var openedCount = 0
    @State private var discoveredLinks: [String] = []
    @State private var showDeleteConfirm = false
    @State private var linkToDelete: SavedLink?
    @State private var editingID: UUID?
    @State private var editingText = ""
    @State private var suggestEditsOpener: SuggestEditsOpener?
    @State private var favoritesObserver: NSObjectProtocol?

    @FocusState private var focusedFavoriteID: UUID?
    @FocusState private var urlFieldFocused: Bool
    @Environment(\.scenePhase) private var scenePhase

    private let saveKey = "SavedLinksKey"
    private let backupSaveKey = "SavedLinksBackupKey"

    private var activeTab: BrowserTab? {
        tabs.first { $0.id == selectedTabID }
    }

    var body: some View {
        appLayout
            .preferredColorScheme(.dark)
            #if os(macOS)
            .frame(minWidth: 1300, minHeight: 750)
            #endif
            .onAppear {
                loadFaves()
                startFavoritesSync()
                syncFavoritesFromCloud()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    syncFavoritesFromCloud()
                    hardRefreshActiveTab()
                }
            }
            .alert("Delete this favorite?", isPresented: $showDeleteConfirm) {
                Button("Delete", role: .destructive) {
                    if let linkToDelete {
                        deleteLink(linkToDelete)
                    }
                }

                Button("Cancel", role: .cancel) {}
            }
    }

    @ViewBuilder
    private var appLayout: some View {
        #if os(macOS)
        desktopLayout
        #else
        mobileLayout
        #endif
    }

    private var desktopLayout: some View {
        HStack(spacing: 0) {
            sidebar

            Divider()

            VStack(spacing: 0) {
                toolbar
                tabBar
                statusBar
                Divider()
                browserArea
            }
        }
    }

    private var mobileLayout: some View {
        VStack(spacing: 0) {
            toolbar
            mobileFavoritesBar
            tabBar
            statusBar
            Divider()
            browserArea
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Favorites")
                .font(.headline)
                .padding(.top)

            Divider()

            Button {
                openFindAGrave()
            } label: {
                Label("FindAGrave.com", systemImage: "safari")
            }

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(sortedSavedLinks) { link in
                        favoriteRow(link)
                    }
                }
            }

            Spacer()

            Text("Favorites auto-sort numerically")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 240)
        .padding()
        .background(.ultraThinMaterial)
    }

    private var sortedSavedLinks: [SavedLink] {
        savedLinks.sorted { first, second in
            if first.name == "South Carolina" { return true }
            if second.name == "South Carolina" { return false }

            let firstNumber = numberPrefix(first.name)
            let secondNumber = numberPrefix(second.name)

            if firstNumber != secondNumber {
                return firstNumber < secondNumber
            }

            return first.name.localizedStandardCompare(second.name) == .orderedAscending
        }
    }

    private func favoriteRow(_ link: SavedLink) -> some View {
        HStack {
            if editingID == link.id {
                TextField("Name", text: $editingText)
                    .focused($focusedFavoriteID, equals: link.id)
                    .onSubmit {
                        renameLink(link)
                    }
            } else {
                Button(link.name) {
                    openTab(url: link.url)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Rename") {
                editingID = link.id
                editingText = link.name
                urlFieldFocused = false

                DispatchQueue.main.async {
                    focusedFavoriteID = link.id
                }
            }

            Button("Delete", role: .destructive) {
                linkToDelete = link
                showDeleteConfirm = true
            }
        }
    }

    private var toolbar: some View {
        VStack(spacing: 8) {
            TextField("Enter FindAGrave URL", text: $urlString)
                .textFieldStyle(.roundedBorder)
                .focused($urlFieldFocused)
                .onSubmit {
                    openTab(url: urlString)
                }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 18) {
                    toolbarButton(title: "Favorite", systemImage: "star") {
                        addCurrentToFaves()
                    }
                    .help("Add current URL to favorites")

                    toolbarButton(title: "Memorials", systemImage: "square.stack") {
                        loadAllMemorials()
                    }
                    .help("Open memorial links from this page")

                    toolbarButton(title: "Suggest", systemImage: "pencil.line") {
                        openSuggestEditsForNextTen()
                    }
                    .help("Open Suggest Edits for the first 10 memorials")

                    toolbarButton(title: "Back", systemImage: "chevron.left") {
                        goBackAndRefresh()
                    }
                    .help("Back")

                    toolbarButton(title: "Forward", systemImage: "chevron.right") {
                        activeTab?.webView.goForward()
                    }
                    .help("Forward")

                    toolbarButton(title: "Refresh", systemImage: "arrow.clockwise") {
                        refreshPage()
                    }
                    .keyboardShortcut("r", modifiers: .command)
                    .help("Refresh")

                    toolbarButton(title: "Browser", systemImage: "safari") {
                        openInBrowser()
                    }
                    .help("Open in browser")

                    Button {
                        if let activeTab {
                            closeTab(activeTab)
                        }
                    } label: {
                        EmptyView()
                    }
                    .keyboardShortcut("w", modifiers: .command)
                    .opacity(0)
                    .frame(width: 0, height: 0)

                    Spacer()
                }
            }
        }
        .padding(10)
        .background(.regularMaterial)
    }

    private var mobileFavoritesBar: some View {
        HStack(spacing: 10) {
            Menu {
                Button("FindAGrave.com") {
                    openFindAGrave()
                }

                ForEach(sortedSavedLinks) { link in
                    Button(link.name) {
                        openTab(url: link.url)
                    }
                }
            } label: {
                Label("Favorites", systemImage: "star")
                    .font(.subheadline)
            }

            Spacer()

            Text("\(sortedSavedLinks.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private func toolbarButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .frame(height: 20)

                Text(title)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(width: 58, height: 42)
        }
        .buttonStyle(.plain)
    }

    private var tabBar: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 4
            let horizontalPadding: CGFloat = 24
            let availableWidth = max(1, geometry.size.width - horizontalPadding)
            let totalSpacing = spacing * CGFloat(max(tabs.count - 1, 0))
            let tabWidth = max(
                54,
                min(220, (availableWidth - totalSpacing) / CGFloat(max(tabs.count, 1)))
            )

            HStack(spacing: spacing) {
                ForEach(tabs) { tab in
                    HStack(spacing: 5) {
                        Button {
                            selectTab(tab)
                        } label: {
                            Text(tab.title)
                                .font(.caption)
                                .lineLimit(1)
                                .minimumScaleFactor(0.55)
                                .truncationMode(.tail)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)

                        Button {
                            closeTab(tab)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)
                        .help("Close tab")
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 6)
                    .frame(width: tabWidth)
                    .background(
                        selectedTabID == tab.id
                        ? Color.accentColor.opacity(0.25)
                        : Color.gray.opacity(0.15)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .help(tab.title)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(height: 46)
        .background(Color.black.opacity(0.15))
    }

    private var statusBar: some View {
        Text("Opened: \(openedCount) / \(discoveredLinks.count)")
            .font(.caption2)
            .padding(.vertical, 3)
    }

    private var browserArea: some View {
        Group {
            if let activeTab {
                WebViewDisplay(webView: activeTab.webView)
                    .id(activeTab.id)
                    .onAppear {
                        hardRefresh(activeTab.webView)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "No tab open",
                    systemImage: "globe",
                    description: Text("Open a FindAGrave URL or choose a favorite.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func openTab(url: String) {
        let formatted = formatURL(url)

        guard let finalURL = URL(string: formatted) else {
            return
        }

        if let existing = tabs.first(where: { $0.id == finalURL.absoluteString }) {
            selectTab(existing)
            return
        }

        let webView = WKWebView()
        let tabID = finalURL.absoluteString
        let navigationDelegate = TabNavigationDelegate()
        navigationDelegate.onTitleChanged = { title in
            updateTabTitle(tabID: tabID, title: title)
        }
        webView.navigationDelegate = navigationDelegate
        webView.allowsBackForwardNavigationGestures = true
        webView.load(noCacheRequest(for: finalURL))

        let tab = BrowserTab(
            id: tabID,
            title: TabNavigationDelegate.titleFallback(for: finalURL),
            webView: webView,
            navigationDelegate: navigationDelegate
        )

        tabs.append(tab)
        selectedTabID = tab.id
        urlString = formatted
    }

    private func updateTabTitle(tabID: String, title: String) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else {
            return
        }

        tabs[index].title = title
    }

    private func selectTab(_ tab: BrowserTab) {
        selectedTabID = tab.id
        urlString = tab.webView.url?.absoluteString ?? tab.id
        hardRefresh(tab.webView)
    }

    private func closeTab(_ tab: BrowserTab) {
        tab.webView.stopLoading()
        tabs.removeAll { $0.id == tab.id }

        if selectedTabID == tab.id {
            selectedTabID = tabs.last?.id
            urlString = activeTab?.webView.url?.absoluteString ?? ""
        }
    }

    private func refreshPage() {
        openedCount = 0
        discoveredLinks = []
        hardRefreshActiveTab()
    }

    private func goBackAndRefresh() {
        guard let webView = activeTab?.webView else {
            return
        }

        if webView.canGoBack {
            webView.goBack()

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                hardRefresh(webView)
            }
        } else {
            hardRefresh(webView)
        }
    }

    private func hardRefreshActiveTab() {
        guard let webView = activeTab?.webView else {
            return
        }

        hardRefresh(webView)
    }

    private func hardRefresh(_ webView: WKWebView) {
        guard let url = webView.url else {
            return
        }

        webView.stopLoading()
        webView.load(noCacheRequest(for: url))
    }

    private func openInBrowser() {
        guard let currentURL = activeTab?.webView.url else {
            return
        }

        openExternalURL(currentURL)
    }

    private func openFindAGrave() {
        openTab(url: "https://www.findagrave.com")
    }

    private func loadAllMemorials() {
        guard let webView = activeTab?.webView else {
            return
        }

        webView.evaluateJavaScript(memorialLinksScript()) { result, error in
            if let error {
                print("JavaScript error:", error)
                return
            }

            guard let links = result as? [String], !links.isEmpty else {
                return
            }

            let urls = links.compactMap(URL.init(string:))

            DispatchQueue.main.async {
                discoveredLinks = links
                openedCount = urls.count

                urls.forEach(openExternalURL)
            }
        }
    }

    private func openSuggestEditsForNextTen() {
        guard let webView = activeTab?.webView else {
            return
        }

        webView.evaluateJavaScript(memorialLinksScript(limit: 10)) { result, error in
            if let error {
                print("JavaScript error:", error)
                return
            }

            guard let links = result as? [String], !links.isEmpty else {
                return
            }

            let urls = links.compactMap(URL.init(string:))

            DispatchQueue.main.async {
                discoveredLinks = links
                openedCount = 0

                let opener = SuggestEditsOpener(urls: urls)
                opener.onProgress = { opened, total in
                    openedCount = opened
                    discoveredLinks = Array(links.prefix(total))
                }
                opener.onFinished = {
                    suggestEditsOpener = nil
                }

                suggestEditsOpener = opener
                opener.start()
            }
        }
    }

    private func memorialLinksScript(limit: Int? = nil) -> String {
        let limitLine = limit.map { "if (results.length >= \($0)) return;" } ?? ""

        return """
        (() => {
            const results = [];
            const seen = new Set();

            document.querySelectorAll('a[href*="/memorial/"]').forEach(anchor => {
                \(limitLine)

                const href = anchor.href;
                if (!href) return;

                const match = href.match(/\\/memorial\\/(\\d+)/);
                if (!match?.[1]) return;

                const id = match[1];
                if (seen.has(id)) return;

                seen.add(id);
                results.push(`https://www.findagrave.com/memorial/${id}`);
            });

            return results;
        })();
        """
    }

    private func formatURL(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
            return trimmed
        }

        return "https://" + trimmed
    }

    private func noCacheRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        return request
    }

    private func numberPrefix(_ text: String) -> Int {
        let digits = text.prefix { $0.isNumber }
        return Int(digits) ?? Int.max
    }

    private func addCurrentToFaves() {
        let candidate = activeTab?.webView.url?.absoluteString ?? urlString
        let formatted = formatURL(candidate)

        guard let url = URL(string: formatted),
              isUsableLink(SavedLink(id: UUID(), name: "Check", url: formatted)) else {
            return
        }

        let newLink = SavedLink(
            id: UUID(),
            name: url.host ?? "Favorite",
            url: formatted
        )

        if !savedLinks.contains(where: { $0.url == newLink.url }) {
            savedLinks.append(newLink)
            saveFaves()
        }
    }

    private func deleteLink(_ link: SavedLink) {
        savedLinks.removeAll { $0.id == link.id }
        saveFaves()
    }

    private func renameLink(_ link: SavedLink) {
        if let index = savedLinks.firstIndex(where: { $0.id == link.id }) {
            savedLinks[index].name = editingText
            saveFaves()
        }

        editingID = nil
        focusedFavoriteID = nil
    }

    private func saveFaves() {
        let linksToSave = cleanedLinks(savedLinks)

        guard !linksToSave.isEmpty,
              let data = try? JSONEncoder().encode(linksToSave) else {
            return
        }

        savedLinks = linksToSave
        UserDefaults.standard.set(data, forKey: saveKey)
        UserDefaults.standard.set(data, forKey: backupSaveKey)

        let store = NSUbiquitousKeyValueStore.default
        store.set(data, forKey: saveKey)
        store.synchronize()
    }

    private func loadFaves() {
        let primaryLinks = linksFromLocalStore(forKey: saveKey)
        let backupLinks = linksFromLocalStore(forKey: backupSaveKey)
        let bestLinks = primaryLinks.count >= backupLinks.count ? primaryLinks : backupLinks

        guard !bestLinks.isEmpty else {
            return
        }

        savedLinks = bestLinks
    }

    private func startFavoritesSync() {
        guard favoritesObserver == nil else {
            return
        }

        let store = NSUbiquitousKeyValueStore.default
        favoritesObserver = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store,
            queue: .main
        ) { _ in
            syncFavoritesFromCloud()
        }

        store.synchronize()
    }

    private func syncFavoritesFromCloud() {
        let store = NSUbiquitousKeyValueStore.default
        store.synchronize()

        if let data = store.data(forKey: saveKey),
           let cloudLinks = try? JSONDecoder().decode([SavedLink].self, from: data) {
            let cleanedCloudLinks = cleanedLinks(cloudLinks)
            let cleanedLocalLinks = cleanedLinks(savedLinks)

            if cleanedCloudLinks.isEmpty, !cleanedLocalLinks.isEmpty {
                saveFaves()
                return
            }

            let mergedLinks = mergedFavorites(local: cleanedLocalLinks, cloud: cleanedCloudLinks)

            if !mergedLinks.isEmpty,
               mergedLinks.map(\.url) != cleanedLocalLinks.map(\.url) ||
                mergedLinks.map(\.name) != cleanedLocalLinks.map(\.name) {
                savedLinks = mergedLinks
                saveFaves()
            }

            return
        }

        guard !savedLinks.isEmpty,
              let data = try? JSONEncoder().encode(savedLinks) else {
            return
        }

        store.set(data, forKey: saveKey)
        store.synchronize()
    }

    private func linksFromLocalStore(forKey key: String) -> [SavedLink] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([SavedLink].self, from: data) else {
            return []
        }

        return cleanedLinks(decoded)
    }

    private func cleanedLinks(_ links: [SavedLink]) -> [SavedLink] {
        var seenURLs = Set<String>()

        return links.filter(isUsableLink).filter { link in
            seenURLs.insert(link.url).inserted
        }
    }

    private func isUsableLink(_ link: SavedLink) -> Bool {
        guard let url = URL(string: link.url),
              let host = url.host,
              !host.isEmpty else {
            return false
        }

        return link.url.hasPrefix("http://") || link.url.hasPrefix("https://")
    }

    private func mergedFavorites(local: [SavedLink], cloud: [SavedLink]) -> [SavedLink] {
        var merged = local
        var knownURLs = Set(local.map(\.url))

        for link in cloud where !knownURLs.contains(link.url) {
            merged.append(link)
            knownURLs.insert(link.url)
        }

        return cleanedLinks(merged)
    }

    private func openExternalURL(_ url: URL) {
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #elseif os(iOS)
        UIApplication.shared.open(url)
        #endif
    }
}
