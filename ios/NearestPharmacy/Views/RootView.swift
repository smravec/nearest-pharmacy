import MapKit
import SwiftUI

struct RootView: View {
    let model: AppModel

    @State private var isSearchPresented = false
    @State private var isAboutPresented = false
    @AccessibilityFocusState private var nearestFocused: Bool

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.ground)
                .navigationTitle("Nearest pharmacy")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
        }
        .tint(Theme.action)
        .mapItemDetailSheet(item: $model.detailItem, displaysMap: false)
        .sheet(isPresented: $isSearchPresented) { LocationSearchView(model: model) }
        .sheet(isPresented: $isAboutPresented) { AboutView() }
        // Not keyed on `.loading`: the state doesn't change when a search was already loading,
        // and a location arriving late must not close the sheet while someone types.
        .onChange(of: model.isResolvingPlace) { _, isResolving in
            if !isResolving, model.placeSearchFailure == nil { isSearchPresented = false }
        }
        .onChange(of: model.announcement) { _, announcement in
            if let announcement { post(announcement) }
        }
        .task(id: model.nearest?.id) {
            guard model.nearest != nil else { return }
            // VoiceOver ignores a focus request made while the screen is still changing.
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            nearestFocused = true
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle:
            HeroView(useLocation: model.useCurrentLocation, search: presentSearch)
        case .ready:
            ResultsView(model: model, nearestFocus: $nearestFocused)
        case .locating, .denied, .loading, .empty, .failed:
            SearchStatusView(model: model, search: presentSearch)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if model.state != .idle {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: model.reset) {
                    Label("Start over", systemImage: "arrow.counterclockwise")
                }
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button(action: presentSearch) {
                Label("Search for a place", systemImage: "magnifyingglass")
            }
            Button {
                isAboutPresented = true
            } label: {
                Label("About", systemImage: "info.circle")
            }
        }
    }

    private func presentSearch() {
        isSearchPresented = true
    }

    private func post(_ announcement: Announcement) {
        var text = AttributedString(announcement.text)
        text.accessibilitySpeechAnnouncementPriority = .high
        AccessibilityNotification.Announcement(text).post()
    }
}

/// Map and panel side by side when there is room, stacked otherwise.
private struct ResultsView: View {
    private enum Pane: Hashable {
        case map
        case panel
    }

    let model: AppModel
    let nearestFocus: AccessibilityFocusState<Bool>.Binding

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let isWide = size.width >= 700 || size.height < 500
            let layout = isWide
                ? AnyLayout(HStackLayout(spacing: 0))
                : AnyLayout(VStackLayout(spacing: 0))

            layout {
                // Reordering by identity keeps the map's camera when the layout changes.
                ForEach(isWide ? [Pane.panel, .map] : [.map, .panel], id: \.self) { pane in
                    switch pane {
                    case .map:
                        PharmacyMap(model: model)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .panel:
                        ResultsPanel(model: model, nearestFocus: nearestFocus)
                            .frame(
                                width: isWide ? min(400, size.width * 0.45) : nil,
                                height: isWide ? nil : size.height * panelShare
                            )
                    }
                }
            }
        }
        // The search sheet's keyboard must not make this look like a short, wide screen.
        .ignoresSafeArea(.keyboard)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
    }

    private var panelShare: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 0.7 : 0.55
    }
}

private struct ResultsPanel: View {
    let model: AppModel
    let nearestFocus: AccessibilityFocusState<Bool>.Binding

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if let origin = model.origin {
                        OriginLine(origin: origin)
                    }
                    if let nearest = model.nearest {
                        NearestCard(model: model, pharmacy: nearest, focus: nearestFocus)
                            .id(nearest.id)
                    }
                    PharmacyList(model: model)
                    AttributionView()
                }
                .padding()
            }
            .background(Theme.ground)
            .onChange(of: model.selectedID) { _, selectedID in
                guard let selectedID else { return }
                withAnimation(reduceMotion ? nil : .default) {
                    proxy.scrollTo(selectedID, anchor: .center)
                }
            }
        }
    }
}

private struct OriginLine: View {
    let origin: Origin

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Near \(origin.labelInSentence)")
                .foregroundStyle(Theme.body)
            if origin.isApproximate {
                Label("Approximate location, so distances are rough", systemImage: "location.slash")
                    .foregroundStyle(Theme.amber)
            }
        }
        .font(.subheadline)
    }
}

extension Origin {
    var labelInSentence: String {
        source == .gps ? "your location" : label
    }
}
