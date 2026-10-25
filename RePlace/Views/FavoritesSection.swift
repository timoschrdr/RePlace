import SwiftUI

struct FavoritesSection: View {
    let model: AppModel

    var body: some View {
        Collapsible("Favorites", expanded: true) {
            Button {
                withAnimation(.smooth) { model.addFavorite() }
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.circle)
            .disabled(model.spot == nil)
            .help("Save current location (name = search field)")
        } content: {
            VStack(spacing: 4) {
                ForEach(model.favorites) { favorite in
                    let selected = model.spot == favorite.spot
                    Button {
                        model.select(favorite.spot)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(LinearGradient.brand)
                            Text(favorite.name)
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .background(selected ? Color.brand.opacity(0.18) : Color.primary.opacity(0.06), in: .capsule)
                    .animation(.smooth, value: selected)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            withAnimation(.smooth) { model.removeFavorite(favorite) }
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                }
            }
        }
    }
}
