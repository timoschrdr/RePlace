import MapKit
import SwiftUI

/// The map with the target, the route and the moving position. A click sets the target or
/// adds a waypoint, depending on the mode; waypoints can be dragged.
struct MapPane: View {
    let model: AppModel
    @Binding var position: MapCameraPosition
    /// The part of the world that is currently visible.
    @Binding var visibleRegion: MKCoordinateRegion?
    @State private var draggedWaypoint: Int?

    var body: some View {
        MapReader { proxy in
            Map(position: $position) {
                if model.mode == .point, let spot = model.spot {
                    Marker("Target", systemImage: "mappin", coordinate: spot.coordinate)
                        .tint(Color.brand)
                }
                if model.routePath.count > 1 {
                    // A light casing under the colored line keeps it readable on every map color.
                    MapPolyline(coordinates: model.routePath.map(\.coordinate))
                        .stroke(.white.opacity(0.55), lineWidth: 9)
                    MapPolyline(coordinates: model.routePath.map(\.coordinate))
                        .stroke(Color.brand, lineWidth: 5)
                }
                ForEach(Array(model.waypoints.enumerated()), id: \.offset) { index, waypoint in
                    Annotation("", coordinate: waypoint.coordinate) {
                        WaypointPin(number: index + 1, isLifted: draggedWaypoint == index)
                            .gesture(drag(index, proxy: proxy), isEnabled: !model.isRouteActive)
                    }
                }
                if let current = model.movingPosition {
                    Annotation("", coordinate: current.coordinate) {
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
            .onMapCameraChange(frequency: .onEnd) { context in
                visibleRegion = context.region
            }
            .onTapGesture(coordinateSpace: .local) { point in
                if let coordinate = proxy.convert(point, from: .local) {
                    model.mapTapped(Spot(latitude: coordinate.latitude, longitude: coordinate.longitude))
                }
            }
        }
    }

    /// Dragging a pin moves the waypoint; the whole drag is one undo step.
    private func drag(_ index: Int, proxy: MapProxy) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .global)
            .onChanged { value in
                if draggedWaypoint != index {
                    draggedWaypoint = index
                    model.beginMovingWaypoint()
                }
                if let coordinate = proxy.convert(value.location, from: .global) {
                    model.moveWaypoint(at: index, to: Spot(latitude: coordinate.latitude, longitude: coordinate.longitude))
                }
            }
            .onEnded { _ in draggedWaypoint = nil }
    }
}

/// A numbered pin. It lifts a little while it is dragged.
private struct WaypointPin: View {
    let number: Int
    let isLifted: Bool

    var body: some View {
        Text("\(number)")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(LinearGradient.brand, in: .circle)
            .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
            .shadow(color: .black.opacity(isLifted ? 0.4 : 0.25), radius: isLifted ? 8 : 3, y: isLifted ? 6 : 2)
            .scaleEffect(isLifted ? 1.18 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLifted)
    }
}
