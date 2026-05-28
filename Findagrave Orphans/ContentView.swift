import SwiftUI
import WebKit

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

enum AppSettingsKeys {
    static let tipsEnabled = "GraveOrphansTipsEnabled"
    static let appearanceMode = "GraveOrphansAppearanceMode"
    static let startPageURL = "GraveOrphansStartPageURL"
    static let suggestBatchSize = "GraveOrphansSuggestBatchSize"
    static let suggestParallelPages = "GraveOrphansSuggestParallelPages"
    static let feedbackEmail = "GraveOrphansFeedbackEmail"
    static let lastFavoritesSyncAt = "GraveOrphansLastFavoritesSyncAt"
    static let liquidGlassScale = "GraveOrphansLiquidGlassScale"
}

enum AppDefaults {
    static let startPageURL = "https://www.findagrave.com/user/8/memorial?firstname=&middlename=&lastname=&birthyear=&birthyearfilter=&deathyear=&deathyearfilter=&location=South+Carolina%2C+USA&locationId=state_43&bio=&linkedToName=&plot=&memorialid=&datefilter=&type=managed&orderby=NAME_ASC"
    static let feedbackEmail = "jonesstevenm@icloud.com"
    static let suggestBatchSize = 10
    static let suggestParallelPages = 4
    static let liquidGlassScale = 1.0
}

enum WebViewFactory {
    static func makeWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()

        let contentController = WKUserContentController()
        contentController.addUserScript(
            WKUserScript(
                source: passwordAutoFillScript,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: false
            )
        )
        configuration.userContentController = contentController

        return WKWebView(frame: .zero, configuration: configuration)
    }

    private static let passwordAutoFillScript = """
    (() => {
        const setWhenMissing = (element, name, value) => {
            const existing = (element.getAttribute(name) || '').trim().toLowerCase();
            if (!existing || existing === 'off') {
                element.setAttribute(name, value);
            }
        };

        const textFor = element => [
            element.id,
            element.name,
            element.placeholder,
            element.getAttribute('aria-label'),
            element.getAttribute('autocomplete')
        ].filter(Boolean).join(' ').toLowerCase();

        const markFields = () => {
            const inputs = Array.from(document.querySelectorAll('input'));
            const passwordFields = inputs.filter(input => input.type === 'password');

            passwordFields.forEach(input => {
                setWhenMissing(input, 'autocomplete', 'current-password');
                input.setAttribute('autocapitalize', 'none');
                input.setAttribute('spellcheck', 'false');
            });

            const usernameFields = inputs.filter(input => {
                const type = (input.type || 'text').toLowerCase();
                if (!['email', 'text', 'search', 'tel', 'url'].includes(type)) {
                    return false;
                }

                const label = textFor(input);
                return label.includes('email') ||
                    label.includes('user') ||
                    label.includes('login') ||
                    label.includes('account') ||
                    label.includes('member');
            });

            usernameFields.forEach(input => {
                const label = textFor(input);
                setWhenMissing(input, 'autocomplete', label.includes('email') ? 'email' : 'username');
                input.setAttribute('autocapitalize', 'none');
                input.setAttribute('spellcheck', 'false');
            });
        };

        markFields();
        new MutationObserver(markFields).observe(document.documentElement, {
            childList: true,
            subtree: true
        });
    })();
    """
}

enum AppearanceMode: String, CaseIterable, Identifiable {
    case dark
    case light
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dark:
            return "Dark"
        case .light:
            return "Light"
        case .system:
            return "System"
        }
    }
}

extension String {
    var colorScheme: ColorScheme? {
        switch AppearanceMode(rawValue: self) {
        case .some(.dark):
            return .dark
        case .some(.light):
            return .light
        case .system, .none:
            return nil
        }
    }
}

extension View {
    @ViewBuilder
    func graveGlassPanel(scale: Double = AppDefaults.liquidGlassScale) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            let strength = liquidGlassStrength(scale)

            self
                .background(.ultraThinMaterial)
                .overlay {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(liquidGlassOpacity(0.34, strength)),
                            Color.white.opacity(liquidGlassOpacity(0.12, strength)),
                            Color.black.opacity(liquidGlassOpacity(0.20, strength))
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                        .allowsHitTesting(false)
                }
                .overlay {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(liquidGlassOpacity(0.20, strength)),
                            Color.clear,
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                    .allowsHitTesting(false)
                }
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.white.opacity(liquidGlassOpacity(0.62, strength)))
                        .frame(height: max(0.5, 1.5 * strength))
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.black.opacity(liquidGlassOpacity(0.28, strength)))
                        .frame(height: 1)
                        .allowsHitTesting(false)
                }
                .shadow(
                    color: Color.black.opacity(liquidGlassOpacity(0.34, strength)),
                    radius: 6 + (12 * strength),
                    x: 0,
                    y: 2 + (6 * strength)
                )
        } else {
            self.background(.regularMaterial)
        }
    }

    @ViewBuilder
    func graveGlassButton(scale: Double = AppDefaults.liquidGlassScale) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            let strength = liquidGlassStrength(scale)

            self
                .background(.regularMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(liquidGlassOpacity(0.42, strength)),
                                    Color.white.opacity(liquidGlassOpacity(0.14, strength)),
                                    Color.black.opacity(liquidGlassOpacity(0.20, strength))
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(liquidGlassOpacity(0.78, strength)),
                                    Color.white.opacity(liquidGlassOpacity(0.18, strength)),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: max(0.6, 1.4 * strength)
                        )
                        .allowsHitTesting(false)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(Color.white.opacity(liquidGlassOpacity(0.52, strength)), lineWidth: max(0.5, strength))
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .topLeading) {
                    Capsule()
                        .fill(Color.white.opacity(liquidGlassOpacity(0.38, strength)))
                        .frame(width: 18 + (12 * strength), height: max(2, 4 * strength))
                        .padding(.top, 6)
                        .padding(.leading, 9)
                        .allowsHitTesting(false)
                }
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .shadow(color: Color.white.opacity(liquidGlassOpacity(0.10, strength)), radius: 1 + strength, x: -1, y: -1)
                .shadow(
                    color: Color.black.opacity(liquidGlassOpacity(0.36, strength)),
                    radius: 3 + (6 * strength),
                    x: 0,
                    y: 1 + (3 * strength)
                )
        } else {
            self
        }
    }
}

private func liquidGlassStrength(_ scale: Double) -> Double {
    min(max(scale, 0), 2)
}

private func liquidGlassOpacity(_ base: Double, _ strength: Double) -> Double {
    min(max(base * strength, 0), 0.95)
}

extension Notification.Name {
    static let clearGraveOrphansCache = Notification.Name("ClearGraveOrphansCache")
    static let syncGraveOrphansFavorites = Notification.Name("SyncGraveOrphansFavorites")
}

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
    @State private var didInitialSetup = false
    @State private var showSplash = true
    @State private var splashIconVisible = false
    @State private var showHelp = false
    @State private var showSettings = false
    @State private var showMobileFavorites = false
    @State private var showTips = false
    @State private var activeTipIndex = 0
    @State private var cacheClearObserver: NSObjectProtocol?
    @State private var favoritesSyncRequestObserver: NSObjectProtocol?
    @State private var lastFavoritesSync = Date.distantPast
    @State private var protectLocalFavoritesUntil = Date.distantPast
    @State private var favoritesSyncMessage = "iCloud sync ready"

    @AppStorage(AppSettingsKeys.tipsEnabled) private var tipsEnabled = true
    @AppStorage(AppSettingsKeys.appearanceMode) private var appearanceMode = AppearanceMode.dark.rawValue
    @AppStorage(AppSettingsKeys.startPageURL) private var startPageURL = AppDefaults.startPageURL
    @AppStorage(AppSettingsKeys.suggestBatchSize) private var suggestBatchSize = AppDefaults.suggestBatchSize
    @AppStorage(AppSettingsKeys.suggestParallelPages) private var suggestParallelPages = AppDefaults.suggestParallelPages
    @AppStorage(AppSettingsKeys.feedbackEmail) private var feedbackEmail = AppDefaults.feedbackEmail
    @AppStorage(AppSettingsKeys.liquidGlassScale) private var liquidGlassScale = AppDefaults.liquidGlassScale
    @FocusState private var focusedFavoriteID: UUID?
    @FocusState private var urlFieldFocused: Bool
    @Environment(\.scenePhase) private var scenePhase

    private let saveKey = "SavedLinksKey"
    private let backupSaveKey = "SavedLinksBackupKey"
    private let saveTimestampKey = "SavedLinksUpdatedAt"
    private let helpTips = [
        AppTip(
            title: "Favorites keep your work handy",
            message: "Open a page you use often, then tap Favorite. Grave Orphans keeps your saved pages sorted so you can jump back quickly.",
            systemImage: "star"
        ),
        AppTip(
            title: "Memorials opens the page list",
            message: "On a search or managed-memorial page, tap Memorials to open the memorial links found on that page.",
            systemImage: "square.stack"
        ),
        AppTip(
            title: "Suggest speeds up edit work",
            message: "Tap Suggest to open Suggest Edits pages for the configured number of memorials on the current page.",
            systemImage: "pencil.line"
        ),
        AppTip(
            title: "Use Help to bring tips back",
            message: "You can hide these tips now and turn them back on later from Help.",
            systemImage: "questionmark.circle"
        )
    ]

    private var activeTab: BrowserTab? {
        tabs.first { $0.id == selectedTabID }
    }

    var body: some View {
        ZStack {
            if showSplash {
                SplashScreen(iconVisible: splashIconVisible)
                    .transition(.opacity)
            } else {
                appLayout
                    .transition(.opacity)
            }

            if showTips, !showSplash {
                TipOverlay(
                    tip: helpTips[activeTipIndex],
                    isLastTip: activeTipIndex == helpTips.count - 1,
                    onNext: advanceTip,
                    onDismiss: dismissTips,
                    onTurnOff: turnOffTips
                )
                    .transition(.opacity)
            }
        }
        .preferredColorScheme(appearanceMode.colorScheme)
        #if os(macOS)
        .frame(minWidth: 1300, minHeight: 750)
        #endif
        .onAppear {
            startInitialSplash()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active, didInitialSetup {
                syncFavoritesNow()
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
        .sheet(isPresented: $showHelp) {
            HelpView(
                tipsEnabled: $tipsEnabled,
                onReplaySplash: replaySplash,
                onShowTips: showTipsFromHelp,
                onTipsEnabledChanged: setTipsEnabled
            )
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        #if os(iOS)
        .sheet(isPresented: $showMobileFavorites) {
            mobileFavoritesSheet
        }
        #endif
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
                openWebsiteHome()
            } label: {
                Label("Website Home", systemImage: "safari")
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

            Button {
                syncFavoritesNow()
            } label: {
                Label("Sync iCloud", systemImage: "icloud.and.arrow.down")
            }
            .help("Sync favorites with iCloud")
        }
        .frame(width: 240)
        .padding()
        .graveGlassPanel(scale: liquidGlassScale)
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
                beginRenaming(link)
            }

            Button("Delete", role: .destructive) {
                linkToDelete = link
                showDeleteConfirm = true
            }
        }
    }

    private var toolbar: some View {
        VStack(spacing: 8) {
            TextField("Enter website URL", text: $urlString)
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

                    toolbarButton(title: "Sync", systemImage: "icloud.and.arrow.down") {
                        syncFavoritesNow()
                    }
                    .help("Sync favorites with iCloud")

                    toolbarButton(title: "Memorials", systemImage: "square.stack") {
                        loadAllMemorials()
                    }
                    .help("Open memorial links from this page")

                    toolbarButton(title: "Suggest", systemImage: "pencil.line") {
                        openSuggestEditsBatch()
                    }
                    .help("Open Suggest Edits for the configured batch")

                    toolbarButton(title: "Back", systemImage: "chevron.left") {
                        goBackAndRefresh()
                    }
                    .help("Back")

                    toolbarButton(title: "Forward", systemImage: "chevron.right") {
                        activeTab?.webView?.goForward()
                    }
                    .help("Forward")

                    toolbarButton(title: "Refresh", systemImage: "arrow.clockwise") {
                        refreshPage()
                    }
                    .keyboardShortcut("r", modifiers: .command)
                    .help("Refresh")

                    toolbarButton(title: "Start", systemImage: "house") {
                        openStartPage()
                    }
                    .help("Open start page")

                    toolbarButton(title: "Close All", systemImage: "xmark.square") {
                        closeAllTabs()
                    }
                    .help("Close all tabs")

                    toolbarButton(title: "Safari", systemImage: "safari") {
                        openInBrowser()
                    }
                    .help("Open current page in Safari for Passwords AutoFill")

                    toolbarButton(title: "Splash", systemImage: "sparkles") {
                        replaySplash()
                    }
                    .help("Show splash screen")

                    toolbarButton(title: "Help", systemImage: "questionmark.circle") {
                        showHelp = true
                    }
                    .help("Help and tips")

                    #if os(iOS)
                    toolbarButton(title: "Settings", systemImage: "gearshape") {
                        showSettings = true
                    }
                    .help("Settings")
                    #endif

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
        .graveGlassPanel(scale: liquidGlassScale)
    }

    private var mobileFavoritesBar: some View {
        HStack(spacing: 10) {
            Button {
                showMobileFavorites = true
            } label: {
                Label("Favorites", systemImage: "star")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)

            Spacer()

            Text("\(sortedSavedLinks.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .graveGlassPanel(scale: liquidGlassScale)
    }

    #if os(iOS)
    private var mobileFavoritesSheet: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        syncFavoritesNow()
                    } label: {
                        Label("Sync iCloud Favorites", systemImage: "icloud.and.arrow.down")
                    }

                    Button {
                        showMobileFavorites = false
                        openWebsiteHome()
                    } label: {
                        Label("Website Home", systemImage: "safari")
                    }
                }

                Section("Favorites") {
                    if sortedSavedLinks.isEmpty {
                        ContentUnavailableView(
                            "No Favorites",
                            systemImage: "star",
                            description: Text("Open a page and tap Favorite to save it here.")
                        )
                    } else {
                        ForEach(sortedSavedLinks) { link in
                            mobileFavoriteRow(link)
                        }
                    }
                }

                Section {
                    Text("\(favoritesSyncMessage). Favorites auto-sort numerically.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        finishFavoriteEditing()
                        showMobileFavorites = false
                    }
                }
            }
        }
    }

    private func mobileFavoriteRow(_ link: SavedLink) -> some View {
        HStack(spacing: 10) {
            if editingID == link.id {
                TextField("Name", text: $editingText)
                    .focused($focusedFavoriteID, equals: link.id)
                    .textInputAutocapitalization(.words)
                    .onSubmit {
                        renameLink(link)
                    }

                Button("Save") {
                    renameLink(link)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button {
                    showMobileFavorites = false
                    openTab(url: link.url)
                } label: {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(link.name)
                            .font(.body)
                            .lineLimit(1)

                        Text(link.url)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                linkToDelete = link
                showDeleteConfirm = true
            } label: {
                Label("Delete", systemImage: "trash")
            }

            Button {
                beginRenaming(link)
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .contextMenu {
            Button("Rename") {
                beginRenaming(link)
            }

            Button("Delete", role: .destructive) {
                linkToDelete = link
                showDeleteConfirm = true
            }
        }
    }
    #endif

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
            .frame(width: 72, height: 52)
            .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .graveGlassButton(scale: liquidGlassScale)
    }

    private var tabBar: some View {
        let glass = liquidGlassStrength(liquidGlassScale)

        return ScrollView(.horizontal, showsIndicators: true) {
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
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.regularMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        selectedTabID == tab.id
                                        ? Color.accentColor.opacity(liquidGlassOpacity(0.42, glass))
                                        : Color.white.opacity(liquidGlassOpacity(0.30, glass)),
                                        Color.white.opacity(liquidGlassOpacity(0.08, glass)),
                                        Color.black.opacity(liquidGlassOpacity(0.20, glass))
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .allowsHitTesting(false)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                Color.white.opacity(liquidGlassOpacity(selectedTabID == tab.id ? 0.68 : 0.46, glass)),
                                lineWidth: max(0.5, 1.2 * glass)
                            )
                            .allowsHitTesting(false)
                    )
                    .overlay(alignment: .topLeading) {
                        Capsule()
                            .fill(Color.white.opacity(liquidGlassOpacity(0.38, glass)))
                            .frame(width: 20 + (14 * glass), height: max(2, 4 * glass))
                            .padding(.top, 5)
                            .padding(.leading, 8)
                            .allowsHitTesting(false)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(
                        color: Color.black.opacity(liquidGlassOpacity(0.34, glass)),
                        radius: 3 + (6 * glass),
                        x: 0,
                        y: 1 + (3 * glass)
                    )
                    .help(tab.title)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .frame(height: 46)
        .graveGlassPanel(scale: liquidGlassScale)
    }

    private var tabWidth: CGFloat {
        #if os(iOS)
        170
        #else
        190
        #endif
    }

    private var spacing: CGFloat {
        4
    }

    private var statusBar: some View {
        VStack(spacing: 2) {
            Text("Opened: \(openedCount) / \(discoveredLinks.count)")
            Text("Not affiliated with Findagrave.com.")
                .foregroundStyle(.secondary)
        }
        .font(.caption2)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity)
        .graveGlassPanel(scale: liquidGlassScale)
    }

    private var browserArea: some View {
        Group {
            if let activeTab, let webView = activeTab.webView {
                WebViewDisplay(webView: webView)
                    .id(activeTab.id)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if activeTab != nil {
                ContentUnavailableView(
                    "Loading tab",
                    systemImage: "globe",
                    description: Text("Preparing this page.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    ensureSelectedTabWebView()
                }
            } else {
                ContentUnavailableView(
                    "No tab open",
                    systemImage: "globe",
                    description: Text("Open a website URL or choose a favorite.")
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
            activeTab?.webView?.load(noCacheRequest(for: finalURL))
            urlString = formatted
            return
        }

        let tabID = finalURL.absoluteString
        let (webView, navigationDelegate) = loadedWebView(for: finalURL, tabID: tabID)

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
        ensureWebView(for: tab.id)
        urlString = activeTab?.webView?.url?.absoluteString ?? tab.id
    }

    private func ensureSelectedTabWebView() {
        guard let selectedTabID else {
            return
        }

        ensureWebView(for: selectedTabID)
    }

    private func ensureWebView(for tabID: String) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }),
              tabs[index].webView == nil,
              let url = URL(string: tabs[index].id) else {
            return
        }

        let (webView, navigationDelegate) = loadedWebView(for: url, tabID: tabID)
        tabs[index].webView = webView
        tabs[index].navigationDelegate = navigationDelegate
    }

    private func loadedWebView(for url: URL, tabID: String) -> (WKWebView, TabNavigationDelegate) {
        let webView = WebViewFactory.makeWebView()
        let navigationDelegate = TabNavigationDelegate()
        navigationDelegate.onTitleChanged = { title in
            updateTabTitle(tabID: tabID, title: title)
        }
        webView.navigationDelegate = navigationDelegate
        webView.allowsBackForwardNavigationGestures = true
        webView.load(noCacheRequest(for: url))

        return (webView, navigationDelegate)
    }

    private func closeTab(_ tab: BrowserTab) {
        tab.webView?.stopLoading()
        tabs.removeAll { $0.id == tab.id }

        if selectedTabID == tab.id {
            selectedTabID = tabs.last?.id
            ensureSelectedTabWebView()
            urlString = activeTab?.webView?.url?.absoluteString ?? ""
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
        guard let currentURL = activeTab?.webView?.url else {
            return
        }

        openExternalURL(currentURL)
    }

    private func openWebsiteHome() {
        openTab(url: "https://www.findagrave.com")
    }

    private func openStartPage() {
        openTab(url: startPageURL)
    }

    private func closeAllTabs() {
        tabs.forEach { tab in
            tab.webView?.stopLoading()
        }

        tabs.removeAll()
        selectedTabID = nil
        urlString = ""
        openedCount = 0
        discoveredLinks = []
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

                openMemorialURLs(urls)
            }
        }
    }

    private func openSuggestEditsBatch() {
        guard let webView = activeTab?.webView else {
            return
        }

        let batchSize = max(1, min(suggestBatchSize, 50))
        let parallelPages = max(1, min(suggestParallelPages, 8))

        webView.evaluateJavaScript(memorialLinksScript(limit: batchSize)) { result, error in
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

                let opener = SuggestEditsOpener(urls: urls, maxConcurrentPages: parallelPages)
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

    private func configureAppOnce() {
        guard !didInitialSetup else {
            return
        }

        didInitialSetup = true
        loadFaves()
        startFavoritesSync()
        startCacheClearObserver()
        startFavoritesSyncRequestObserver()
        openStartPage()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            syncFavoritesNow()
        }
    }

    private func startInitialSplash() {
        guard !didInitialSetup else {
            configureAppOnce()
            return
        }

        playSplash(configureAfter: true)
    }

    private func replaySplash() {
        showHelp = false
        showTips = false
        playSplash(configureAfter: false)
    }

    private func playSplash(configureAfter: Bool) {
        splashIconVisible = false
        showSplash = true

        if configureAfter {
            configureAppOnce()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeInOut(duration: 4.2)) {
                splashIconVisible = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 5.1) {
            withAnimation(.easeOut(duration: 0.35)) {
                showSplash = false
            }

            if configureAfter {
                showFirstRunTipsSoon()
            }
        }
    }

    private func showFirstRunTipsSoon() {
        guard tipsEnabled else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            activeTipIndex = 0
            showTips = true
        }
    }

    private func advanceTip() {
        if activeTipIndex < helpTips.count - 1 {
            activeTipIndex += 1
        } else {
            dismissTips()
        }
    }

    private func dismissTips() {
        setTipsEnabled(false)
        showTips = false
    }

    private func turnOffTips() {
        setTipsEnabled(false)
        showTips = false
    }

    private func showTipsFromHelp() {
        setTipsEnabled(true)
        activeTipIndex = 0
        showHelp = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            showTips = true
        }
    }

    private func setTipsEnabled(_ isEnabled: Bool) {
        tipsEnabled = isEnabled
    }

    private func numberPrefix(_ text: String) -> Int {
        let digits = text.prefix { $0.isNumber }
        return Int(digits) ?? Int.max
    }

    private func addCurrentToFaves() {
        let candidate = activeTab?.webView?.url?.absoluteString ?? urlString
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
        if editingID == link.id {
            finishFavoriteEditing()
        }
        saveFaves()
    }

    private func beginRenaming(_ link: SavedLink) {
        editingID = link.id
        editingText = link.name
        urlFieldFocused = false

        DispatchQueue.main.async {
            focusedFavoriteID = link.id
        }
    }

    private func finishFavoriteEditing() {
        editingID = nil
        editingText = ""
        focusedFavoriteID = nil
    }

    private func renameLink(_ link: SavedLink) {
        if let index = savedLinks.firstIndex(where: { $0.id == link.id }) {
            let trimmedName = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
            savedLinks[index].name = trimmedName.isEmpty ? link.name : trimmedName
            saveFaves()
        }

        finishFavoriteEditing()
    }

    private func saveFaves() {
        saveFaves(markUpdated: true)
    }

    private func saveFaves(markUpdated: Bool) {
        let linksToSave = cleanedLinks(savedLinks)

        guard let data = try? JSONEncoder().encode(linksToSave) else {
            return
        }

        savedLinks = linksToSave
        UserDefaults.standard.set(data, forKey: saveKey)
        UserDefaults.standard.set(data, forKey: backupSaveKey)

        let updatedAt: TimeInterval
        if markUpdated {
            protectLocalFavoritesUntil = Date().addingTimeInterval(30)
            updatedAt = Date().timeIntervalSince1970
            UserDefaults.standard.set(updatedAt, forKey: saveTimestampKey)
        } else {
            updatedAt = UserDefaults.standard.double(forKey: saveTimestampKey)
        }

        let store = NSUbiquitousKeyValueStore.default
        store.set(data, forKey: saveKey)
        store.set(updatedAt, forKey: saveTimestampKey)
        store.synchronize()
        markFavoritesSynced()
        favoritesSyncMessage = "Pushed to iCloud"
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

    private func startFavoritesSyncRequestObserver() {
        guard favoritesSyncRequestObserver == nil else {
            return
        }

        favoritesSyncRequestObserver = NotificationCenter.default.addObserver(
            forName: .syncGraveOrphansFavorites,
            object: nil,
            queue: .main
        ) { _ in
            syncFavoritesNow()
        }
    }

    private func startCacheClearObserver() {
        guard cacheClearObserver == nil else {
            return
        }

        cacheClearObserver = NotificationCenter.default.addObserver(
            forName: .clearGraveOrphansCache,
            object: nil,
            queue: .main
        ) { _ in
            clearBrowserCache()
        }
    }

    private func clearBrowserCache() {
        tabs.forEach { tab in
            tab.webView?.stopLoading()
        }

        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: .distantPast
        ) {
            DispatchQueue.main.async {
                self.tabs.forEach { tab in
                    if let webView = tab.webView,
                       let url = webView.url {
                        webView.load(self.noCacheRequest(for: url))
                    }
                }
            }
        }
    }

    private func syncFavoritesNow() {
        syncFavoritesFromCloud(throttled: false)
    }

    private func syncFavoritesFromCloud(throttled: Bool = false) {
        if throttled, Date().timeIntervalSince(lastFavoritesSync) < 15 {
            return
        }

        lastFavoritesSync = Date()
        let store = NSUbiquitousKeyValueStore.default
        store.synchronize()
        let localUpdatedAt = UserDefaults.standard.double(forKey: saveTimestampKey)
        let cloudUpdatedAt = store.double(forKey: saveTimestampKey)

        if let data = store.data(forKey: saveKey),
           let cloudLinks = try? JSONDecoder().decode([SavedLink].self, from: data) {
            let cleanedCloudLinks = cleanedLinks(cloudLinks)
            let cleanedLocalLinks = cleanedLinks(savedLinks)

            if Date() < protectLocalFavoritesUntil {
                favoritesSyncMessage = "Keeping recent local edit"
                return
            }

            if cloudUpdatedAt > localUpdatedAt {
                savedLinks = cleanedCloudLinks
                UserDefaults.standard.set(data, forKey: saveKey)
                UserDefaults.standard.set(data, forKey: backupSaveKey)
                UserDefaults.standard.set(cloudUpdatedAt, forKey: saveTimestampKey)
                markFavoritesSynced()
                favoritesSyncMessage = "Updated from iCloud"
                return
            }

            if localUpdatedAt > cloudUpdatedAt {
                saveFaves(markUpdated: false)
                markFavoritesSynced()
                favoritesSyncMessage = "Pushed latest favorites to iCloud"
                return
            }

            let mergedLinks = mergedFavorites(local: cleanedLocalLinks, cloud: cleanedCloudLinks)

            if mergedLinks.map(\.url) != cleanedLocalLinks.map(\.url) ||
                mergedLinks.map(\.name) != cleanedLocalLinks.map(\.name) {
                savedLinks = mergedLinks
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: saveTimestampKey)
                saveFaves(markUpdated: false)
                markFavoritesSynced()
                favoritesSyncMessage = "Merged iCloud favorites"
            } else {
                markFavoritesSynced()
                favoritesSyncMessage = "iCloud favorites current"
            }

            return
        }

        guard let data = try? JSONEncoder().encode(cleanedLinks(savedLinks)) else {
            return
        }

        store.set(data, forKey: saveKey)
        store.set(localUpdatedAt, forKey: saveTimestampKey)
        store.synchronize()
        markFavoritesSynced()
        favoritesSyncMessage = "Pushed to iCloud"
    }

    private func markFavoritesSynced() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: AppSettingsKeys.lastFavoritesSyncAt)
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
        var mergedByURL = Dictionary(uniqueKeysWithValues: local.map { ($0.url, $0) })

        for link in cloud {
            mergedByURL[link.url] = link
        }

        return cleanedLinks(Array(mergedByURL.values))
    }

    private func openExternalURL(_ url: URL) {
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #elseif os(iOS)
        UIApplication.shared.open(url)
        #endif
    }

    private func openMemorialURLs(_ urls: [URL]) {
        #if os(macOS)
        urls.forEach(openExternalURL)
        #elseif os(iOS)
        let firstTabID = urls.first?.absoluteString

        for url in urls {
            addDeferredTab(url)
        }

        if let firstTabID,
           let firstTab = tabs.first(where: { $0.id == firstTabID }) {
            selectTab(firstTab)
        }
        #endif
    }

    private func addDeferredTab(_ url: URL) {
        if tabs.contains(where: { $0.id == url.absoluteString }) {
            return
        }

        tabs.append(
            BrowserTab(
                id: url.absoluteString,
                title: TabNavigationDelegate.titleFallback(for: url),
                webView: nil,
                navigationDelegate: nil
            )
        )
    }
}

private struct AppTip {
    let title: String
    let message: String
    let systemImage: String
}

private struct TipOverlay: View {
    let tip: AppTip
    let isLastTip: Bool
    let onNext: () -> Void
    let onDismiss: () -> Void
    let onTurnOff: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: tip.systemImage)
                        .font(.system(size: 28, weight: .semibold))
                        .frame(width: 36)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(tip.title)
                            .font(.headline)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(tip.message)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HStack(spacing: 12) {
                    Button("Hide Tips", action: onTurnOff)
                    Button("Dismiss", action: onDismiss)

                    Spacer()

                    Button(isLastTip ? "Done" : "Next", action: onNext)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(20)
            .frame(maxWidth: 430)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(18)
        }
    }
}

private struct HelpView: View {
    @Binding var tipsEnabled: Bool
    @AppStorage(AppSettingsKeys.feedbackEmail) private var feedbackEmail = AppDefaults.feedbackEmail
    @Environment(\.dismiss) private var dismiss

    let onReplaySplash: () -> Void
    let onShowTips: () -> Void
    let onTipsEnabledChanged: (Bool) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Quick Actions") {
                    Button {
                        onReplaySplash()
                    } label: {
                        Label("Show Splash Screen", systemImage: "sparkles")
                    }

                    Button {
                        onShowTips()
                    } label: {
                        Label("Show Tips Now", systemImage: "lightbulb")
                    }

                    Toggle(
                        "Show tips on launch",
                        isOn: Binding(
                            get: { tipsEnabled },
                            set: { onTipsEnabledChanged($0) }
                        )
                    )
                }

                Section("How Grave Orphans Helps") {
                    HelpRow(
                        systemImage: "star",
                        title: "Favorite",
                        message: "Save the page you are viewing so you can return to it quickly."
                    )

                    HelpRow(
                        systemImage: "square.stack",
                        title: "Memorials",
                        message: "Open the memorial links found on the current page. On iPhone they open as tabs inside the app."
                    )

                    HelpRow(
                        systemImage: "pencil.line",
                        title: "Suggest",
                        message: "Open Suggest Edits pages for the configured number of memorials on the current page."
                    )

                    HelpRow(
                        systemImage: "safari",
                        title: "Safari",
                        message: "Open the current page in Safari when you need Apple Passwords AutoFill for login."
                    )

                    HelpRow(
                        systemImage: "arrow.clockwise",
                        title: "Refresh",
                        message: "Reload the current tab and reset the opened-count display."
                    )
                }

                Section("Notice") {
                    Text("Grave Orphans is not affiliated with Findagrave.com in any way.")

                    Button {
                        openFeedbackEmail()
                    } label: {
                        Label("Submit Feedback", systemImage: "envelope")
                    }
                }
            }
            .navigationTitle("Help")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 520, minHeight: 560)
        #endif
    }

    private func openFeedbackEmail() {
        let subject = "Grave Orphans Feedback".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let body = "App feedback:\n\n".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        let recipient = feedbackEmail.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: "mailto:\(recipient)?subject=\(subject)&body=\(body)") else {
            return
        }

        #if os(macOS)
        NSWorkspace.shared.open(url)
        #elseif os(iOS)
        UIApplication.shared.open(url)
        #endif
    }
}

private struct HelpRow: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 28)
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 2)
        }
    }
}

private struct SplashScreen: View {
    let iconVisible: Bool

    var body: some View {
        GeometryReader { geometry in
            let iconSize = min(geometry.size.width, geometry.size.height) * 0.5

            ZStack {
                Color.black.ignoresSafeArea()

                VStack(spacing: 34) {
                    ZStack {
                        Text("GRAVE ORPHANS")
                            .font(.system(size: 54, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.48)
                            .frame(maxWidth: geometry.size.width * 0.88)

                        Text("GRAVE ORPHANS")
                            .font(.system(size: 54, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.2),
                                        Color(red: 0.54, green: 0.52, blue: 0.46).opacity(0.8),
                                        .black.opacity(0.35)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .blendMode(.multiply)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.48)
                            .frame(maxWidth: geometry.size.width * 0.88)

                        SplashTitleCrackOverlay()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.72),
                                        .black.opacity(0.82),
                                        .white.opacity(0.46)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: max(0.8, geometry.size.width * 0.0015), lineCap: .round, lineJoin: .round)
                            )
                            .frame(width: min(geometry.size.width * 0.88, 560), height: 72)
                            .opacity(iconVisible ? 1 : 0)
                    }
                    .opacity(iconVisible ? 1 : 0.82)

                    Image("SplashIcon")
                        .resizable()
                        .scaledToFit()
                    .frame(width: iconSize, height: iconSize)
                    .opacity(iconVisible ? 1 : 0)
                    .scaleEffect(iconVisible ? 1 : 0.72)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct SplashTitleCrackOverlay: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        addWeb(to: &path, center: CGPoint(x: w * 0.16, y: h * 0.32), radius: min(w, h) * 0.26)
        addWeb(to: &path, center: CGPoint(x: w * 0.38, y: h * 0.58), radius: min(w, h) * 0.22)
        addWeb(to: &path, center: CGPoint(x: w * 0.64, y: h * 0.35), radius: min(w, h) * 0.24)
        addWeb(to: &path, center: CGPoint(x: w * 0.84, y: h * 0.55), radius: min(w, h) * 0.2)

        path.move(to: CGPoint(x: w * 0.18, y: h * 0.36))
        path.addLine(to: CGPoint(x: w * 0.33, y: h * 0.54))
        path.addLine(to: CGPoint(x: w * 0.52, y: h * 0.42))
        path.addLine(to: CGPoint(x: w * 0.7, y: h * 0.5))
        path.addLine(to: CGPoint(x: w * 0.86, y: h * 0.38))

        path.move(to: CGPoint(x: w * 0.09, y: h * 0.72))
        path.addLine(to: CGPoint(x: w * 0.25, y: h * 0.45))
        path.addLine(to: CGPoint(x: w * 0.45, y: h * 0.72))

        path.move(to: CGPoint(x: w * 0.58, y: h * 0.18))
        path.addLine(to: CGPoint(x: w * 0.73, y: h * 0.68))
        path.addLine(to: CGPoint(x: w * 0.92, y: h * 0.22))

        return path
    }

    private func addWeb(to path: inout Path, center: CGPoint, radius: CGFloat) {
        let spokeCount = 7

        for index in 0..<spokeCount {
            let angle = (CGFloat(index) / CGFloat(spokeCount)) * .pi * 2
            let end = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius * 0.58
            )
            path.move(to: center)
            path.addLine(to: end)
        }

        for ring in 1...2 {
            let scale = CGFloat(ring) / 2.8
            var firstPoint: CGPoint?
            var previousPoint: CGPoint?

            for index in 0...spokeCount {
                let angle = (CGFloat(index) / CGFloat(spokeCount)) * .pi * 2
                let point = CGPoint(
                    x: center.x + cos(angle) * radius * scale,
                    y: center.y + sin(angle) * radius * scale * 0.58
                )

                if index == 0 {
                    firstPoint = point
                    path.move(to: point)
                } else if let previousPoint {
                    let control = CGPoint(
                        x: (previousPoint.x + point.x) / 2,
                        y: (previousPoint.y + point.y) / 2 + radius * 0.08
                    )
                    path.addQuadCurve(to: point, control: control)
                }

                previousPoint = point
            }

            if let firstPoint, let previousPoint {
                path.addLine(to: firstPoint)
                _ = previousPoint
            }
        }
    }
}
