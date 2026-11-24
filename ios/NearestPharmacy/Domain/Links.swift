import Foundation

enum WebLink {
    static func appleMapsPharmacies(near origin: Origin?) -> URL? {
        var items = [URLQueryItem(name: "q", value: "pharmacy")]
        if let origin {
            items.append(URLQueryItem(name: "sll", value: origin.coordinate.queryValue))
        }
        return url("https://maps.apple.com/", items)
    }

    /// A Google Maps search for this pharmacy. Needs no API key.
    static func googleMaps(_ pharmacy: Pharmacy) -> URL? {
        url("https://www.google.com/maps/search/", [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(
                name: "query",
                value: "\(pharmacy.name), \(pharmacy.address ?? pharmacy.coordinate.queryValue)"
            ),
        ])
    }

    static func call(_ phoneNumber: String) -> URL? {
        let digits = phoneNumber.filter { $0.isASCII && $0.isNumber }
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel:\(phoneNumber.hasPrefix("+") ? "+" : "")\(digits)")
    }

    private static func url(_ base: String, _ items: [URLQueryItem]) -> URL? {
        guard var components = URLComponents(string: base) else { return nil }
        components.queryItems = items
        // A plus sign would be read as a space.
        let query = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        components.percentEncodedQuery = query
        return components.url
    }
}
