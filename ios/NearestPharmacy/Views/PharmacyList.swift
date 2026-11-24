import SwiftUI

/// The pharmacies after the nearest one, which has its own card.
struct PharmacyList: View {
    let model: AppModel
    let others: [Pharmacy]

    var body: some View {
        if !others.isEmpty {
            Text("Other pharmacies")
                .font(.headline)
                .foregroundStyle(Theme.ink)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, 8)
            ForEach(Array(others.enumerated()), id: \.element.id) { index, pharmacy in
                PharmacyRow(model: model, pharmacy: pharmacy, rank: index + 2)
                    .id(pharmacy.id)
            }
        }
    }
}

private struct PharmacyRow: View {
    let model: AppModel
    let pharmacy: Pharmacy
    let rank: Int

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                model.select(pharmacy.id)
            } label: {
                summary
            }
            .buttonStyle(.plain)
            .accessibilityLabel(spokenSummary)
            .accessibilityHint("Shows it on the map")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityAction(named: "Directions") { model.openDirections(to: pharmacy) }
            .accessibilityAction(named: "Hours and details") { model.showDetails(for: pharmacy) }

            if isSelected {
                PharmacyActions(model: model, pharmacy: pharmacy)
            }
        }
        .pharmacyCard(isSelected: isSelected)
    }

    private var summary: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))

        return layout {
            Text(rank, format: .number)
                .monospacedDigit()
                .foregroundStyle(Theme.muted)
            VStack(alignment: .leading, spacing: 2) {
                Text(pharmacy.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                if let address = pharmacy.address {
                    Text(address)
                        .font(.subheadline)
                        .foregroundStyle(Theme.muted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // No walking time: a straight-line estimate would look faster than the nearest one's route.
            Text(Format.distance(pharmacy.distanceMeters))
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, minHeight: Theme.minimumTarget, alignment: .leading)
        .contentShape(.rect)
    }

    private var isSelected: Bool {
        model.selectedID == pharmacy.id
    }

    private var spokenSummary: String {
        [
            pharmacy.name,
            Format.spokenDistance(pharmacy.distanceMeters),
            pharmacy.address,
        ]
        .compactMap(\.self)
        .joined(separator: ", ")
    }
}

struct AttributionView: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 0) {
                openStreetMap
                Text(", ")
                photon
            }
            .buttonStyle(.textLink)
            // The targets reach away from each other, so the two lines of text stay together.
            VStack(alignment: .leading, spacing: 0) {
                openStreetMap
                    .buttonStyle(TextLinkStyle(alignment: .bottomLeading))
                photon
                    .buttonStyle(TextLinkStyle(alignment: .topLeading))
            }
        }
        .foregroundStyle(Theme.body)
    }

    private var openStreetMap: some View {
        CreditLink(title: "© OpenStreetMap contributors (ODbL)", address: CreditLink.openStreetMap)
    }

    private var photon: some View {
        CreditLink(title: "search by Photon", address: CreditLink.photon)
    }
}

struct CreditLink: View {
    static let openStreetMap = "https://www.openstreetmap.org/copyright"
    static let photon = "https://photon.komoot.io"

    let title: String
    let address: String

    var body: some View {
        if let url = URL(string: address) {
            Link(title, destination: url)
        }
    }
}
