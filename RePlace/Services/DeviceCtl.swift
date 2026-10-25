import Foundation

/// An iPhone (or other iOS device) known to CoreDevice.
struct Device: Identifiable, Hashable {
    let id: String
    let name: String
    let model: String
    let connected: Bool

    var label: String { "\(name) (\(model))" }
}

/// A thin wrapper around `xcrun devicectl`, the command line tool that ships with Xcode.
enum DeviceCtl {
    struct Result {
        let ok: Bool
        let output: String
    }

    nonisolated static func run(_ args: [String]) async -> Result {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
                process.arguments = ["devicectl"] + args
                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe
                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: Result(ok: false, output: error.localizedDescription))
                    return
                }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
                continuation.resume(returning: Result(ok: process.terminationStatus == 0, output: text))
            }
        }
    }

    nonisolated static func listDevices() async -> [Device] {
        let jsonURL = FileManager.default.temporaryDirectory.appendingPathComponent("replace-devices-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: jsonURL) }
        let result = await run(["list", "devices", "--json-output", jsonURL.path, "--quiet"])
        guard result.ok,
              let data = try? Data(contentsOf: jsonURL),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let devices = (root["result"] as? [String: Any])?["devices"] as? [[String: Any]]
        else { return [] }

        return devices.compactMap { entry in
            let hardware = entry["hardwareProperties"] as? [String: Any]
            guard hardware?["platform"] as? String == "iOS",
                  let id = entry["identifier"] as? String
            else { return nil }
            let properties = entry["deviceProperties"] as? [String: Any]
            let connection = entry["connectionProperties"] as? [String: Any]
            let state = connection?["tunnelState"] as? String
            return Device(
                id: id,
                name: properties?["name"] as? String ?? "iPhone",
                model: hardware?["marketingName"] as? String ?? "iOS",
                connected: state != nil && state != "unavailable"
            )
        }
        .sorted { ($0.connected ? 0 : 1, $0.name) < ($1.connected ? 0 : 1, $1.name) }
    }

    /// `devicectl` sometimes fails once with a transient XPC error ("remoteService was
    /// unavailable"). Retrying a couple of times makes long routes robust.
    nonisolated static func retrying(
        attempts: Int = 3,
        _ operation: () async -> Result
    ) async -> Result {
        var result = await operation()
        var remaining = attempts - 1
        while !result.ok, remaining > 0, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(700))
            result = await operation()
            remaining -= 1
        }
        return result
    }

    nonisolated static func setLocation(device: String, latitude: Double, longitude: Double) async -> Result {
        await run([
            "device", "simulate", "location", "coordinate",
            "--device", device,
            "--latitude", String(latitude),
            "--longitude", String(longitude),
        ])
    }

    nonisolated static func clearLocation(device: String) async -> Result {
        await run(["device", "simulate", "location", "clear", "--device", device])
    }
}
