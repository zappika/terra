import Foundation

/// Checks a route is safe to hand to TERRA. Send stays disabled unless this passes.
nonisolated enum RouteValidator {
    /// TERRA's route buffer limit (draft; confirm with firmware).
    static let maxPoints = 2_000
    /// The path must begin this close to the start point.
    static let maxStartGapMeters = 150.0
    /// Walking routes end at the nearest path, which can be inside a park or courtyard.
    static let maxDestinationGapMeters = 300.0
    /// A simplified straight segment longer than this suggests scrambled points.
    static let maxSegmentMeters = 3_000.0

    enum Issue: Equatable, Sendable, CustomStringConvertible {
        case unsupportedVersion(Int)
        case tooFewPoints
        case tooManyPoints(Int)
        case invalidCoordinate(index: Int)
        case startTooFar(meters: Int)
        case destinationTooFar(meters: Int)
        case segmentTooLong(index: Int)
        case lengthMismatch
        case invalidTurn(index: Int)

        var description: String {
            switch self {
            case .unsupportedVersion(let v): "Route format version \(v) is not supported."
            case .tooFewPoints: "The route has no path to follow."
            case .tooManyPoints(let n): "The route has \(n) points, more than TERRA can store."
            case .invalidCoordinate(let i): "Route point \(i) is not a valid location."
            case .startTooFar(let m): "The route begins \(m) m from the start point."
            case .destinationTooFar(let m): "The route ends \(m) m from the destination."
            case .segmentTooLong(let i): "The route jumps unexpectedly after point \(i)."
            case .lengthMismatch: "The route's path does not match its distance."
            case .invalidTurn(let i): "Turn \(i) does not match the route's path."
            }
        }
    }

    static func validate(_ route: RouteV1) -> [Issue] {
        var issues: [Issue] = []
        if route.version != RouteV1.currentVersion { issues.append(.unsupportedVersion(route.version)) }

        let all = [route.start, route.destination] + route.points
        if let bad = all.firstIndex(where: { !isValid($0) }) {
            issues.append(.invalidCoordinate(index: max(bad - 2, 0)))
            return issues // Distances below are meaningless with broken coordinates.
        }

        let points = route.points
        guard points.count >= 2 else { return issues + [.tooFewPoints] }
        if points.count > maxPoints { issues.append(.tooManyPoints(points.count)) }

        let startGap = Geo.distance(points[0], route.start)
        if startGap > maxStartGapMeters { issues.append(.startTooFar(meters: Int(startGap))) }
        let endGap = Geo.distance(points[points.count - 1], route.destination)
        if endGap > maxDestinationGapMeters { issues.append(.destinationTooFar(meters: Int(endGap))) }

        for (i, (a, b)) in zip(points, points.dropFirst()).enumerated() where Geo.distance(a, b) > maxSegmentMeters {
            issues.append(.segmentTooLong(index: i))
            break
        }

        // Simplification only shortens the path a little; a large gap means points are out of order.
        let length = Geo.pathLength(points)
        if route.distanceMeters > 0, length > route.distanceMeters * 1.25 + 50 || length < route.distanceMeters * 0.75 - 50 {
            issues.append(.lengthMismatch)
        }

        var lastIndex = 0
        for (i, turn) in route.turns.enumerated() {
            if turn.pointIndex <= lastIndex || turn.pointIndex >= points.count - 1 || abs(turn.turnDegrees) > 180 {
                issues.append(.invalidTurn(index: i))
                break
            }
            lastIndex = turn.pointIndex
        }
        return issues
    }

    private static func isValid(_ c: Coordinate) -> Bool {
        c.lat.isFinite && c.lon.isFinite && (-90...90).contains(c.lat) && (-180...180).contains(c.lon)
            && !(c.lat == 0 && c.lon == 0)
    }
}
