#if DEBUG
import MapKit
import SwiftUI

/// Fails the first search, to exercise the error screen and its retry button.
actor FailOnceFinder: PharmacyFinding {
    private let base: any PharmacyFinding
    private var hasFailed = false

    init(base: any PharmacyFinding) {
        self.base = base
    }

    func nearest(to origin: Coordinate) async throws -> PharmacyResults {
        guard hasFailed else {
            hasFailed = true
            throw SearchFailure.serviceUnavailable
        }
        return try await base.nearest(to: origin)
    }
}

private struct FakeFinder: PharmacyFinding {
    let result: Result<[Pharmacy], SearchFailure>

    func nearest(to origin: Coordinate) async throws -> PharmacyResults {
        PharmacyResults(pharmacies: try result.get(), radiusKilometers: 100)
    }
}

private struct FakeLocation: LocationProviding {
    let result: Result<Origin, LocationError>

    func current() async throws -> Origin {
        try result.get()
    }
}

private struct FakeMaps: AppleMapsProviding {
    func mapItem(for pharmacy: Pharmacy) async throws -> MKMapItem? {
        let item = MKMapItem(placemark: MKPlacemark(coordinate: pharmacy.coordinate.clLocationCoordinate))
        item.name = pharmacy.name
        item.phoneNumber = "+358 9 123 4567"
        return item
    }

    func walkingTime(from origin: Coordinate, to pharmacy: Pharmacy) async throws -> WalkingTime {
        WalkingTime(seconds: 720, isEstimate: false)
    }

    func openDirections(to pharmacy: Pharmacy) {}
}

private extension Origin {
    static let sample = Origin(coordinate: Coordinate(latitude: 60.1719, longitude: 24.9414))
}

private extension Pharmacy {
    static let samples = [
        sample(1, "Sample Pharmacy", "Example Street 1, Helsinki", latitude: 60.1770),
        sample(2, "Another Pharmacy", nil, latitude: 60.1640),
        sample(3, "Faraway Pharmacy", "Example Road 3, Vantaa", latitude: 60.2100),
    ]

    private static func sample(_ id: Int, _ name: String, _ address: String?, latitude: Double) -> Pharmacy {
        let coordinate = Coordinate(latitude: latitude, longitude: 24.9414)
        return Pharmacy(
            id: "node/\(id)",
            name: name,
            coordinate: coordinate,
            address: address,
            distanceMeters: Origin.sample.coordinate.meters(to: coordinate)
        )
    }
}

private extension AppModel {
    static func preview(
        finding pharmacies: Result<[Pharmacy], SearchFailure>,
        at origin: Result<Origin, LocationError> = .success(.sample)
    ) -> AppModel {
        let model = AppModel(
            finder: FakeFinder(result: pharmacies),
            location: FakeLocation(result: origin),
            maps: FakeMaps()
        )
        model.useCurrentLocation()
        return model
    }
}

#Preview("Ready") {
    RootView(model: .preview(finding: .success(Pharmacy.samples)))
}

#Preview("Empty") {
    RootView(model: .preview(finding: .success([])))
}

#Preview("Denied") {
    RootView(model: .preview(finding: .success([]), at: .failure(.denied)))
}

#Preview("Failed") {
    RootView(model: .preview(finding: .failure(.serviceUnavailable)))
}
#endif
