import MapKit

/// Suggests and resolves places with Apple's search.
@MainActor
final class PlaceSearch: NSObject, PlaceSearching {
    private static let minimumQueryLength = 2
    private static let maximumSuggestions = 8
    private static let resultTypes: MKLocalSearch.ResultType = [.address, .pointOfInterest]

    var onSuggestions: (([PlaceSuggestion]) -> Void)?

    private let completer = MKLocalSearchCompleter()
    private var activeQuery = ""
    private var completions: [PlaceSuggestion.ID: MKLocalSearchCompletion] = [:]
    /// Kept so a row tapped while the list refreshes still resolves.
    private var previousCompletions: [PlaceSuggestion.ID: MKLocalSearchCompletion] = [:]

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
            completions = [:]
            previousCompletions = [:]
            activeQuery = ""
            onSuggestions?([])
            return
        }
        activeQuery = trimmed
        completer.queryFragment = trimmed
    }

    func resolve(_ suggestion: PlaceSuggestion) async throws -> Origin {
        guard let completion = completions[suggestion.id] ?? previousCompletions[suggestion.id] else {
            return try await resolve(text: suggestion.fullName)
        }
        let request = MKLocalSearch.Request(completion: completion)
        return try await firstPlace(for: request) { _ in suggestion.fullName }
    }

    func resolve(text: String) async throws -> Origin {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        request.resultTypes = Self.resultTypes
        return try await firstPlace(for: request) { Self.label(for: $0) ?? text }
    }

    private func firstPlace(
        for request: MKLocalSearch.Request,
        label: (MKMapItem) -> String
    ) async throws -> Origin {
        do {
            let response = try await MKLocalSearch(request: request).start()
            try Task.checkCancellation()
            guard let item = response.mapItems.first(where: {
                CLLocationCoordinate2DIsValid($0.placemark.coordinate)
            }) else { throw SearchFailure.placeNotFound }

            let coordinate = item.placemark.coordinate
            return Origin(
                coordinate: Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude),
                label: label(item),
                source: .search
            )
        } catch {
            throw Task.isCancelled ? CancellationError() : SearchFailure(mapKitError: error)
        }
    }

    /// "Springfield, MO, United States", without the parts that repeat an earlier one.
    private static func label(for item: MKMapItem) -> String? {
        let placemark = item.placemark
        let parts = [item.name, placemark.locality, placemark.administrativeArea, placemark.country]
        var label: [String] = []
        for case let part? in parts where !part.isEmpty {
            let isRepeated = label.contains {
                $0.compare(part, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            }
            if !isRepeated { label.append(part) }
        }
        return label.isEmpty ? nil : label.joined(separator: ", ")
    }
}

extension SearchFailure {
    init(mapKitError error: any Error) {
        if let failure = error as? SearchFailure {
            self = failure
        } else if let networkCode = Self.networkErrorCode(in: error) {
            // Checked first, so a network error is never reported as "not found".
            let isOffline = [
                NSURLErrorNotConnectedToInternet,
                NSURLErrorDataNotAllowed,
                NSURLErrorInternationalRoamingOff,
            ].contains(networkCode)
            self = isOffline ? .offline : .serviceUnavailable
        } else if (error as? MKError)?.code == .placemarkNotFound {
            self = .placeNotFound
        } else {
            self = .serviceUnavailable
        }
    }

    /// The cause may be wrapped, so this looks through the underlying errors.
    private static func networkErrorCode(in error: any Error) -> Int? {
        var current: NSError? = error as NSError
        for _ in 0..<5 {
            guard let candidate = current else { return nil }
            if candidate.domain == NSURLErrorDomain { return candidate.code }
            current = candidate.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return nil
    }
}

extension PlaceSearch: @preconcurrency MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        guard isCurrent else { return }

        var suggestions: [PlaceSuggestion] = []
        var latest: [PlaceSuggestion.ID: MKLocalSearchCompletion] = [:]
        for (index, completion) in completer.results.prefix(Self.maximumSuggestions).enumerated() {
            let suggestion = PlaceSuggestion(
                id: "\(index)|\(completion.title)|\(completion.subtitle)",
                title: completion.title,
                subtitle: completion.subtitle
            )
            suggestions.append(suggestion)
            latest[suggestion.id] = completion
        }
        previousCompletions = completions
        completions = latest
        onSuggestions?(suggestions)
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: any Error) {
        guard isCurrent else { return }
        onSuggestions?([])
    }

    /// False for a late callback after the query was cleared or replaced.
    private var isCurrent: Bool {
        !activeQuery.isEmpty && activeQuery == completer.queryFragment
    }
}
