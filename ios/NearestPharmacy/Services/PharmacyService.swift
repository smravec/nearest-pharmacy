import Foundation

protocol PharmacyFinding: Sendable {
    /// Returns an empty list only when the service answered and found nothing in the whole radius.
    func nearest(to origin: Coordinate) async throws -> PharmacyResults
}

/// Finds pharmacies in OpenStreetMap through Photon's public geocoder.
struct PhotonPharmacyService: PharmacyFinding {
    private static let radiusKilometers = 100

    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 8
        configuration.httpAdditionalHeaders = ["User-Agent": "NearestPharmacy-iOS/1.0"]
        session = URLSession(configuration: configuration)
    }

    func nearest(to origin: Coordinate) async throws -> PharmacyResults {
        do {
            let (data, response) = try await session.data(from: Self.url(near: origin))
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw SearchFailure.serviceUnavailable
            }
            return PharmacyResults(
                pharmacies: try Self.pharmacies(in: data, from: origin),
                radiusKilometers: Self.radiusKilometers
            )
        } catch {
            throw Task.isCancelled ? CancellationError() : SearchFailure(error)
        }
    }

    /// Photon gets the position rounded to about 100 m; the exact distances are worked out here.
    private static func url(near origin: Coordinate) throws -> URL {
        var components = URLComponents(string: "https://photon.komoot.io/reverse")
        components?.queryItems = [
            URLQueryItem(name: "lat", value: Coordinate.degrees(origin.latitude, decimals: 3)),
            URLQueryItem(name: "lon", value: Coordinate.degrees(origin.longitude, decimals: 3)),
            URLQueryItem(name: "osm_tag", value: "amenity:pharmacy"),
            URLQueryItem(name: "radius", value: String(radiusKilometers)),
            URLQueryItem(name: "limit", value: "30"),
            URLQueryItem(name: "lang", value: "default"),
        ]
        guard let url = components?.url else { throw SearchFailure.serviceUnavailable }
        return url
    }

    private static func pharmacies(in data: Data, from origin: Coordinate) throws -> [Pharmacy] {
        let features = try JSONDecoder().decode(PhotonResponse.self, from: data).features
        let usable = features.compactMap { $0.value?.pharmacy(from: origin) }
        // Unreadable results must not look like "no pharmacies here".
        guard features.isEmpty || !usable.isEmpty else { throw SearchFailure.serviceUnavailable }

        var seen = Set<Pharmacy.ID>()
        return usable
            .filter { seen.insert($0.id).inserted }
            .sorted { ($0.distanceMeters, $0.id) < ($1.distanceMeters, $1.id) }
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
        return Pharmacy(
            id: id,
            name: properties.name.nonBlank ?? "Pharmacy",
            coordinate: coordinate,
            address: address,
            distanceMeters: origin.meters(to: coordinate)
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
