import SwiftUI

/// The floating glass panel: device, mode, search, the settings of the chosen mode and favorites.
/// The main buttons stay pinned below the scrolling content so they are always visible.
struct SidebarView: View {
    let model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    DeviceSection(model: model)
                    ModeSwitch(model: model)
                    SearchSection(model: model)
                    Group {
                        if model.mode == .point {
                            PointSection(model: model)
                        } else {
                            RouteSection(model: model)
                        }
                    }
                    .transition(.opacity)
                    FavoritesSection(model: model)
                }
                .padding(20)
                .animation(.smooth, value: model.mode)
            }
            .scrollIndicators(.hidden)

            ActionRow(model: model)
                .padding(.horizontal, 20)
                .padding(.top, 4)
            HelpButton()
        }
    }
}
