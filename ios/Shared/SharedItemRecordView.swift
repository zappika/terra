import SwiftUI

/// List sections showing a recorded share. Used by the share extension and the app's
/// "Last shared item" debug screen. Text is selectable so values can be copied out.
struct SharedItemRecordSections: View {
    var record: SharedItemRecord

    var body: some View {
        Section("Links") {
            if record.links.isEmpty {
                Text("No URL found in the share").foregroundStyle(.secondary)
            }
            ForEach(Array(record.links.enumerated()), id: \.offset) { _, link in
                VStack(alignment: .leading, spacing: 4) {
                    Text(link.parsed).font(.headline)
                    Text(link.original).font(.footnote.monospaced())
                    ForEach(Array(link.redirects.enumerated()), id: \.offset) { _, hop in
                        Text("→ \(hop)").font(.footnote.monospaced()).foregroundStyle(.secondary)
                    }
                    if let error = link.resolveError {
                        Text("Redirect failed: \(error)").font(.footnote).foregroundStyle(.red)
                    }
                }
                .textSelection(.enabled)
            }
        }
        ForEach(Array(record.items.enumerated()), id: \.offset) { index, item in
            Section("Item \(index + 1)") {
                if let title = item.title { LabeledContent("Title", value: title) }
                if let text = item.contentText { LabeledContent("Content text", value: text) }
                if !item.userInfoKeys.isEmpty {
                    LabeledContent("userInfo keys", value: item.userInfoKeys.joined(separator: ", "))
                }
                ForEach(Array(item.attachments.enumerated()), id: \.offset) { a, attachment in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Attachment \(a + 1)" + (attachment.suggestedName.map { " — \($0)" } ?? ""))
                            .font(.headline)
                        Text(attachment.typeIdentifiers.joined(separator: "\n"))
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary)
                        ForEach(Array(attachment.values.enumerated()), id: \.offset) { _, value in
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(value.typeIdentifier) → \(value.kind)").font(.subheadline.bold())
                                Text(value.text.isEmpty ? "(empty)" : value.text).font(.footnote.monospaced())
                            }
                        }
                    }
                    .textSelection(.enabled)
                }
            }
        }
        Section {
            LabeledContent("Received", value: record.receivedAt.formatted(date: .abbreviated, time: .standard))
        }
    }
}

/// The full record as pretty JSON, for copying into the spike doc.
extension SharedItemRecord {
    var prettyJSON: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }
}
