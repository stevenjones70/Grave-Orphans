import SwiftUI

@main
struct GraveOrphansApp: App {

    var body: some Scene {

        WindowGroup {
            ContentView()
        }

        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}
