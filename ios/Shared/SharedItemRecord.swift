import Foundation

/// Everything the share extension saw for one share, for the spike's debug views.
/// Written by the extension to the App Group, read by the app's "Last shared item" screen.
nonisolated struct SharedItemRecord: Codable, Equatable, Sendable {
    struct Item: Codable, Equatable, Sendable {
        var title: String?
        var contentText: String?
        var userInfoKeys: [String]
        var attachments: [Attachment]
    }

    struct Attachment: Codable, Equatable, Sendable {
        var typeIdentifiers: [String]
        var suggestedName: String?
        var values: [Value]
    }

    /// What loading one type identifier produced, as text.
    struct Value: Codable, Equatable, Sendable {
        var typeIdentifier: String
        var kind: String          // "URL", "String", "Data", "MKMapItem", "error", …
        var text: String
    }

    /// A URL found in the share, any redirects followed, and what the parser made of it.
    struct Link: Codable, Equatable, Sendable {
        var original: String
        var redirects: [String]
        var final: String?
        var resolveError: String?
        var parsed: String
    }

    var receivedAt: Date
    var items: [Item]
    var links: [Link]
}

/// The App Group both targets share. Must match both .entitlements files.
nonisolated enum SharedItemStore {
    static let appGroup = "group.com.zappika.terra"
    private static let key = "lastSharedItem"

    static func save(_ record: SharedItemRecord) {
        guard let defaults = UserDefaults(suiteName: appGroup),
              let data = try? JSONEncoder().encode(record) else { return }
        defaults.set(data, forKey: key)
    }

    static func load() -> SharedItemRecord? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(SharedItemRecord.self, from: data)
    }

    static func clear() {
        UserDefaults(suiteName: appGroup)?.removeObject(forKey: key)
    }

    /// Whether the App Group container is reachable (false means the entitlement is missing).
    static var isAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup) != nil
    }
}

/// Follows HTTP redirects for a link and records each hop. Used for `maps.apple/p/…`.
nonisolated final class LinkResolver: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var hops: [String] = []

    /// Returns every redirect target in order and the final URL. If the last page is HTML
    /// with a canonical or og:url Apple Maps link, that's appended as a final hop.
    static func resolve(_ url: URL) async -> (redirects: [String], final: URL?, error: String?) {
        let resolver = LinkResolver()
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        let session = URLSession(configuration: config, delegate: resolver, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await session.data(for: request)
            var redirects = resolver.recorded
            var final = response.url
            if let html = String(data: data.prefix(200_000), encoding: .utf8),
               let pageLink = canonicalMapsLink(inHTML: html), pageLink != final {
                redirects.append(pageLink.absoluteString)
                final = pageLink
            }
            return (redirects, final, nil)
        } catch {
            return (resolver.recorded, nil, error.localizedDescription)
        }
    }

    /// The first maps.apple.com URL in a page's og:url or canonical link.
    static func canonicalMapsLink(inHTML html: String) -> URL? {
        let pattern = #"(?:property="og:url"|rel="canonical")[^>]*?(?:content|href)="(https://maps\.apple\.com/[^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html)
        else { return nil }
        let raw = String(html[range]).replacingOccurrences(of: "&amp;", with: "&")
        return URL(string: raw)
    }

    private var recorded: [String] { lock.withLock { hops } }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        // Completion-handler form: the async form crashes swift-frontend 6.4 in SILGen.
        if let url = request.url { lock.withLock { hops.append(url.absoluteString) } }
        completionHandler(request)
    }
}
