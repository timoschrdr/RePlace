import CoreLocation

/// Geometry helpers for walking a simulated device along a route.
nonisolated enum RouteMath {
    /// A sampled point together with its distance from the start of the sampled path.
    struct Stop: Equatable {
        var spot: Spot
        var distance: Double
    }

    /// Distance in meters between two spots.
    static func distance(_ a: Spot, _ b: Spot) -> Double {
        a.location.distance(from: b.location)
    }

    /// Total length of a path in meters.
    static func length(of path: [Spot]) -> Double {
        zip(path, path.dropFirst()).reduce(0) { $0 + distance($1.0, $1.1) }
    }

    /// The point `t` (0...1) of the way from `a` to `b`.
    static func interpolate(_ a: Spot, _ b: Spot, _ t: Double) -> Spot {
        Spot(
            latitude: a.latitude + (b.latitude - a.latitude) * t,
            longitude: a.longitude + (b.longitude - a.longitude) * t
        )
    }

    /// Points along `path`, one every `step` meters. The first stop is the start of the
    /// path and the last stop is always its exact end, so the device stops where the
    /// route ends.
    static func stops(along path: [Spot], every step: Double) -> [Stop] {
        guard let first = path.first, let last = path.last else { return [] }
        guard path.count > 1, step > 0 else { return [Stop(spot: first, distance: 0)] }

        var result = [Stop(spot: first, distance: 0)]
        var before = 0.0  // length of all segments before the current one
        var carry = 0.0   // meters travelled since the last stop
        for (a, b) in zip(path, path.dropFirst()) {
            let segment = distance(a, b)
            guard segment > 0 else { continue }
            var position = step - carry  // distance into this segment of the next stop
            while position <= segment {
                result.append(Stop(spot: interpolate(a, b, position / segment), distance: before + position))
                position += step
            }
            carry = segment - (position - step)
            before += segment
        }
        if result.last?.spot != last { result.append(Stop(spot: last, distance: before)) }
        return result
    }

    /// Distance in meters from `spot` to the closest point on the line `path`.
    static func distance(from spot: Spot, to path: [Spot]) -> Double {
        guard let first = path.first else { return .infinity }
        guard path.count > 1 else { return distance(spot, first) }
        // Flat local projection in meters around `spot`: precise enough for distances of a few km.
        let metersPerLat = 110_574.0
        let metersPerLon = 111_320.0 * cos(spot.latitude * .pi / 180)
        func xy(_ p: Spot) -> (Double, Double) {
            ((p.longitude - spot.longitude) * metersPerLon, (p.latitude - spot.latitude) * metersPerLat)
        }
        var best = Double.infinity
        for (a, b) in zip(path, path.dropFirst()) {
            let (ax, ay) = xy(a), (bx, by) = xy(b)
            let dx = bx - ax, dy = by - ay
            let lengthSquared = dx * dx + dy * dy
            let t = lengthSquared > 0 ? min(max(-(ax * dx + ay * dy) / lengthSquared, 0), 1) : 0
            best = min(best, ((ax + t * dx) * (ax + t * dx) + (ay + t * dy) * (ay + t * dy)).squareRoot())
        }
        return best
    }

    /// Removes short out-and-back spikes: a point where the path turns around sharply between
    /// two short segments (a detour to a waypoint that is not on the road, or a snapped end point).
    static func removingSpikes(from path: [Spot], maxLength: Double = 80) -> [Spot] {
        func isSpike(_ a: Spot, _ b: Spot, _ c: Spot) -> Bool {
            let lengthAB = distance(a, b), lengthBC = distance(b, c)
            guard lengthAB > 0, lengthBC > 0, lengthAB < maxLength, lengthBC < maxLength else { return false }
            let metersPerLon = 111_320.0 * cos(b.latitude * .pi / 180)
            let ux = (b.longitude - a.longitude) * metersPerLon, uy = (b.latitude - a.latitude) * 110_574.0
            let vx = (c.longitude - b.longitude) * metersPerLon, vy = (c.latitude - b.latitude) * 110_574.0
            let cosine = (ux * vx + uy * vy) / (lengthAB * lengthBC)
            return cosine < -0.94  // turns by more than about 160 degrees
        }
        var result: [Spot] = []
        for point in path {
            while result.count >= 2, isSpike(result[result.count - 2], result[result.count - 1], point) {
                result.removeLast()
            }
            result.append(point)
        }
        return result
    }

    /// The part of `path` that is left after `travelled` meters. The result starts at the
    /// exact point reached after that distance. Used to continue a paused route.
    static func remainder(of path: [Spot], after travelled: Double) -> [Spot] {
        guard travelled > 0, path.count > 1 else { return path }
        var covered = 0.0
        for index in 1..<path.count {
            let segment = distance(path[index - 1], path[index])
            if covered + segment >= travelled {
                let t = segment > 0 ? (travelled - covered) / segment : 0
                return [interpolate(path[index - 1], path[index], t)] + Array(path[index...])
            }
            covered += segment
        }
        return [path[path.count - 1]]
    }
}
