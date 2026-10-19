import MapKit
import SwiftUI

extension Color {
    /// Akzentfarbe der App: ein warmes Rot ("Manipulation").
    static let brandRed = Color(red: 0.90, green: 0.16, blue: 0.20)
}

private extension View {
    /// The shared look of text fields and pickers: a fully rounded, softly filled pill.
    func pill() -> some View {
        padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.quaternary, in: .capsule)
    }
}

struct ContentView: View {
    @State private var model = AppModel()
    @State private var showHelp = false
    @Namespace private var modeNamespace
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 52.5163, longitude: 13.3777),
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        )
    )

    var body: some View {
        ZStack(alignment: .topLeading) {
            map
                // Reserve the sidebar's width so Apple's Maps logo and legal link
                // (bottom-left) stay visible instead of being covered by the panel.
                .safeAreaInset(edge: .leading, spacing: 0) {
                    Color.clear.frame(width: 344)
                }
                .ignoresSafeArea(.container, edges: [.top, .trailing, .bottom])

            sidebar
                .frame(width: 320)
                .frame(maxHeight: .infinity)
                .glassEffect(.regular, in: .rect(cornerRadius: 24))
                .padding(12)
        }
        .overlay(alignment: .bottom) { statusPill }
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .navigationTitle("RePlace.")
        .tint(.brandRed)
        .task { await model.refreshDevices() }
        .onChange(of: model.movingPosition) { _, new in
            guard let new else { return }
            withAnimation(.linear(duration: 0.9)) {
                position = .region(MKCoordinateRegion(
                    center: new.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
                ))
            }
        }
        .onChange(of: model.spot) { _, new in
            guard let new else { return }
            withAnimation(.smooth) {
                position = .region(MKCoordinateRegion(
                    center: new.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                ))
            }
        }
    }

    // MARK: Karte

    private var map: some View {
        MapReader { proxy in
            Map(position: $position) {
                if model.mode == .point, let spot = model.spot {
                    Marker("Target", systemImage: "mappin", coordinate: spot.coordinate)
                        .tint(Color.brandRed)
                }
                if model.routePath.count > 1 {
                    MapPolyline(coordinates: model.routePath.map(\.coordinate))
                        .stroke(Color.brandRed, lineWidth: 5)
                }
                ForEach(Array(model.waypoints.enumerated()), id: \.offset) { index, waypoint in
                    Marker("\(index + 1)", monogram: Text("\(index + 1)"), coordinate: waypoint.coordinate)
                        .tint(Color.brandRed)
                }
                if let position = model.movingPosition {
                    Annotation("", coordinate: position.coordinate) {
                        Circle()
                            .fill(.blue)
                            .frame(width: 16, height: 16)
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                            .shadow(radius: 2)
                    }
                }
            }
            .mapControls {
                MapCompass()
                MapZoomStepper()
                MapScaleView()
            }
            .onTapGesture(coordinateSpace: .local) { point in
                if let coordinate = proxy.convert(point, from: .local) {
                    model.mapTapped(Spot(latitude: coordinate.latitude, longitude: coordinate.longitude))
                }
            }
        }
    }

    // MARK: Seitenleiste

    private var sidebar: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    deviceSection
                    modeSection
                    searchSection
                    if model.mode == .point {
                        coordinateSection
                    } else {
                        routeSection
                    }
                    favoritesSection
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            // Pinned below the scrolling content so the main buttons are always visible.
            actionRow
                .padding(.horizontal, 20)
                .padding(.top, 4)
            helpBar
        }
    }

    private func sectionTitle(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private var deviceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Device")
            HStack(spacing: 8) {
                Image(systemName: "iphone")
                    .foregroundStyle(.secondary)
                Picker("Device", selection: $model.selectedDeviceID) {
                    ForEach(model.devices) { device in
                        Text(device.label).tag(Optional(device.id))
                    }
                }
                .labelsHidden()
                .tint(.primary)
                Button {
                    Task { await model.refreshDevices() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .tint(.secondary)
                .help("Reload devices")
            }
            .pill()
        }
    }

    // MARK: Modus

    private var modeSection: some View {
        HStack(spacing: 0) {
            modeButton("Point", .point)
            modeButton("Route", .route)
        }
        .padding(3)
        .background(.quaternary, in: .capsule)
        .frame(maxWidth: .infinity)
        .opacity(model.isRouteActive ? 0.5 : 1)
    }

    private func modeButton(_ title: LocalizedStringKey, _ value: TargetMode) -> some View {
        let selected = model.mode == value
        return Button {
            withAnimation(.snappy) { model.mode = value }
        } label: {
            Text(title)
                .font(.callout.weight(.medium))
                .foregroundStyle(selected ? Color.white : Color.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background {
                    if selected {
                        Capsule()
                            .fill(Color.brandRed)
                            .matchedGeometryEffect(id: "modeBackground", in: modeNamespace)
                    }
                }
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .disabled(model.isRouteActive)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Suche

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Address")
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search address or place", text: $model.query)
                    .textFieldStyle(.plain)
                    .onSubmit { Task { await model.search() } }
            }
            .pill()

            if !model.searchResults.isEmpty {
                VStack(spacing: 2) {
                    ForEach(model.searchResults, id: \.self) { item in
                        Button {
                            model.choose(item)
                        } label: {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.name ?? "–").lineLimit(1)
                                if let address = item.address?.shortAddress {
                                    Text(address)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
                .background(.quaternary.opacity(0.6), in: .rect(cornerRadius: 20))
            }
        }
    }

    private var coordinateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Coordinates")
            HStack(spacing: 8) {
                Image(systemName: "location")
                    .foregroundStyle(.secondary)
                TextField("52.516275, 13.377704", text: $model.coordText)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .onSubmit { model.applyCoordText() }
            }
            .pill()
            Text("Or click on the map.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 14)
        }
    }

    // MARK: Route

    private var routeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionTitle("Route")
                Spacer()
                if !model.waypoints.isEmpty {
                    Button("Clear") { model.clearWaypoints() }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .disabled(model.isRouteActive)
                }
            }

            if model.waypoints.isEmpty {
                Text("Click the map or pick a place to add waypoints. The iPhone moves along them in order and stops at the last one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
            } else {
                VStack(spacing: 4) {
                    ForEach(Array(model.waypoints.enumerated()), id: \.offset) { index, waypoint in
                        HStack(spacing: 8) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 20, height: 20)
                                .background(Color.brandRed, in: .circle)
                            Text(AppModel.format(waypoint))
                                .font(.system(.caption, design: .monospaced))
                            Spacer()
                            Button {
                                model.removeWaypoint(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .disabled(model.isRouteActive)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.quaternary.opacity(0.6), in: .capsule)
                    }
                }
            }

            Toggle("Follow roads", isOn: $model.followRoads)
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(model.isRouteActive)
                .padding(.horizontal, 14)

            VStack(alignment: .leading, spacing: 6) {
                Text("Speed: \(Int(model.speedKmh)) km/h")
                    .font(.callout)
                    .padding(.horizontal, 14)
                Slider(value: $model.speedKmh, in: 1...130, step: 1)
                    .disabled(model.isMoving)
                    .padding(.horizontal, 14)
                HStack(spacing: 6) {
                    speedPreset("figure.walk", 5)
                    speedPreset("bicycle", 15)
                    speedPreset("car.fill", 50)
                }
            }

            if model.waypoints.count >= 2 {
                HStack(spacing: 6) {
                    if model.isCalculatingRoute {
                        ProgressView().controlSize(.small)
                        Text("Calculating route…")
                    } else {
                        Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                        Text("\(distanceText) · \(durationText)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
            }

            if model.isRouteActive || model.progress > 0 {
                ProgressView(value: model.progress)
                    .padding(.horizontal, 14)
            }
        }
    }

    private func speedPreset(_ symbol: String, _ kmh: Double) -> some View {
        Button {
            model.speedKmh = kmh
        } label: {
            Label("\(Int(kmh)) km/h", systemImage: symbol)
                .font(.caption)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
        .disabled(model.isMoving)
    }

    private var distanceText: String {
        Measurement(value: model.routeDistance, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }

    private var durationText: String {
        Duration.seconds(Int(model.routeDuration))
            .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 2))
    }

    // MARK: Aktionen

    /// Main action and Reset side by side, the same in both modes.
    private var actionRow: some View {
        HStack(spacing: 8) {
            primaryButton
            Button {
                Task { await model.reset() }
            } label: {
                Text("Reset")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .disabled(model.isBusy || model.selectedDeviceID == nil)
        }
    }

    @ViewBuilder
    private var primaryButton: some View {
        if model.mode == .point {
            actionButton("Set Location") {
                model.applyCoordText()
                Task { await model.apply() }
            }
            .disabled(model.isBusy || model.selectedDeviceID == nil || model.coordText.isEmpty)
        } else if model.isMoving {
            actionButton("Pause") {
                Task { await model.pauseRoute() }
            }
        } else if model.isPaused {
            actionButton("Continue") { model.startRoute() }
                .disabled(model.isBusy || model.selectedDeviceID == nil)
        } else {
            actionButton("Start Route") { model.startRoute() }
                .disabled(
                    model.isBusy || model.selectedDeviceID == nil
                        || model.waypoints.count < 2 || model.isCalculatingRoute
                )
        }
    }

    private func actionButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.large)
    }

    // MARK: Favoriten

    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionTitle("Favorites")
                Spacer()
                Button {
                    model.addFavorite()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("Save current location (name = search field)")
                .disabled(model.spot == nil)
            }
            VStack(spacing: 2) {
                ForEach(model.favorites) { favorite in
                    Button {
                        model.select(favorite.spot)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption)
                            Text(favorite.name).lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .contentShape(.capsule)
                    }
                    .buttonStyle(.plain)
                    .background(
                        model.spot == favorite.spot ? Color.accentColor.opacity(0.18) : .clear,
                        in: .capsule
                    )
                    .contextMenu {
                        Button("Delete", role: .destructive) { model.removeFavorite(favorite) }
                    }
                }
            }
        }
    }

    // MARK: Hilfe

    private var helpBar: some View {
        HStack {
            Button {
                showHelp.toggle()
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 18))
            }
            .buttonStyle(.borderless)
            .help("Help")
            .popover(isPresented: $showHelp, arrowEdge: .top) { helpContent }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var helpContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RePlace.")
                .font(.headline)
            Text("Sets a simulated GPS location on your iPhone. It applies to the whole device, so every app sees it.")
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 8) {
                helpRow("1.circle.fill", "Connect your iPhone, unlock it and turn on Developer Mode.")
                helpRow("2.circle.fill", "Pick a place: click the map, search an address or paste coordinates.")
                helpRow("3.circle.fill", "Press “Set Location”. For a moving route, switch to “Route”, add waypoints and press “Start Route”. “Pause” stops where you are, “Continue” goes on from there.")
                helpRow("arrow.uturn.backward.circle.fill", "“Reset” brings back your real location. The simulation also ends when the connection is lost.")
            }
            Divider()
            Text("Requires Xcode (uses Apple's devicectl). Only use this on your own devices and in line with the terms of the apps you use.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: 320)
    }

    private func helpRow(_ icon: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(Color.brandRed)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Status

    private var statusPill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(model.status)
                .font(.callout)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .capsule)
        .padding(.bottom, 20)
        .padding(.leading, 344)
    }

    private var statusColor: Color {
        if model.isPaused { return .orange }
        return model.isSimulating ? Color.brandRed : Color.secondary.opacity(0.5)
    }
}
