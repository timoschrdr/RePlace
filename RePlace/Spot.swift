import CoreLocation

/// A latitude/longitude pair. Plain value type so it can be used off the main actor.
nonisolated struct Spot: Equatable, Codable {
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}
