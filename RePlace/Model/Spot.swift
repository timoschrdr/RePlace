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

    /// "52.516275, 13.377704"
    var text: String {
        String(format: "%.6f, %.6f", latitude, longitude)
    }

    init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Reads "latitude, longitude" with a dot as decimal separator. Commas, spaces and
    /// semicolons separate the two numbers, so decimal commas ("51,43 7,21") are not supported.
    init?(parsing text: String) {
        let numbers = text
            .replacingOccurrences(of: ",", with: " ")
            .split(whereSeparator: { $0 == " " || $0 == ";" })
            .compactMap { Double($0) }
        guard numbers.count == 2,
              (-90...90).contains(numbers[0]),
              (-180...180).contains(numbers[1])
        else { return nil }
        self.init(latitude: numbers[0], longitude: numbers[1])
    }
}
