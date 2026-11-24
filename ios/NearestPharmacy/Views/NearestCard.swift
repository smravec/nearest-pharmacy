import SwiftUI

struct NearestCard: View {
    let model: AppModel
    let pharmacy: Pharmacy
    let isApproximate: Bool
    let focus: AccessibilityFocusState<Bool>.Binding

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

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

            PharmacyActions(model: model, pharmacy: pharmacy)
        }
        .pharmacyCard(isSelected: isSelected)
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(isApproximate ? "Near you" : "Nearest")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.tealText)
            Text(pharmacy.name)
                .font((dynamicTypeSize.isAccessibilitySize ? Font.title3 : .title2).bold())
                .foregroundStyle(Theme.ink)
            distances
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

    private var distances: some View {
        let parts = ["\(Format.distance(pharmacy.distanceMeters)) straight line", walk.map(Format.walk)].compactMap(\.self)

        return ViewThatFits(in: .horizontal) {
            Text(parts.joined(separator: " · "))
            VStack(alignment: .leading, spacing: 2) {
                ForEach(parts, id: \.self) { Text($0) }
            }
        }
    }

    private var walk: WalkingTime? {
        model.routeWalk ?? pharmacy.estimatedWalk
    }

    private var isSelected: Bool {
        model.selectedID == pharmacy.id
    }

    private var spokenSummary: String {
        [
            "\(isApproximate ? "Near you" : "Nearest pharmacy"): \(pharmacy.name)",
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
                    Theme.selection.frame(width: 5)
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

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !dynamicTypeSize.isAccessibilitySize { caveat.padding(.bottom, 4) }
            // Call appears late, and must not move the other buttons under a finger.
            ViewThatFits(in: .horizontal) {
                VStack(alignment: .leading, spacing: 8) {
                    directions
                    HStack(spacing: 8) {
                        details
                        call
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    directions
                    details
                    call
                }
            }
            if let message = place?.message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(Theme.body)
                    .padding(.top, 4)
            }
            // Above the buttons, this much large text would push them off the screen.
            if dynamicTypeSize.isAccessibilitySize { caveat.padding(.top, 4) }
            if let url = WebLink.googleMaps(pharmacy) {
                Link("Google Maps", destination: url)
                    .buttonStyle(.textLink)
                    .font(.subheadline)
                    .accessibilityLabel("Google Maps for \(pharmacy.name)")
                    .accessibilityHint("Searches for this pharmacy in Google Maps")
            }
        }
    }

    private var place: PlaceDetails? {
        model.details[pharmacy.id]
    }

    private var caveat: some View {
        Label("Hours not checked. May be closed or closed down.", systemImage: "info.circle")
            .font(.subheadline)
            .foregroundStyle(Theme.amber)
    }

    private var directions: some View {
        Button {
            model.openDirections(to: pharmacy)
        } label: {
            // Beside the icon, the largest text would have to break the word.
            if dynamicTypeSize.isAccessibilitySize {
                Text("Directions")
            } else {
                Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
            }
        }
        .buttonStyle(.primaryPill)
        .accessibilityLabel("Directions to \(pharmacy.name)")
        .accessibilityHint("Opens Apple Maps")
    }

    @ViewBuilder
    private var call: some View {
        if let url = place?.phoneURL {
            Link("Call", destination: url)
                .buttonStyle(.secondaryPill)
                .accessibilityLabel("Call \(pharmacy.name)")
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
                Text("Hours & details")
            }
        }
        .buttonStyle(.secondaryPill)
        .disabled(place == .loading)
        .accessibilityLabel("\(place == .loading ? "Loading details" : "Hours and details") for \(pharmacy.name)")
        .accessibilityHint("Shows Apple Maps information")
    }
}
