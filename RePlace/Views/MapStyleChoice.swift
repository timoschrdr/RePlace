import MapKit
import SwiftUI

/// The map looks the user can switch between.
enum MapStyleChoice: String, CaseIterable, Identifiable {
    case standard
    case satellite

    static let storageKey = "mapStyle"

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .standard: "Map"
        case .satellite: "Satellite"
        }
    }

    var style: MapStyle {
        switch self {
        case .standard: .standard
        case .satellite: .hybrid
        }
    }
}
