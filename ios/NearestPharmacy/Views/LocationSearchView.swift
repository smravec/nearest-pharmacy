import MapKit
import SwiftUI

struct LocationSearchView: View {
    private enum Lookup: Equatable {
        case idle
        case running
        case failed(String)
    }

    let useLocation: () -> Void
    let select: (Origin) -> Void

    @State private var query = ""
    @State private var places = PlaceSearch()
    @State private var lookup = Lookup.idle
    @State private var lookupTask: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                currentLocation
                status
                suggestions
            }
            .scrollContentBackground(.hidden)
            .background(Theme.ground)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Address or place"
            )
            .autocorrectionDisabled()
            .onChange(of: query) {
                lookupTask?.cancel()
                lookup = .idle
                places.update(query: query)
            }
            .onSubmit(of: .search, submit)
            .navigationTitle("Search for a place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .tint(Theme.action)
        .onDisappear { lookupTask?.cancel() }
    }

    private var currentLocation: some View {
        Section {
            Button(action: useLocation) {
                Label("Use my location", systemImage: "location.fill")
                    .searchRow()
            }
            .listRowBackground(Theme.sheet)
        } footer: {
            if query.isEmpty {
                Text("Suggestions come from Apple Maps.")
                    .foregroundStyle(Theme.body)
            }
        }
    }

    @ViewBuilder
    private var status: some View {
        switch lookup {
        case .idle:
            EmptyView()
        case .running:
            ProgressView("Finding place")
                .listRowBackground(Theme.sheet)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(Theme.error)
                .listRowBackground(Theme.sheet)
        }
    }

    private var suggestions: some View {
        Section {
            ForEach(places.suggestions, id: \.self) { suggestion in
                Button {
                    find { try await places.place(for: suggestion) }
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
        .disabled(lookup == .running)
    }

    private func submit() {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        find { try await places.place(named: text) }
    }

    /// A search already running behind the sheet goes on until a place is found.
    private func find(_ place: @escaping () async throws -> Origin?) {
        lookupTask?.cancel()
        lookup = .running
        lookupTask = Task {
            do {
                let place = try await place()
                guard !Task.isCancelled else { return }
                if let place {
                    select(place)
                } else {
                    fail("No place matches that search.")
                }
            } catch {
                guard !Task.isCancelled else { return }
                fail(
                    SearchFailure(error) == .offline
                        ? "You're offline. Check your connection."
                        : "Place search isn't available right now. Try again."
                )
            }
        }
    }

    private func fail(_ message: String) {
        lookup = .failed(message)
        VoiceOver.announce(message)
    }
}

private extension View {
    func searchRow() -> some View {
        frame(maxWidth: .infinity, minHeight: Theme.minimumTarget, alignment: .leading)
            .contentShape(.rect)
    }
}
