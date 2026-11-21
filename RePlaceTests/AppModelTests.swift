import Foundation
import Testing
@testable import RePlace

/// Tests of the model without a device and without network: roads are off, no device is chosen.
/// Preferences that live only in memory, so the tests never write a file into the user's
/// Library (a file-backed suite leaves an empty file behind).
final class MemoryDefaults: UserDefaults {
    private var store: [String: Any] = [:]

    init() { super.init(suiteName: "memory-\(UUID().uuidString)")! }

    override func object(forKey defaultName: String) -> Any? { store[defaultName] }
    override func data(forKey defaultName: String) -> Data? { store[defaultName] as? Data }
    override func set(_ value: Any?, forKey defaultName: String) { store[defaultName] = value }
    override func removeObject(forKey defaultName: String) { store[defaultName] = nil }
}

@MainActor
struct AppModelTests {
    private let defaults = MemoryDefaults()
    private let a = Spot(latitude: 51.0, longitude: 7.0)
    private let b = Spot(latitude: 51.1, longitude: 7.1)
    private let c = Spot(latitude: 51.2, longitude: 7.2)

    private func makeModel() -> AppModel {
        let model = AppModel(defaults: defaults)
        model.followRoads = false
        return model
    }

    // MARK: waypoints

    @Test func undoWalksBackThroughEveryChange() {
        let model = makeModel()
        #expect(!model.canUndoWaypoints)
        model.addWaypoint(a); model.addWaypoint(b); model.addWaypoint(c)
        model.undoWaypoints()
        #expect(model.waypoints == [a, b])
        model.undoWaypoints(); model.undoWaypoints()
        #expect(model.waypoints.isEmpty && !model.canUndoWaypoints)
        model.undoWaypoints()
        #expect(model.waypoints.isEmpty)
    }

    @Test func aDragIsOneUndoStep() {
        let model = makeModel()
        model.addWaypoint(a); model.addWaypoint(b); model.addWaypoint(c)
        model.beginMovingWaypoint()
        for i in 1...10 { model.moveWaypoint(at: 1, to: Spot(latitude: 51.1 + Double(i) / 100, longitude: 7.1)) }
        #expect(model.waypoints[1] != b)
        model.undoWaypoints()
        #expect(model.waypoints == [a, b, c])
        model.moveWaypoint(at: 9, to: a)                      // out of range: ignored
        #expect(model.waypoints == [a, b, c])
    }

    @Test func removeAndClearCanBeUndone() {
        let model = makeModel()
        model.addWaypoint(a); model.addWaypoint(b); model.addWaypoint(c)
        model.removeWaypoint(at: 0)
        #expect(model.waypoints == [b, c])
        model.undoWaypoints()
        model.clearWaypoints(); model.clearWaypoints()        // the second clear records nothing
        model.undoWaypoints()
        #expect(model.waypoints == [a, b, c])
    }

    // MARK: places and coordinates

    @Test func coordinateTextIsAppliedAndNormalised() {
        let model = makeModel()
        model.coordText = "52,5 13,4"                         // German writing
        model.applyCoordText()
        #expect(model.spot == Spot(latitude: 52.5, longitude: 13.4))
        #expect(model.coordText == "52.500000, 13.400000")
    }

    @Test func invalidCoordinatesKeepTheOldPlaceAndSendNothing() async {
        let model = makeModel()
        model.selectedDeviceID = "no-such-device"             // would fail if anything were sent
        model.spot = a
        model.coordText = "nonsense"
        await model.apply()
        #expect(model.spot == a)
        #expect(!model.isSimulating)
        #expect(model.lastSetAt == nil)
        #expect(model.status.contains("Invalid"))
    }

    @Test func favoritesGetTheNameOfTheChosenPlace() {
        let model = makeModel()
        model.select(a, name: "Home")
        model.addFavorite()
        #expect(model.favorites.last?.name == "Home")
        model.mapTapped(b)                                      // a click on the map has no name
        model.mode = .point
        model.spot = b
        model.addFavorite()
        #expect(model.favorites.last?.name == b.text)
    }

    // MARK: main action

    @Test func mainActionFollowsTheModeAndTheState() {
        let model = makeModel()
        #expect(model.primaryAction == .setLocation && !model.isPrimaryActionEnabled)
        model.mode = .route
        #expect(model.primaryAction == .startRoute && !model.isPrimaryActionEnabled && !model.canReset)
        model.performPrimaryAction()
        #expect(!model.isMoving)
        model.isMoving = true
        #expect(model.primaryAction == .pause && model.isPrimaryActionEnabled)
        model.isMoving = false; model.isPaused = true
        #expect(model.primaryAction == .resume)
    }

    // MARK: estimates

    @Test func estimatedArrivalIsLengthOverSpeed() {
        let model = makeModel()
        model.speedKmh = 36                                     // 10 m/s
        model.addWaypoint(a); model.addWaypoint(b)
        let seconds = model.routeDistance / 10
        let now = Date()
        #expect(abs(model.estimatedArrival(startingAt: now).timeIntervalSince(now) - seconds) < 0.01)
        #expect(model.isDriving)
        model.speedKmh = 5
        #expect(!model.isDriving)
    }

    // MARK: saved routes, import, persistence

    @Test func savedRoutesCanBeLoadedAndDeleted() {
        let model = makeModel()
        model.speedKmh = 50
        model.addWaypoint(a); model.addWaypoint(c)
        model.saveRoute()
        #expect(model.savedRoutes.count == 1)
        model.clearWaypoints(); model.speedKmh = 5
        model.load(model.savedRoutes[0])
        #expect(model.waypoints == [a, c] && model.speedKmh == 50 && model.mode == .route)
        model.removeSavedRoute(model.savedRoutes[0])
        #expect(model.savedRoutes.isEmpty)
    }

    @Test func importReplacesTheRouteAndTurnsOffRoadsForLongTracks() {
        let model = makeModel()
        #expect(!model.importRoute([a]))                        // too few points
        #expect(model.importRoute([a, b, c]))
        #expect(model.waypoints == [a, b, c] && model.mode == .route)
        model.undoWaypoints()
        #expect(model.waypoints.isEmpty)

        model.followRoads = true
        let track = (0..<100).map { Spot(latitude: 51 + Double($0) / 1000, longitude: 7) }
        #expect(model.importRoute(track))
        #expect(!model.followRoads)
    }

    @Test func theSessionIsRemembered() {
        let first = makeModel()
        first.mode = .route
        first.speedKmh = 70
        first.preferMotorways = false
        first.addWaypoint(a); first.addWaypoint(b)
        first.saveRoute()
        first.addFavorite()                                     // no spot: nothing happens, still fine

        let second = AppModel(defaults: defaults)
        #expect(second.mode == .route && second.speedKmh == 70 && !second.preferMotorways)
        #expect(second.waypoints == [a, b])
        #expect(!second.followRoads)
        #expect(second.savedRoutes.count == 1)
        #expect(second.routePath == [a, b])                     // straight lines, as roads are off
    }

    @Test func aLocationFromAnEarlierLaunchIsReportedHonestly() {
        defaults.set(Date(), forKey: "lastSetAt")
        let model = AppModel(defaults: defaults)
        #expect(model.isSimulating)
        #expect(model.status.contains("may still be active") || model.status.contains("womöglich"))
    }

    @Test func theMapShowsTheRouteOnlyInRouteMode() {
        // The map reads `mode`, `routePath`, `waypoints` and `movingPosition`; the route data must
        // survive a switch to "Point" so that it is there again when "Route" is chosen.
        let model = makeModel()
        model.mode = .route
        model.addWaypoint(Spot(latitude: 51, longitude: 7)); model.addWaypoint(Spot(latitude: 51.1, longitude: 7.1))
        model.mode = .point
        #expect(model.waypoints.count == 2 && model.routePath.count == 2)
        model.mode = .route
        #expect(model.waypoints.count == 2 && model.routePath.count == 2)
    }
}
