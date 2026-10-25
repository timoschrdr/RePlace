import SwiftUI

// MARK: Colors

extension Color {
    /// The accent of the app, taken from the raccoon icon: a warm coral between orange and pink.
    static let brand = Color(red: 0.91, green: 0.33, blue: 0.30)
    static let brandLight = Color(red: 0.95, green: 0.48, blue: 0.27)
    static let brandDark = Color(red: 0.85, green: 0.24, blue: 0.35)
}

extension LinearGradient {
    /// Orange at the top, coral pink at the bottom, like the icon.
    static let brand = LinearGradient(colors: [.brandLight, .brandDark], startPoint: .top, endPoint: .bottom)
}

// MARK: Sizes

/// Sizes that several views have to agree on.
enum Layout {
    static let sidebarWidth: CGFloat = 340
    /// Sidebar width plus its outer margin: the part of the window the map should not use.
    static let mapInset: CGFloat = sidebarWidth + 24
    static let cardRadius: CGFloat = 18
}

// MARK: Surfaces

extension View {
    /// The look of text fields and pickers: a fully rounded, softly filled pill.
    func pill() -> some View {
        padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.primary.opacity(0.08), in: .capsule)
    }

    /// A softly filled, rounded card for grouped content.
    func card() -> some View {
        padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.06), in: .rect(cornerRadius: Layout.cardRadius, style: .continuous))
    }
}

// MARK: Buttons

/// Fully rounded buttons. They press down with a spring and fade when disabled.
struct CapsuleButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }

    var kind: Kind = .secondary
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(kind == .primary ? Color.white : Color.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background {
                switch kind {
                case .primary:
                    Capsule().fill(LinearGradient.brand)
                        .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.5))
                        .shadow(color: .brandDark.opacity(0.35), radius: 6, y: 3)
                case .secondary:
                    Capsule().fill(Color.primary.opacity(configuration.isPressed ? 0.18 : 0.10))
                }
            }
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .animation(.smooth, value: isEnabled)
    }
}

/// A small round icon button.
struct CircleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .frame(width: 28, height: 28)
            .background(Color.primary.opacity(configuration.isPressed ? 0.20 : 0.10), in: .circle)
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

/// A small capsule that can be selected, for presets.
struct ChipButtonStyle: ButtonStyle {
    var isSelected: Bool
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background {
                if isSelected {
                    Capsule().fill(LinearGradient.brand)
                } else {
                    Capsule().fill(Color.primary.opacity(configuration.isPressed ? 0.18 : 0.10))
                }
            }
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
            .animation(.smooth, value: isSelected)
    }
}

extension ButtonStyle where Self == CapsuleButtonStyle {
    static var primaryCapsule: CapsuleButtonStyle { CapsuleButtonStyle(kind: .primary) }
    static var secondaryCapsule: CapsuleButtonStyle { CapsuleButtonStyle(kind: .secondary) }
}

extension ButtonStyle where Self == CircleButtonStyle {
    static var circle: CircleButtonStyle { CircleButtonStyle() }
}

// MARK: Text

extension Date {
    /// A short, readable time: "Today, 19:58", "24 Oct, 19:58" or with the year for other years.
    var stamp: String {
        let time = formatted(.dateTime.hour().minute())
        let calendar = Calendar.current
        if calendar.isDateInToday(self) { return "\(String(localized: "Today")), \(time)" }
        if calendar.isDate(self, equalTo: .now, toGranularity: .year) {
            return "\(formatted(.dateTime.day().month(.abbreviated))), \(time)"
        }
        return "\(formatted(.dateTime.day().month(.abbreviated).year())), \(time)"
    }
}

/// The title above a sidebar section.
struct SectionTitle: View {
    private let key: LocalizedStringKey

    init(_ key: LocalizedStringKey) {
        self.key = key
    }

    var body: some View {
        Text(key)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }
}

/// A row with a label on the left and a value on the right.
struct ValueRow: View {
    let title: LocalizedStringKey
    let value: String

    init(_ title: LocalizedStringKey, _ value: String) {
        self.title = title
        self.value = value
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(value)
                .monospacedDigit()
                .contentTransition(.numericText())
        }
        .font(.callout)
    }
}

/// A row with a label on the left and a switch on the right.
struct SwitchRow: View {
    let title: LocalizedStringKey
    @Binding var isOn: Bool

    init(_ title: LocalizedStringKey, isOn: Binding<Bool>) {
        self.title = title
        self._isOn = isOn
    }

    var body: some View {
        HStack {
            Text(title)
            Spacer(minLength: 12)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
        .font(.body)
    }
}

// MARK: Collapsing

/// A section that folds open and closed with a smooth animation.
struct Collapsible<Accessory: View, Content: View>: View {
    let title: LocalizedStringKey
    @State private var isExpanded: Bool
    @ViewBuilder var accessory: Accessory
    @ViewBuilder var content: Content

    init(
        _ title: LocalizedStringKey,
        expanded: Bool = false,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self._isExpanded = State(initialValue: expanded)
        self.accessory = accessory()
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button {
                    withAnimation(.smooth(duration: 0.35)) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        SectionTitle(title)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                Spacer()
                accessory
            }
            if isExpanded {
                content
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            }
        }
    }
}

extension Collapsible where Accessory == EmptyView {
    init(_ title: LocalizedStringKey, expanded: Bool = false, @ViewBuilder content: () -> Content) {
        self.init(title, expanded: expanded, accessory: { EmptyView() }, content: content)
    }
}
