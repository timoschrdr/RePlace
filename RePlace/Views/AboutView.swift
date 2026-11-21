import SwiftUI

/// The "About RePlace." window: icon, name, version and a button that opens the releases page
/// on GitHub in the browser.
struct AboutView: View {
    static let windowID = "about"
    static let releasesURL = URL(string: "https://github.com/timoschrdr/RePlace/releases/latest")!

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    var body: some View {
        VStack(spacing: 6) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .accessibilityHidden(true)
            Text("RePlace.")
                .font(.title.weight(.semibold))
            Text("Version \(version)")
                .foregroundStyle(.secondary)
            Link(destination: Self.releasesURL) {
                Label("Check for Updates", systemImage: "arrow.up.right.square")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .help("Opens the releases page on GitHub")
            .padding(.top, 10)
        }
        .padding(.horizontal, 48)
        .padding(.vertical, 28)
        .frame(minWidth: 300)
    }
}
