import Foundation
import Testing
@testable import RePlace

@MainActor
struct ConnectionWatchTests {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)
    private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    @Test func aShortDropIsIgnored() {
        var watch = ConnectionWatch()
        #expect(watch.observe(connected: true, now: at(0)) == nil)
        #expect(watch.observe(connected: false, now: at(6)) == nil)
        #expect(watch.observe(connected: true, now: at(12)) == nil)     // back within the grace period
        #expect(watch.observe(connected: true, now: at(18)) == nil)
    }

    @Test func aLongerLossIsReportedOnceAndThenRestored() {
        var watch = ConnectionWatch()
        #expect(watch.observe(connected: false, now: at(0)) == nil)
        #expect(watch.observe(connected: false, now: at(6)) == nil)
        #expect(watch.observe(connected: false, now: at(12)) == .lost(notify: true, unstable: false))
        #expect(watch.observe(connected: false, now: at(18)) == nil)    // not again for the same loss
        #expect(watch.observe(connected: true, now: at(24)) == .restored)
        #expect(watch.observe(connected: true, now: at(30)) == nil)
    }

    @Test func frequentLossesStopNotifyingAndSayWhy() {
        var watch = ConnectionWatch()
        func loss(startingAt start: TimeInterval) -> ConnectionWatch.Event? {
            _ = watch.observe(connected: false, now: at(start))
            let event = watch.observe(connected: false, now: at(start + 11))
            _ = watch.observe(connected: true, now: at(start + 20))
            return event
        }
        #expect(loss(startingAt: 0) == .lost(notify: true, unstable: false))
        #expect(loss(startingAt: 60) == .lost(notify: true, unstable: false))
        #expect(loss(startingAt: 120) == .lost(notify: false, unstable: true))      // the first one that is not notified
        #expect(loss(startingAt: 180) == .lost(notify: false, unstable: false))     // the explanation is given only once
    }

    @Test func oldLossesAreForgotten() {
        var watch = ConnectionWatch()
        for start in [0.0, 60] {
            _ = watch.observe(connected: false, now: at(start))
            _ = watch.observe(connected: false, now: at(start + 11))
            _ = watch.observe(connected: true, now: at(start + 20))
        }
        // more than 10 minutes later the earlier losses no longer count
        _ = watch.observe(connected: false, now: at(1000))
        #expect(watch.observe(connected: false, now: at(1011)) == .lost(notify: true, unstable: false))
    }

    @Test func anInterruptedRouteIsReportedAtOnce() {
        var watch = ConnectionWatch()
        #expect(watch.interrupted(now: at(0)) == .lost(notify: true, unstable: false))
        #expect(watch.interrupted(now: at(1)) == nil)                                // same loss
        #expect(watch.observe(connected: false, now: at(30)) == nil)                 // and not counted a second time
        #expect(watch.observe(connected: true, now: at(40)) == .restored)
    }

    @Test func clearingTheObservationForgetsTheCurrentLossOnly() {
        var watch = ConnectionWatch()
        _ = watch.interrupted(now: at(0))
        watch.clearObservation()
        #expect(watch.observe(connected: true, now: at(5)) == nil)
    }
}
