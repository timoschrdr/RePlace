import MapKit
import SwiftUI

extension Color {
    /// Akzentfarbe der App: ein warmes Rot ("Manipulation").
    static let brandRed = Color(red: 0.90, green: 0.16, blue: 0.20)
}

struct ContentView: View {
    @State private var model = AppModel()
    @State private var showHelp = false
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
                if let spot = model.spot {
                    Marker("Target", systemImage: "mappin", coordinate: spot.coordinate)
                        .tint(Color.brandRed)
                }
            }
            .mapControls {
                MapCompass()
                MapZoomStepper()
                MapScaleView()
            }
            .onTapGesture(coordinateSpace: .local) { point in
                if let coordinate = proxy.convert(point, from: .local) {
                    model.spot = Spot(latitude: coordinate.latitude, longitude: coordinate.longitude)
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
                    searchSection
                    coordinateSection
                    actionSection
                    favoritesSection
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
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
        }
    }

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
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.quaternary, in: .rect(cornerRadius: 10))

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
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(.quaternary.opacity(0.6), in: .rect(cornerRadius: 10))
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
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.quaternary, in: .rect(cornerRadius: 10))
            Text("Or click on the map.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var actionSection: some View {
        VStack(spacing: 8) {
            Button {
                model.applyCoordText()
                Task { await model.apply() }
            } label: {
                Text("Set Location").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(model.isBusy || model.selectedDeviceID == nil || model.coordText.isEmpty)

            Button {
                Task { await model.reset() }
            } label: {
                Text("Reset").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(model.isBusy || model.selectedDeviceID == nil)
        }
    }

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
                        model.spot = favorite.spot
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                                .font(.caption)
                            Text(favorite.name).lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .background(
                        model.spot == favorite.spot ? Color.accentColor.opacity(0.18) : .clear,
                        in: .rect(cornerRadius: 8)
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
                helpRow("3.circle.fill", "Press “Set Location”.")
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
                .fill(model.isSimulating ? Color.brandRed : Color.secondary.opacity(0.5))
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
}
