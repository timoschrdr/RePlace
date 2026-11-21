import Foundation
import MapKit
import Observation
import SwiftUI

/// The state of the app and the logic behind the buttons. This file holds the chosen device and
/// place, favorites, saved routes and the planning of a route; the simulation itself (sending
/// positions to the iPhone) is in `AppModel+Simulation.swift`.
@Observable
final class AppModel {
    // MARK: Device and place

    var devices: [Device] = []
    var selectedDeviceID: String?
    var spot: Spot? {
        didSet { if let spot { coordText = spot.text } }
    }
    /// Name of the chosen place if it came from a search or a favorite; used to name favorites.
    var spotName: String?
    var coordText = ""
    var query = "" {
        didSet {
            guard query != oldValue else { return }
            suggestions.query = query
            suggestionsVisible = !query.trimmingCharacters(in: .whitespaces).isEmpty
            searchResults = []
        }
    }
    let suggestions = SearchSuggestions()
    var suggestionsVisible = false
    var searchResults: [MKMapItem] = []
    var favorites: [Favorite] = []
    var savedRoutes: [SavedRoute] = []
    var status = String(localized: "Choose a device and a location.")
    var isBusy = false
    var isSimulating = false

    // MARK: Route settings and state

    var mode: TargetMode = .point {
        didSet { saveSession() }
    }
    var waypoints: [Spot] = [] {
        didSet {
            scheduleRouteRefresh()
            saveSession()
        }
    }
    var followRoads = true {
        didSet {
            scheduleRouteRefresh()
            saveSession()
        }
    }
    /// Take a motorway alternative over a faster route through town (driving speeds only).
    var preferMotorways = true {
        didSet {
            scheduleRouteRefresh()
            saveSession()
        }
    }
    var speedKmh = 5.0 {
        didSet {
            saveSession()
            // Walking and driving use different road networks.
            if (oldValue >= Self.drivingThresholdKmh) != (speedKmh >= Self.drivingThresholdKmh) {
                scheduleRouteRefresh()
            }
        }
    }
    /// The path the device will follow: road geometry or straight lines between waypoints.
    var routePath: [Spot] = []
    /// Main roads of the planned path, e.g. `["A43"]`. Empty for straight lines.
    var routeRoads: [String] = []
    var isMoving = false
    /// True after Pause (or an interrupted run) while the route can be continued.
    var isPaused = false
    var progress = 0.0
    var movingPosition: Spot?
    var isCalculatingRoute = false

    // MARK: Time stamps

    /// When the single location was last set (or the last route ended). Kept across launches,
    /// because the simulated location stays on the iPhone until it is reset.
    var lastSetAt: Date?
    /// When the current route was started, and when it arrived.
    var routeStartedAt: Date?
    var routeFinishedAt: Date?

    // MARK: Internals (internal rather than private: shared with AppModel+Simulation.swift)

    /// From this speed on routes are planned for a car, below it for a pedestrian.
    static let drivingThresholdKmh = 20.0
    /// Seconds between two simulated positions.
    static let tick = 1.0
    /// A hang of devicectl longer than this many ticks moves the schedule instead of making the
    /// device jump far ahead.
    static let maxCatchUpTicks = 3
    /// More waypoints than this switch "Follow roads" off after an import: routing hundreds of
    /// points through Apple Maps would be slow and pointless.
    static let maxRoutedWaypoints = 25

    let defaults: UserDefaults
    var routeTask: Task<Void, Never>?
    var refreshTask: Task<Void, Never>?
    var sleepActivity: NSObjectProtocol?
    /// Earlier states of the waypoint list, for undo.
    private var waypointHistory: [[Spot]] = []
    /// Meters of the route path the device has already covered.
    var travelled = 0.0

    private enum Key {
        static let favorites = "favorites"
        static let savedRoutes = "savedRoutes"
        static let lastSet = "lastSetAt"
        static let session = "session"
    }

    /// What is remembered from one launch to the next.
    private struct Session: Codable {
        var mode: TargetMode
        var speedKmh: Double
        var followRoads: Bool
        var preferMotorways: Bool
        var waypoints: [Spot]
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Key.favorites),
           let saved = try? JSONDecoder().decode([Favorite].self, from: data) {
            favorites = saved
        } else {
            favorites = [
                Favorite(name: "Brandenburg Gate, Berlin", spot: Spot(latitude: 52.516275, longitude: 13.377704)),
                Favorite(name: "Eiffel Tower, Paris", spot: Spot(latitude: 48.858370, longitude: 2.294481)),
            ]
        }
        if let data = defaults.data(forKey: Key.savedRoutes),
           let saved = try? JSONDecoder().decode([SavedRoute].self, from: data) {
            savedRoutes = saved
        }
        if let data = defaults.data(forKey: Key.session),
           let session = try? JSONDecoder().decode(Session.self, from: data) {
            // Assigned in init, so the property observers (and with them the route planning) do not run yet.
            mode = session.mode
            speedKmh = min(max(session.speedKmh, SpeedScale.minimum), SpeedScale.maximum)
            followRoads = session.followRoads
            preferMotorways = session.preferMotorways
            waypoints = session.waypoints
        }
        lastSetAt = defaults.object(forKey: Key.lastSet) as? Date
        if let lastSetAt {
            // The simulated location stays on the iPhone after the app quits, so be honest about it.
            isSimulating = true
            status = String(localized: "A location was set \(lastSetAt.stamp) and may still be active. Press Reset to end it.")
        }
        if !waypoints.isEmpty { scheduleRouteRefresh() }
    }

    private func saveSession() {
        let session = Session(mode: mode, speedKmh: speedKmh, followRoads: followRoads,
                              preferMotorways: preferMotorways, waypoints: waypoints)
        if let data = try? JSONEncoder().encode(session) { defaults.set(data, forKey: Key.session) }
    }

    // MARK: Devices

    /// Reloads the list of connected iPhones. The quiet variant (used by the automatic refresh)
    /// leaves the status line alone and does nothing while the iPhone is being sent positions, so
    /// it does not compete with the simulation.
    func refreshDevices(announce: Bool = true) async {
        if !announce && (isMoving || isBusy) { return }
        let hadDevices = !devices.isEmpty
        devices = await DeviceCtl.listDevices().filter(\.connected)
        if selectedDeviceID == nil || !devices.contains(where: { $0.id == selectedDeviceID }) {
            selectedDeviceID = devices.first?.id
        }
        let noDevice = String(localized: "No iPhone connected. Plug it in, unlock it and reload.")
        if devices.isEmpty {
            if announce || hadDevices { status = noDevice }
        } else if !hadDevices, status == noDevice {
            status = String(localized: "Choose a device and a location.")
        }
    }

    // MARK: Choosing a place

    func applyCoordText() {
        guard let parsed = Spot(parsing: coordText) else {
            status = String(localized: "Invalid coordinates. Format: 52.516275, 13.377704")
            return
        }
        spotName = nil
        spot = parsed
    }

    func search() async {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        suggestionsVisible = false
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        do {
            let response = try await MKLocalSearch(request: request).start()
            searchResults = Array(response.mapItems.prefix(6))
            if searchResults.isEmpty { status = String(localized: "Nothing found for “\(text)”.") }
        } catch {
            status = String(localized: "Search failed: \(error.localizedDescription)")
        }
    }

    /// A click on the map: sets the target in point mode, adds a waypoint in route mode.
    /// The map is not recentered, because the user is already looking at that spot.
    func mapTapped(_ newSpot: Spot) {
        spotName = nil
        if mode == .route {
            addWaypoint(newSpot)
        } else {
            spot = newSpot
        }
    }

    /// A place picked from the search results or the favorites. The map moves there.
    func select(_ newSpot: Spot, name: String? = nil) {
        spot = newSpot
        spotName = name
        if mode == .route { addWaypoint(newSpot) }
    }

    func choose(_ item: MKMapItem) {
        let coordinate = item.location.coordinate
        select(Spot(latitude: coordinate.latitude, longitude: coordinate.longitude), name: item.name)
        searchResults = []
        if let name = item.name { query = name }
        suggestionsVisible = false
    }

    /// A suggestion from the list under the address field: look up where it is, then choose it.
    func choose(_ suggestion: MKLocalSearchCompletion) async {
        do {
            let response = try await MKLocalSearch(request: MKLocalSearch.Request(completion: suggestion)).start()
            if let item = response.mapItems.first { choose(item) }
        } catch {
            status = String(localized: "Search failed: \(error.localizedDescription)")
        }
    }

    // MARK: Favorites and saved routes

    func addFavorite() {
        guard let spot else { return }
        let name = spotName?.trimmingCharacters(in: .whitespaces)
        favorites.append(Favorite(name: name?.isEmpty == false ? name! : spot.text, spot: spot))
        save(favorites, key: Key.favorites)
    }

    func removeFavorite(_ favorite: Favorite) {
        favorites.removeAll { $0.id == favorite.id }
        save(favorites, key: Key.favorites)
    }

    func saveRoute() {
        guard waypoints.count >= 2 else { return }
        let distance = Measurement(value: routeDistance, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
        let name = String(localized: "Route \(savedRoutes.count + 1) · \(distance)")
        savedRoutes.append(SavedRoute(name: name, waypoints: waypoints, speedKmh: speedKmh))
        save(savedRoutes, key: Key.savedRoutes)
    }

    func removeSavedRoute(_ route: SavedRoute) {
        savedRoutes.removeAll { $0.id == route.id }
        save(savedRoutes, key: Key.savedRoutes)
    }

    func load(_ route: SavedRoute) {
        guard !isRouteActive else { return }
        recordWaypoints()
        mode = .route
        speedKmh = route.speedKmh
        waypoints = route.waypoints
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
    }

    /// Uses the points of an imported file as the new route. Returns false if there are too few.
    @discardableResult
    func importRoute(_ spots: [Spot]) -> Bool {
        guard !isRouteActive else { return false }
        guard spots.count >= 2 else {
            status = String(localized: "That file has no route with at least two points.")
            return false
        }
        recordWaypoints()
        mode = .route
        if spots.count > Self.maxRoutedWaypoints { followRoads = false }
        waypoints = spots
        status = String(localized: "Imported a route with \(spots.count) points.")
        return true
    }

    // MARK: Route: waypoints and estimates

    /// True while a route is running or paused; the waypoints are locked then.
    var isRouteActive: Bool { isMoving || isPaused }

    /// True if the chosen speed plans the route for a car.
    var isDriving: Bool { speedKmh >= Self.drivingThresholdKmh }

    /// Length of the current route path in meters.
    var routeDistance: Double { RouteMath.length(of: routePath) }

    /// Estimated travel time of the whole route in seconds at the chosen speed.
    var routeDuration: Double { seconds(for: routeDistance) }

    /// When the route will end if it runs (or continues) at `start` with the chosen speed.
    func estimatedArrival(startingAt start: Date) -> Date {
        start.addingTimeInterval(seconds(for: max(routeDistance - travelled, 0)))
    }

    private func seconds(for distance: Double) -> Double {
        speedKmh > 0 ? distance / (speedKmh / 3.6) : 0
    }

    var canUndoWaypoints: Bool { !waypointHistory.isEmpty && !isRouteActive }

    /// Remembers the current waypoints so the next change can be undone.
    private func recordWaypoints() {
        waypointHistory.append(waypoints)
        if waypointHistory.count > 50 { waypointHistory.removeFirst() }
    }

    func addWaypoint(_ newSpot: Spot) {
        guard !isRouteActive else { return }
        recordWaypoints()
        waypoints.append(newSpot)
    }

    func removeWaypoint(at index: Int) {
        guard !isRouteActive, waypoints.indices.contains(index) else { return }
        recordWaypoints()
        waypoints.remove(at: index)
    }

    func clearWaypoints() {
        guard !isRouteActive, !waypoints.isEmpty else { return }
        recordWaypoints()
        waypoints.removeAll()
        movingPosition = nil
        progress = 0
    }

    /// Call once when the user starts dragging a waypoint, so the whole drag is one undo step.
    func beginMovingWaypoint() {
        guard !isRouteActive else { return }
        recordWaypoints()
    }

    func moveWaypoint(at index: Int, to newSpot: Spot) {
        guard !isRouteActive, waypoints.indices.contains(index) else { return }
        waypoints[index] = newSpot
    }

    func undoWaypoints() {
        guard canUndoWaypoints, let previous = waypointHistory.popLast() else { return }
        waypoints = previous
    }

    // MARK: Main action

    /// What the big button does: it depends on the mode and on whether a route is running.
    enum PrimaryAction {
        case setLocation, startRoute, pause, resume

        var title: LocalizedStringKey {
            switch self {
            case .setLocation: "Set Location"
            case .startRoute: "Start Route"
            case .pause: "Pause"
            case .resume: "Continue"
            }
        }
    }

    var primaryAction: PrimaryAction {
        if mode == .point { return .setLocation }
        if isMoving { return .pause }
        return isPaused ? .resume : .startRoute
    }

    var isPrimaryActionEnabled: Bool {
        switch primaryAction {
        case .setLocation: !isBusy && selectedDeviceID != nil && !coordText.isEmpty
        case .startRoute: !isBusy && selectedDeviceID != nil && waypoints.count >= 2 && !isCalculatingRoute
        case .pause: true
        case .resume: !isBusy && selectedDeviceID != nil
        }
    }

    var canReset: Bool { !isBusy && selectedDeviceID != nil }

    func performPrimaryAction() {
        guard isPrimaryActionEnabled else { return }
        switch primaryAction {
        case .setLocation:
            Task { await apply() }
        case .startRoute, .resume:
            startRoute()
        case .pause:
            Task { await pauseRoute() }
        }
    }

    // MARK: Route: planning

    /// Recomputes the route path after the waypoints, road mode or speed changed.
    func scheduleRouteRefresh() {
        refreshTask?.cancel()
        guard !isRouteActive else { return }
        progress = 0
        travelled = 0
        routeStartedAt = nil
        routeFinishedAt = nil
        routePath = waypoints
        routeRoads = []
        isCalculatingRoute = false
        guard followRoads, waypoints.count >= 2 else { return }
        refreshTask = Task {
            try? await Task.sleep(for: .milliseconds(400))  // debounce quick successive clicks
            guard !Task.isCancelled else { return }
            isCalculatingRoute = true
            let planned = await plannedRoute()
            guard !Task.isCancelled else { return }
            isCalculatingRoute = false
            if let planned {
                routePath = planned.path
                routeRoads = planned.roads
            } else {
                status = String(localized: "Could not calculate roads. Using straight lines instead.")
            }
        }
    }

    /// The route along roads, or nil if Apple Maps could not provide it.
    func plannedRoute() async -> PlannedRoute? {
        await RoutePlanner.route(through: waypoints, driving: isDriving, preferMotorways: preferMotorways)
    }
}
