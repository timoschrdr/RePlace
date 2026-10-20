import SwiftUI

/// Opened with RePlace. > Settings… (⌘,) in the menu bar.
struct SettingsView: View {
    @AppStorage(AppIcon.storageKey) private var choice = AppIconChoice.raccoon.rawValue
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("App Icon")
                .font(.headline)

            HStack(spacing: 16) {
                ForEach(AppIconChoice.allCases) { option in
                    card(for: option)
                }
            }

            Text("Changes the icon in the Dock while RePlace. is running. The icon in Finder and in the Applications folder stays the same.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(24)
        .frame(width: 400)
        .tint(.brandRed)
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
                    .frame(width: 104, height: 104)
                Text(option.title)
                    .font(.callout.weight(selected ? .semibold : .regular))
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .background(selected ? Color.brandRed.opacity(0.12) : .clear, in: .rect(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(selected ? Color.brandRed : Color.secondary.opacity(0.25), lineWidth: selected ? 2 : 1)
            }
            .contentShape(.rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
