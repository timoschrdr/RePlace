import Foundation

/// A saved place in the favorites list.
struct Favorite: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var spot: Spot
}

/// A saved route: its waypoints and the speed it was planned with.
struct SavedRoute: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var waypoints: [Spot]
    var speedKmh: Double
}

/// Whether a click on the map sets a single location or adds a waypoint to a route.
enum TargetMode: String, Codable, Hashable {
    case point
    case route
}
