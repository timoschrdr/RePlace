import Testing
@testable import RePlace

@MainActor
struct RoutePlannerTests {
    @Test(arguments: ["A43", "A 3", "A57", "AP-7", "M25", "E40", "I-95"])
    func motorwayNames(name: String) {
        #expect(RoutePlanner.isMotorway(name))
    }

    @Test(arguments: ["B1", "B226", "N7", "L551", "Cruismannstraße", "Am Hausacker", "Autobahn", "A", "A1234", "Alte Straße 5", ""])
    func otherRoadsAreNotMotorways(name: String) {
        #expect(!RoutePlanner.isMotorway(name))
    }
}
