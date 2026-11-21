import Foundation

/// Turns the raw output of a failed `devicectl` call into a message a person can act on.
nonisolated enum DeviceError {
    enum Kind: Equatable {
        case developerMode, locked, notPaired, timeout, connection, other
    }

    static func kind(for output: String) -> Kind {
        let text = output.lowercased()
        func has(_ words: String...) -> Bool { words.contains { text.contains($0) } }

        if has("developer mode") { return .developerMode }
        if has("locked", "passcode") { return .locked }
        if has("not paired", "pairing", "trust") { return .notPaired }
        if has("timed out", "timeout") { return .timeout }
        if has("remote process", "remoteservice", "xpc", "not connected", "no devices", "unavailable", "could not be found") {
            return .connection
        }
        return .other
    }

    /// True if the connection to the iPhone is gone or does not answer (as opposed to a locked
    /// iPhone or a missing setting).
    static func isConnectionLoss(_ output: String) -> Bool {
        let kind = kind(for: output)
        return kind == .connection || kind == .timeout
    }

    static func message(for output: String) -> String {
        switch kind(for: output) {
        case .developerMode:
            return String(localized: "Turn on Developer Mode on your iPhone (Settings → Privacy & Security).")
        case .locked:
            return String(localized: "Your iPhone is locked. Unlock it and try again.")
        case .notPaired:
            return String(localized: "Your iPhone is not paired with this Mac. Connect it and tap Trust.")
        case .timeout:
            return String(localized: "Your iPhone did not respond in time. Check the connection and try again.")
        case .connection:
            return String(localized: "The connection to your iPhone was interrupted. Reconnect it and try again.")
        case .other:
            let detail = output.split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .last { !$0.isEmpty } ?? String(localized: "unknown")
            return String(localized: "Error: \(detail)")
        }
    }
}
