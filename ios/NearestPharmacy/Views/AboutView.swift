import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                section("Independent demo") {
                    Text("This app is an independent demo. It isn't an official pharmacy or healthcare service.")
                }
                section("Data") {
                    Text("Pharmacies come from OpenStreetMap, searched with Photon. They can be out of date. Opening hours aren't checked, and a listed pharmacy may have closed down. Phone numbers, place details and the route to the nearest one come from Apple Maps. Check with the pharmacy before you travel.")
                    AttributionView()
                        .font(.footnote)
                }
                section("Distances") {
                    Text("Distances are straight lines. The nearest pharmacy's walking time is Apple's route. Marked ~, it is an estimate along the straight line at 5 km an hour. Over 3 km, no walking time is shown.")
                }
                section("Privacy") {
                    Text("Your position, or the place you search for, is sent to Photon, rounded to about 100 m, and to Apple for the walking route. Apple also gets your place searches and the pharmacies looked up for details. Tapping Google Maps sends that pharmacy's name and address, or its position, to Google. The app has no accounts or analytics.")
                }
            }
            .foregroundStyle(Theme.ink)
            .scrollContentBackground(.hidden)
            .background(Theme.ground)
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .tint(Theme.action)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        Section {
            content()
                .listRowBackground(Theme.sheet)
        } header: {
            Text(title)
                .foregroundStyle(Theme.body)
        }
    }
}
