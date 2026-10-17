import CoreLocation
import Observation

enum LocationFailure: Error {
    case denied
    case restricted
    case unavailable
}

/// Asks for location only when a route needs a start point, then returns one fix.
@Observable
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private(set) var authorization: CLAuthorizationStatus

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var authorizationWaiters: [CheckedContinuation<Void, Never>] = []
    @ObservationIgnored private var locationWaiters: [CheckedContinuation<CLLocation, Error>] = []

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    var isAuthorized: Bool {
        authorization == .authorizedWhenInUse || authorization == .authorizedAlways
    }

    func currentLocation() async throws(LocationFailure) -> CLLocation {
        if authorization == .notDetermined {
            await withCheckedContinuation { authorizationWaiters.append($0) ; manager.requestWhenInUseAuthorization() }
        }
        switch authorization {
        case .denied: throw .denied
        case .restricted: throw .restricted
        case .notDetermined: throw .denied
        default: break
        }

        if let recent = manager.location, recent.timestamp.timeIntervalSinceNow > -30, recent.horizontalAccuracy <= 50 {
            return recent
        }
        do {
            return try await withCheckedThrowingContinuation { continuation in
                locationWaiters.append(continuation)
                if locationWaiters.count == 1 { manager.requestLocation() }
            }
        } catch {
            throw .unavailable
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            authorization = status
            guard authorization != .notDetermined else { return }
            let waiters = authorizationWaiters
            authorizationWaiters = []
            waiters.forEach { $0.resume() }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        MainActor.assumeIsolated {
            guard let location = locations.last else { return }
            let waiters = locationWaiters
            locationWaiters = []
            waiters.forEach { $0.resume(returning: location) }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            // `requestLocation` gives up with `locationUnknown` when it can't get a fix.
            let waiters = locationWaiters
            locationWaiters = []
            waiters.forEach { $0.resume(throwing: error) }
        }
    }
}
