import Foundation

/// Maps the position of the speed slider to km/h and back. The slider is not linear: the lower
/// half covers walking, cycling and city speeds in fine steps, the upper half motorway speeds.
enum SpeedScale {
    static let minimum = 1.0
    static let maximum = 130.0

    /// Pairs of (slider position 0...1, km/h). Between them the scale is linear.
    private static let knots: [(position: Double, speed: Double)] = [
        (0, minimum), (0.25, 20), (0.6, 80), (1, maximum),
    ]

    /// The speed in whole km/h for a slider position between 0 and 1.
    static func speed(at position: Double) -> Double {
        let p = min(max(position, 0), 1)
        for (low, high) in zip(knots, knots.dropFirst()) where p <= high.position {
            let t = (p - low.position) / (high.position - low.position)
            return (low.speed + (high.speed - low.speed) * t).rounded()
        }
        return maximum
    }

    /// The slider position between 0 and 1 for a speed in km/h.
    static func position(of speed: Double) -> Double {
        let v = min(max(speed, minimum), maximum)
        for (low, high) in zip(knots, knots.dropFirst()) where v <= high.speed {
            let t = (v - low.speed) / (high.speed - low.speed)
            return low.position + (high.position - low.position) * t
        }
        return 1
    }
}
