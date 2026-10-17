import Foundation
import MapKit
import Testing
@testable import TERRA

/// The repo fixture, bundled into the test target from ios/Fixtures.
func loadFixture() throws -> RouteV1 {
    let url = try #require(Bundle(for: FixtureToken.self).url(forResource: "sample-route-v1", withExtension: "json"))
    return try RouteV1.makeDecoder().decode(RouteV1.self, from: Data(contentsOf: url))
}
final class FixtureToken {}

struct FixtureTests {
    @Test func fixtureDecodesAndValidates() throws {
        let route = try loadFixture()
        #expect(route.version == 1)
        #expect(route.points.count >= 2)
        #expect(!route.turns.isEmpty)
        #expect(RouteValidator.validate(route).isEmpty)
    }

    @Test func fixtureRoundTripsThroughJSON() throws {
        let route = try loadFixture()
        let decoded = try RouteV1.makeDecoder().decode(RouteV1.self, from: route.jsonData())
        #expect(decoded == route)
    }

    /// Regenerates ios/Fixtures/sample-route-v1.json from a real Apple Maps walking route.
    /// Runs only when TERRA_WRITE_FIXTURE is set (see ios/README.md).
    @Test(.enabled(if: ProcessInfo.processInfo.environment["TERRA_WRITE_FIXTURE"] != nil))
    func writeFixtureFromAppleMaps() async throws {
        let path = try #require(ProcessInfo.processInfo.environment["TERRA_WRITE_FIXTURE"])
        let start = CLLocationCoordinate2D(latitude: 41.387015, longitude: 2.170047)        // Plaça de Catalunya
        let destination = Place(
            mapItem: MKMapItem(placemark: MKPlacemark(coordinate: .init(latitude: 41.403629, longitude: 2.174356))),
            name: "Sagrada Família",
            address: "Carrer de Mallorca, 401, 08013 Barcelona"
        )
        let (mkRoute, _) = try await WalkingDirections.calculate(from: start, to: destination)
        let route = RouteBuilder.build(
            RawDirections(mkRoute, name: destination.name, start: start, destination: destination.coordinate),
            id: UUID(uuidString: "7E2A0C1E-5B8D-4F43-9A51-3C0F6D2B9E11")!,
            createdAt: Date(timeIntervalSince1970: 1_792_000_000)
        )
        #expect(RouteValidator.validate(route).isEmpty)
        try route.jsonData(pretty: true).write(to: URL(fileURLWithPath: path))
        print("wrote \(path): \(mkRoute.polyline.pointCount) → \(route.points.count) points, \(route.turns.count) turns")
    }
}

struct BuilderTests {
    /// An L-shaped street walk: 300 m north, then 200 m east, sampled every ~5 m.
    func lWalk() -> RawDirections {
        let origin = Coordinate(lat: 41.39, lon: 2.17)
        let mPerDegLat = 111_195.0
        let mPerDegLon = mPerDegLat * cos(origin.lat * .pi / 180)
        var path: [Coordinate] = []
        for m in stride(from: 0.0, through: 300, by: 5) { path.append(Coordinate(lat: origin.lat + m / mPerDegLat, lon: origin.lon)) }
        let corner = path.last!
        for m in stride(from: 5.0, through: 200, by: 5) { path.append(Coordinate(lat: corner.lat, lon: corner.lon + m / mPerDegLon)) }
        return RawDirections(
            name: "Test", start: path.first!, destination: path.last!, path: path,
            steps: [
                .init(startCoordinate: path.first!, instruction: ""),
                .init(startCoordinate: corner, instruction: "Turn right onto Test Street"),
                .init(startCoordinate: path.last!, instruction: "Arrive at the destination"),
            ],
            distanceMeters: 500, expectedTravelTimeSeconds: 360
        )
    }

    @Test func keepsTheCornerAndDropsStraightPoints() {
        let route = RouteBuilder.build(lWalk())
        #expect(route.points.count == 3)
        #expect(route.turns.count == 1)
        let turn = route.turns[0]
        #expect(turn.pointIndex == 1)
        #expect((80...100).contains(turn.turnDegrees)) // right turn
        #expect(abs(turn.distanceFromStartMeters - 300) < 2)
        #expect(RouteValidator.validate(route).isEmpty)
    }

    @Test func keepsBendsWithoutManeuvers() {
        var raw = lWalk()
        raw.steps = [] // No instructions at all: the bend must still survive simplification.
        let route = RouteBuilder.build(raw)
        #expect(route.points.count == 3)
        #expect(route.turns.isEmpty)
    }

    @Test func keepsEveryFixtureTurnOnThePath() throws {
        let route = try loadFixture()
        for turn in route.turns {
            #expect(route.points.indices.contains(turn.pointIndex))
        }
    }
}

struct ValidatorTests {
    @Test func rejectsBrokenRoutes() throws {
        var route = try loadFixture()
        route.points[3] = Coordinate(lat: .nan, lon: 2.17)
        #expect(RouteValidator.validate(route).contains(.invalidCoordinate(index: 3)))

        route = try loadFixture()
        route.points = [route.points[0]]
        #expect(RouteValidator.validate(route).contains(.tooFewPoints))

        route = try loadFixture()
        route.destination = Coordinate(lat: route.destination.lat + 0.01, lon: route.destination.lon)
        #expect(RouteValidator.validate(route).contains { if case .destinationTooFar = $0 { true } else { false } })

        route = try loadFixture()
        route.points.reverse()
        #expect(!RouteValidator.validate(route).isEmpty)
    }
}
