import Foundation

/// Raw directions, already pulled out of MapKit (see `RouteBuilder+MapKit`).
nonisolated struct RawDirections: Sendable {
    struct Step: Sendable {
        var startCoordinate: Coordinate
        var instruction: String
    }

    var name: String
    var start: Coordinate
    var destination: Coordinate
    /// Full-resolution route geometry in walking order.
    var path: [Coordinate]
    var steps: [Step]
    var distanceMeters: Double
    var expectedTravelTimeSeconds: Double
}

/// Turns raw directions into a compact `RouteV1` without dropping turns or bends.
nonisolated enum RouteBuilder {
    /// Max distance (m) a dropped point may sit from the simplified line. Small enough to
    /// keep every street bend; large enough to drop the dense points along straight streets.
    static let toleranceMeters = 3.0
    /// How far before and after a turn we look to measure its angle.
    static let turnLookMeters = 15.0

    static func build(_ raw: RawDirections, id: UUID = UUID(), createdAt: Date = Date()) -> RouteV1 {
        let path = dedupe(raw.path)
        let cumulative = cumulativeDistances(path)

        // Pin every maneuver to a vertex of the full path, walking forward so order holds.
        var maneuvers: [(index: Int, instruction: String)] = []
        var searchFrom = 0
        for step in raw.steps where !step.instruction.isEmpty {
            guard let index = nearestIndex(to: step.startCoordinate, in: path, from: searchFrom) else { continue }
            searchFrom = index
            // The first and last vertices are the start and arrival, not turns.
            guard index > 0, index < path.count - 1 else { continue }
            if maneuvers.last?.index == index { continue }
            maneuvers.append((index, step.instruction))
        }

        var keep = Set([0, max(path.count - 1, 0)])
        keep.formUnion(maneuvers.map(\.index))
        let kept = simplify(path, forced: keep)

        let remap = Dictionary(uniqueKeysWithValues: kept.enumerated().map { ($1, $0) })
        let turns = maneuvers.compactMap { m -> TurnMarker? in
            guard let newIndex = remap[m.index] else { return nil }
            return TurnMarker(
                pointIndex: newIndex,
                turnDegrees: Int(turnAngle(at: m.index, path: path, cumulative: cumulative).rounded()),
                instruction: m.instruction,
                distanceFromStartMeters: (cumulative[m.index] * 10).rounded() / 10
            )
        }

        return RouteV1(
            version: RouteV1.currentVersion,
            id: id,
            name: raw.name,
            start: raw.start,
            destination: raw.destination,
            points: kept.map { path[$0] },
            turns: turns,
            distanceMeters: raw.distanceMeters.rounded(),
            expectedTravelTimeSeconds: raw.expectedTravelTimeSeconds.rounded(),
            createdAt: createdAt
        )
    }

    // MARK: - Geometry

    static func dedupe(_ path: [Coordinate]) -> [Coordinate] {
        var out: [Coordinate] = []
        for c in path where out.last != c { out.append(c) }
        return out
    }

    static func cumulativeDistances(_ path: [Coordinate]) -> [Double] {
        var out = [0.0]
        for (a, b) in zip(path, path.dropFirst()) { out.append(out.last! + Geo.distance(a, b)) }
        return out
    }

    static func nearestIndex(to c: Coordinate, in path: [Coordinate], from start: Int) -> Int? {
        guard start < path.count else { return nil }
        var best: (index: Int, d: Double)?
        for i in start..<path.count {
            let d = Geo.distance(c, path[i])
            if best == nil || d < best!.d { best = (i, d) }
        }
        return best?.index
    }

    /// Douglas–Peucker run separately between forced vertices, so forced ones always stay.
    /// Returns the kept indices in ascending order.
    static func simplify(_ path: [Coordinate], forced: Set<Int>) -> [Int] {
        guard path.count > 2 else { return Array(path.indices) }
        let anchors = forced.filter { path.indices.contains($0) }.sorted()
        var keep = Set(anchors)
        for (a, b) in zip(anchors, anchors.dropFirst()) {
            douglasPeucker(path, a, b, &keep)
        }
        return keep.sorted()
    }

    private static func douglasPeucker(_ path: [Coordinate], _ first: Int, _ last: Int, _ keep: inout Set<Int>) {
        guard last > first + 1 else { return }
        let origin = path[first]
        let a = Geo.project(path[first], origin: origin)
        let b = Geo.project(path[last], origin: origin)
        var worst = (index: first, d: 0.0)
        for i in (first + 1)..<last {
            let p = Geo.project(path[i], origin: origin)
            let d = segmentDistance(p, a, b)
            if d > worst.d { worst = (i, d) }
        }
        if worst.d > toleranceMeters {
            keep.insert(worst.index)
            douglasPeucker(path, first, worst.index, &keep)
            douglasPeucker(path, worst.index, last, &keep)
        }
    }

    private static func segmentDistance(_ p: (x: Double, y: Double), _ a: (x: Double, y: Double), _ b: (x: Double, y: Double)) -> Double {
        let dx = b.x - a.x, dy = b.y - a.y
        let len2 = dx * dx + dy * dy
        guard len2 > 0 else { return hypot(p.x - a.x, p.y - a.y) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / len2))
        return hypot(p.x - (a.x + t * dx), p.y - (a.y + t * dy))
    }

    /// Heading change at `index`, measured between points about `turnLookMeters` either side.
    static func turnAngle(at index: Int, path: [Coordinate], cumulative: [Double]) -> Double {
        guard index > 0, index < path.count - 1 else { return 0 }
        var before = index - 1
        while before > 0, cumulative[index] - cumulative[before] < turnLookMeters { before -= 1 }
        var after = index + 1
        while after < path.count - 1, cumulative[after] - cumulative[index] < turnLookMeters { after += 1 }
        return Geo.headingChange(
            from: Geo.bearing(path[before], path[index]),
            to: Geo.bearing(path[index], path[after])
        )
    }
}
