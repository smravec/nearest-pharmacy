import MapKit
import Observation

/// Suggests and resolves places with Apple's search.
@MainActor
@Observable
final class PlaceSearch: NSObject {
    private static let minimumQueryLength = 2
    private static let maximumSuggestions = 8

    private(set) var suggestions: [MKLocalSearchCompletion] = []
    /// Apple has answered, without suggestions.
    private(set) var hasNoSuggestions = false

    @ObservationIgnored private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.resultTypes = [.address, .pointOfInterest]
        completer.delegate = self
    }

    func update(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= Self.minimumQueryLength else {
            completer.cancel()
            // Setting an unchanged fragment does nothing, so retyping the same query would show no list.
            completer.queryFragment = ""
            suggestions = []
            hasNoSuggestions = false
            return
        }
        completer.queryFragment = trimmed
    }

    /// Nil when there is no such place. Throws `SearchFailure` or `CancellationError`.
    func place(for suggestion: MKLocalSearchCompletion) async throws -> Origin? {
        let name = [suggestion.title, suggestion.subtitle].filter { !$0.isEmpty }.joined(separator: ", ")
        return try await place(for: MKLocalSearch.Request(completion: suggestion)) { _ in name }
    }

    func place(named text: String) async throws -> Origin? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        return try await place(for: request) { Self.name(of: $0) ?? text }
    }

    private func place(
        for request: MKLocalSearch.Request,
        name: (MKMapItem) -> String
    ) async throws -> Origin? {
        try await MKLocalSearch(request: request).mapItems()
            .first { CLLocationCoordinate2DIsValid($0.placemark.coordinate) }
            .map { Origin(coordinate: Coordinate($0.placemark.coordinate), placeName: name($0)) }
    }

    /// "Springfield, MO, United States", without the parts that repeat an earlier one.
    private static func name(of item: MKMapItem) -> String? {
        let placemark = item.placemark
        let parts = [item.name, placemark.locality, placemark.administrativeArea, placemark.country]
        var name: [String] = []
        for case let part? in parts where !part.isEmpty {
            let isRepeated = name.contains {
                $0.compare(part, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            }
            if !isRepeated { name.append(part) }
        }
        return name.isEmpty ? nil : name.joined(separator: ", ")
    }
}

extension PlaceSearch: @preconcurrency MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        // A late callback after the query was cleared.
        guard !completer.queryFragment.isEmpty else { return }
        suggestions = Array(completer.results.prefix(Self.maximumSuggestions))
        hasNoSuggestions = suggestions.isEmpty
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        guard !completer.queryFragment.isEmpty else { return }
        suggestions = []
        hasNoSuggestions = true
    }
}
