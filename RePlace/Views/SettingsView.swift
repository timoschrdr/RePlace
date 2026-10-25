import SwiftUI

/// Opened with RePlace. > Settings… (⌘,) in the menu bar.
struct SettingsView: View {
    @AppStorage(AppIcon.storageKey) private var choice = AppIconChoice.raccoon.rawValue
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("App Icon")
                .font(.title3.weight(.semibold))

            HStack(spacing: 12) {
                ForEach(AppIconChoice.allCases) { option in
                    card(for: option)
                }
            }

            Text("Changes the icon in the Dock while RePlace. is running. The icon in Finder and in the Applications folder stays the same.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(width: 500)
        .tint(.brand)
        .animation(.smooth, value: choice)
        .onChange(of: choice) { AppIcon.apply() }
    }

    private func card(for option: AppIconChoice) -> some View {
        let selected = choice == option.rawValue
        return Button {
            choice = option.rawValue
        } label: {
            VStack(spacing: 8) {
                Image(option.imageName(dark: colorScheme == .dark))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 100, height: 100)
                    .scaleEffect(selected ? 1.06 : 1)
                Text(option.title)
                    .font(.callout.weight(selected ? .semibold : .regular))
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(
                selected ? Color.brand.opacity(0.14) : Color.primary.opacity(0.05),
                in: .rect(cornerRadius: Layout.cardRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous)
                    .strokeBorder(selected ? Color.brand : .clear, lineWidth: 2)
            }
            .contentShape(.rect(cornerRadius: Layout.cardRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
