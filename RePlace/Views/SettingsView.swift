import SwiftUI

/// Opened with RePlace. > Settings… (⌘,) in the menu bar. The standard icon is shown large with a
/// tag; the older icons are collected below it as "Legacy" and need no names.
struct SettingsView: View {
    @AppStorage(AppIcon.storageKey) private var choice = AppIconChoice.raccoon.rawValue
    @Environment(\.colorScheme) private var colorScheme

    /// The version of the app, e.g. "1.2.0".
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }

    private var legacyChoices: [AppIconChoice] { AppIconChoice.allCases.filter { $0 != .raccoon } }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle("App Icon")
                standardCard
            }

            VStack(alignment: .leading, spacing: 10) {
                SectionTitle("Legacy")
                HStack(spacing: 12) {
                    ForEach(legacyChoices) { option in
                        legacyCard(option)
                    }
                }
            }

            Text("Changes the icon in the Dock while RePlace. is running. The icon in Finder and in the Applications folder stays the same.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(28)
        .frame(width: 440)
        .tint(.brand)
        .animation(.smooth, value: choice)
        .onChange(of: choice) { AppIcon.apply() }
    }

    // MARK: Cards

    private var standardCard: some View {
        let option = AppIconChoice.raccoon
        return Button {
            choice = option.rawValue
        } label: {
            HStack(spacing: 18) {
                icon(option, size: 96)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Standard")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(LinearGradient.brand, in: .capsule)
                    Text("Version \(appVersion)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                checkmark(isSelected: isSelected(option))
            }
            .padding(16)
            .modifier(SelectableCard(isSelected: isSelected(option)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(isSelected(option) ? .isSelected : [])
    }

    private func legacyCard(_ option: AppIconChoice) -> some View {
        Button {
            choice = option.rawValue
        } label: {
            VStack(spacing: 10) {
                icon(option, size: 72)
                checkmark(isSelected: isSelected(option))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .modifier(SelectableCard(isSelected: isSelected(option)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(isSelected(option) ? .isSelected : [])
    }

    private func icon(_ option: AppIconChoice, size: CGFloat) -> some View {
        Image(option.imageName(dark: colorScheme == .dark))
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
            .scaleEffect(isSelected(option) ? 1.05 : 1)
    }

    /// A filled check when selected, an empty ring otherwise.
    private func checkmark(isSelected: Bool) -> some View {
        ZStack {
            Circle().strokeBorder(Color.primary.opacity(0.25), lineWidth: 1.5)
                .opacity(isSelected ? 0 : 1)
            Circle().fill(LinearGradient.brand)
                .overlay(Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white))
                .scaleEffect(isSelected ? 1 : 0.4)
                .opacity(isSelected ? 1 : 0)
        }
        .frame(width: 22, height: 22)
    }

    private func isSelected(_ option: AppIconChoice) -> Bool { choice == option.rawValue }
}

/// The soft card behind an icon choice; a colored ring marks the selected one.
private struct SelectableCard: ViewModifier {
    let isSelected: Bool

    func body(content: Content) -> some View {
        content
            .background(
                isSelected ? Color.brand.opacity(0.12) : Color.primary.opacity(0.06),
                in: .rect(cornerRadius: Layout.cardRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous)
                    .strokeBorder(isSelected ? Color.brand : .clear, lineWidth: 2)
            }
            .contentShape(.rect(cornerRadius: Layout.cardRadius, style: .continuous))
    }
}
