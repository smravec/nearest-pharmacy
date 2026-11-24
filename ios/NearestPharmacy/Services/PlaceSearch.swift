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
            let parts = [suggestion.title, suggestion.subtitle].filter { !$0.isEmpty }
            return try await resolve(text: parts.joined(separator: ", "))
        }
        let request = MKLocalSearch.Request(completion: completion)
        return try await firstPlace(for: request) { _ in suggestion.title }
    }

    func resolve(text: String) async throws -> Origin {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        request.resultTypes = Self.resultTypes
        return try await firstPlace(for: request) { $0.name ?? text }
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
            throw Task.isCancelled ? CancellationError() : Self.mapped(error)
        }
    }

    private static func mapped(_ error: any Error) -> any Error {
        if error is CancellationError || error is SearchFailure { return error }
        if let error = error as? MKError, error.code == .placemarkNotFound {
            return SearchFailure.placeNotFound
        }
        return isOffline(error) ? SearchFailure.offline : SearchFailure.serviceUnavailable
    }

    /// MapKit wraps network errors, so the cause is somewhere in the underlying chain.
    private static func isOffline(_ error: any Error) -> Bool {
        let offlineCodes = [
            NSURLErrorNotConnectedToInternet,
            NSURLErrorDataNotAllowed,
            NSURLErrorInternationalRoamingOff,
        ]
        var current: NSError? = error as NSError
        for _ in 0..<5 {
            guard let candidate = current else { return false }
            if candidate.domain == NSURLErrorDomain {
                return offlineCodes.contains(candidate.code)
            }
            current = candidate.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return false
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
