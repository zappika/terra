import MapKit

/// A chosen destination or start point, with the name and address the user saw.
struct Place: Identifiable, Equatable {
    let id = UUID()
    var mapItem: MKMapItem
    var name: String
    var address: String

    var coordinate: CLLocationCoordinate2D { mapItem.placemark.coordinate }

    init(mapItem: MKMapItem, name: String? = nil, address: String? = nil) {
        self.mapItem = mapItem
        self.name = name ?? mapItem.name ?? "Dropped pin"
        self.address = address ?? mapItem.placemark.title ?? ""
    }

    static func == (a: Place, b: Place) -> Bool { a.id == b.id }
}

enum StartPoint: Equatable {
    case currentLocation
    case place(Place)

    var label: String {
        switch self {
        case .currentLocation: "Current location"
        case .place(let p): p.name
        }
    }
}
