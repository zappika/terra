import MapKit
import SwiftUI

/// Screen 1: a map with place search. Choosing a result opens the route preview.
struct FindPlaceView: View {
    @Environment(RoutePlanner.self) private var planner
    @Environment(TransferController.self) private var transfer
    @State private var search = PlaceSearch()
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var isSearching = false
    @State private var sheetDetent: PresentationDetent = .medium
    @State private var screenHeight: CGFloat = 800
    @State private var showingSharedItem = false

    var body: some View {
        NavigationStack {
            Map(position: $position) {
                UserAnnotation()
                if let planned = planner.plannedRoute {
                    MapPolyline(coordinates: planned.route.points.map(\.clCoordinate))
                        .stroke(.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                    Marker("Start", systemImage: "figure.walk", coordinate: planned.route.points[0].clCoordinate)
                        .tint(.green)
                    Marker(planned.destination.name, coordinate: planned.destination.coordinate)
                        .tint(.red)
                } else if let destination = planner.destination {
                    Marker(destination.name, coordinate: destination.coordinate)
                        .tint(.red)
                }
            }
            // Keep the route visible above the medium sheet; MapKit fits camera rects inside the safe area.
            .safeAreaPadding(.bottom, planner.isActive ? screenHeight * 0.55 : 0)
            .onGeometryChange(for: CGFloat.self, of: { $0.size.height }) { screenHeight = $0 }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
                MapScaleView()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                search.setRegion(context.region)
            }
            .navigationTitle("TERRA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    @Bindable var transfer = transfer
                    Menu("Developer", systemImage: "hammer") {
                        Section("Mock TERRA (no hardware yet)") {
                            Picker("Mock TERRA", selection: $transfer.mockBehavior) {
                                ForEach(MockTerraBehavior.allCases) { Text($0.label).tag($0) }
                            }
                            .pickerStyle(.inline)
                        }
                        Section("Apple Maps share spike") {
                            Button("Last shared item", systemImage: "square.and.arrow.down") {
                                showingSharedItem = true
                            }
                        }
                    }
                }
            }
            .searchable(text: $search.query, isPresented: $isSearching, prompt: "Search for a place")
            .searchSuggestions {
                ForEach(search.suggestions) { suggestion in
                    Button {
                        select(suggestion)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(suggestion.title)
                            if !suggestion.subtitle.isEmpty {
                                Text(suggestion.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            .onSubmit(of: .search) {
                Task { await search.submit() }
            }
            .overlay {
                if search.isResolving {
                    ProgressView("Finding place…")
                        .padding()
                        .background(.regularMaterial, in: .rect(cornerRadius: 12))
                }
            }
            .alert("Search", isPresented: Binding(
                get: { search.errorMessage != nil },
                set: { if !$0 { search.errorMessage = nil } }
            )) {
                Button("OK") {}
            } message: {
                Text(search.errorMessage ?? "")
            }
            .sheet(isPresented: $showingSharedItem) {
                LastSharedItemView()
            }
            .sheet(isPresented: Binding(
                get: { planner.isActive },
                set: { if !$0 { planner.reset() } }
            )) {
                RoutePreviewSheet(onChangeDestination: changeDestination)
                    .presentationDetents([.fraction(0.25), .medium, .large], selection: $sheetDetent)
                    .presentationBackgroundInteraction(.enabled(upThrough: .medium))
                    .interactiveDismissDisabled()
            }
            .onChange(of: planner.destination) { _, destination in
                if let destination {
                    withAnimation { position = .item(destination.mapItem) }
                }
            }
            .onChange(of: planner.plannedRoute?.route.id) { _, _ in
                guard let planned = planner.plannedRoute else { return }
                withAnimation { position = .rect(Self.rect(for: planned.route)) }
            }
        }
    }

    private func select(_ suggestion: PlaceSearch.Suggestion) {
        isSearching = false
        Task {
            guard let place = await search.resolve(suggestion) else { return }
            search.clear()
            transfer.reset()
            sheetDetent = .medium
            planner.choose(place)
        }
    }

    private func changeDestination() {
        planner.reset()
        transfer.reset()
        isSearching = true
    }

    /// The whole route with a margin for the markers.
    static func rect(for route: RouteV1) -> MKMapRect {
        let points = route.points.map { MKMapPoint($0.clCoordinate) }
        let xs = points.map(\.x), ys = points.map(\.y)
        let minX = xs.min()!, maxX = xs.max()!, minY = ys.min()!, maxY = ys.max()!
        let w = max(maxX - minX, 300), h = max(maxY - minY, 300)
        return MKMapRect(x: minX - w * 0.15, y: minY - h * 0.2, width: w * 1.3, height: h * 1.3)
    }
}
