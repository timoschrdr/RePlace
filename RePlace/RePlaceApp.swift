import SwiftUI

@main
struct RePlaceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 860, minHeight: 600)
        }

        Settings {
            SettingsView()
        }
    }
}
