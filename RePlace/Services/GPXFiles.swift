import AppKit
import UniformTypeIdentifiers

/// The file dialogs for importing and exporting routes as GPX.
@MainActor
enum GPXFiles {
    private static var types: [UTType] {
        [UTType(filenameExtension: "gpx"), .xml].compactMap { $0 }
    }

    static func chooseAndImport(into model: AppModel) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = types
        panel.allowsMultipleSelection = false
        panel.message = String(localized: "Choose a GPX file with a route.")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        importFile(at: url, into: model)
    }

    static func importFile(at url: URL, into model: AppModel) {
        guard let data = try? Data(contentsOf: url) else {
            model.status = String(localized: "The file could not be read.")
            return
        }
        model.importRoute(GPX.points(in: data))
    }

    static func exportCurrentRoute(from model: AppModel) {
        guard model.waypoints.count >= 2 else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = types.prefix(1).map { $0 }
        panel.nameFieldStringValue = "RePlace-route.gpx"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let xml = GPX.document(name: url.deletingPathExtension().lastPathComponent,
                               waypoints: model.waypoints, path: model.routePath)
        do {
            try xml.write(to: url, atomically: true, encoding: .utf8)
            model.status = String(localized: "Route exported.")
        } catch {
            model.status = String(localized: "The file could not be saved.")
        }
    }
}
