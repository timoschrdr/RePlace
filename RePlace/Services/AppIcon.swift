import AppKit
import SwiftUI

/// The app icons the user can choose from in the settings. The raccoon is the icon of the app
/// itself; the others (the previous "legacy" raccoon, the grey raccoon and the pin) are
/// alternatives that are shown in the Dock.
enum AppIconChoice: String, CaseIterable, Identifiable {
    case raccoon
    case legacy
    case gray
    case pin

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .raccoon: "Raccoon"
        case .legacy: "Legacy Raccoon"
        case .gray: "Grey Raccoon"
        case .pin: "Pin"
        }
    }

    /// Name of the image in the asset catalog.
    func imageName(dark: Bool) -> String {
        let base: String
        switch self {
        case .raccoon: base = "Raccoon"
        case .legacy: base = "Legacy"
        case .gray: base = "Gray"
        case .pin: base = "Pin"
        }
        return base + (dark ? "Dark" : "Light")
    }
}

/// macOS has no alternate app icon API. The Dock icon can however be changed while the app
/// runs, so the chosen icon is applied at launch and whenever the appearance changes.
/// The icon shown in Finder and in the Applications folder always stays the default one (the raccoon).
enum AppIcon {
    static let storageKey = "appIcon"

    static var choice: AppIconChoice {
        AppIconChoice(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .raccoon
    }

    static var isDark: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    static func apply() {
        switch choice {
        case .raccoon:
            NSApp.applicationIconImage = nil  // back to the icon in the app bundle
        case .legacy, .gray, .pin:
            NSApp.applicationIconImage = NSImage(named: choice.imageName(dark: isDark))
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appearanceObservation: NSKeyValueObservation?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppIcon.apply()
        // The Dock icon does not follow light/dark mode by itself when it is set from code.
        appearanceObservation = NSApp.observe(\.effectiveAppearance) { _, _ in
            Task { @MainActor in AppIcon.apply() }
        }
    }
}
