import SwiftUI

/// Every state between the start screen and the results.
struct SearchStatusView: View {
    let model: AppModel
    let search: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        switch model.state {
        case .locating: locating
        case .loading(let origin): loading(origin)
        case .denied: denied
        case .empty(let radiusKilometers): empty(radiusKilometers)
        case .failed(let failure, let origin): failed(failure, near: origin)
        case .idle, .ready: EmptyView()
        }
    }

    private var locating: some View {
        StatusView(
            icon: nil,
            title: "Finding your location",
            message: "Allow location access if iOS asks."
        ) {
            secondarySearch
        }
    }

    private func loading(_ origin: Origin) -> some View {
        StatusView(
            icon: nil,
            title: "Finding pharmacies",
            message: "Looking near \(origin.labelInSentence)."
        ) {
            SkeletonRows()
        }
    }

    private var denied: some View {
        StatusView(
            icon: "location.slash",
            title: "Location is off",
            message: "Search for an address instead, or allow location in Settings."
        ) {
            primarySearch
            Button("Try again", action: model.retry)
                .buttonStyle(.secondaryPill)
            openSettings
        }
    }

    private func empty(_ radiusKilometers: Int) -> some View {
        StatusView(
            icon: "mappin.slash",
            title: "No pharmacies found",
            message: "There are none in OpenStreetMap within \(radiusKilometers) km."
        ) {
            primarySearch
            searchInAppleMaps(near: nil)
        }
    }

    @ViewBuilder
    private func failed(_ failure: SearchFailure, near origin: Origin?) -> some View {
        switch failure {
        case .offline:
            StatusView(
                icon: "wifi.slash",
                title: "You're offline",
                message: "Check your connection and try again."
            ) {
                tryAgain
                searchInAppleMaps(near: origin)
            }
        case .serviceUnavailable:
            StatusView(
                icon: "exclamationmark.triangle",
                title: "Pharmacy search isn't responding",
                message: failure.message
            ) {
                tryAgain
                secondarySearch
                searchInAppleMaps(near: origin)
            }
        case .locationUnavailable:
            StatusView(
                icon: "location.slash",
                title: "Couldn't find your location",
                message: "Try again, or search for a place."
            ) {
                tryAgain
                secondarySearch
                openSettings
            }
        }
    }

    private var tryAgain: some View {
        Button("Try again", action: model.retry)
            .buttonStyle(.primaryPill)
    }

    private var primarySearch: some View {
        Button("Search for a place", action: search)
            .buttonStyle(.primaryPill)
    }

    private var secondarySearch: some View {
        Button("Search for a place", action: search)
            .buttonStyle(.secondaryPill)
    }

    @ViewBuilder
    private func searchInAppleMaps(near origin: Origin?) -> some View {
        if let url = WebLink.appleMapsPharmacies(near: origin) {
            Link("Search in Apple Maps", destination: url)
                .buttonStyle(.secondaryPill)
        }
    }

    private var openSettings: some View {
        Button("Open Settings") {
            if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
        }
        .buttonStyle(.secondaryPill)
    }
}

struct StatusView<Actions: View>: View {
    /// Nil shows a spinner.
    let icon: String?
    let title: String
    let message: String
    @ViewBuilder let actions: Actions

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                symbol
                    .accessibilityHidden(true)
                Text(title)
                    .font(.title2.bold())
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(message)
                    .foregroundStyle(Theme.body)
                VStack(spacing: 12) { actions }
                    .padding(.top, 12)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: 560)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var symbol: some View {
        if let icon {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(Theme.action)
        } else {
            ProgressView()
                .controlSize(.large)
        }
    }
}

private struct SkeletonRows: View {
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    bar(width: 180)
                    bar(width: 120)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.sheet, in: .rect(cornerRadius: Theme.cardRadius))
            }
        }
        .accessibilityHidden(true)
    }

    private func bar(width: CGFloat) -> some View {
        Capsule()
            .fill(Theme.hairline)
            .frame(width: width, height: 12)
    }
}
