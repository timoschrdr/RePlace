import SwiftUI

/// The glass pill at the bottom of the map with the current status message.
struct StatusPill: View {
    let model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
                .animation(.smooth, value: model.isSimulating)
            Text(model.status)
                .font(.callout)
                .lineLimit(2)
                .contentTransition(.opacity)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .glassEffect(.regular, in: .capsule)
        .padding(.bottom, 20)
        .padding(.leading, Layout.mapInset)
        .animation(.smooth, value: model.status)
    }

    private var color: Color {
        if model.isPaused { return .orange }
        return model.isSimulating ? Color.brand : Color.secondary.opacity(0.5)
    }
}
