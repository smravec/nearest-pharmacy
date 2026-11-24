import Foundation

enum Distance {
    private static let earthRadiusMeters = 6_371_008.8
    private static let walkingMetersPerMinute = 5000.0 / 60

    /// Straight-line (haversine) distance.
    static func meters(from: Coordinate, to: Coordinate) -> Double {
        let fromLatitude = radians(from.latitude)
        let toLatitude = radians(to.latitude)
        let halfLatitude = sin((toLatitude - fromLatitude) / 2)
        let halfLongitude = sin(radians(to.longitude - from.longitude) / 2)

        let a = halfLatitude * halfLatitude
            + cos(fromLatitude) * cos(toLatitude) * halfLongitude * halfLongitude
        // Rounding can push `a` just past 1 for antipodal points, where asin is undefined.
        return 2 * earthRadiusMeters * asin(min(max(a, 0), 1).squareRoot())
    }

    static func walkMinutes(meters: Double) -> Int {
        max(1, Int((meters / walkingMetersPerMinute).rounded(.up)))
    }

    private static func radians(_ degrees: Double) -> Double {
        degrees * .pi / 180
    }
}
