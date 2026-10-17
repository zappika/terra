import MapKit
import UniformTypeIdentifiers

/// Spike step: records every item provider type and loaded value in a share, plus every
/// URL in it (with short-link redirects followed) and what `AppleMapsLink` makes of it.
/// Nothing here picks a destination or starts routing.
enum ShareInspector {
    static func inspect(_ extensionItems: [NSExtensionItem]) async -> SharedItemRecord {
        var items: [SharedItemRecord.Item] = []
        for item in extensionItems {
            var attachments: [SharedItemRecord.Attachment] = []
            for provider in item.attachments ?? [] {
                attachments.append(await inspect(provider))
            }
            items.append(.init(
                title: item.attributedTitle?.string,
                contentText: item.attributedContentText?.string,
                userInfoKeys: (item.userInfo ?? [:]).keys.map { "\($0)" }.sorted(),
                attachments: attachments
            ))
        }

        var seen = Set<String>()
        var urls: [URL] = []
        for text in candidateTexts(items) {
            for url in AppleMapsLink.links(in: text) where seen.insert(url.absoluteString).inserted {
                urls.append(url)
            }
        }
        var links: [SharedItemRecord.Link] = []
        for url in urls { links.append(await resolveAndParse(url)) }
        return SharedItemRecord(receivedAt: .now, items: items, links: links)
    }

    static func resolveAndParse(_ url: URL) async -> SharedItemRecord.Link {
        var link = SharedItemRecord.Link(original: url.absoluteString, redirects: [], final: nil, resolveError: nil,
                                         parsed: AppleMapsLink.parse(url).summary)
        guard case .shortLink = AppleMapsLink.parse(url) else { return link }
        let resolved = await LinkResolver.resolve(url)
        link.redirects = resolved.redirects
        link.final = resolved.final?.absoluteString
        link.resolveError = resolved.error
        if let final = resolved.final {
            link.parsed = "After redirect: " + AppleMapsLink.parse(final).summary
        }
        return link
    }

    /// Text that might hold URLs: loaded URL/String values, titles and content text.
    private static func candidateTexts(_ items: [SharedItemRecord.Item]) -> [String] {
        var texts: [String] = []
        for item in items {
            for attachment in item.attachments {
                for value in attachment.values where ["URL", "String", "NSAttributedString", "MKMapItem"].contains(value.kind) {
                    texts.append(value.text)
                }
            }
            texts += [item.title, item.contentText].compactMap { $0 }
        }
        return texts
    }

    private static func inspect(_ provider: NSItemProvider) async -> SharedItemRecord.Attachment {
        var values: [SharedItemRecord.Value] = []
        for type in provider.registeredTypeIdentifiers {
            values.append(await loadItem(provider, type))
        }
        if provider.canLoadObject(ofClass: MKMapItem.self) {
            values.append(await loadMapItem(provider))
        }
        return .init(typeIdentifiers: provider.registeredTypeIdentifiers, suggestedName: provider.suggestedName, values: values)
    }

    private static func loadItem(_ provider: NSItemProvider, _ type: String) async -> SharedItemRecord.Value {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type, options: nil) { item, error in
                continuation.resume(returning: describe(item, error, type: type))
            }
        }
    }

    private static func loadMapItem(_ provider: NSItemProvider) async -> SharedItemRecord.Value {
        await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: MKMapItem.self) { object, error in
                let text: String
                if let mapItem = object as? MKMapItem {
                    text = describe(mapItem)
                } else {
                    text = error?.localizedDescription ?? "nil"
                }
                continuation.resume(returning: .init(typeIdentifier: "loadObject(MKMapItem)", kind: object == nil ? "error" : "MKMapItem", text: text))
            }
        }
    }

    nonisolated private static func describe(_ item: (any NSSecureCoding)?, _ error: (any Error)?, type: String) -> SharedItemRecord.Value {
        if let error { return .init(typeIdentifier: type, kind: "error", text: error.localizedDescription) }
        switch item {
        case let url as URL:
            return .init(typeIdentifier: type, kind: "URL", text: url.isFileURL ? fileSummary(url) : url.absoluteString)
        case let string as String:
            return .init(typeIdentifier: type, kind: "String", text: string)
        case let attributed as NSAttributedString:
            return .init(typeIdentifier: type, kind: "NSAttributedString", text: attributed.string)
        case let data as Data:
            return .init(typeIdentifier: type, kind: "Data", text: dataSummary(data))
        case let mapItem as MKMapItem:
            return .init(typeIdentifier: type, kind: "MKMapItem", text: describe(mapItem))
        case let other?:
            return .init(typeIdentifier: type, kind: String(describing: Swift.type(of: other)), text: String(describing: other))
        case nil:
            return .init(typeIdentifier: type, kind: "nil", text: "")
        }
    }

    nonisolated private static func describe(_ item: MKMapItem) -> String {
        let c = item.placemark.coordinate
        var lines = [
            "name: \(item.name ?? "nil")",
            "coordinate: \(c.latitude), \(c.longitude)",
            "address: \(item.placemark.title ?? "nil")",
        ]
        if let url = item.url { lines.append("url: \(url.absoluteString)") }
        if let id = item.identifier { lines.append("identifier: \(id.rawValue)") }
        return lines.joined(separator: "\n")
    }

    /// Bytes as UTF-8 if they read as text (vCards do), else a size and hex prefix.
    nonisolated private static func dataSummary(_ data: Data) -> String {
        if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            return "\(data.count) bytes, UTF-8:\n" + String(text.prefix(4000))
        }
        let hex = data.prefix(64).map { String(format: "%02x", $0) }.joined()
        return "\(data.count) bytes: \(hex)\(data.count > 64 ? "…" : "")"
    }

    nonisolated private static func fileSummary(_ url: URL) -> String {
        guard let data = try? Data(contentsOf: url) else { return "file \(url.lastPathComponent) (unreadable)" }
        return "file \(url.lastPathComponent), " + dataSummary(data)
    }
}
