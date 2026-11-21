import AppKit
import SwiftUI

extension Animation {
    /// The standard smooth animation, or almost none if the user turned on "Reduce motion".
    static var calm: Animation {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? .linear(duration: 0.001) : .smooth
    }

    /// The springy press effect of buttons, calmed in the same way.
    static var calmSpring: Animation {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            ? .linear(duration: 0.001) : .spring(response: 0.3, dampingFraction: 0.6)
    }
}
