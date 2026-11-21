import SwiftUI

@main
struct RePlaceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .frame(minWidth: 860, minHeight: 600)
                .onAppear { AppDelegate.model = model }
        }
        .commands {
            CommandGroup(after: .appInfo) {
                // The arrow shows that this opens the GitHub releases page in the browser.
                Button("Check for Updates…", systemImage: "arrow.up.right.square") {
                    NSWorkspace.shared.open(Self.releasesURL)
                }
            }
            CommandGroup(after: .undoRedo) {
                Button("Undo Last Waypoint") { model.undoWaypoints() }
                    .keyboardShortcut("z", modifiers: [.command, .option])
                    .disabled(!model.canUndoWaypoints)
            }
            CommandMenu("Simulation") {
                Button(model.primaryAction.title) { model.performPrimaryAction() }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(!model.isPrimaryActionEnabled)
                Button("Reset") { Task { await model.reset() } }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(!model.canReset)
                Divider()
                Button("Import GPX…") { GPXFiles.chooseAndImport(into: model) }
                    .keyboardShortcut("o", modifiers: .command)
                    .disabled(model.isRouteActive)
                Button("Export Route as GPX…") { GPXFiles.exportCurrentRoute(from: model) }
                    .keyboardShortcut("e", modifiers: .command)
                    .disabled(model.waypoints.count < 2)
                Divider()
                Button("Clear Waypoints") { model.clearWaypoints() }
                    .disabled(model.waypoints.isEmpty || model.isRouteActive)
            }
        }

        Settings {
            SettingsView()
        }
    }

    private static let releasesURL = URL(string: "https://github.com/timoschrdr/RePlace/releases/latest")!
}
