import Foundation

/// A saved place in the favorites list.
struct Favorite: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var spot: Spot
}

/// Whether a click on the map sets a single location or adds a waypoint to a route.
enum TargetMode: Hashable {
    case point
    case route
}
