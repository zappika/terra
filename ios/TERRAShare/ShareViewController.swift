import SwiftUI
import UIKit

/// Share extension entry point. Spike only: shows what Apple Maps (or anything else)
/// shared and saves it to the App Group. It doesn't hand a destination to the app yet.
final class ShareViewController: UIViewController {
    private let model = ShareModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        let root = ShareView(model: model) { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: nil)
        }
        let host = UIHostingController(rootView: root)
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)

        let items = extensionContext?.inputItems.compactMap { $0 as? NSExtensionItem } ?? []
        Task {
            let record = await ShareInspector.inspect(items)
            SharedItemStore.save(record)
            model.record = record
            model.saved = SharedItemStore.isAvailable
        }
    }
}

@Observable
final class ShareModel {
    var record: SharedItemRecord?
    var saved = false
}

struct ShareView: View {
    var model: ShareModel
    var done: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if let record = model.record {
                    Section {
                        Text(model.saved
                             ? "Saved. Open TERRA › Developer › Last shared item to see this again."
                             : "Couldn't reach the App Group, so this wasn't saved.")
                            .font(.footnote)
                            .foregroundStyle(model.saved ? Color.secondary : Color.red)
                        ShareLink(item: record.prettyJSON) {
                            Label("Share as JSON", systemImage: "square.and.arrow.up")
                        }
                    }
                    SharedItemRecordSections(record: record)
                } else {
                    HStack {
                        ProgressView()
                        Text("Reading shared item…")
                    }
                }
            }
            .navigationTitle("Shared Item (debug)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: done)
                }
            }
        }
    }
}
