import Testing
@testable import RePlace

@MainActor
struct SpeedScaleTests {
    @Test func endsAndKnots() {
        #expect(SpeedScale.speed(at: 0) == 1)
        #expect(SpeedScale.speed(at: 1) == 130)
        #expect(SpeedScale.speed(at: 0.25) == 20)
        #expect(SpeedScale.speed(at: 0.6) == 80)
        #expect(SpeedScale.speed(at: -3) == 1 && SpeedScale.speed(at: 9) == 130)
    }

    @Test func neverDecreasesAndRoundTrips() {
        var last = 0.0
        for i in 0...200 {
            let value = SpeedScale.speed(at: Double(i) / 200)
            #expect(value >= last)
            last = value
        }
        for kmh in 1...130 {
            #expect(SpeedScale.speed(at: SpeedScale.position(of: Double(kmh))) == Double(kmh))
        }
    }
}
