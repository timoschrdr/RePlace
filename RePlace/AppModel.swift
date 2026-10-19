import Foundation
import MapKit
import Observation

struct Spot: Equatable, Codable {
    var latitude: Double
    var longitude: Double

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct Favorite: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var spot: Spot
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

    private let favoritesKey = "favorites"

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

    func choose(_ item: MKMapItem) {
        spot = Spot(latitude: item.location.coordinate.latitude, longitude: item.location.coordinate.longitude)
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

    // MARK: Simulation

    private static func errorStatus(_ output: String) -> String {
        let detail = output.split(separator: "\n").last.map(String.init) ?? String(localized: "unknown")
        return String(localized: "Error: \(detail)")
    }

    func apply() async {
        guard let device = selectedDeviceID, let spot else { return }
        isBusy = true
        defer { isBusy = false }
        let result = await DeviceCtl.setLocation(device: device, latitude: spot.latitude, longitude: spot.longitude)
        if result.ok {
            isSimulating = true
            status = String(localized: "Location set: \(Self.format(spot))")
        } else {
            status = Self.errorStatus(result.output)
        }
    }

    func reset() async {
        guard let device = selectedDeviceID else { return }
        isBusy = true
        defer { isBusy = false }
        let result = await DeviceCtl.clearLocation(device: device)
        if result.ok {
            isSimulating = false
            status = String(localized: "Simulation stopped. Your iPhone uses its real location again.")
        } else {
            status = Self.errorStatus(result.output)
        }
    }
}
