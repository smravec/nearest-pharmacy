import Foundation

/// Distances and walking times, always metric, as shown and as spoken by VoiceOver.
enum Format {
    private static let locale = Locale(identifier: "en_GB")

    static func distance(_ meters: Double) -> String {
        let length = Length(meters: meters)
        return "\(length.number) \(length.isKilometers ? "km" : "m")"
    }

    static func spokenDistance(_ meters: Double) -> String {
        let length = Length(meters: meters)
        guard length.isKilometers else { return "\(length.number) metres" }
        return length.number == "1.0" ? "1 kilometre" : "\(length.number) kilometres"
    }

    static func walk(_ minutes: Int) -> String {
        let (hours, rest) = minutes.quotientAndRemainder(dividingBy: 60)
        if hours == 0 { return "~\(rest) min walk" }
        return rest == 0 ? "~\(hours) h walk" : "~\(hours) h \(rest) min walk"
    }

    static func spokenWalk(_ minutes: Int) -> String {
        let (hours, rest) = minutes.quotientAndRemainder(dividingBy: 60)
        let hourPart = hours == 1 ? "1 hour" : "\(hours) hours"
        let minutePart = rest == 1 ? "1 minute" : "\(rest) minutes"

        let duration: String
        if hours == 0 {
            duration = minutePart
        } else {
            duration = rest == 0 ? hourPart : "\(hourPart) \(minutePart)"
        }
        return "about \(duration)\(duration.hasSuffix("s") ? "'" : "'s") walk"
    }

    private struct Length {
        let number: String
        let isKilometers: Bool

        init(meters: Double) {
            let roundedMeters = (meters / 10).rounded() * 10
            isKilometers = roundedMeters >= 1000
            guard isKilometers else {
                number = Format.number(max(roundedMeters, 10), decimals: 0)
                return
            }
            // Decimals depend on the rounded value, so 9.96 km becomes "10", not "10.0".
            let tenths = (meters / 100).rounded()
            number = tenths < 100
                ? Format.number(tenths / 10, decimals: 1)
                : Format.number((meters / 1000).rounded(), decimals: 0)
        }
    }

    private static func number(_ value: Double, decimals: Int) -> String {
        value.formatted(.number.precision(.fractionLength(decimals)).locale(locale))
    }
}
