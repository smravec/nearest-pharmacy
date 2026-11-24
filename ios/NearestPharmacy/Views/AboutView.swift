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
                    Text("Pharmacies come from OpenStreetMap, searched with Photon. They can be out of date. Place details come from Apple Maps. Check with the pharmacy before you travel.")
                    AttributionView()
                        .font(.footnote)
                }
                section("Distances") {
                    Text("Distances are straight lines. Walking times assume 5 km/h.")
                }
                section("Privacy") {
                    Text("Your position, or the place you search for, is sent to Photon and Apple to find results. The app has no accounts or analytics.")
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
