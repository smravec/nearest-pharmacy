import SwiftUI

struct HeroView: View {
    let useLocation: () -> Void
    let search: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                card
                Text("Your position is sent to Photon (rounded to about 100 m), which searches OpenStreetMap, and to Apple Maps.")
                    .font(.footnote)
                    .foregroundStyle(Theme.body)
            }
            .frame(maxWidth: 560)
            .padding()
            .frame(maxWidth: .infinity)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: "cross.case.fill")
                .font(.largeTitle)
                .foregroundStyle(Theme.action)
                .accessibilityHidden(true)
            Text("Find your nearest pharmacy")
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
            Text("See the closest pharmacies, how far they are and how to walk there.")
            VStack(alignment: .leading, spacing: 12) {
                Button("Use my location", action: useLocation)
                    .buttonStyle(.primaryPill)
                Button("Search for a place", action: search)
                    .buttonStyle(.secondaryPill)
            }
            .padding(.top, 8)
        }
        .foregroundStyle(Theme.ink)
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.heroGradient, in: .rect(cornerRadius: Theme.cardRadius))
    }
}
