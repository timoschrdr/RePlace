import MapKit
import SwiftUI

/// The address field with suggestions while typing; Return searches and lists the results.
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
                if !model.query.isEmpty {
                    Button {
                        withAnimation(.calm) { model.query = "" }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .pill()

            if !model.searchResults.isEmpty {
                list {
                    ForEach(model.searchResults, id: \.self) { item in
                        row(title: item.name ?? "–", subtitle: item.address?.shortAddress) {
                            withAnimation(.calm) { model.choose(item) }
                        }
                    }
                }
            } else if model.suggestionsVisible, !model.suggestions.items.isEmpty {
                list {
                    ForEach(model.suggestions.items, id: \.self) { suggestion in
                        row(title: suggestion.title, subtitle: suggestion.subtitle) {
                            Task { await model.choose(suggestion) }
                        }
                    }
                }
            }
        }
        .animation(.calm, value: model.searchResults.count)
        .animation(.calm, value: model.suggestions.items.count)
    }

    private func list<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 2) { content() }
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: Layout.cardRadius, style: .continuous))
            .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
    }

    private func row(title: String, subtitle: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title).lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
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
