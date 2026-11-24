import Foundation

/// Distances and walking times, always metric, as shown and as spoken by VoiceOver.
enum Format {
    private static let locale = Locale(identifier: "en_GB")

    static func distance(_ meters: Double) -> String {
        length(meters, width: .abbreviated)
    }

    static func spokenDistance(_ meters: Double) -> String {
        length(meters, width: .wide)
    }

    /// The tilde marks an estimate.
    static func walk(_ walk: WalkingTime) -> String {
        "\(walk.isEstimate ? "~" : "")\(duration(walk, width: .abbreviated)) walk"
    }

    static func spokenWalk(_ walk: WalkingTime) -> String {
        "\(walk.isEstimate ? "about " : "")\(duration(walk, width: .wide)) on foot"
    }

    private static func length(
        _ meters: Double,
        width: Measurement<UnitLength>.FormatStyle.UnitWidth
    ) -> String {
        let tens = max(10, (meters / 10).rounded() * 10)
        let kilometers = (meters / 100).rounded() / 10
        let value = tens < 1000
            ? Measurement(value: tens, unit: UnitLength.meters)
            : Measurement(value: kilometers < 10 ? kilometers : kilometers.rounded(), unit: .kilometers)
        let style = Measurement<UnitLength>.FormatStyle(
            width: width,
            locale: locale,
            usage: .asProvided,
            numberFormatStyle: .number.precision(.fractionLength(0...1)).locale(locale)
        )
        return value.formatted(style)
    }

    private static func duration(_ walk: WalkingTime, width: Duration.UnitsFormatStyle.UnitWidth) -> String {
        Duration.seconds(walk.minutes * 60)
            .formatted(.units(allowed: [.hours, .minutes], width: width).locale(locale))
    }
}
