import SwiftUI

@main
struct Findagrave_OrphansApp: App {

    var body: some Scene {

        WindowGroup {
            ContentView()
        }

        #if os(macOS)
        Settings {
            EmptyView()
        }
        #endif
    }
}
