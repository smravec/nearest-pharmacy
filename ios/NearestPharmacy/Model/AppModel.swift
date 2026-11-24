import Foundation
import MapKit
import Observation

/// Text for VoiceOver. The id makes a repeated message a new announcement.
struct Announcement: Equatable, Sendable {
    let id: Int
    let text: String
}

@MainActor
@Observable
final class AppModel {
    private(set) var state: SearchState = .idle
    private(set) var origin: Origin?
    private(set) var suggestions: [PlaceSuggestion] = []
    private(set) var isResolvingPlace = false
    private(set) var placeSearchFailure: SearchFailure?
    private(set) var detailsLoadingID: Pharmacy.ID?
    private(set) var detailsUnavailableID: Pharmacy.ID?
    private(set) var announcement: Announcement?

    var query = "" {
        didSet {
            guard query != oldValue else { return }
            placeSearchFailure = nil
            guard !suppressSuggestions else { return }
            acceptsSuggestions = true
            places.update(query: query)
        }
    }

    var selectedID: Pharmacy.ID?
    var detailItem: MKMapItem?

    var pharmacies: [Pharmacy] {
        guard case .ready(let results) = state else { return [] }
        return results.pharmacies
    }

    var nearest: Pharmacy? { pharmacies.first }

    private enum Action {
        case locate
        case find(Origin)
    }

    private let finder: any PharmacyFinding
    private let location: any LocationProviding
    private let places: any PlaceSearching
    private let details: any PlaceDetailing

    @ObservationIgnored private var lastAction: Action?
    /// Set while `choose` fills in the query, which is not typing.
    @ObservationIgnored private var suppressSuggestions = false
    /// False once a place was picked or submitted, so a late callback can't reopen the list.
    @ObservationIgnored private var acceptsSuggestions = false

    // A task may outlive its cancellation, so its results count only while its generation is current.
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var searchGeneration = 0
    @ObservationIgnored private var placeTask: Task<Void, Never>?
    @ObservationIgnored private var placeGeneration = 0
    @ObservationIgnored private var detailsTask: Task<Void, Never>?
    @ObservationIgnored private var detailsGeneration = 0

    init(
        finder: any PharmacyFinding,
        location: any LocationProviding,
        places: any PlaceSearching,
        details: any PlaceDetailing
    ) {
        self.finder = finder
        self.location = location
        self.places = places
        self.details = details
        places.onSuggestions = { [weak self] in self?.receive($0) }
    }

    static func live() -> AppModel {
        var finder: any PharmacyFinding = PhotonPharmacyService()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-failPharmacySearch") {
            finder = FailOnceFinder(base: finder)
        }
        #endif
        return AppModel(
            finder: finder,
            location: LocationService(),
            places: PlaceSearch(),
            details: PlaceDetails()
        )
    }

    // MARK: - Searching

    func useCurrentLocation() {
        cancelAll()
        origin = nil
        selectedID = nil
        placeSearchFailure = nil
        lastAction = .locate
        state = .locating

        let generation = searchGeneration
        searchTask = Task {
            do {
                let found = try await location.current()
                guard generation == searchGeneration else { return }
                await find(found, generation: generation)
            } catch is CancellationError {
                return
            } catch {
                guard generation == searchGeneration else { return }
                if error as? LocationError == .denied {
                    state = .denied
                    announce("Location is off. Search for a place instead.")
                } else {
                    fail(.locationUnavailable)
                }
            }
        }
    }

    func choose(_ suggestion: PlaceSuggestion) {
        suppressSuggestions = true
        query = suggestion.title
        suppressSuggestions = false
        closeSuggestions()
        resolvePlace { [places] in try await places.resolve(suggestion) }
    }

    func submitQuery() {
        let text = trimmedQuery
        guard !text.isEmpty else { return }
        closeSuggestions()
        places.update(query: "")
        resolvePlace { [places] in try await places.resolve(text: text) }
    }

    /// A failed place lookup is not repeated here: the person resubmits the query.
    func retry() {
        switch lastAction {
        case .locate: useCurrentLocation()
        case .find(let origin): startFinding(from: origin)
        case nil: break
        }
    }

    func reset() {
        cancelAll()
        state = .idle
        origin = nil
        selectedID = nil
        query = ""
        suggestions = []
        placeSearchFailure = nil
        lastAction = nil
    }

    // MARK: - One pharmacy

    func showDetails(for pharmacy: Pharmacy) {
        detailsTask?.cancel()
        detailsGeneration += 1
        detailItem = nil
        detailsUnavailableID = nil
        detailsLoadingID = pharmacy.id

        let generation = detailsGeneration
        detailsTask = Task {
            let item = await details.mapItem(for: pharmacy)
            guard generation == detailsGeneration else { return }
            detailsLoadingID = nil
            if let item {
                detailItem = item
            } else {
                detailsUnavailableID = pharmacy.id
                announce("Apple Maps has no details for this pharmacy")
            }
        }
    }

    func openDirections(to pharmacy: Pharmacy) {
        let placemark = MKPlacemark(coordinate: pharmacy.coordinate.clLocationCoordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = pharmacy.name
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking,
        ])
    }

    // MARK: - Tasks

    private func cancelAll() {
        searchTask?.cancel()
        placeTask?.cancel()
        detailsTask?.cancel()
        searchGeneration += 1
        placeGeneration += 1
        detailsGeneration += 1
        isResolvingPlace = false
        detailItem = nil
        detailsLoadingID = nil
        detailsUnavailableID = nil
    }

    private func startFinding(from origin: Origin) {
        cancelAll()
        let generation = searchGeneration
        searchTask = Task { await find(origin, generation: generation) }
    }

    private func find(_ newOrigin: Origin, generation: Int) async {
        guard generation == searchGeneration else { return }
        origin = newOrigin
        lastAction = .find(newOrigin)
        selectedID = nil
        state = .loading
        do {
            let results = try await finder.nearest(to: newOrigin.coordinate)
            guard generation == searchGeneration else { return }
            show(results, from: newOrigin)
        } catch is CancellationError {
            return
        } catch {
            guard generation == searchGeneration else { return }
            fail(error as? SearchFailure ?? .serviceUnavailable)
        }
    }

    /// Leaves a running search alone until the place is known: if the lookup fails, its result still shows.
    private func resolvePlace(_ resolve: @escaping @MainActor () async throws -> Origin) {
        placeTask?.cancel()
        placeGeneration += 1
        isResolvingPlace = true
        placeSearchFailure = nil

        let generation = placeGeneration
        placeTask = Task {
            do {
                let place = try await resolve()
                guard generation == placeGeneration else { return }
                startFinding(from: place)
            } catch is CancellationError {
                return
            } catch {
                guard generation == placeGeneration else { return }
                let failure = error as? SearchFailure ?? .serviceUnavailable
                isResolvingPlace = false
                placeSearchFailure = failure
                announce(
                    failure == .serviceUnavailable
                        ? "The place search isn't responding."
                        : Self.message(for: failure)
                )
            }
        }
    }

    // MARK: - Suggestions

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func receive(_ newSuggestions: [PlaceSuggestion]) {
        guard newSuggestions.isEmpty || (acceptsSuggestions && !trimmedQuery.isEmpty) else { return }
        suggestions = newSuggestions
    }

    private func closeSuggestions() {
        acceptsSuggestions = false
        suggestions = []
    }

    // MARK: - Outcomes

    private func show(_ results: PharmacyResults, from origin: Origin) {
        guard let first = results.pharmacies.first else {
            state = .empty(radiusKilometers: results.radiusKilometers)
            announce("No pharmacies found within \(results.radiusKilometers) kilometres.")
            return
        }
        state = .ready(results)
        selectedID = first.id

        let distance = Format.spokenDistance(first.distanceMeters)
        let walk = Format.spokenWalk(first.walkMinutes)
        let caveat = origin.isApproximate ? " Your location is approximate." : ""
        announce("Nearest pharmacy: \(first.name), \(distance), \(walk).\(caveat)")
    }

    private func fail(_ failure: SearchFailure) {
        state = .failed(failure)
        announce(Self.message(for: failure))
    }

    private func announce(_ text: String) {
        announcement = Announcement(id: (announcement?.id ?? 0) + 1, text: text)
    }

    private static func message(for failure: SearchFailure) -> String {
        switch failure {
        case .offline: "You're offline."
        case .serviceUnavailable: "The pharmacy search isn't responding."
        case .locationUnavailable: "Your location couldn't be found."
        case .placeNotFound: "No place found for that search."
        }
    }
}
