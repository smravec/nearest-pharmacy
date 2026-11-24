import MapKit

@MainActor
protocol AppleMapsProviding {
    /// The Apple Maps place for this pharmacy, or nil when none matches confidently.
    func mapItem(for pharmacy: Pharmacy) async throws -> MKMapItem?
    func walkingTime(from origin: Coordinate, to pharmacy: Pharmacy) async throws -> WalkingTime
    func openDirections(to pharmacy: Pharmacy)
}

struct AppleMaps: AppleMapsProviding {
    func mapItem(for pharmacy: Pharmacy) async throws -> MKMapItem? {
        let byName = MKLocalSearch.Request()
        byName.naturalLanguageQuery = pharmacy.name
        byName.resultTypes = .pointOfInterest
        byName.region = MKCoordinateRegion(
            center: pharmacy.coordinate.clLocationCoordinate,
            latitudinalMeters: 400,
            longitudinalMeters: 400
        )
        if let match = Self.match(for: pharmacy, named: try await MKLocalSearch(request: byName).mapItems()) {
            return match
        }

        let nearby = MKLocalPointsOfInterestRequest(center: pharmacy.coordinate.clLocationCoordinate, radius: 150)
        nearby.pointOfInterestFilter = MKPointOfInterestFilter(including: [.pharmacy])
        return Self.match(for: pharmacy, nearby: try await MKLocalSearch(request: nearby).mapItems())
    }

    func walkingTime(from origin: Coordinate, to pharmacy: Pharmacy) async throws -> WalkingTime {
        let request = MKDirections.Request()
        request.source = Self.mapItem(at: origin)
        request.destination = Self.mapItem(at: pharmacy.coordinate)
        request.transportType = .walking
        let seconds = try await MKDirections(request: request).calculateETA().expectedTravelTime
        return WalkingTime(seconds: seconds, isEstimate: false)
    }

    func openDirections(to pharmacy: Pharmacy) {
        let item = Self.mapItem(at: pharmacy.coordinate)
        item.name = pharmacy.name
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: pharmacy.isWalkable
                ? MKLaunchOptionsDirectionsModeWalking
                : MKLaunchOptionsDirectionsModeDefault,
        ])
    }

    /// The closest pharmacy with the same name, else the closest with a partly matching one.
    static func match(for pharmacy: Pharmacy, named items: [MKMapItem]) -> MKMapItem? {
        let name = PharmacyName(pharmacy.name)
        return closest(to: pharmacy, within: 150, in: items, where: name.equals)
            ?? closest(to: pharmacy, within: 75, in: items, where: name.overlaps)
    }

    /// For names that differ too much for the search by name, but share the same spot.
    static func match(for pharmacy: Pharmacy, nearby items: [MKMapItem]) -> MKMapItem? {
        closest(to: pharmacy, within: 20, in: items, where: PharmacyName(pharmacy.name).couldBe)
    }

    private static func closest(
        to pharmacy: Pharmacy,
        within limit: Double,
        in items: [MKMapItem],
        where isMatch: (PharmacyName) -> Bool
    ) -> MKMapItem? {
        func meters(_ item: MKMapItem) -> Double {
            pharmacy.coordinate.meters(to: Coordinate(item.placemark.coordinate))
        }
        return items
            .filter { $0.pointOfInterestCategory == .pharmacy && meters($0) <= limit }
            .filter { isMatch(PharmacyName($0.name ?? "")) }
            .min { meters($0) < meters($1) }
    }

    private static func mapItem(at coordinate: Coordinate) -> MKMapItem {
        MKMapItem(placemark: MKPlacemark(coordinate: coordinate.clLocationCoordinate))
    }
}

extension MKLocalSearch {
    /// Empty when Apple found nothing. Throws `SearchFailure` or `CancellationError`.
    @MainActor
    func mapItems() async throws -> [MKMapItem] {
        do {
            let items = try await start().mapItems
            try Task.checkCancellation()
            return items
        } catch {
            if Task.isCancelled { throw CancellationError() }
            // A network error must never be reported as "not found".
            if (error as? MKError)?.code == .placemarkNotFound, SearchFailure.networkCode(in: error) == nil {
                return []
            }
            throw SearchFailure(error)
        }
    }
}
