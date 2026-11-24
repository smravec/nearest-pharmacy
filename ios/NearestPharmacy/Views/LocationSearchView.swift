import SwiftUI

struct LocationSearchView: View {
    let model: AppModel

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            List {
                currentLocation
                if model.isResolvingPlace {
                    ProgressView("Finding place")
                        .listRowBackground(Theme.sheet)
                }
                if let failure = model.placeSearchFailure {
                    Label(failure.placeSearchMessage, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(Theme.error)
                        .listRowBackground(Theme.sheet)
                }
                suggestions
            }
            .scrollContentBackground(.hidden)
            .background(Theme.ground)
            .searchable(
                text: $model.query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Address or place"
            )
            .autocorrectionDisabled()
            .onSubmit(of: .search) { model.submitQuery() }
            .navigationTitle("Search for a place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .tint(Theme.action)
    }

    private var currentLocation: some View {
        Section {
            Button {
                model.useCurrentLocation()
                dismiss()
            } label: {
                Label("Use my location", systemImage: "location.fill")
                    .searchRow()
            }
            .listRowBackground(Theme.sheet)
        } footer: {
            if model.query.isEmpty {
                Text("Suggestions come from Apple Maps.")
                    .foregroundStyle(Theme.body)
            }
        }
    }

    private var suggestions: some View {
        Section {
            ForEach(model.suggestions) { suggestion in
                Button {
                    model.choose(suggestion)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.title)
                            .foregroundStyle(Theme.ink)
                        if !suggestion.subtitle.isEmpty {
                            Text(suggestion.subtitle)
                                .font(.subheadline)
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    .searchRow()
                }
                .listRowBackground(Theme.sheet)
            }
        }
        .disabled(model.isResolvingPlace)
    }
}

private extension View {
    func searchRow() -> some View {
        frame(maxWidth: .infinity, minHeight: Theme.minimumTarget, alignment: .leading)
            .contentShape(.rect)
    }
}

private extension SearchFailure {
    var placeSearchMessage: String {
        switch self {
        case .placeNotFound: "No place matches that search."
        case .offline: "You're offline. Check your connection."
        case .serviceUnavailable, .locationUnavailable: "Place search isn't available right now. Try again."
        }
    }
}
