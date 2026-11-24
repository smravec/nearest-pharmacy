import MapKit
import Observation

/// What Apple Maps has for one pharmacy.
enum PlaceDetails: Equatable {
    case loading
    case found(MKMapItem)
    case unmatched
    case failed
}

// Cancelling a task and checking `Task.isCancelled` after its last await both happen on the main
// actor, so a replaced task can never write its result.
@MainActor
@Observable
final class AppModel {
    private(set) var state: SearchState = .idle
    /// To the nearest pharmacy, once Apple Maps has answered.
    private(set) var routeWalk: WalkingTime?
    private(set) var details: [Pharmacy.ID: PlaceDetails] = [:]
    /// Grows with each tap in the list, so a tap on the selected pharmacy recenters the map too.
    private(set) var listSelectionCount = 0

    var selectedID: Pharmacy.ID?
    var detailItem: MKMapItem?

    private let finder: any PharmacyFinding
    private let location: any LocationProviding
    private let maps: any AppleMapsProviding

    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var detailsTask: Task<Void, Never>?

    init(
        finder: any PharmacyFinding,
        location: any LocationProviding = LocationService(),
        maps: any AppleMapsProviding = AppleMaps()
    ) {
        self.finder = finder
        self.location = location
        self.maps = maps
    }

    static func live() -> AppModel {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-failPharmacySearch") {
            return AppModel(finder: FailOnceFinder(base: PhotonPharmacyService()))
        }
        #endif
        return AppModel(finder: PhotonPharmacyService())
    }

    // MARK: - Searching

    func useCurrentLocation() {
        reset()
        state = .locating
        searchTask = Task {
            do {
                let origin = try await location.current()
                guard !Task.isCancelled else { return }
                state = .loading(origin)
                await find(from: origin)
            } catch {
                guard !Task.isCancelled else { return }
                if error as? LocationError == .denied {
                    state = .denied
                    VoiceOver.announce("Location is off. Search for a place instead.")
                } else {
                    fail(.locationUnavailable, near: nil)
                }
            }
        }
    }

    func search(from origin: Origin) {
        reset()
        state = .loading(origin)
        searchTask = Task { await find(from: origin) }
    }

    func retry() {
        if case .failed(_, let origin?) = state {
            search(from: origin)
        } else {
            useCurrentLocation()
        }
    }

    func reset() {
        searchTask?.cancel()
        detailsTask?.cancel()
        state = .idle
        routeWalk = nil
        details = [:]
        selectedID = nil
        detailItem = nil
    }

    private func find(from origin: Origin) async {
        do {
            let results = try await finder.nearest(to: origin.coordinate)
            guard !Task.isCancelled else { return }
            await show(results, from: origin)
        } catch {
            guard !Task.isCancelled else { return }
            fail(SearchFailure(error), near: origin)
        }
    }

    private func show(_ results: PharmacyResults, from origin: Origin) async {
        let count = results.pharmacies.count
        guard let nearest = results.pharmacies.first else {
            state = .empty(radiusKilometers: results.radiusKilometers)
            VoiceOver.announce("No pharmacies found within \(results.radiusKilometers) kilometres.")
            return
        }
        selectedID = nearest.id
        state = .ready(origin, results.pharmacies)
        // VoiceOver's focus moves to the nearest one, which reads its name and distance.
        let found = count == 1 ? "1 pharmacy found." : "\(count) pharmacies found."
        VoiceOver.announce(origin.isApproximate ? "\(found) Your location is approximate." : found)

        async let walk: Void = loadWalk(from: origin, to: nearest)
        async let place: Void = loadPlace(of: nearest)
        _ = await (walk, place)
    }

    /// Skipped when the origin is approximate: a route would look more precise than it is.
    private func loadWalk(from origin: Origin, to pharmacy: Pharmacy) async {
        guard pharmacy.isWalkable, !origin.isApproximate else { return }
        let walk = try? await maps.walkingTime(from: origin.coordinate, to: pharmacy)
        guard !Task.isCancelled else { return }
        routeWalk = walk
    }

    /// Finds the phone number without a tap. A failure stays silent, because Details tries again.
    private func loadPlace(of pharmacy: Pharmacy) async {
        do {
            let item = try await maps.mapItem(for: pharmacy)
            // A tap on Details is already asking the same question.
            guard !Task.isCancelled, details[pharmacy.id] != .loading else { return }
            details[pharmacy.id] = item.map(PlaceDetails.found) ?? .unmatched
        } catch {}
    }

    private func fail(_ failure: SearchFailure, near origin: Origin?) {
        state = .failed(failure, origin)
        VoiceOver.announce(failure.message)
    }

    // MARK: - One pharmacy

    /// For taps in the list. The map binds `selectedID` itself.
    func select(_ id: Pharmacy.ID) {
        selectedID = id
        listSelectionCount += 1
    }

    func showDetails(for pharmacy: Pharmacy) {
        cancelDetails()
        if case .found(let item) = details[pharmacy.id] {
            detailItem = item
            return
        }
        details[pharmacy.id] = .loading
        detailsTask = Task {
            do {
                let item = try await maps.mapItem(for: pharmacy)
                guard !Task.isCancelled else { return }
                details[pharmacy.id] = item.map(PlaceDetails.found) ?? .unmatched
                detailItem = item
            } catch {
                guard !Task.isCancelled else { return }
                details[pharmacy.id] = .failed
            }
            if let message = details[pharmacy.id]?.message { VoiceOver.announce(message) }
        }
    }

    func cancelDetails() {
        detailsTask?.cancel()
        details = details.filter { $0.value != .loading }
    }

    func openDirections(to pharmacy: Pharmacy) {
        maps.openDirections(to: pharmacy)
    }
}

extension PlaceDetails {
    var message: String? {
        switch self {
        case .loading, .found: nil
        case .unmatched: "Couldn't confidently match this in Apple Maps."
        case .failed: "Couldn't reach Apple Maps. Try again."
        }
    }

    var phoneURL: URL? {
        guard case .found(let item) = self else { return nil }
        return item.phoneNumber.flatMap(WebLink.call)
    }
}

extension SearchFailure {
    var message: String {
        switch self {
        case .offline: "You're offline."
        case .serviceUnavailable: "The search service couldn't be reached. This doesn't mean there are no pharmacies nearby."
        case .locationUnavailable: "Your location couldn't be found."
        }
    }
}
