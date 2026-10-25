import SwiftUI

/// The question mark in the corner of the sidebar and the explanation it opens.
struct HelpButton: View {
    @State private var isShown = false

    var body: some View {
        HStack {
            Button {
                isShown.toggle()
            } label: {
                Image(systemName: "questionmark")
            }
            .buttonStyle(.circle)
            .help("Help")
            .popover(isPresented: $isShown, arrowEdge: .top) { content }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("RePlace.")
                .font(.title3.weight(.semibold))
            Text("Sets a simulated GPS location on your iPhone. It applies to the whole device, so every app sees it.")
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 10) {
                row("1.circle.fill", "Connect your iPhone, unlock it and turn on Developer Mode.")
                row("2.circle.fill", "Pick a place: click the map, search an address or paste coordinates.")
                row("3.circle.fill", "Press “Set Location”. For a moving route, switch to “Route”, add waypoints and press “Start Route”. “Pause” stops where you are, “Continue” goes on from there.")
                row("arrow.uturn.backward.circle.fill", "“Reset” brings back your real location. The simulation also ends when the connection is lost.")
            }
            Divider()
            Text("Shortcuts: ⌘↩ main button, ⌘R reset, ⌥⌘Z undo last waypoint. Drag a numbered pin on the map to move a waypoint.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Requires Xcode (uses Apple's devicectl). Only use this on your own devices and in line with the terms of the apps you use.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(width: Layout.sidebarWidth)
    }

    private func row(_ icon: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(LinearGradient.brand)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
