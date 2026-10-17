import MapKit

enum DirectionsFailure: Error, Equatable {
    case noWalkingRoute
    case network
    case emptyRoute
    case invalid([RouteValidator.Issue])
    case other(String)

    var title: String {
        switch self {
        case .noWalkingRoute: "No walking route"
        case .network: "Couldn't reach Apple Maps"
        case .emptyRoute: "No walking route"
        case .invalid: "Route can't be sent"
        case .other: "Couldn't calculate a route"
        }
    }

    var message: String {
        switch self {
        case .noWalkingRoute: "Apple Maps couldn't find a way to walk there. Try a different destination."
        case .network: "Check your internet connection and try again."
        case .emptyRoute: "Apple Maps returned a route without a path. Try again or choose another destination."
        case .invalid(let issues): issues.map(\.description).joined(separator: "\n")
        case .other(let text): text
        }
    }
}

/// A calculated walking route, both as MapKit returned it and as TERRA would store it.
struct PlannedRoute {
    var destination: Place
    var start: StartPoint
    var mkRoute: MKRoute
    var route: RouteV1
}

enum WalkingDirections {
    static func calculate(from start: CLLocationCoordinate2D, to destination: Place) async throws(DirectionsFailure) -> (MKRoute, RouteV1) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = destination.mapItem
        request.transportType = .walking
        request.requestsAlternateRoutes = false

        let response: MKDirections.Response
        do {
            response = try await MKDirections(request: request).calculate()
        } catch {
            throw failure(for: error)
        }
        guard let mkRoute = response.routes.first, mkRoute.polyline.pointCount >= 2 else {
            throw .emptyRoute
        }

        let route = RouteBuilder.build(RawDirections(mkRoute, name: destination.name, start: start, destination: destination.coordinate))
        let issues = RouteValidator.validate(route)
        guard issues.isEmpty else { throw .invalid(issues) }
        return (mkRoute, route)
    }

    private static func failure(for error: Error) -> DirectionsFailure {
        if let mk = error as? MKError {
            switch mk.code {
            case .directionsNotFound, .placemarkNotFound: return .noWalkingRoute
            case .serverFailure, .loadingThrottled: return .network
            default: break
            }
        }
        if (error as NSError).domain == NSURLErrorDomain { return .network }
        return .other(error.localizedDescription)
    }
}

extension RawDirections {
    init(_ route: MKRoute, name: String, start: CLLocationCoordinate2D, destination: CLLocationCoordinate2D) {
        self.init(
            name: name,
            start: Coordinate(start),
            destination: Coordinate(destination),
            path: route.polyline.coordinates.map(Coordinate.init),
            steps: route.steps.compactMap { step in
                guard let first = step.polyline.coordinates.first else { return nil }
                return Step(startCoordinate: Coordinate(first), instruction: step.instructions)
            },
            distanceMeters: route.distance,
            expectedTravelTimeSeconds: route.expectedTravelTime
        )
    }
}

extension Coordinate {
    init(_ c: CLLocationCoordinate2D) { self.init(lat: c.latitude, lon: c.longitude) }
    var clCoordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lon) }
}

extension MKMultiPoint {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}
