import MapKit
import SwiftUI

struct RootView: View {
    let model: AppModel

    @State private var isSearchPresented = false
    @State private var isAboutPresented = false

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
        .sheet(isPresented: $isSearchPresented) {
            LocationSearchView(
                isLocationDenied: model.state == .denied,
                useLocation: searchFromLocation,
                select: search
            )
        }
        .sheet(isPresented: $isAboutPresented) { AboutView() }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle:
            HeroView(useLocation: model.useCurrentLocation, search: presentSearch)
        case .ready(let origin, let pharmacies):
            ResultsView(model: model, origin: origin, pharmacies: pharmacies, search: presentSearch)
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
            Button(action: presentAbout) {
                Label("About", systemImage: "info.circle")
            }
        }
    }

    // Details arriving later would try to open a second sheet.
    private func presentSearch() {
        model.cancelDetails()
        isSearchPresented = true
    }

    private func presentAbout() {
        model.cancelDetails()
        isAboutPresented = true
    }

    private func searchFromLocation() {
        isSearchPresented = false
        model.useCurrentLocation()
    }

    private func search(from origin: Origin) {
        // A place may still resolve while the closed sheet animates away.
        guard isSearchPresented else { return }
        isSearchPresented = false
        model.search(from: origin)
    }
}

/// Map and panel side by side when there is room, stacked otherwise.
private struct ResultsView: View {
    private enum Pane: Hashable {
        case map
        case panel
    }

    let model: AppModel
    let origin: Origin
    let pharmacies: [Pharmacy]
    let search: () -> Void

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
                        PharmacyMap(model: model, origin: origin, pharmacies: pharmacies)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .panel:
                        ResultsPanel(model: model, origin: origin, pharmacies: pharmacies, search: search)
                            // VoiceOver reads the results before the map's pins.
                            .accessibilitySortPriority(1)
                            .frame(
                                width: isWide ? min(400, size.width * 0.45) : nil,
                                height: isWide ? nil : panelHeight(in: size.height)
                            )
                    }
                }
            }
        }
        // The search sheet's keyboard must not make this look like a short, wide screen.
        .ignoresSafeArea(.keyboard)
    }

    private func panelHeight(in height: CGFloat) -> CGFloat {
        if dynamicTypeSize.isAccessibilitySize { return height * 0.85 }
        // 420 points show the nearest card and the next heading, if that leaves room for the map.
        return max(height * 0.55, min(420, height * 0.7))
    }
}

private struct ResultsPanel: View {
    let model: AppModel
    let origin: Origin
    let pharmacies: [Pharmacy]
    let search: () -> Void

    @AccessibilityFocusState private var nearestFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if !dynamicTypeSize.isAccessibilitySize { originLine }
                    if let nearest = pharmacies.first {
                        NearestCard(
                            model: model,
                            pharmacy: nearest,
                            isApproximate: origin.isApproximate,
                            focus: $nearestFocused
                        )
                        .id(nearest.id)
                    }
                    if dynamicTypeSize.isAccessibilitySize { originLine }
                    PharmacyList(model: model, others: Array(pharmacies.dropFirst()))
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(Theme.ground)
            .safeAreaInset(edge: .bottom, spacing: 0) { PinnedAttribution() }
            .onChange(of: model.selectedID) { _, selectedID in
                guard let selectedID else { return }
                withAnimation(reduceMotion ? nil : .default) {
                    proxy.scrollTo(selectedID, anchor: .center)
                }
            }
        }
        .task {
            // VoiceOver ignores a focus request made while the screen is still changing.
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            nearestFocused = true
        }
    }

    private var originLine: some View {
        OriginLine(origin: origin, search: search)
    }
}

/// OpenStreetMap's license requires the credit to be visible along with the results.
private struct PinnedAttribution: View {
    var body: some View {
        HStack(spacing: 0) {
            CreditLink(title: "© OpenStreetMap", address: CreditLink.openStreetMap)
                .accessibilityLabel("OpenStreetMap contributors, licence information")
            Text(" · ")
                .foregroundStyle(Theme.body)
                .accessibilityHidden(true)
            CreditLink(title: "Photon", address: CreditLink.photon)
                .accessibilityLabel("Photon, search service")
        }
        .buttonStyle(.textLink)
        .font(.caption)
        // Larger text would leave little room for the results. About has it at full size.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .background(Theme.sheet)
        .overlay(alignment: .top) {
            Theme.hairline.frame(height: 1).ignoresSafeArea(edges: .horizontal)
        }
    }
}

private struct OriginLine: View {
    let origin: Origin
    let search: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Near \(origin.labelInSentence)")
                .foregroundStyle(Theme.body)
            if origin.isApproximate {
                Label("Approximate location, so distances are rough", systemImage: "location.slash")
                    .foregroundStyle(Theme.amber)
                Button("Search for a place", action: search)
                    .buttonStyle(.textLink)
            }
        }
        .font(.subheadline)
    }
}
