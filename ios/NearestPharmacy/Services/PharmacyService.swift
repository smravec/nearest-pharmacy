import Foundation

/// Finds pharmacies in OpenStreetMap through Photon's public geocoder.
struct PhotonPharmacyService: PharmacyFinding {
    private static let radiiKilometers = [5, 15, 50, 100]
    private static let totalTimeout: Duration = .seconds(15)

    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 8
        configuration.httpAdditionalHeaders = ["User-Agent": "NearestPharmacy-iOS/1.0"]
        session = URLSession(configuration: configuration)
    }

    func nearest(to origin: Coordinate) async throws -> PharmacyResults {
        try await withThrowingTaskGroup(of: PharmacyResults.self) { group in
            defer { group.cancelAll() }
            group.addTask { try await search(from: origin) }
            group.addTask {
                try await Task.sleep(for: Self.totalTimeout)
                throw SearchFailure.serviceUnavailable
            }
            guard let results = try await group.next() else { throw SearchFailure.serviceUnavailable }
            return results
        }
    }

    /// Widens the radius until something is found, so nearby searches stay small.
    private func search(from origin: Coordinate) async throws -> PharmacyResults {
        var lastRadius = 0
        for radius in Self.radiiKilometers {
            try Task.checkCancellation()
            lastRadius = radius
            let pharmacies = try await pharmacies(within: radius, of: origin)
            if !pharmacies.isEmpty {
                return PharmacyResults(pharmacies: pharmacies, radiusKilometers: radius)
            }
        }
        return PharmacyResults(pharmacies: [], radiusKilometers: lastRadius)
    }

    private func pharmacies(within radius: Int, of origin: Coordinate) async throws -> [Pharmacy] {
        do {
            let (data, response) = try await session.data(from: url(origin: origin, radius: radius))
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw SearchFailure.serviceUnavailable
            }
            return try Self.pharmacies(in: data, within: radius, of: origin)
        } catch {
            throw Self.mapped(error)
        }
    }

    private func url(origin: Coordinate, radius: Int) throws -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "photon.komoot.io"
        components.path = "/reverse"
        components.queryItems = [
            URLQueryItem(name: "lat", value: Self.degrees(origin.latitude)),
            URLQueryItem(name: "lon", value: Self.degrees(origin.longitude)),
            URLQueryItem(name: "osm_tag", value: "amenity:pharmacy"),
            URLQueryItem(name: "radius", value: String(radius)),
            URLQueryItem(name: "limit", value: "30"),
            URLQueryItem(name: "lang", value: "default"),
        ]
        guard let url = components.url else { throw SearchFailure.serviceUnavailable }
        return url
    }

    private static func degrees(_ value: Double) -> String {
        String(format: "%.5f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private static func pharmacies(in data: Data, within radius: Int, of origin: Coordinate) throws -> [Pharmacy] {
        let features = try JSONDecoder().decode(PhotonResponse.self, from: data).features
        let usable = features.compactMap { $0.value?.pharmacy(from: origin) }
        // Unreadable results must not look like "no pharmacies here".
        guard features.isEmpty || !usable.isEmpty else { throw SearchFailure.serviceUnavailable }

        // Photon's radius is not exact, hence the 5% slack.
        let limitMeters = Double(radius) * 1000 * 1.05
        var seen = Set<Pharmacy.ID>()
        return usable
            .filter { $0.distanceMeters <= limitMeters && seen.insert($0.id).inserted }
            .sorted { ($0.distanceMeters, $0.id) < ($1.distanceMeters, $1.id) }
    }

    private static func mapped(_ error: any Error) -> any Error {
        switch error {
        case is CancellationError:
            return error
        case let error as URLError:
            switch error.code {
            case .cancelled:
                return CancellationError()
            case .notConnectedToInternet, .dataNotAllowed, .internationalRoamingOff:
                return SearchFailure.offline
            default:
                return SearchFailure.serviceUnavailable
            }
        default:
            return SearchFailure.serviceUnavailable
        }
    }
}

// MARK: - Photon response

private struct PhotonResponse: Decodable {
    let features: [Lossy<PhotonFeature>]
}

/// Keeps one malformed element from failing the whole array.
private struct Lossy<Value: Decodable>: Decodable {
    let value: Value?

    init(from decoder: any Decoder) {
        value = try? Value(from: decoder)
    }
}

private struct PhotonFeature: Decodable {
    struct Geometry: Decodable {
        /// GeoJSON order: longitude, then latitude.
        let coordinates: [Double]
    }

    struct Properties: Decodable {
        let osmType: String
        let osmID: Int64
        let osmValue: String
        let name: String?
        let street: String?
        let housenumber: String?
        let locality: String?
        let postcode: String?
        let city: String?

        enum CodingKeys: String, CodingKey {
            case osmType = "osm_type"
            case osmID = "osm_id"
            case osmValue = "osm_value"
            case name, street, housenumber, locality, postcode, city
        }
    }

    let geometry: Geometry
    let properties: Properties

    /// Nil when this isn't a pharmacy with a usable id and position.
    func pharmacy(from origin: Coordinate) -> Pharmacy? {
        guard properties.osmValue == "pharmacy", let id, let coordinate else { return nil }
        let meters = Distance.meters(from: origin, to: coordinate)
        return Pharmacy(
            id: id,
            name: properties.name.nonBlank ?? "Pharmacy",
            coordinate: coordinate,
            address: address,
            distanceMeters: meters,
            walkMinutes: Distance.walkMinutes(meters: meters)
        )
    }

    private var id: String? {
        switch properties.osmType {
        case "N": "node/\(properties.osmID)"
        case "W": "way/\(properties.osmID)"
        case "R": "relation/\(properties.osmID)"
        default: nil
        }
    }

    private var coordinate: Coordinate? {
        let values = geometry.coordinates
        // The ranges also reject NaN and infinity.
        guard values.count >= 2,
              (-180...180).contains(values[0]),
              (-90...90).contains(values[1])
        else { return nil }
        return Coordinate(latitude: values[1], longitude: values[0])
    }

    private var address: String? {
        let street = properties.street.nonBlank.map { street in
            [street, properties.housenumber.nonBlank].compactMap { $0 }.joined(separator: " ")
        }
        let town = [properties.postcode.nonBlank, properties.city.nonBlank]
            .compactMap { $0 }
            .joined(separator: " ")
        return [street ?? properties.locality.nonBlank, town]
            .compactMap(\.nonBlank)
            .joined(separator: ", ")
            .nonBlank
    }
}

private extension String {
    var nonBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension String? {
    var nonBlank: String? { flatMap(\.nonBlank) }
}

// MARK: - Debugging

#if DEBUG
/// Fails the first search, to exercise the error screen and its retry button.
actor FailOnceFinder: PharmacyFinding {
    private let base: any PharmacyFinding
    private var hasFailed = false

    init(base: any PharmacyFinding) {
        self.base = base
    }

    func nearest(to origin: Coordinate) async throws -> PharmacyResults {
        guard hasFailed else {
            hasFailed = true
            throw SearchFailure.serviceUnavailable
        }
        return try await base.nearest(to: origin)
    }
}
#endif
