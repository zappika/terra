import SwiftUI

/// Developer screen: the last item the share extension recorded (Apple Maps spike).
struct LastSharedItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var record: SharedItemRecord?

    var body: some View {
        NavigationStack {
            List {
                if !SharedItemStore.isAvailable {
                    Text("The App Group \(SharedItemStore.appGroup) isn't available, so shares can't be read.")
                        .foregroundStyle(.red)
                }
                if let record {
                    Section {
                        ShareLink(item: record.prettyJSON) {
                            Label("Share as JSON", systemImage: "square.and.arrow.up")
                        }
                        Button("Clear", role: .destructive) {
                            SharedItemStore.clear()
                            self.record = nil
                        }
                    }
                    SharedItemRecordSections(record: record)
                } else {
                    ContentUnavailableView(
                        "Nothing shared yet",
                        systemImage: "square.and.arrow.down",
                        description: Text("In Apple Maps, open a place or a route, tap Share and choose TERRA.")
                    )
                }
            }
            .navigationTitle("Last Shared Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .refreshable { record = SharedItemStore.load() }
            .onAppear { record = SharedItemStore.load() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { record = SharedItemStore.load() }
            }
        }
    }
}
