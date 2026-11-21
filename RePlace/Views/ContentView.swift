import MapKit
import SwiftUI

/// The window: the map fills it, the floating sidebar, the map buttons and the status pill lie on top.
struct ContentView: View {
    let model: AppModel
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 52.5163, longitude: 13.3777),
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        )
    )
    @AppStorage(MapStyleChoice.storageKey) private var mapStyleRaw = MapStyleChoice.standard.rawValue

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
        .overlay(alignment: .topTrailing) { mapButtons }
        .overlay(alignment: .bottom) { StatusPill(model: model) }
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .navigationTitle("RePlace.")
        .tint(.brand)
        .task {
            await model.refreshDevices()
            // Notice an iPhone being plugged in or removed without pressing reload.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(6))
                await model.refreshDevices(announce: false)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first(where: { $0.pathExtension.lowercased() == "gpx" }) else { return false }
            GPXFiles.importFile(at: url, into: model)
            return true
        }
        .onChange(of: model.movingPosition) { _, new in
            guard let new else { return }
            withAnimation(.linear(duration: 0.9)) { position = Self.region(around: new, span: 0.008) }
        }
        .onChange(of: model.spot) { _, new in
            guard let new else { return }
            withAnimation(.calm) { position = Self.region(around: new, span: 0.02) }
        }
        .onChange(of: model.isCalculatingRoute) { _, calculating in
            if !calculating { showRoute(onlyIfHidden: true) }
        }
    }

    // MARK: Map buttons

    /// Round glass buttons in the corner of the map: switch between map and satellite, and "show the whole route".
    private var mapButtons: some View {
        VStack(spacing: 10) {
            Button {
                withAnimation(.calm) {
                    mapStyleRaw = (mapStyleRaw == MapStyleChoice.standard.rawValue ? MapStyleChoice.satellite : .standard).rawValue
                }
            } label: {
                glassIcon(mapStyleRaw == MapStyleChoice.standard.rawValue ? "globe.europe.africa" : "map")
            }
            .buttonStyle(.plain)
            .help("Map style")
            .accessibilityLabel("Map style")
            .accessibilityValue(Text((MapStyleChoice(rawValue: mapStyleRaw) ?? .standard).title))

            Button {
                showRoute(onlyIfHidden: false)
            } label: {
                glassIcon("scope")
            }
            .buttonStyle(.plain)
            .disabled(!canShowRoute)
            .opacity(canShowRoute ? 1 : 0.4)
            .help("Show the whole route")
            .accessibilityLabel("Show the whole route")
        }
        .padding(.top, 14)
        .padding(.trailing, 14)
    }

    private var canShowRoute: Bool { model.mode == .route && model.routePath.count >= 2 }

    private func glassIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 15, weight: .semibold))
            .frame(width: 38, height: 38)
            .glassEffect(.regular, in: .circle)
            .contentShape(.circle)
    }

    // MARK: Camera

    /// Moves the map to the planned route; with `onlyIfHidden` only if part of it is out of view.
    private func showRoute(onlyIfHidden: Bool) {
        let path = model.routePath
        guard model.mode == .route, !model.isRouteActive || !onlyIfHidden, path.count > 1 else { return }
        if onlyIfHidden, let visibleRegion, path.allSatisfy(visibleRegion.contains) { return }
        withAnimation(.calm) { position = Self.region(fitting: path) }
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
