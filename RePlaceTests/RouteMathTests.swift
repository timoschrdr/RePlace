import Foundation
import Testing
@testable import RePlace

@MainActor
struct RouteMathTests {
    /// A point `east`/`north` meters from a fixed origin, so distances are easy to reason about.
    private func point(_ east: Double, _ north: Double) -> Spot {
        let lat0 = 51.5, lon0 = 7.2
        return Spot(latitude: lat0 + north / 110_574, longitude: lon0 + east / (111_320 * cos(lat0 * .pi / 180)))
    }

    @Test func distanceToLine() {
        let line = [point(0, 0), point(1000, 0)]
        #expect(abs(RouteMath.distance(from: point(500, 100), to: line) - 100) < 0.5)
        #expect(abs(RouteMath.distance(from: point(1300, 400), to: line) - 500) < 0.5)   // beyond the end
        #expect(RouteMath.distance(from: point(500, 0), to: line) < 0.5)
        #expect(RouteMath.distance(from: point(0, 0), to: []) == .infinity)
    }

    @Test func spikesAreRemovedButCornersAndLongUTurnsStay() {
        let spike = [point(0, 0), point(100, 0), point(130, 0), point(100, 2), point(200, 0)]
        let cleaned = RouteMath.removingSpikes(from: spike)
        #expect(cleaned.count < spike.count)
        #expect(cleaned.first == spike.first && cleaned.last == spike.last)

        let corner = [point(0, 0), point(60, 0), point(60, 60)]
        #expect(RouteMath.removingSpikes(from: corner) == corner)
        let uTurn = [point(0, 0), point(500, 0), point(0, 10)]
        #expect(RouteMath.removingSpikes(from: uTurn) == uTurn)
    }

    @Test func stopsEndExactlyAtTheEnd() throws {
        let path = [point(0, 0), point(1000, 0), point(1000, 1000)]
        let stops = RouteMath.stops(along: path, every: 10)
        #expect(stops.first?.spot == path.first)
        #expect(stops.last?.spot == path.last)
        #expect(abs(try #require(stops.last).distance - RouteMath.length(of: path)) < 0.01)
    }

    @Test func remainderContinuesFromTheTravelledDistance() {
        let path = [point(0, 0), point(1000, 0), point(1000, 1000)]
        let total = RouteMath.length(of: path)
        let rest = RouteMath.remainder(of: path, after: 30)
        #expect(abs(RouteMath.length(of: rest) - (total - 30)) < 0.5)
        #expect(RouteMath.remainder(of: path, after: total + 50).count == 1)
    }
}
