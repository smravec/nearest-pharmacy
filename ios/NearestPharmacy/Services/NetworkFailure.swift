import Foundation

extension SearchFailure {
    init(_ error: any Error) {
        self = switch Self.networkCode(in: error) {
        case NSURLErrorNotConnectedToInternet, NSURLErrorDataNotAllowed, NSURLErrorInternationalRoamingOff: .offline
        default: error as? SearchFailure ?? .serviceUnavailable
        }
    }

    /// MapKit may wrap the network error, so this looks through the underlying errors.
    static func networkCode(in error: any Error) -> Int? {
        let error = error as NSError
        if error.domain == NSURLErrorDomain { return error.code }
        return error.underlyingErrors.lazy.compactMap { networkCode(in: $0) }.first
    }
}
