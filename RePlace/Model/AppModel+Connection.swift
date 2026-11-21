import Foundation

/// Noticing that the iPhone has gone away while a simulation is active, and telling the user.
extension AppModel {
    /// Remember which device the simulation runs on, and ask once for permission to notify.
    func noteSimulating(on device: String) {
        simulatedDeviceID = device
        if !notificationsRequested {
            notificationsRequested = true
            notifier.requestAccess()
        }
    }

    /// Called after every look at the list of connected devices.
    func observeConnection(now: Date = .now) {
        guard isSimulating, let device = simulatedDeviceID else { return }
        let connected = devices.contains { $0.id == device }
        handle(connectionWatch.observe(connected: connected, now: now))
    }

    /// A step of the route could not be sent because the connection is gone.
    func connectionInterrupted(now: Date = .now) {
        handle(connectionWatch.interrupted(now: now))
    }

    private func handle(_ event: ConnectionWatch.Event?) {
        switch event {
        case .lost(let notify, let unstable):
            let message = String(localized: "Lost the connection to your iPhone. The simulation may still be active on it.")
            status = unstable
                ? String(localized: "The connection keeps dropping. Further alerts are paused for 10 minutes.")
                : message
            if notify { notifier.send("RePlace.", message) }
        case .restored:
            status = String(localized: "Your iPhone is connected again.")
        case nil:
            break
        }
    }
}
