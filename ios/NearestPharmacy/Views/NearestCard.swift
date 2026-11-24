import SwiftUI

struct NearestCard: View {
    let model: AppModel
    let pharmacy: Pharmacy
    let focus: AccessibilityFocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                model.select(pharmacy.id)
            } label: {
                summary
            }
            .buttonStyle(.plain)
            .accessibilityLabel(spokenSummary)
            .accessibilityAddTraits(isSelected ? [.isHeader, .isSelected] : .isHeader)
            .accessibilityFocused(focus)

            PharmacyActions(model: model, pharmacy: pharmacy)
        }
        .pharmacyCard(isSelected: isSelected)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Nearest")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.tealText)
            Text(pharmacy.name)
                .font(.title2.bold())
                .foregroundStyle(Theme.ink)
            Text("\(Format.distance(pharmacy.distanceMeters)) · \(Format.walk(pharmacy.walkMinutes))")
                .monospacedDigit()
                .foregroundStyle(Theme.body)
            if let address = pharmacy.address {
                Text(address)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
            Text("Straight-line distance; walking time is an estimate at 5 km/h.")
                .font(.caption)
                .foregroundStyle(Theme.muted)
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
            "Nearest pharmacy: \(pharmacy.name)",
            "\(Format.spokenDistance(pharmacy.distanceMeters)) in a straight line",
            Format.spokenWalk(pharmacy.walkMinutes),
            pharmacy.address,
        ]
        .compactMap(\.self)
        .joined(separator: ", ")
    }
}

extension View {
    /// The bar marks the pharmacy selected on the map.
    func pharmacyCard(isSelected: Bool) -> some View {
        padding()
            .background(Theme.sheet)
            .overlay(alignment: .leading) {
                if isSelected {
                    Theme.teal.frame(width: 3)
                }
            }
            .clipShape(.rect(cornerRadius: Theme.cardRadius))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cardRadius).strokeBorder(Theme.hairline)
            }
    }
}

struct PharmacyActions: View {
    let model: AppModel
    let pharmacy: Pharmacy

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { buttons }
                VStack(alignment: .leading, spacing: 12) { buttons }
            }
            if let detailsMessage {
                Text(detailsMessage)
                    .font(.subheadline)
                    .foregroundStyle(Theme.body)
            }
        }
    }

    private var detailsMessage: String? {
        switch pharmacy.id {
        case model.detailsUnavailableID: "Apple Maps has no details for this pharmacy."
        case model.detailsFailedID: "Couldn't reach Apple Maps. Try again."
        default: nil
        }
    }

    @ViewBuilder
    private var buttons: some View {
        Button {
            model.openDirections(to: pharmacy)
        } label: {
            Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
        }
        .buttonStyle(PrimaryPillStyle())
        .accessibilityHint("Opens Apple Maps")

        Button {
            model.showDetails(for: pharmacy)
        } label: {
            if isLoadingDetails {
                HStack(spacing: 8) {
                    ProgressView().accessibilityHidden(true)
                    Text("Loading details")
                }
            } else {
                Text("Details")
            }
        }
        .buttonStyle(SecondaryPillStyle())
        .disabled(isLoadingDetails)
        .accessibilityHint("Shows Apple Maps information")
    }

    private var isLoadingDetails: Bool {
        model.detailsLoadingID == pharmacy.id
    }
}
