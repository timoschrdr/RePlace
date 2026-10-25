import MapKit
import SwiftUI

/// The window: the map fills it, the floating sidebar and the status pill lie on top.
struct ContentView: View {
    let model: AppModel
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 52.5163, longitude: 13.3777),
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        )
    )

    var body: some View {
        ZStack(alignment: .topLeading) {
            MapPane(model: model, position: $position, visibleRegion: $visibleRegion)
                // Reserve the sidebar's width so Apple's Maps logo and legal link
                // (bottom-left) stay visible instead of being covered by the panel.
                .safeAreaInset(edge: .leading, spacing: 0) {
                    Color.clear.frame(width: Layout.mapInset)
                }
                .ignoresSafeArea(.container, edges: [.top, .trailing, .bottom])

            SidebarView(model: model)
                .frame(width: Layout.sidebarWidth)
                .frame(maxHeight: .infinity)
                .glassEffect(.regular.tint(Color.brand.opacity(0.07)), in: .rect(cornerRadius: 28, style: .continuous))
                .padding(12)
        }
        .overlay(alignment: .bottom) { StatusPill(model: model) }
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .navigationTitle("RePlace.")
        .tint(.brand)
        .task { await model.refreshDevices() }
        .onChange(of: model.movingPosition) { _, new in
            guard let new else { return }
            withAnimation(.linear(duration: 0.9)) { position = Self.region(around: new, span: 0.008) }
        }
        .onChange(of: model.spot) { _, new in
            guard let new else { return }
            withAnimation(.smooth) { position = Self.region(around: new, span: 0.02) }
        }
        .onChange(of: model.isCalculatingRoute) { _, calculating in
            if !calculating { showRouteIfHidden() }
        }
    }

    /// Moves the map to the planned route, unless all of it is in view already.
    private func showRouteIfHidden() {
        let path = model.routePath
        guard !model.isRouteActive, path.count > 1 else { return }
        if let visibleRegion, path.allSatisfy(visibleRegion.contains) { return }
        withAnimation(.smooth) { position = Self.region(fitting: path) }
    }

    /// A region that shows the whole path with some room around it.
    private static func region(fitting path: [Spot]) -> MapCameraPosition {
        let latitudes = path.map(\.latitude), longitudes = path.map(\.longitude)
        guard let minLat = latitudes.min(), let maxLat = latitudes.max(),
              let minLon = longitudes.min(), let maxLon = longitudes.max() else { return .automatic }
        return .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            span: MKCoordinateSpan(
                latitudeDelta: max((maxLat - minLat) * 1.5, 0.005),
                longitudeDelta: max((maxLon - minLon) * 1.5, 0.005)
            )
        ))
    }

    private static func region(around spot: Spot, span: Double) -> MapCameraPosition {
        .region(MKCoordinateRegion(
            center: spot.coordinate,
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        ))
    }
}

private extension MKCoordinateRegion {
    func contains(_ spot: Spot) -> Bool {
        abs(spot.latitude - center.latitude) <= span.latitudeDelta / 2
            && abs(spot.longitude - center.longitude) <= span.longitudeDelta / 2
    }
}
