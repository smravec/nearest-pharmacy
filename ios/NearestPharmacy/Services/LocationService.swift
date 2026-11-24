import CoreLocation

/// A single position fix. Permission is only requested once `current()` is called.
@MainActor
final class LocationService: LocationProviding {
    private nonisolated static let goodAccuracyMeters = 100.0
    private nonisolated static let maximumAge: TimeInterval = 60
    private static let fixTimeout: Duration = .seconds(12)

    func current() async throws -> Origin {
        let session = CLServiceSession(authorization: .whenInUse)
        defer { session.invalidate() }

        do {
            let fix = try await fix()
            return Origin(
                coordinate: Coordinate(
                    latitude: fix.coordinate.latitude,
                    longitude: fix.coordinate.longitude
                ),
                label: "Your location",
                source: .gps,
                accuracyMeters: fix.horizontalAccuracy
            )
        } catch let error as LocationError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw Task.isCancelled ? CancellationError() : LocationError.unavailable
        }
    }

    private func fix() async throws -> CLLocation {
        let best = BestFix()
        let final = try await withThrowingTaskGroup(of: CLLocation?.self) { group in
            defer { group.cancelAll() }
            group.addTask { try await Self.goodFix(recordingInto: best) }
            group.addTask {
                try await Self.waitForDeadline()
                return nil
            }
            return try await group.next() ?? nil
        }
        try Task.checkCancellation()

        if let final { return final }
        guard let fallback = await best.location else { throw LocationError.unavailable }
        return fallback
    }

    private nonisolated static func goodFix(recordingInto best: BestFix) async throws -> CLLocation? {
        for try await update in CLLocationUpdate.liveUpdates(.default) {
            if update.authorizationDenied || update.authorizationDeniedGlobally || update.authorizationRestricted {
                throw LocationError.denied
            }
            guard !update.authorizationRequestInProgress,
                  let location = update.location,
                  location.horizontalAccuracy >= 0,
                  abs(location.timestamp.timeIntervalSinceNow) <= maximumAge
            else { continue }

            await best.record(location)
            if location.horizontalAccuracy <= goodAccuracyMeters || update.accuracyLimited {
                return location
            }
        }
        return nil
    }

    /// Polls the permission instead of relying on the order of the first updates, and only
    /// starts the clock once it is decided, so reading the prompt doesn't use up the time.
    private static func waitForDeadline() async throws {
        while true {
            switch CLLocationManager().authorizationStatus {
            case .notDetermined:
                try await Task.sleep(for: .milliseconds(250))
            case .denied, .restricted:
                throw LocationError.denied
            default:
                return try await Task.sleep(for: fixTimeout)
            }
        }
    }
}

/// The most accurate fix so far, in case no good one arrives in time.
private actor BestFix {
    private(set) var location: CLLocation?

    func record(_ candidate: CLLocation) {
        if let location, location.horizontalAccuracy <= candidate.horizontalAccuracy { return }
        location = candidate
    }
}
