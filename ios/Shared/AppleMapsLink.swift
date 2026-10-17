import Foundation

/// Reads a destination out of an Apple Maps URL. Pure: no network, no MapKit.
///
/// Apple Maps share links carry a destination at most, never the route geometry the
/// user picked, so the app always calculates its own walking route from the result.
/// A bare search query (`q=` with no coordinate) is returned as `.searchQuery` so the
/// app can prefill search and let the user choose; it must never pick a place itself.
/// Expected cases are listed in ios/docs/apple-maps-share-spike.md.
nonisolated enum AppleMapsLink {
    struct LatLon: Equatable, Hashable, Sendable, Codable {
        var latitude: Double
        var longitude: Double
    }

    enum Destination: Equatable, Sendable {
        /// An exact point. `placeID` is the Apple Maps place identifier when the link has one.
        case coordinate(LatLon, name: String?, placeID: String?)
        /// A street address or place name to geocode.
        case address(String, name: String?)
        /// Only an Apple Maps place identifier (`place-id` / `auid`); resolve it with MapKit.
        case placeID(String, name: String?)
        /// Search text only. Show it in search; don't choose a result for the user.
        case searchQuery(String)
    }

    enum Result: Equatable, Sendable {
        case destination(Destination)
        /// A `maps.apple/p/…` short link: follow its redirect, then parse the final URL.
        case shortLink(URL)
        /// An Apple Maps URL without a usable destination, and why.
        case unusable(String)
        case notAppleMaps
    }

    static func parse(_ url: URL) -> Result {
        guard let host = url.host()?.lowercased() else { return .notAppleMaps }
        let path = url.path().lowercased()

        if host == "maps.apple" { return .shortLink(url) }
        guard host == "maps.apple.com" || host == "maps.apple.com." else { return .notAppleMaps }
        if path.hasPrefix("/p/") { return .shortLink(url) }

        let query = Query(url)
        let name = query["name"] ?? query["q"]

        // Directions: the destination is daddr (legacy) or destination (unified URLs).
        // Their own source / saddr is ignored; TERRA starts from the phone's location.
        if let destination = query["destination"] ?? query["daddr"] {
            if let point = latLon(destination) {
                return .destination(.coordinate(point, name: query["name"], placeID: query.placeID))
            }
            return .destination(.address(destination, name: query["name"]))
        }
        if path.hasPrefix("/directions") || query["saddr"] != nil || query["source"] != nil {
            return .unusable("Directions link without a destination")
        }

        // Places: an explicit coordinate beats everything else.
        if let point = (query["coordinate"] ?? query["ll"]).flatMap(latLon) {
            return .destination(.coordinate(point, name: name, placeID: query.placeID))
        }
        if let address = query["address"] {
            return .destination(.address(address, name: query["name"] ?? query["q"]))
        }
        if let placeID = query.placeID {
            return .destination(.placeID(placeID, name: name))
        }
        // `q` with a `sll`/`near`/`center` is still only a search near somewhere, not a place.
        if let text = query["q"] ?? query["query"] {
            if let point = latLon(text) {
                return .destination(.coordinate(point, name: nil, placeID: nil))
            }
            return .destination(.searchQuery(text))
        }
        return .unusable("No destination in link")
    }

    /// Parses shared text: the first Apple Maps link in it, if any.
    static func parse(text: String) -> Result {
        let urls = links(in: text)
        for url in urls {
            let result = parse(url)
            if result != .notAppleMaps { return result }
        }
        return .notAppleMaps
    }

    /// Every http(s) URL in a piece of text, in order.
    static func links(in text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return detector.matches(in: text, range: range).compactMap(\.url).filter { ["http", "https"].contains($0.scheme?.lowercased()) }
    }

    /// "41.403629,2.174356" (spaces allowed) → a valid coordinate, else nil.
    static func latLon(_ text: String) -> LatLon? {
        let parts = text.split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2,
              let lat = Double(parts[0]), let lon = Double(parts[1]),
              lat.isFinite, lon.isFinite,
              (-90...90).contains(lat), (-180...180).contains(lon)
        else { return nil }
        return LatLon(latitude: lat, longitude: lon)
    }

    /// Query items by lowercased name; empty values count as missing. `+` reads as a space.
    private struct Query {
        private var items: [String: String] = [:]

        init(_ url: URL) {
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            for item in components?.percentEncodedQueryItems ?? [] {
                let raw = (item.value ?? "").replacingOccurrences(of: "+", with: " ")
                let value = (raw.removingPercentEncoding ?? raw).trimmingCharacters(in: .whitespacesAndNewlines)
                let key = item.name.lowercased()
                if !value.isEmpty, items[key] == nil { items[key] = value }
            }
        }

        subscript(key: String) -> String? { items[key] }
        var placeID: String? { items["place-id"] ?? items["auid"] }
    }
}

extension AppleMapsLink.Destination {
    /// One line for debug screens.
    nonisolated var summary: String {
        switch self {
        case let .coordinate(p, name, placeID):
            var s = "Coordinate \(p.latitude), \(p.longitude)"
            if let name { s += " — \(name)" }
            if let placeID { s += " (place \(placeID))" }
            return s
        case let .address(address, name):
            return "Address “\(address)”" + (name.map { " — \($0)" } ?? "")
        case let .placeID(id, name):
            return "Place ID \(id)" + (name.map { " — \($0)" } ?? "")
        case let .searchQuery(text):
            return "Search only “\(text)” (user must choose)"
        }
    }
}

extension AppleMapsLink.Result {
    nonisolated var summary: String {
        switch self {
        case .destination(let d): d.summary
        case .shortLink(let url): "Short link, needs redirect: \(url.absoluteString)"
        case .unusable(let why): "Unusable: \(why)"
        case .notAppleMaps: "Not an Apple Maps link"
        }
    }
}
