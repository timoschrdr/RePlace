import Foundation
import MapKit
import Observation

struct Favorite: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var spot: Spot
}

enum TargetMode: Hashable {
    case point
    case route
}

@Observable
final class AppModel {
    var devices: [Device] = []
    var selectedDeviceID: String?
    var spot: Spot? {
        didSet { if let spot { coordText = Self.format(spot) } }
    }
    var coordText = ""
    var query = ""
    var searchResults: [MKMapItem] = []
    var favorites: [Favorite] = []
    var status = String(localized: "Choose a device and a location.")
    var isBusy = false
    var isSimulating = false

    // MARK: Route state

    var mode: TargetMode = .point
    var waypoints: [Spot] = [] {
        didSet { scheduleRouteRefresh() }
    }
    var followRoads = true {
        didSet { scheduleRouteRefresh() }
    }
    var speedKmh = 5.0 {
        didSet {
            // Walking and driving use different road networks.
            if (oldValue >= Self.drivingThresholdKmh) != (speedKmh >= Self.drivingThresholdKmh) {
                scheduleRouteRefresh()
            }
        }
    }
    /// The path the device will follow: road geometry or straight lines between waypoints.
    var routePath: [Spot] = []
    var isMoving = false
    /// True after Pause (or an interrupted run) while the route can be continued.
    var isPaused = false
    var progress = 0.0
    var movingPosition: Spot?
    var isCalculatingRoute = false

    private static let drivingThresholdKmh = 20.0
    /// Seconds between two simulated positions.
    private static let tick = 1.0

    private let favoritesKey = "favorites"
    private var routeTask: Task<Void, Never>?
    /// Meters of the route path the device has already covered.
    private var travelled = 0.0
    private var refreshTask: Task<Void, Never>?

    init() {
        if let data = UserDefaults.standard.data(forKey: favoritesKey),
           let saved = try? JSONDecoder().decode([Favorite].self, from: data) {
            favorites = saved
        } else {
            favorites = [
                Favorite(name: "Brandenburg Gate, Berlin", spot: Spot(latitude: 52.516275, longitude: 13.377704)),
                Favorite(name: "Eiffel Tower, Paris", spot: Spot(latitude: 48.858370, longitude: 2.294481)),
            ]
        }
    }

    static func format(_ spot: Spot) -> String {
        String(format: "%.6f, %.6f", spot.latitude, spot.longitude)
    }

    // MARK: Geräte

    func refreshDevices() async {
        devices = await DeviceCtl.listDevices().filter(\.connected)
        if selectedDeviceID == nil || !devices.contains(where: { $0.id == selectedDeviceID }) {
            selectedDeviceID = devices.first?.id
        }
        if devices.isEmpty {
            status = String(localized: "No iPhone connected. Plug it in, unlock it and reload.")
        }
    }

    // MARK: Ort wählen

    func applyCoordText() {
        let numbers = coordText
            .replacingOccurrences(of: ",", with: " ")
            .split(whereSeparator: { $0 == " " || $0 == ";" })
            .compactMap { Double($0) }
        // Dezimalkomma ("51,43 7,21") ist mehrdeutig; erwartet wird "lat, lon" mit Punkt.
        guard numbers.count == 2,
              (-90...90).contains(numbers[0]),
              (-180...180).contains(numbers[1])
        else {
            status = String(localized: "Invalid coordinates. Format: 52.516275, 13.377704")
            return
        }
        spot = Spot(latitude: numbers[0], longitude: numbers[1])
    }

    func search() async {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
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
        if mode == .route {
            addWaypoint(newSpot)
        } else {
            spot = newSpot
        }
    }

    /// A place picked from the search results or the favorites. The map moves there.
    func select(_ newSpot: Spot) {
        spot = newSpot
        if mode == .route { addWaypoint(newSpot) }
    }

    func choose(_ item: MKMapItem) {
        let coordinate = item.location.coordinate
        select(Spot(latitude: coordinate.latitude, longitude: coordinate.longitude))
        searchResults = []
    }

    // MARK: Favoriten

    func addFavorite() {
        guard let spot else { return }
        let name = query.trimmingCharacters(in: .whitespaces)
        favorites.append(Favorite(name: name.isEmpty ? Self.format(spot) : name, spot: spot))
        saveFavorites()
    }

    func removeFavorite(_ favorite: Favorite) {
        favorites.removeAll { $0.id == favorite.id }
        saveFavorites()
    }

    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: favoritesKey)
        }
    }

    // MARK: Simulation (single point)

    private static func errorStatus(_ output: String) -> String {
        let detail = output.split(separator: "\n").last.map(String.init) ?? String(localized: "unknown")
        return String(localized: "Error: \(detail)")
    }

    func apply() async {
        guard let device = selectedDeviceID, let spot else { return }
        await pauseRoute()
        isPaused = false
        isBusy = true
        defer { isBusy = false }
        let result = await DeviceCtl.retrying {
            await DeviceCtl.setLocation(device: device, latitude: spot.latitude, longitude: spot.longitude)
        }
        if result.ok {
            isSimulating = true
            status = String(localized: "Location set: \(Self.format(spot))")
        } else {
            status = Self.errorStatus(result.output)
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
            status = String(localized: "Simulation stopped. Your iPhone uses its real location again.")
        } else {
            status = Self.errorStatus(result.output)
        }
    }

    // MARK: Route

    /// True while a route is running or paused; the waypoints are locked then.
    var isRouteActive: Bool { isMoving || isPaused }

    /// Length of the current route path in meters.
    var routeDistance: Double { RouteMath.length(of: routePath) }

    /// Estimated travel time in seconds at the chosen speed.
    var routeDuration: Double {
        speedKmh > 0 ? routeDistance / (speedKmh / 3.6) : 0
    }

    func addWaypoint(_ newSpot: Spot) {
        guard !isRouteActive else { return }
        waypoints.append(newSpot)
    }

    func removeWaypoint(at index: Int) {
        guard !isRouteActive, waypoints.indices.contains(index) else { return }
        waypoints.remove(at: index)
    }

    func clearWaypoints() {
        guard !isRouteActive else { return }
        waypoints.removeAll()
        movingPosition = nil
        progress = 0
    }

    private func straightPath() -> [Spot] { waypoints }

    /// Recomputes the route path after the waypoints, road mode or speed changed.
    private func scheduleRouteRefresh() {
        refreshTask?.cancel()
        guard !isRouteActive else { return }
        progress = 0
        travelled = 0
        routePath = straightPath()
        guard followRoads, waypoints.count >= 2 else { return }
        refreshTask = Task {
            try? await Task.sleep(for: .milliseconds(400))  // debounce quick successive clicks
            guard !Task.isCancelled else { return }
            isCalculatingRoute = true
            let path = await roadPath()
            guard !Task.isCancelled else { return }
            isCalculatingRoute = false
            if let path {
                routePath = path
            } else {
                status = String(localized: "Could not calculate roads. Using straight lines instead.")
            }
        }
    }

    /// Route geometry that follows roads, or nil if Apple Maps could not provide it.
    private func roadPath() async -> [Spot]? {
        let transport: MKDirectionsTransportType = speedKmh >= Self.drivingThresholdKmh ? .automobile : .walking
        var path: [Spot] = []
        for (from, to) in zip(waypoints, waypoints.dropFirst()) {
            let request = MKDirections.Request()
            request.source = MKMapItem(location: from.location, address: nil)
            request.destination = MKMapItem(location: to.location, address: nil)
            request.transportType = transport
            guard let route = try? await MKDirections(request: request).calculate().routes.first else {
                return nil
            }
            let polyline = route.polyline
            var coordinates = [CLLocationCoordinate2D](
                repeating: CLLocationCoordinate2D(), count: polyline.pointCount
            )
            polyline.getCoordinates(&coordinates, range: NSRange(location: 0, length: polyline.pointCount))
            path.append(from)
            path.append(contentsOf: coordinates.map { Spot(latitude: $0.latitude, longitude: $0.longitude) })
            path.append(to)
        }
        return path
    }

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

    private func runRoute(device: String, resuming: Bool) async {
        defer { isMoving = false }
        refreshTask?.cancel()
        if !resuming {
            progress = 0
            travelled = 0
            movingPosition = nil  // so a Pause before the first step is not "continuable"
        }

        if !resuming, followRoads, routePath.count <= waypoints.count {
            status = String(localized: "Calculating route…")
            routePath = await roadPath() ?? straightPath()
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

        let clock = ContinuousClock()
        var next = clock.now

        for stop in stops {
            if Task.isCancelled {
                isPaused = movingPosition != nil
                status = String(localized: "Route paused. Your iPhone stays at the last position.")
                return
            }
            let result = await DeviceCtl.retrying {
                await DeviceCtl.setLocation(device: device, latitude: stop.spot.latitude, longitude: stop.spot.longitude)
            }
            guard result.ok else {
                // A step that fails because the user pressed Pause is not an error. Other
                // failures also leave the route paused so it can be continued.
                isPaused = movingPosition != nil
                status = Task.isCancelled
                    ? String(localized: "Route paused. Your iPhone stays at the last position.")
                    : Self.errorStatus(result.output)
                return
            }
            isSimulating = true
            movingPosition = stop.spot
            travelled = base + stop.distance
            progress = total > 0 ? min(travelled / total, 1) : 1
            let percent = "\(Int(progress * 100)) %"
            status = String(localized: "Moving along the route: \(percent)")
            // Keep a steady pace. If a step was slow, do not rush the following ones to catch
            // up, because that would make the device move faster than the chosen speed.
            next = max(next + .seconds(Self.tick), clock.now)
            try? await clock.sleep(until: next)
        }

        travelled = 0
        progress = 1  // avoid a floating-point leftover such as 0.99999999
        isPaused = false
        status = String(localized: "Route finished. Your iPhone stays at the end point.")
    }
}
