import SwiftUI

@main
struct RePlaceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .frame(minWidth: 860, minHeight: 600)
        }
        .commands {
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
                Button("Clear Waypoints") { model.clearWaypoints() }
                    .disabled(model.waypoints.isEmpty || model.isRouteActive)
            }
        }

        Settings {
            SettingsView()
        }
    }
}
