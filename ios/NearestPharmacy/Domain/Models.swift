import CoreLocation

struct Coordinate: Hashable, Sendable {
    let latitude: Double
    let longitude: Double

    var clLocationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Straight-line distance.
    func meters(to other: Coordinate) -> Double {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }

    /// "60.1719,24.9414", as map links expect it.
    var queryValue: String {
        "\(Self.degrees(latitude, decimals: 6)),\(Self.degrees(longitude, decimals: 6))"
    }

    static func degrees(_ value: Double, decimals: Int) -> String {
        String(format: "%.\(decimals)f", locale: Locale(identifier: "en_US_POSIX"), value)
    }
}

extension Coordinate {
    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

/// The point distances are measured from.
struct Origin: Equatable, Sendable {
    static let goodAccuracyMeters = 100.0

    let coordinate: Coordinate
    /// Nil for the device's own position.
    var placeName: String?
    var accuracyMeters: Double?

    /// Too rough to say which pharmacy is nearest.
    var isApproximate: Bool {
        (accuracyMeters ?? 0) > Self.goodAccuracyMeters
    }

    var labelInSentence: String { placeName ?? "your location" }
}

struct Pharmacy: Identifiable, Hashable, Sendable {
    private static let walkableMeters = 3000.0
    private static let walkingMetersPerSecond = 5000.0 / 3600

    /// OpenStreetMap identifier, for example `node/668244336`.
    let id: String
    let name: String
    let coordinate: Coordinate
    let address: String?
    /// Straight-line distance from the origin.
    let distanceMeters: Double

    var isWalkable: Bool { distanceMeters <= Self.walkableMeters }

    /// Nil when it is too far to suggest walking.
    var estimatedWalk: WalkingTime? {
        guard isWalkable else { return nil }
        return WalkingTime(seconds: distanceMeters / Self.walkingMetersPerSecond, isEstimate: true)
    }
}

struct WalkingTime: Equatable, Sendable {
    let minutes: Int
    /// From the straight line, not from a route.
    let isEstimate: Bool

    init(seconds: TimeInterval, isEstimate: Bool) {
        minutes = max(1, Int((seconds / 60).rounded(.up)))
        self.isEstimate = isEstimate
    }
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
    case loading(Origin)
    case ready(Origin, [Pharmacy])
    case empty(Origin, radiusKilometers: Int)
    /// The origin is nil when finding it is what failed.
    case failed(SearchFailure, Origin?)
}

enum SearchFailure: Error, Equatable, Sendable {
    case offline
    case serviceUnavailable
    case locationUnavailable
}

enum LocationError: Error, Equatable, Sendable {
    case denied
    case unavailable
}
