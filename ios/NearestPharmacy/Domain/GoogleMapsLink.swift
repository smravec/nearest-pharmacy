import Foundation

extension Pharmacy {
    /// A Google Maps search for this pharmacy. Needs no API key.
    var googleMapsURL: URL? {
        let position = String(
            format: "%.6f,%.6f",
            locale: Locale(identifier: "en_US_POSIX"),
            coordinate.latitude,
            coordinate.longitude
        )
        let place = address ?? position
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.google.com"
        components.path = "/maps/search/"
        components.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "query", value: "\(name), \(place)"),
        ]
        // A plus sign would be read as a space.
        components.percentEncodedQuery = components.percentEncodedQuery?
            .replacingOccurrences(of: "+", with: "%2B")
        return components.url
    }
}
