import SwiftUI

/// The coordinate field of the single-location mode and when the location was last set.
struct PointSection: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle("Coordinates")
                HStack(spacing: 8) {
                    Image(systemName: "location")
                        .foregroundStyle(.secondary)
                    TextField("52.516275, 13.377704", text: $model.coordText)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                        .onSubmit { model.applyCoordText() }
                }
                .pill()
                Text("Or click on the map.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 14)
            }
            if let set = model.lastSetAt {
                ValueRow("Location set", set.stamp)
                    .card()
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            }
        }
        .animation(.smooth, value: model.lastSetAt)
    }
}
