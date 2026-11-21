import Foundation

/// Decides when a lost connection is worth telling the user about.
///
/// - A short drop that is over within `gracePeriod` is ignored.
/// - A loss is reported once, however long it lasts, and again as "restored" afterwards.
/// - If connections keep dropping (more than `maxNotifications` reported losses within `window`),
///   further ones are reported without a notification, because they would only be noise.
nonisolated struct ConnectionWatch {
    enum Event: Equatable {
        /// The connection is lost. `notify` says whether to show a notification; `unstable` is true
        /// once, for the first loss that is no longer notified.
        case lost(notify: Bool, unstable: Bool)
        case restored
    }

    var gracePeriod: TimeInterval = 10
    var window: TimeInterval = 600
    var maxNotifications = 2

    private var missingSince: Date?
    private var reported = false
    private var lossDates: [Date] = []

    /// Call with every observation of the device. Returns an event at most once per loss.
    mutating func observe(connected: Bool, now: Date) -> Event? {
        if connected {
            missingSince = nil
            guard reported else { return nil }
            reported = false
            return .restored
        }
        guard !reported else { return nil }
        guard let since = missingSince else {
            missingSince = now
            return nil
        }
        guard now.timeIntervalSince(since) >= gracePeriod else { return nil }
        return register(now)
    }

    /// A loss that is known right away, for example a step of a route that could not be sent.
    /// Returns nil if this loss has already been reported.
    mutating func interrupted(now: Date) -> Event? {
        guard !reported else { return nil }
        return register(now)
    }

    /// Forget the current observation (the simulation ended), but keep the history of losses.
    mutating func clearObservation() {
        missingSince = nil
        reported = false
    }

    private mutating func register(_ now: Date) -> Event {
        reported = true
        lossDates = lossDates.filter { now.timeIntervalSince($0) < window } + [now]
        let count = lossDates.count
        return .lost(notify: count <= maxNotifications, unstable: count == maxNotifications + 1)
    }
}
