import SwiftUI

/// Screen 2: the bottom sheet over the map for calculating, ready and failed states.
struct RoutePreviewSheet: View {
    @Environment(RoutePlanner.self) private var planner
    var onChangeDestination: () -> Void

    @State private var showConnection = false
    @State private var showStartPicker = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Walking Route")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Change destination", systemImage: "xmark", action: onChangeDestination)
                    }
                }
        }
        .sheet(isPresented: $showConnection) {
            if let planned = planner.plannedRoute {
                ConnectionSheet(route: planned.route)
                    .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showStartPicker) {
            StartPointPicker { start in
                showStartPicker = false
                planner.setStart(start)
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch planner.phase {
        case .idle, .calculating:
            ProgressView("Calculating walking route…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready(let planned):
            RouteDetails(
                planned: planned,
                onSend: { showConnection = true },
                onChangeStart: { showStartPicker = true },
                onChangeDestination: onChangeDestination
            )
        case .failed(let failure):
            ContentUnavailableView {
                Label(failure.title, systemImage: "figure.walk.motion.trianglebadge.exclamationmark")
            } description: {
                Text(failure.message)
            } actions: {
                Button("Try Again") { planner.calculate() }
                    .buttonStyle(.borderedProminent)
                Button("Change Destination", action: onChangeDestination)
            }
        case .needsStart(let failure):
            LocationNeededView(failure: failure, onChooseStart: { showStartPicker = true })
        }
    }
}

private struct RouteDetails: View {
    var planned: PlannedRoute
    var onSend: () -> Void
    var onChangeStart: () -> Void
    var onChangeDestination: () -> Void

    private var distance: String {
        Measurement(value: planned.route.distanceMeters, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }

    private var time: String {
        Duration.seconds(planned.route.expectedTravelTimeSeconds)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(planned.destination.name)
                        .font(.headline)
                    if !planned.destination.address.isEmpty {
                        Text(planned.destination.address)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Label {
                        Text("Walking · \(distance) · \(time)")
                    } icon: {
                        Image(systemName: "figure.walk")
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.top, 4)
                }
                Button(action: onChangeStart) {
                    LabeledContent("Start", value: planned.start.label)
                }
                .foregroundStyle(.primary)
                LabeledContent("Route", value: "TERRA route")
            } footer: {
                Text("TERRA calculated this walking route with Apple Maps. This is the exact path it will send.")
            }

            Section {
                LabeledContent("Points", value: "\(planned.route.points.count)")
                LabeledContent("Turns", value: "\(planned.route.turns.count)")
                if let file = try? RouteExport.file(for: planned.route) {
                    ShareLink(item: file) {
                        Label("Export Route JSON", systemImage: "square.and.arrow.up")
                    }
                }
            } header: {
                Text("Development")
            } footer: {
                Text("Exporting saves the route as a file. It does not send it to TERRA.")
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Button(action: onSend) {
                    Label("Send to TERRA", systemImage: "arrow.up.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Button(action: onChangeDestination) {
                    Text("Change Destination").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)
        }
    }
}

private struct LocationNeededView: View {
    var failure: LocationFailure
    var onChooseStart: () -> Void
    @Environment(RoutePlanner.self) private var planner
    @Environment(\.openURL) private var openURL

    var body: some View {
        ContentUnavailableView {
            Label("Start point needed", systemImage: "location.slash")
        } description: {
            Text(message)
        } actions: {
            if failure != .unavailable {
                Button("Open Settings") {
                    openURL(URL(string: UIApplication.openSettingsURLString)!)
                }
                .buttonStyle(.borderedProminent)
            }
            Button("Try Again") { planner.calculate() }
            Button("Choose Start Point", action: onChooseStart)
        }
    }

    private var message: String {
        switch failure {
        case .denied: "A walking route needs a start point. Allow location access in Settings, or choose a start point yourself."
        case .restricted: "Location access is restricted on this iPhone. Choose a start point to calculate the route."
        case .unavailable: "Your location isn't available right now. Try again, or choose a start point yourself."
        }
    }
}

enum RouteExport {
    static func file(for route: RouteV1) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("terra-route-\(route.id.uuidString.prefix(8).lowercased()).json")
        try route.jsonData(pretty: true).write(to: url)
        return url
    }
}
