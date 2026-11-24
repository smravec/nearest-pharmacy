import SwiftUI

/// Every state between the start screen and the results.
struct SearchStatusView: View {
    let model: AppModel
    let search: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        switch model.state {
        case .locating: locating
        case .loading: loading
        case .denied: denied
        case .empty(let radiusKilometers): empty(radiusKilometers)
        case .failed(let failure): failed(failure)
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

    private var loading: some View {
        StatusView(
            icon: nil,
            title: "Finding pharmacies",
            message: "Looking near \(model.origin?.labelInSentence ?? "you")."
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
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .buttonStyle(SecondaryPillStyle())
        }
    }

    private func empty(_ radiusKilometers: Int) -> some View {
        StatusView(
            icon: "mappin.slash",
            title: "No pharmacies found",
            message: "There are none in OpenStreetMap within \(radiusKilometers) km."
        ) {
            primarySearch
        }
    }

    @ViewBuilder
    private func failed(_ failure: SearchFailure) -> some View {
        switch failure {
        case .offline:
            StatusView(
                icon: "wifi.slash",
                title: "You're offline",
                message: "Check your connection and try again."
            ) {
                tryAgain
            }
        case .serviceUnavailable:
            StatusView(
                icon: "exclamationmark.triangle",
                title: "Pharmacy search isn't responding",
                message: "This is a problem with the search service, not a sign that there are no pharmacies nearby."
            ) {
                tryAgain
                secondarySearch
            }
        case .locationUnavailable:
            StatusView(
                icon: "location.slash",
                title: "Couldn't find your location",
                message: "Try again, or search for a place."
            ) {
                tryAgain
                secondarySearch
            }
        case .placeNotFound:
            StatusView(
                icon: "magnifyingglass",
                title: "Place not found",
                message: "Try a different address or place."
            ) {
                primarySearch
            }
        }
    }

    private var tryAgain: some View {
        Button("Try again", action: model.retry)
            .buttonStyle(PrimaryPillStyle())
    }

    private var primarySearch: some View {
        Button("Search for a place", action: search)
            .buttonStyle(PrimaryPillStyle())
    }

    private var secondarySearch: some View {
        Button("Search for a place", action: search)
            .buttonStyle(SecondaryPillStyle())
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
