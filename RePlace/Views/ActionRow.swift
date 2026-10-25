import SwiftUI

/// The main action and Reset side by side, the same in both modes.
struct ActionRow: View {
    let model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            Button {
                model.performPrimaryAction()
            } label: {
                Text(model.primaryAction.title)
                    .contentTransition(.opacity)
            }
            .buttonStyle(.primaryCapsule)
            .disabled(!model.isPrimaryActionEnabled)
            .keyboardShortcut(.return, modifiers: .command)

            Button {
                Task { await model.reset() }
            } label: {
                Text("Reset")
            }
            .buttonStyle(.secondaryCapsule)
            .disabled(!model.canReset)
            .keyboardShortcut("r", modifiers: .command)
        }
        .animation(.smooth, value: model.primaryAction)
    }
}
