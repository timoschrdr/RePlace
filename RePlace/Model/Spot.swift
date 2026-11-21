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

    /// Reads a coordinate pair as people write it: "52.516275, 13.377704", "52.516275 13.377704",
    /// "52.516275;13.377704" or with decimal commas ("52,516275 13,377704"). Between the numbers
    /// there must be a space, a semicolon or a comma followed by a space; "52,5,13,4" is rejected
    /// because it cannot be read unambiguously.
    init?(parsing text: String) {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: ";", with: " ").replacingOccurrences(of: ", ", with: " ")
        var tokens = cleaned.split(whereSeparator: \.isWhitespace).map(String.init)
        if tokens.count == 1 {
            // "52.5,13.4" without a space: a single comma separates the numbers.
            let parts = tokens[0].split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard parts.count == 2 else { return nil }
            tokens = parts
        }
        guard tokens.count == 2,
              let latitude = Double(tokens[0].replacingOccurrences(of: ",", with: ".")),
              let longitude = Double(tokens[1].replacingOccurrences(of: ",", with: ".")),
              (-90...90).contains(latitude),
              (-180...180).contains(longitude)
        else { return nil }
        self.init(latitude: latitude, longitude: longitude)
    }
}
