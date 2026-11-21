import Foundation

/// Sending positions to the iPhone: a single location and the walk along a route.
extension AppModel {
    // MARK: Single location

    func markLocationSet(at date: Date = .now) {
        lastSetAt = date
        defaults.set(date, forKey: "lastSetAt")
    }

    func clearLocationSet() {
        lastSetAt = nil
        defaults.removeObject(forKey: "lastSetAt")
    }

    func apply() async {
        guard let device = selectedDeviceID else { return }
        // Read the text field first: if it is not a valid coordinate, nothing is sent.
        guard let spot = Spot(parsing: coordText) else {
            status = String(localized: "Invalid coordinates. Format: 52.516275, 13.377704")
            return
        }
        if spot != self.spot {
            spotName = nil
            self.spot = spot
        }
        await pauseRoute()
        isPaused = false
        isBusy = true
        defer { isBusy = false }
        let result = await DeviceCtl.retrying {
            await DeviceCtl.setLocation(device: device, latitude: spot.latitude, longitude: spot.longitude)
        }
        if result.ok {
            isSimulating = true
            routeStartedAt = nil
            routeFinishedAt = nil
            markLocationSet()
            status = String(localized: "Location set: \(spot.text)")
        } else {
            status = DeviceError.message(for: result.output)
        }
    }

    func reset() async {
        guard let device = selectedDeviceID else { return }
        await pauseRoute()
        isPaused = false
        travelled = 0
        isBusy = true
        defer { isBusy = false }
        let result = await DeviceCtl.retrying { await DeviceCtl.clearLocation(device: device) }
        if result.ok {
            isSimulating = false
            movingPosition = nil
            progress = 0
            routeStartedAt = nil
            routeFinishedAt = nil
            clearLocationSet()
            status = String(localized: "Simulation stopped. Your iPhone uses its real location again.")
        } else {
            status = DeviceError.message(for: result.output)
        }
    }

    // MARK: Route

    /// Starts the route from the beginning, or continues it after a pause.
    func startRoute() {
        guard let device = selectedDeviceID, waypoints.count >= 2, !isMoving else { return }
        let resuming = isPaused
        isPaused = false
        isMoving = true  // set right away so the UI cannot start a second run
        routeTask = Task { await runRoute(device: device, resuming: resuming) }
    }

    /// Pauses moving. The device stays at its current simulated position and the route can
    /// be continued from there.
    func pauseRoute() async {
        routeTask?.cancel()
        await routeTask?.value
        routeTask = nil
        isMoving = false
    }

    /// Keeps the Mac from going to sleep while a route runs; a sleeping Mac would stop it.
    private func preventSleep() {
        guard sleepActivity == nil else { return }
        sleepActivity = ProcessInfo.processInfo.beginActivity(
            options: [.idleSystemSleepDisabled, .userInitiated],
            reason: "Simulating a route"
        )
    }

    private func allowSleep() {
        guard let activity = sleepActivity else { return }
        ProcessInfo.processInfo.endActivity(activity)
        sleepActivity = nil
    }

    private func runRoute(device: String, resuming: Bool) async {
        preventSleep()
        defer {
            isMoving = false
            allowSleep()
        }
        refreshTask?.cancel()
        if !resuming {
            progress = 0
            travelled = 0
            movingPosition = nil  // so a Pause before the first step is not "continuable"
            routeStartedAt = .now
            routeFinishedAt = nil
        }

        if !resuming, followRoads, routePath.count <= waypoints.count {
            status = String(localized: "Calculating route…")
            if let planned = await plannedRoute() {
                routePath = planned.path
                routeRoads = planned.roads
            } else {
                routePath = waypoints
                routeRoads = []
            }
        }
        guard !Task.isCancelled else { return }

        // After a pause only the rest of the path is walked, so the speed may have changed.
        let total = RouteMath.length(of: routePath)
        let base = travelled
        var stops = RouteMath.stops(
            along: RouteMath.remainder(of: routePath, after: base),
            every: max(speedKmh / 3.6 * Self.tick, 0.5)
        )
        if resuming, !stops.isEmpty { stops.removeFirst() }  // the device is already there

        // The pace follows the clock, not the number of steps sent. A new position is due every
        // `tick` seconds. If sending one takes longer (devicectl is sometimes slow), the next
        // one skips ahead to where the device should be by now, so the average speed and the
        // estimated end time stay correct. The last point is never skipped.
        let clock = ContinuousClock()
        var started = clock.now
        let offset = resuming ? 1 : 0  // after a pause the first stop is one tick away
        var index = 0

        while index < stops.count {
            if Task.isCancelled {
                isPaused = movingPosition != nil
                status = String(localized: "Route paused. Your iPhone stays at the last position.")
                return
            }
            var due = Int(started.duration(to: clock.now) / .seconds(Self.tick)) - offset
            if due - index > Self.maxCatchUpTicks {
                started += .seconds(Double(due - index - Self.maxCatchUpTicks) * Self.tick)
                due = index + Self.maxCatchUpTicks
            }
            index = min(max(index, due), stops.count - 1)
            let stop = stops[index]

            let result = await DeviceCtl.retrying {
                await DeviceCtl.setLocation(device: device, latitude: stop.spot.latitude, longitude: stop.spot.longitude)
            }
            guard result.ok else {
                // A step that fails because the user pressed Pause is not an error. Other
                // failures also leave the route paused so it can be continued.
                isPaused = movingPosition != nil
                status = Task.isCancelled
                    ? String(localized: "Route paused. Your iPhone stays at the last position.")
                    : DeviceError.message(for: result.output)
                return
            }
            isSimulating = true
            movingPosition = stop.spot
            travelled = base + stop.distance
            progress = total > 0 ? min(travelled / total, 1) : 1
            let percent = "\(Int(progress * 100)) %"
            status = String(localized: "Moving along the route: \(percent)")

            index += 1
            if index < stops.count {
                try? await clock.sleep(until: started + .seconds(Double(index + offset) * Self.tick))
            }
        }

        travelled = 0
        progress = 1  // avoid a floating-point leftover such as 0.99999999
        isPaused = false
        routeFinishedAt = .now
        markLocationSet()
        status = String(localized: "Route finished. Your iPhone stays at the end point.")
    }
}
