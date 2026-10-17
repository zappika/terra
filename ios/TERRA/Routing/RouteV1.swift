import Foundation

/// The route TERRA stores and navigates. Independent of MapKit so firmware, tests and
/// fixtures can share it. Coordinates are WGS84 degrees rounded to 6 decimals (~0.1 m).
nonisolated struct RouteV1: Codable, Equatable, Sendable {
    static let currentVersion = 1

    var version: Int
    var id: UUID
    var name: String
    var start: Coordinate
    var destination: Coordinate
    /// Simplified path from start to destination, in walking order.
    var points: [Coordinate]
    /// Points where the walker must change direction, referencing `points`.
    var turns: [TurnMarker]
    var distanceMeters: Double
    var expectedTravelTimeSeconds: Double
    var createdAt: Date
}

nonisolated struct Coordinate: Codable, Equatable, Hashable, Sendable {
    var lat: Double
    var lon: Double

    init(lat: Double, lon: Double) {
        self.lat = Self.round(lat)
        self.lon = Self.round(lon)
    }

    private static func round(_ value: Double) -> Double {
        guard value.isFinite else { return value }
        return (value * 1_000_000).rounded() / 1_000_000
    }
}

nonisolated struct TurnMarker: Codable, Equatable, Sendable {
    /// Index into `RouteV1.points`.
    var pointIndex: Int
    /// Signed change of heading in degrees: negative is left, positive is right.
    var turnDegrees: Int
    /// Apple Maps instruction text, for display and debugging only.
    var instruction: String
    /// Distance along the route from the start to this turn.
    var distanceFromStartMeters: Double
}

nonisolated extension RouteV1 {
    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func jsonData(pretty: Bool = false) throws -> Data {
        let encoder = Self.makeEncoder()
        if pretty { encoder.outputFormatting.insert(.prettyPrinted) }
        return try encoder.encode(self)
    }
}
