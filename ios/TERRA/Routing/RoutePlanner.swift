import MapKit
import Observation

/// Owns the walk being prepared: destination, start point and the calculated route.
@Observable
final class RoutePlanner {
    enum Phase {
        case idle
        case calculating
        case ready(PlannedRoute)
        case failed(DirectionsFailure)
        /// Location is denied or unavailable, so the user must allow it or pick a start.
        case needsStart(LocationFailure)
    }

    private(set) var phase: Phase = .idle
    private(set) var destination: Place?
    var start: StartPoint = .currentLocation

    @ObservationIgnored let location: LocationProvider
    @ObservationIgnored private var task: Task<Void, Never>?

    init(location: LocationProvider) {
        self.location = location
    }

    var plannedRoute: PlannedRoute? {
        if case .ready(let planned) = phase { planned } else { nil }
    }

    var isActive: Bool {
        if case .idle = phase { false } else { true }
    }

    func choose(_ place: Place) {
        destination = place
        calculate()
    }

    func setStart(_ start: StartPoint) {
        self.start = start
        calculate()
    }

    func calculate() {
        guard let destination else { return }
        task?.cancel()
        phase = .calculating
        task = Task {
            let startCoordinate: CLLocationCoordinate2D
            switch start {
            case .place(let place):
                startCoordinate = place.coordinate
            case .currentLocation:
                do {
                    startCoordinate = try await location.currentLocation().coordinate
                } catch {
                    guard !Task.isCancelled else { return }
                    phase = .needsStart(error as? LocationFailure ?? .unavailable)
                    return
                }
            }
            do {
                let (mkRoute, route) = try await WalkingDirections.calculate(from: startCoordinate, to: destination)
                guard !Task.isCancelled else { return }
                phase = .ready(PlannedRoute(destination: destination, start: start, mkRoute: mkRoute, route: route))
            } catch {
                guard !Task.isCancelled else { return }
                phase = .failed(error as? DirectionsFailure ?? .other(error.localizedDescription))
            }
        }
    }

    func reset() {
        task?.cancel()
        destination = nil
        phase = .idle
    }
}
