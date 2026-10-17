import SwiftUI

@main
struct TERRAApp: App {
    @State private var location: LocationProvider
    @State private var planner: RoutePlanner
    @State private var transfer = TransferController()

    init() {
        let location = LocationProvider()
        _location = State(initialValue: location)
        _planner = State(initialValue: RoutePlanner(location: location))
    }

    var body: some Scene {
        WindowGroup {
            FindPlaceView()
                .environment(location)
                .environment(planner)
                .environment(transfer)
        }
    }
}
