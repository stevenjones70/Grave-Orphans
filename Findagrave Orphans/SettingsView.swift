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

    @State private var cacheMessage = ""

    var body: some View {
        Form {
            Section("Appearance") {
                Picker("Mode", selection: $appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.title).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Tips") {
                Toggle("Show tips on launch", isOn: $tipsEnabled)

                Text("Turn this back on when you want the first-time tips to appear again.")
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
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 460)
        .preferredColorScheme(appearanceMode.colorScheme)
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
