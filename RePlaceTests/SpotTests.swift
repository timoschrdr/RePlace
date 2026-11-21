import Testing
@testable import RePlace

@MainActor
struct SpotTests {
    @Test(arguments: [
        ("51.5, 7.2", 51.5, 7.2),
        (" 51.5 ; 7.2 ", 51.5, 7.2),
        ("51.5 7.2", 51.5, 7.2),
        ("51.5,7.2", 51.5, 7.2),
        ("51,5 7,2", 51.5, 7.2),          // decimal commas
        ("51,5, 7,2", 51.5, 7.2),
        ("-33.8688, 151.2093", -33.8688, 151.2093),
    ])
    func parsesCommonWritings(text: String, latitude: Double, longitude: Double) throws {
        let spot = try #require(Spot(parsing: text))
        #expect(spot.latitude == latitude)
        #expect(spot.longitude == longitude)
    }

    @Test(arguments: ["", "51.5", "a, b", "91, 7", "51, 181", "51,5,7,2", "1 2 3"])
    func rejectsInvalidText(text: String) {
        #expect(Spot(parsing: text) == nil)
    }

    @Test func textRoundTrips() throws {
        let spot = Spot(latitude: 1.5, longitude: -2.25)
        #expect(Spot(parsing: spot.text) == spot)
        #expect(Spot(latitude: 52.516275, longitude: 13.377704).text == "52.516275, 13.377704")
    }
}
