import SwiftUI

/// The full-width switch between a single point and a route.
struct ModeSwitch: View {
    @Bindable var model: AppModel
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 0) {
            button("Point", .point)
            button("Route", .route)
        }
        .padding(3)
        .background(Color.primary.opacity(0.08), in: .capsule)
        .frame(maxWidth: .infinity)
        .opacity(model.isRouteActive ? 0.5 : 1)
        .animation(.smooth, value: model.isRouteActive)
    }

    private func button(_ title: LocalizedStringKey, _ value: TargetMode) -> some View {
        let selected = model.mode == value
        return Button {
            withAnimation(.smooth(duration: 0.35)) { model.mode = value }
        } label: {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(selected ? Color.white : Color.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background {
                    if selected {
                        Capsule()
                            .fill(LinearGradient.brand)
                            .shadow(color: .brandDark.opacity(0.3), radius: 4, y: 2)
                            .matchedGeometryEffect(id: "selection", in: namespace)
                    }
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .disabled(model.isRouteActive)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
