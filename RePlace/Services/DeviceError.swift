import Foundation

/// Turns the raw output of a failed `devicectl` call into a message a person can act on.
nonisolated enum DeviceError {
    static func message(for output: String) -> String {
        let text = output.lowercased()
        func has(_ words: String...) -> Bool { words.contains { text.contains($0) } }

        if has("developer mode") {
            return String(localized: "Turn on Developer Mode on your iPhone (Settings → Privacy & Security).")
        }
        if has("locked", "passcode") {
            return String(localized: "Your iPhone is locked. Unlock it and try again.")
        }
        if has("not paired", "pairing", "trust") {
            return String(localized: "Your iPhone is not paired with this Mac. Connect it and tap Trust.")
        }
        if has("timed out", "timeout") {
            return String(localized: "Your iPhone did not respond in time. Check the connection and try again.")
        }
        if has("remote process", "remoteservice", "xpc", "not connected", "no devices", "unavailable", "could not be found") {
            return String(localized: "The connection to your iPhone was interrupted. Reconnect it and try again.")
        }
        let detail = output.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .last { !$0.isEmpty } ?? String(localized: "unknown")
        return String(localized: "Error: \(detail)")
    }
}
