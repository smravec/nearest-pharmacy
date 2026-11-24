import SwiftUI

struct NearestCard: View {
    let model: AppModel
    let pharmacy: Pharmacy
    let isApproximate: Bool
    let focus: AccessibilityFocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                model.select(pharmacy.id)
            } label: {
                summary
            }
            .buttonStyle(.plain)
            .accessibilityLabel(spokenSummary)
            .accessibilityHint("Shows it on the map")
            .accessibilityAddTraits(isSelected ? [.isHeader, .isSelected] : .isHeader)
            .accessibilityFocused(focus)

            Label("Hours not checked. May have closed down.", systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(Theme.amber)

            PharmacyActions(model: model, pharmacy: pharmacy)
        }
        .pharmacyCard(isSelected: isSelected)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(isApproximate ? "Pharmacies near you" : "Nearest")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.tealText)
            Text(pharmacy.name)
                .font(.title2.bold())
                .foregroundStyle(Theme.ink)
            Text([Format.distance(pharmacy.distanceMeters), walk.map(Format.walk)].compactMap(\.self).joined(separator: " · "))
                .monospacedDigit()
                .foregroundStyle(Theme.body)
            if let address = pharmacy.address {
                Text(address)
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, minHeight: Theme.minimumTarget, alignment: .leading)
        .contentShape(.rect)
    }

    private var walk: WalkingTime? {
        model.routeWalk ?? pharmacy.estimatedWalk
    }

    private var isSelected: Bool {
        model.selectedID == pharmacy.id
    }

    private var spokenSummary: String {
        [
            "\(isApproximate ? "Pharmacies near you" : "Nearest pharmacy"): \(pharmacy.name)",
            "\(Format.spokenDistance(pharmacy.distanceMeters)) in a straight line",
            walk.map(Format.spokenWalk),
            pharmacy.address,
        ]
        .compactMap(\.self)
        .joined(separator: ", ")
    }
}

extension View {
    /// The bar marks the pharmacy selected on the map.
    func pharmacyCard(isSelected: Bool) -> some View {
        padding(.horizontal)
            .padding(.vertical, 12)
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
        VStack(alignment: .leading, spacing: 4) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    directions
                    call
                    details
                }
                VStack(alignment: .leading, spacing: 8) {
                    directions
                    HStack(spacing: 8) {
                        call
                        details
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    directions
                    call
                    details
                }
            }
            if let message = place?.message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Theme.body)
                    .padding(.top, 4)
            }
            if let url = WebLink.googleMaps(pharmacy) {
                Link("Google Maps", destination: url)
                    .buttonStyle(.textLink)
                    .font(.subheadline)
                    .accessibilityHint("Searches for this pharmacy in Google Maps")
            }
        }
    }

    private var place: PlaceDetails? {
        model.details[pharmacy.id]
    }

    private var directions: some View {
        Button {
            model.openDirections(to: pharmacy)
        } label: {
            Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
        }
        .buttonStyle(.primaryPill)
        .accessibilityHint("Opens Apple Maps")
    }

    @ViewBuilder
    private var call: some View {
        if let url = place?.phoneURL {
            Link("Call", destination: url)
                .buttonStyle(.secondaryPill)
        }
    }

    private var details: some View {
        Button {
            model.showDetails(for: pharmacy)
        } label: {
            if place == .loading {
                HStack(spacing: 8) {
                    ProgressView().accessibilityHidden(true)
                    Text("Loading details")
                }
            } else {
                Text("Details")
            }
        }
        .buttonStyle(.secondaryPill)
        .disabled(place == .loading)
        .accessibilityHint("Shows Apple Maps information")
    }
}
