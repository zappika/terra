import MapKit
import Observation

/// Live address and place suggestions as the user types, using `MKLocalSearchCompleter`.
@Observable
final class PlaceSearch: NSObject, MKLocalSearchCompleterDelegate {
    struct Suggestion: Identifiable {
        enum Source { case completion(MKLocalSearchCompletion), item(MKMapItem) }
        let id = UUID()
        var title: String
        var subtitle: String
        var source: Source
    }

    var query = "" {
        didSet {
            guard query != oldValue else { return }
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                suggestions = []
                completer.cancel()
            } else {
                completer.queryFragment = query
            }
        }
    }
    private(set) var suggestions: [Suggestion] = []
    private(set) var isResolving = false
    var errorMessage: String?

    @ObservationIgnored private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    /// Bias suggestions toward what the map is showing.
    func setRegion(_ region: MKCoordinateRegion) {
        completer.region = region
    }

    /// Return-key search: show full search results as suggestions instead of guessing one.
    func submit() async {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        request.region = completer.region
        do {
            let items = try await MKLocalSearch(request: request).start().mapItems
            suggestions = items.map {
                Suggestion(title: $0.name ?? text, subtitle: $0.placemark.title ?? "", source: .item($0))
            }
            if items.isEmpty { errorMessage = "No places match “\(text)”." }
        } catch {
            errorMessage = "Search isn't available right now. Check your connection and try again."
        }
    }

    /// Looks up the coordinate for a suggestion.
    func resolve(_ suggestion: Suggestion) async -> Place? {
        switch suggestion.source {
        case .item(let item):
            return Place(mapItem: item, name: suggestion.title, address: suggestion.subtitle)
        case .completion(let completion):
            isResolving = true
            defer { isResolving = false }
            do {
                let response = try await MKLocalSearch(request: MKLocalSearch.Request(completion: completion)).start()
                guard let item = response.mapItems.first else {
                    errorMessage = "Apple Maps couldn't find “\(suggestion.title)”. Try another result."
                    return nil
                }
                return Place(mapItem: item, name: suggestion.title, address: suggestion.subtitle)
            } catch {
                errorMessage = "Couldn't look up “\(suggestion.title)”. Check your connection and try again."
                return nil
            }
        }
    }

    func clear() {
        query = ""
        suggestions = []
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results.map {
            Suggestion(title: $0.title, subtitle: $0.subtitle, source: .completion($0))
        }
        MainActor.assumeIsolated { suggestions = results }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // Partial queries routinely fail; keep the previous suggestions.
    }
}
