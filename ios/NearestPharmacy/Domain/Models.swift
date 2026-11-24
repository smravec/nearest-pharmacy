import Foundation
import MapKit

struct Coordinate: Hashable, Sendable {
    let latitude: Double
    let longitude: Double

    var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// The point distances are measured from.
struct Origin: Equatable, Sendable {
    enum Source: Sendable {
        case gps
        case search
    }

    let coordinate: Coordinate
    let label: String
    let source: Source
    var accuracyMeters: Double?

    /// True when iOS only shared an approximate position, so distances are rough.
    var isApproximate: Bool {
        guard let accuracyMeters else { return false }
        return accuracyMeters > 500
    }
}

struct Pharmacy: Identifiable, Hashable, Sendable {
    /// OpenStreetMap identifier, for example `node/668244336`.
    let id: String
    let name: String
    let coordinate: Coordinate
    let address: String?
    /// Straight-line distance from the origin.
    let distanceMeters: Double
    let walkMinutes: Int
}

struct PharmacyResults: Equatable, Sendable {
    /// Sorted by distance, closest first.
    let pharmacies: [Pharmacy]
    let radiusKilometers: Int
}

enum SearchState: Equatable, Sendable {
    case idle
    case locating
    /// Location can't be used, so the person has to search for a place.
    case denied
    case loading
    case ready(PharmacyResults)
    case empty(radiusKilometers: Int)
    case failed(SearchFailure)
}

enum SearchFailure: Error, Equatable, Sendable {
    case offline
    case serviceUnavailable
    case locationUnavailable
    case placeNotFound
}

enum LocationError: Error, Equatable, Sendable {
    case denied
    case unavailable
}

struct PlaceSuggestion: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String

    /// The title alone may name several places.
    var fullName: String {
        [title, subtitle].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

protocol PharmacyFinding: Sendable {
    /// Throws `SearchFailure` or `CancellationError`.
    /// Returns an empty list only when the service answered and found nothing in the widest radius.
    func nearest(to origin: Coordinate) async throws -> PharmacyResults
}

@MainActor
protocol LocationProviding: AnyObject {
    /// Asks for permission if needed. Throws `LocationError` or `CancellationError`.
    func current() async throws -> Origin
}

@MainActor
protocol PlaceSearching: AnyObject {
    /// Called whenever the suggestions change.
    var onSuggestions: (([PlaceSuggestion]) -> Void)? { get set }
    func update(query: String)
    /// Throws `SearchFailure` or `CancellationError`.
    func resolve(_ suggestion: PlaceSuggestion) async throws -> Origin
    func resolve(text: String) async throws -> Origin
}

@MainActor
protocol PlaceDetailing: AnyObject {
    /// The Apple Maps place for this pharmacy, or nil when none matches confidently.
    /// Throws `SearchFailure` or `CancellationError`.
    func mapItem(for pharmacy: Pharmacy) async throws -> MKMapItem?
}
