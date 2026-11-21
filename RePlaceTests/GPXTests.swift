import Foundation
import Testing
@testable import RePlace

@MainActor
struct GPXTests {
    private let a = Spot(latitude: 51.1, longitude: 7.1)
    private let b = Spot(latitude: 51.2, longitude: 7.2)
    private let c = Spot(latitude: 51.3, longitude: 7.3)

    @Test func exportedRouteReadsBack() {
        let xml = GPX.document(name: "A & B <test>", waypoints: [a, b, c], path: [a, b, c])
        #expect(xml.contains("A &amp; B &lt;test&gt;"))
        #expect(GPX.points(in: Data(xml.utf8)) == [a, b, c])
    }

    @Test func exportedTrackIsAddedWhenItIsMoreDetailed() {
        let detailed = [a, Spot(latitude: 51.15, longitude: 7.15), b, c]
        let xml = GPX.document(name: "r", waypoints: [a, c], path: detailed)
        #expect(xml.contains("<trkpt"))
        // the route (the waypoints) wins when the file is read again
        #expect(GPX.points(in: Data(xml.utf8)) == [a, c])
    }

    @Test func prefersRouteThenTrackThenWaypoints() {
        let track = #"<gpx><trk><trkseg><trkpt lat="1" lon="1"/><trkpt lat="2" lon="2"/></trkseg></trk></gpx>"#
        #expect(GPX.points(in: Data(track.utf8)).count == 2)
        let waypoints = #"<gpx><wpt lat="3" lon="3"/><wpt lat="4" lon="4"/></gpx>"#
        #expect(GPX.points(in: Data(waypoints.utf8)).count == 2)
        let both = #"<gpx><wpt lat="9" lon="9"/><wpt lat="8" lon="8"/><rte><rtept lat="5" lon="5"/><rtept lat="6" lon="6"/></rte></gpx>"#
        #expect(GPX.points(in: Data(both.utf8)) == [Spot(latitude: 5, longitude: 5), Spot(latitude: 6, longitude: 6)])
    }

    @Test func rejectsBrokenFilesAndBadCoordinates() {
        #expect(GPX.points(in: Data("not xml".utf8)).isEmpty)
        #expect(GPX.points(in: Data(#"<gpx><rte><rtept lat="1" lon="1"/></rte></gpx>"#.utf8)).isEmpty)   // one point only
        let bad = #"<gpx><rte><rtept lat="95" lon="1"/><rtept lat="1" lon="1"/><rtept lat="2" lon="2"/></rte></gpx>"#
        #expect(GPX.points(in: Data(bad.utf8)).count == 2)                                                   // the invalid point is skipped
    }

    @Test func longTracksAreThinnedKeepingTheEnds() {
        let many = (0..<5000).map { Spot(latitude: 50 + Double($0) / 10_000, longitude: 7) }
        let thin = GPX.thinned(many, to: GPX.maxPoints)
        #expect(thin.count == GPX.maxPoints)
        #expect(thin.first == many.first && thin.last == many.last)
        #expect(GPX.thinned([a, b], to: 500) == [a, b])
    }
}
