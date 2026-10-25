import SwiftUI

/// Everything about a route: waypoints, speed, a summary with times, and the options.
/// Rarely needed details are folded away.
struct RouteSection: View {
    @Bindable var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            waypoints
            SpeedCard(model: model)
            if model.waypoints.count >= 2 {
                SummaryCard(model: model)
                    .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
            }
            Collapsible("Options") {
                VStack(spacing: 14) {
                    SwitchRow("Follow roads", isOn: $model.followRoads)
                    if model.followRoads, model.isDriving {
                        SwitchRow("Prefer motorways", isOn: $model.preferMotorways)
                            .transition(.opacity.combined(with: .scale(scale: 0.97, anchor: .top)))
                    }
                }
                .disabled(model.isRouteActive)
                .card()
                .animation(.smooth, value: model.followRoads)
                .animation(.smooth, value: model.isDriving)
            }
        }
        .animation(.smooth, value: model.waypoints.count >= 2)
    }

    @ViewBuilder
    private var waypoints: some View {
        if model.waypoints.isEmpty {
            Text("Click the map or pick a place to add waypoints. The iPhone moves along them in order and stops at the last one.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .card()
        } else {
            Collapsible("Waypoints") {
                HStack(spacing: 8) {
                    Text("\(model.waypoints.count)")
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .padding(.horizontal, 9)
                        .padding(.vertical, 3)
                        .background(Color.brand.opacity(0.18), in: .capsule)
                    Button {
                        withAnimation(.smooth) { model.undoWaypoints() }
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .buttonStyle(.circle)
                    .disabled(!model.canUndoWaypoints)
                    .help("Undo last waypoint (⌥⌘Z)")
                    Button {
                        withAnimation(.smooth) { model.clearWaypoints() }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.circle)
                    .disabled(model.isRouteActive)
                    .help("Remove all waypoints")
                }
            } content: {
                VStack(spacing: 6) {
                    ForEach(Array(model.waypoints.enumerated()), id: \.offset) { index, waypoint in
                        HStack(spacing: 10) {
                            Text("\(index + 1)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(LinearGradient.brand, in: .circle)
                            Text(waypoint.text)
                                .font(.system(.callout, design: .monospaced))
                            Spacer()
                            Button {
                                withAnimation(.smooth) { model.removeWaypoint(at: index) }
                            } label: {
                                Image(systemName: "xmark")
                            }
                            .buttonStyle(.circle)
                            .disabled(model.isRouteActive)
                            .help("Remove waypoint")
                        }
                        .padding(.leading, 10)
                        .padding(.trailing, 6)
                        .padding(.vertical, 5)
                        .background(Color.primary.opacity(0.06), in: .capsule)
                    }
                }
            }
        }
    }
}

/// The speed slider, its value and presets for walking, cycling, driving and the motorway.
private struct SpeedCard: View {
    @Bindable var model: AppModel

    private let presets: [(symbol: String, kmh: Double)] = [
        ("figure.walk", 5), ("bicycle", 15), ("car.fill", 50), ("speedometer", 120),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Speed")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(model.speedKmh)) km/h")
                    .font(.title3.weight(.semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.smooth, value: model.speedKmh)
            }
            Slider(value: sliderPosition, in: 0...1)
                .disabled(model.isMoving)
            HStack(spacing: 6) {
                ForEach(presets, id: \.kmh) { preset in
                    Button {
                        withAnimation(.smooth) { model.speedKmh = preset.kmh }
                    } label: {
                        Label("\(Int(preset.kmh))", systemImage: preset.symbol)
                    }
                    .buttonStyle(ChipButtonStyle(isSelected: model.speedKmh == preset.kmh))
                    .disabled(model.isMoving)
                    .help("\(Int(preset.kmh)) km/h")
                }
            }
        }
        .card()
    }

    /// The slider position (0...1) of the current speed, on the non-linear scale.
    private var sliderPosition: Binding<Double> {
        Binding(
            get: { SpeedScale.position(of: model.speedKmh) },
            set: { model.speedKmh = SpeedScale.speed(at: $0) }
        )
    }
}

/// Length, roads, start and end of the route, the current position and the progress.
private struct SummaryCard: View {
    let model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.isCalculatingRoute {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Calculating route…")
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
            } else {
                ValueRow("Route", "\(distanceText) · \(durationText)")
                if !model.routeRoads.isEmpty {
                    ValueRow("Via", model.routeRoads.prefix(2).joined(separator: ", "))
                }
            }

            TimelineView(.periodic(from: .now, by: 1)) { context in
                VStack(alignment: .leading, spacing: 8) {
                    if let started = model.routeStartedAt {
                        ValueRow("Start", started.stamp)
                    } else {
                        ValueRow("Start (now)", context.date.stamp)
                    }
                    if let finished = model.routeFinishedAt {
                        ValueRow("End", finished.stamp)
                    } else {
                        ValueRow("End (estimated)", model.estimatedArrival(startingAt: context.date).stamp)
                    }
                }
            }

            if model.isRouteActive, let position = model.movingPosition {
                ValueRow("Position", position.text)
            }
            if model.isPaused {
                Text("Paused. The end time is for continuing right now.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            if model.isRouteActive || model.progress > 0 {
                ProgressView(value: model.progress)
                    .tint(.brand)
                    .animation(.smooth, value: model.progress)
            }
        }
        .card()
        .animation(.smooth, value: model.isCalculatingRoute)
        .animation(.smooth, value: model.isRouteActive)
    }

    private var distanceText: String {
        Measurement(value: model.routeDistance, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }

    private var durationText: String {
        Duration.seconds(Int(model.routeDuration))
            .formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 2))
    }
}
