import SwiftUI
import WebKit

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct SettingsView: View {
    @AppStorage(AppSettingsKeys.tipsEnabled) private var tipsEnabled = true
    @AppStorage(AppSettingsKeys.appearanceMode) private var appearanceMode = AppearanceMode.dark.rawValue
    @AppStorage(AppSettingsKeys.startPageURL) private var startPageURL = AppDefaults.startPageURL
    @AppStorage(AppSettingsKeys.suggestBatchSize) private var suggestBatchSize = AppDefaults.suggestBatchSize
    @AppStorage(AppSettingsKeys.suggestParallelPages) private var suggestParallelPages = AppDefaults.suggestParallelPages
    @AppStorage(AppSettingsKeys.feedbackEmail) private var feedbackEmail = AppDefaults.feedbackEmail
    @AppStorage(AppSettingsKeys.lastFavoritesSyncAt) private var lastFavoritesSyncAt = 0.0
    @AppStorage(AppSettingsKeys.liquidGlassScale) private var liquidGlassScale = AppDefaults.liquidGlassScale

    @State private var cacheMessage = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Mode", selection: $appearanceMode) {
                        ForEach(AppearanceMode.allCases) { mode in
                            Text(mode.title).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    LabeledContent("Liquid glass", value: liquidGlassScaleText)

                    Slider(value: $liquidGlassScale, in: 0...2, step: 0.05) {
                        Text("Liquid glass")
                    } minimumValueLabel: {
                        Text("Low")
                    } maximumValueLabel: {
                        Text("High")
                    }

                    Button("Restore Default Glass") {
                        liquidGlassScale = AppDefaults.liquidGlassScale
                    }
                }

                Section("Tips") {
                    Toggle("Show tips on launch", isOn: $tipsEnabled)

                    Text("Turn this back on when you want the first-time tips to appear again.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("iCloud") {
                    LabeledContent("Last sync", value: lastSyncText)

                    Button {
                        NotificationCenter.default.post(name: .syncGraveOrphansFavorites, object: nil)
                    } label: {
                        Label("Sync Favorites Now", systemImage: "icloud.and.arrow.down")
                    }

                    Text("Favorites also sync automatically when the app opens, becomes active, and after you add, rename, or delete one.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Startup") {
                    TextField("Start page URL", text: $startPageURL)
                        .textFieldStyle(.roundedBorder)

                    Button("Restore Default Start Page") {
                        startPageURL = AppDefaults.startPageURL
                    }
                }

                Section("Suggest") {
                    Stepper(
                        "Memorials per batch: \(suggestBatchSize)",
                        value: $suggestBatchSize,
                        in: 1...50
                    )

                    Stepper(
                        "Pages at once: \(suggestParallelPages)",
                        value: $suggestParallelPages,
                        in: 1...8
                    )

                    Text("Higher values can be faster, but may open more pages than expected if the website responds slowly.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Browser Data") {
                    Button("Clear Cache") {
                        clearCache()
                    }

                    Button("Clear Cookies and Website Data") {
                        clearAllWebsiteData()
                    }

                    if !cacheMessage.isEmpty {
                        Text(cacheMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("About") {
                    LabeledContent("Version", value: appVersionText)

                    Text("Grave Orphans is not affiliated with Findagrave.com in any way.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("Feedback email", text: $feedbackEmail)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        openFeedbackEmail()
                    } label: {
                        Label("Submit Feedback", systemImage: "envelope")
                    }
                }

                Section("Privacy & Support") {
                    Text("Grave Orphans does not use analytics or advertising tracking. Favorites are saved on this device and, when iCloud is available, in your private iCloud key-value storage.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        openSupportEmail()
                    } label: {
                        Label("Contact Support", systemImage: "questionmark.circle")
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            #endif
        }
        .preferredColorScheme(appearanceMode.colorScheme)
        #if os(macOS)
        .padding(20)
        .frame(width: 460)
        #endif
    }

    private var lastSyncText: String {
        guard lastFavoritesSyncAt > 0 else {
            return "Not yet"
        }

        let date = Date(timeIntervalSince1970: lastFavoritesSyncAt)
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private var appVersionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (version, build) {
        case let (.some(version), .some(build)):
            return "\(version) (\(build))"
        case let (.some(version), .none):
            return version
        case let (.none, .some(build)):
            return "Build \(build)"
        default:
            return "Unknown"
        }
    }

    private var liquidGlassScaleText: String {
        "\(Int((liquidGlassScale * 100).rounded()))%"
    }

    private func clearCache() {
        let cacheTypes: Set<String> = [
            WKWebsiteDataTypeDiskCache,
            WKWebsiteDataTypeMemoryCache
        ]

        WKWebsiteDataStore.default().removeData(
            ofTypes: cacheTypes,
            modifiedSince: .distantPast
        ) {
            DispatchQueue.main.async {
                cacheMessage = "Cache cleared."
                NotificationCenter.default.post(name: .clearGraveOrphansCache, object: nil)
            }
        }
    }

    private func clearAllWebsiteData() {
        WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: .distantPast
        ) {
            DispatchQueue.main.async {
                cacheMessage = "Cookies, cache, and website data cleared."
                NotificationCenter.default.post(name: .clearGraveOrphansCache, object: nil)
            }
        }
    }

    private func openFeedbackEmail() {
        let subject = "Grave Orphans Feedback".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let body = "App feedback:\n\n".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let recipient = feedbackEmail.trimmingCharacters(in: .whitespacesAndNewlines)

        openEmail(to: recipient, subject: subject, body: body)
    }

    private func openSupportEmail() {
        let subject = "Grave Orphans Support".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let body = "Support request:\n\n".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let recipient = feedbackEmail.trimmingCharacters(in: .whitespacesAndNewlines)

        openEmail(to: recipient, subject: subject, body: body)
    }

    private func openEmail(to recipient: String, subject: String, body: String) {
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
