import SwiftUI

struct SearchSection: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Address")
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search address or place", text: $model.query)
                    .textFieldStyle(.plain)
                    .onSubmit { Task { await model.search() } }
            }
            .pill()

            if !model.searchResults.isEmpty {
                VStack(spacing: 2) {
                    ForEach(model.searchResults, id: \.self) { item in
                        Button {
                            withAnimation(.smooth) { model.choose(item) }
                        } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.name ?? "–").lineLimit(1)
                                if let address = item.address?.shortAddress {
                                    Text(address)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity)
                .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: Layout.cardRadius, style: .continuous))
                .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            }
        }
        .animation(.smooth, value: model.searchResults.count)
    }
}
