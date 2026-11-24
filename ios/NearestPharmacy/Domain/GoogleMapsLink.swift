import Foundation

extension Pharmacy {
    /// A Google Maps search for this pharmacy. Needs no API key.
    var googleMapsURL: URL? {
        let place = address ?? "\(coordinate.latitude),\(coordinate.longitude)"
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
