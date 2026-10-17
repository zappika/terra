import SwiftUI

/// Lets the user use their location or search for a start point by hand.
struct StartPointPicker: View {
    var onPick: (StartPoint) -> Void
    @State private var search = PlaceSearch()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if search.query.isEmpty {
                    Button {
                        onPick(.currentLocation)
                    } label: {
                        Label("Current Location", systemImage: "location.fill")
                    }
                }
                ForEach(search.suggestions) { suggestion in
                    Button {
                        Task {
                            if let place = await search.resolve(suggestion) { onPick(.place(place)) }
                        }
                    } label: {
                        VStack(alignment: .leading) {
                            Text(suggestion.title)
                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            .overlay {
                if search.isResolving { ProgressView() }
            }
            .searchable(text: $search.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search for a start point")
            .onSubmit(of: .search) { Task { await search.submit() } }
            .navigationTitle("Start Point")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
