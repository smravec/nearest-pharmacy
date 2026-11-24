import MapKit

/// Finds the Apple Maps place that is the same pharmacy as an OpenStreetMap one.
@MainActor
final class PlaceDetails: PlaceDetailing {
    private static let searchSpanMeters = 400.0

    /// Only successes, so asking again repeats a search that found nothing.
    private var found: [Pharmacy.ID: MKMapItem] = [:]

    func mapItem(for pharmacy: Pharmacy) async throws -> MKMapItem? {
        if let item = found[pharmacy.id] { return item }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = pharmacy.name
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(
            center: pharmacy.coordinate.clLocationCoordinate,
            latitudinalMeters: Self.searchSpanMeters,
            longitudinalMeters: Self.searchSpanMeters
        )
        do {
            let response = try await MKLocalSearch(request: request).start()
            try Task.checkCancellation()
            let match = Self.bestMatch(for: pharmacy, in: response.mapItems)
            found[pharmacy.id] = match
            return match
        } catch {
            if Task.isCancelled { throw CancellationError() }
            let failure = SearchFailure(mapKitError: error)
            if failure == .placeNotFound { return nil }
            throw failure
        }
    }

    /// The closest pharmacy with the same name, else the closest with a partly matching one.
    static func bestMatch(for pharmacy: Pharmacy, in items: [MKMapItem]) -> MKMapItem? {
        let candidates = items
            .filter { $0.pointOfInterestCategory == .pharmacy }
            .map { item in
                (
                    item: item,
                    meters: meters(from: pharmacy, to: item),
                    match: NameMatch(item.name ?? "", pharmacy.name)
                )
            }

        func closest(_ match: NameMatch, within limit: Double) -> MKMapItem? {
            candidates
                .filter { $0.match == match && $0.meters <= limit }
                .min { $0.meters < $1.meters }?
                .item
        }
        return closest(.exact, within: 150) ?? closest(.partial, within: 75)
    }

    private static func meters(from pharmacy: Pharmacy, to item: MKMapItem) -> Double {
        let position = item.placemark.coordinate
        return Distance.meters(
            from: pharmacy.coordinate,
            to: Coordinate(latitude: position.latitude, longitude: position.longitude)
        )
    }
}

/// How well two pharmacy names agree, judged by their distinctive words.
enum NameMatch {
    /// "Alexa Apotheke" and "Alexa-Apotheke".
    case exact
    /// One name has more words: "Kallion apteekki" and "Kallion Apteekki Oy".
    case partial

    init?(_ a: String, _ b: String) {
        let aWords = Self.words(in: a)
        let bWords = Self.words(in: b)
        let aDistinctive = aWords.subtracting(Self.genericWords)
        let bDistinctive = bWords.subtracting(Self.genericWords)

        // An empty set is a subset of everything, so purely generic names must agree in full.
        if aDistinctive.isEmpty || bDistinctive.isEmpty {
            guard !aWords.isEmpty, aWords == bWords else { return nil }
            self = .exact
        } else if aDistinctive == bDistinctive {
            self = .exact
        } else if aDistinctive.isSubset(of: bDistinctive) || bDistinctive.isSubset(of: aDistinctive) {
            self = .partial
        } else {
            return nil
        }
    }

    /// Words that don't tell one pharmacy from another.
    private static let genericWords = Set([
        "apteekki", "apteekin", "sivuapteekki", "apotek", "apoteket", "apotheke", "apteka", "apteek",
        "pharmacy", "pharmacie", "pharma", "farmacia", "farmacija", "farmacie", "chemist", "chemists",
        "drugstore", "drug", "store", "lekarna", "lekaren", "ljekarna", "patika", "gyogyszertar",
        "aptieka", "vaistine", "eczane", "eczanesi", "аптека", "φαρμακείο",
    ].map(folded))

    private static let connectors: Set<String> = [
        "de", "la", "le", "am", "der", "die", "das", "the", "of", "and", "at", "i", "y", "et",
    ]

    private static func words(in name: String) -> Set<String> {
        Set(folded(name).split { !$0.isLetter && !$0.isNumber }.map(String.init))
            .subtracting(connectors)
    }

    private static func folded(_ text: String) -> String {
        text.folding(
            options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
    }
}
