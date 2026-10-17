import Foundation

/// Small spherical-earth helpers; accurate to well under a metre at walking scales.
nonisolated enum Geo {
    static let earthRadius = 6_371_000.0

    static func distance(_ a: Coordinate, _ b: Coordinate) -> Double {
        let φ1 = a.lat * .pi / 180, φ2 = b.lat * .pi / 180
        let Δφ = (b.lat - a.lat) * .pi / 180
        let Δλ = (b.lon - a.lon) * .pi / 180
        let h = sin(Δφ / 2) * sin(Δφ / 2) + cos(φ1) * cos(φ2) * sin(Δλ / 2) * sin(Δλ / 2)
        return 2 * earthRadius * atan2(sqrt(h), sqrt(1 - h))
    }

    /// Initial bearing from `a` to `b`, degrees clockwise from north in 0..<360.
    static func bearing(_ a: Coordinate, _ b: Coordinate) -> Double {
        let φ1 = a.lat * .pi / 180, φ2 = b.lat * .pi / 180
        let Δλ = (b.lon - a.lon) * .pi / 180
        let y = sin(Δλ) * cos(φ2)
        let x = cos(φ1) * sin(φ2) - sin(φ1) * cos(φ2) * cos(Δλ)
        let θ = atan2(y, x) * 180 / .pi
        return (θ + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Signed smallest difference `to - from` in -180...180.
    static func headingChange(from: Double, to: Double) -> Double {
        var d = (to - from).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 }
        if d < -180 { d += 360 }
        return d
    }

    static func pathLength(_ points: [Coordinate]) -> Double {
        zip(points, points.dropFirst()).reduce(0) { $0 + distance($1.0, $1.1) }
    }

    /// Projects to local metres (equirectangular around `origin`).
    static func project(_ c: Coordinate, origin: Coordinate) -> (x: Double, y: Double) {
        let x = (c.lon - origin.lon) * .pi / 180 * earthRadius * cos(origin.lat * .pi / 180)
        let y = (c.lat - origin.lat) * .pi / 180 * earthRadius
        return (x, y)
    }
}
