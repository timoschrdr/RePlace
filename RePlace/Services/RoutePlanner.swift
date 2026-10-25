import MapKit

/// A path along roads and the names of the main roads it uses.
struct PlannedRoute {
    var path: [Spot]
    /// Main road of each leg, e.g. `["A43"]`. Consecutive duplicates are merged.
    var roads: [String]

    static func + (head: PlannedRoute, tail: PlannedRoute) -> PlannedRoute {
        var roads = head.roads
        for road in tail.roads where roads.last != road { roads.append(road) }
        return PlannedRoute(path: head.path + tail.path, roads: roads)
    }
}

/// Plans a path along roads through the waypoints the user clicked, using Apple Maps.
///
/// Routing every pair of waypoints on its own gives chaotic results: a click next to a road is
/// snapped to a different spot each time, so the route detours, turns around or leaves the
/// motorway. Instead the whole trip is routed from the first to the last waypoint, and
/// intermediate waypoints are only used where the route would otherwise miss them.
enum RoutePlanner {
    /// An intermediate waypoint closer than this to the planned route counts as "on the way".
    static let viaTolerance = 150.0
    /// The same for a route over a motorway: clicks next to a motorway cannot be reached from it
    /// (there are no ramps in between), so they are given more room instead of leaving the motorway.
    static let motorwayViaTolerance = 600.0
    /// A motorway alternative is taken over the fastest route if it is at most this many times slower.
    static let motorwayTimeFactor = 2.0
    /// Maximum number of times the trip is split at a missed waypoint.
    private static let maxDepth = 8

    /// - Parameters:
    ///   - driving: Route for a car instead of for a pedestrian.
    ///   - preferMotorways: When driving, take a motorway alternative if Apple Maps offers one,
    ///     even if a route through town is a little faster.
    /// - Returns: `nil` if Apple Maps could not provide a route.
    static func route(through waypoints: [Spot], driving: Bool, preferMotorways: Bool) async -> PlannedRoute? {
        guard waypoints.count >= 2 else { return PlannedRoute(path: waypoints, roads: []) }
        let options = Options(driving: driving, preferMotorways: driving && preferMotorways)
        guard var planned = await plan(waypoints[...], options: options, depth: 0) else { return nil }
        planned.path = RouteMath.removingSpikes(from: planned.path)
        return planned
    }

    /// Whether a road name looks like a motorway: A43, AP-7, M25, E40, I-95.
    /// Federal and country roads (B1, N7) are deliberately not matched.
    static func isMotorway(_ name: String) -> Bool {
        name.range(of: #"^(?:AP|A|M|E|I)[\s-]?\d{1,3}\b"#, options: .regularExpression) != nil
    }

    private struct Options {
        var driving: Bool
        var preferMotorways: Bool
    }

    private static func plan(_ points: ArraySlice<Spot>, options: Options, depth: Int) async -> PlannedRoute? {
        guard let first = points.first, let last = points.last else { return nil }
        let direct: PlannedRoute
        if RouteMath.distance(first, last) < 30 {
            direct = PlannedRoute(path: [first, last], roads: [])  // a loop: nothing to route between start and end
        } else if let routed = await leg(from: first, to: last, options: options) {
            direct = routed
        } else {
            return nil
        }

        // The intermediate waypoint that the direct route misses by the most.
        let tolerance = options.preferMotorways && direct.roads.contains(where: isMotorway) ? motorwayViaTolerance : viaTolerance
        let missed = points.dropFirst().dropLast().enumerated()
            .map { (offset: $0.offset, miss: RouteMath.distance(from: $0.element, to: direct.path)) }
            .filter { $0.miss > tolerance }
            .max { $0.miss < $1.miss }
        guard let missed, depth < maxDepth else { return direct }

        // Split at that waypoint and plan both halves the same way.
        let split = points.startIndex + 1 + missed.offset
        guard let head = await plan(points[points.startIndex...split], options: options, depth: depth + 1),
              let tail = await plan(points[split...], options: options, depth: depth + 1)
        else { return nil }
        return head + tail
    }

    /// One route between two spots, without the raw end points (they are rarely on a road).
    private static func leg(from: Spot, to: Spot, options: Options) async -> PlannedRoute? {
        let request = MKDirections.Request()
        request.source = MKMapItem(location: from.location, address: nil)
        request.destination = MKMapItem(location: to.location, address: nil)
        request.transportType = options.driving ? .automobile : .walking
        request.requestsAlternateRoutes = options.driving

        var routes: [MKRoute] = []
        for attempt in 0..<3 {
            if let found = try? await MKDirections(request: request).calculate().routes, !found.isEmpty {
                routes = found
                break
            }
            try? await Task.sleep(for: .milliseconds(600 * (attempt + 1)))  // Apple Maps rate limits bursts
        }
        guard let chosen = choose(from: routes, preferMotorways: options.preferMotorways) else { return nil }

        let polyline = chosen.polyline
        var coordinates = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: polyline.pointCount)
        polyline.getCoordinates(&coordinates, range: NSRange(location: 0, length: polyline.pointCount))
        return PlannedRoute(
            path: coordinates.map { Spot(latitude: $0.latitude, longitude: $0.longitude) },
            roads: chosen.name.isEmpty ? [] : [chosen.name]
        )
    }

    /// The fastest route, or the fastest motorway route if motorways are preferred and one is
    /// not much slower.
    private static func choose(from routes: [MKRoute], preferMotorways: Bool) -> MKRoute? {
        guard let fastest = routes.min(by: { $0.expectedTravelTime < $1.expectedTravelTime }) else { return nil }
        guard preferMotorways, !isMotorway(fastest.name),
              let motorway = routes.filter({ isMotorway($0.name) }).min(by: { $0.expectedTravelTime < $1.expectedTravelTime }),
              motorway.expectedTravelTime <= fastest.expectedTravelTime * motorwayTimeFactor
        else { return fastest }
        return motorway
    }
}
