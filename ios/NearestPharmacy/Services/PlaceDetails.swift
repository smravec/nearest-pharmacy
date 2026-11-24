import MapKit

/// Finds the Apple Maps place that is the same pharmacy as an OpenStreetMap one.
@MainActor
final class PlaceDetails: PlaceDetailing {
    private static let searchSpanMeters = 400.0
    private static let maximumDistanceMeters = 150.0

    /// Only successes: a miss may just be a network failure.
    private var found: [Pharmacy.ID: MKMapItem] = [:]

    func mapItem(for pharmacy: Pharmacy) async -> MKMapItem? {
        if let item = found[pharmacy.id] { return item }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = pharmacy.name
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(
            center: pharmacy.coordinate.clLocationCoordinate,
            latitudinalMeters: Self.searchSpanMeters,
            longitudinalMeters: Self.searchSpanMeters
        )
        guard let response = try? await MKLocalSearch(request: request).start() else { return nil }

        let match = response.mapItems
            .filter { $0.pointOfInterestCategory == .pharmacy }
            .filter { Self.namesMatch($0.name ?? "", pharmacy.name) }
            .map { (item: $0, meters: Self.meters(from: pharmacy, to: $0)) }
            .filter { $0.meters <= Self.maximumDistanceMeters }
            .min { $0.meters < $1.meters }?
            .item
        found[pharmacy.id] = match
        return match
    }

    private static func meters(from pharmacy: Pharmacy, to item: MKMapItem) -> Double {
        let position = item.placemark.coordinate
        return Distance.meters(
            from: pharmacy.coordinate,
            to: Coordinate(latitude: position.latitude, longitude: position.longitude)
        )
    }

    // MARK: - Names

    /// Words that don't tell one pharmacy from another, already folded.
    private nonisolated static let genericWords: Set<String> = [
        "apteekki", "apteekin", "sivuapteekki", "apotek", "apoteket", "apotheke", "apteka", "apteek",
        "pharmacy", "pharmacie", "pharma", "farmacia", "farmacija", "chemist", "chemists", "drugstore",
        "the", "uusi",
    ]

    /// Compares the distinctive words, so "Kallion apteekki" matches "Kallion Apteekki Oy"
    /// but not another pharmacy.
    nonisolated static func namesMatch(_ a: String, _ b: String) -> Bool {
        let aWords = words(in: a)
        let bWords = words(in: b)
        let aDistinctive = aWords.subtracting(genericWords)
        let bDistinctive = bWords.subtracting(genericWords)

        // An empty set is a subset of everything, so purely generic names must match exactly.
        if aDistinctive.isEmpty || bDistinctive.isEmpty { return aWords == bWords }
        return aDistinctive.isSubset(of: bDistinctive) || bDistinctive.isSubset(of: aDistinctive)
    }

    private nonisolated static func words(in name: String) -> Set<String> {
        let folded = name.folding(
            options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        return Set(folded.split { !$0.isLetter && !$0.isNumber }.map(String.init))
    }
}
