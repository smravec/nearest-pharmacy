import MapKit
import SwiftUI

struct PharmacyMap: View {
    private struct Content: Equatable {
        let pharmacies: [Pharmacy]
        let selectedID: Pharmacy.ID?
        let listSelectionCount: Int
    }

    let model: AppModel

    @State private var position: MapCameraPosition
    @Namespace private var scope
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(model: AppModel) {
        self.model = model
        _position = State(initialValue: .fitting(model.origin, model.pharmacies))
    }

    var body: some View {
        map
            .ignoresSafeArea(edges: [.horizontal, .top])
            .overlay(alignment: .topTrailing) { controls }
            .mapScope(scope)
            // One handler for all, so the automatic selection that comes with new results
            // doesn't replace the view of all of them.
            .onChange(of: content) { old, new in
                if new.pharmacies != old.pharmacies {
                    position = .fitting(model.origin, new.pharmacies)
                } else if let selected = new.pharmacies.first(where: { $0.id == new.selectedID }) {
                    move(to: .region(around: selected))
                }
            }
    }

    private var content: Content {
        Content(
            pharmacies: model.pharmacies,
            selectedID: model.selectedID,
            listSelectionCount: model.listSelectionCount
        )
    }

    private var map: some View {
        @Bindable var model = model

        return Map(position: $position, selection: $model.selectedID, scope: scope) {
            if let origin = model.origin {
                Annotation(
                    origin.source == .gps ? "Your location" : origin.label,
                    coordinate: origin.coordinate.clLocationCoordinate
                ) {
                    OriginDot()
                }
            }
            ForEach(model.pharmacies) { pharmacy in
                let isNearest = pharmacy.id == model.nearest?.id
                // The symbol differs too: in dark mode both tints are the same.
                Marker(
                    pharmacy.name,
                    systemImage: isNearest ? "cross.case.fill" : "cross.fill",
                    coordinate: pharmacy.coordinate.clLocationCoordinate
                )
                .tint(isNearest ? Theme.action : Theme.teal)
                .tag(pharmacy.id)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls { MapScaleView() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Map of nearby pharmacies")
        .accessibilityHint("The same pharmacies are in the list.")
    }

    /// The compass is placed here because its default spot is under the recenter button.
    private var controls: some View {
        VStack(spacing: 8) {
            Button {
                move(to: .fitting(model.origin, model.pharmacies))
            } label: {
                Image(systemName: "scope")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.action)
                    .frame(width: Theme.minimumTarget, height: Theme.minimumTarget)
                    .background(.regularMaterial, in: .circle)
                    .contentShape(.circle)
            }
            .accessibilityLabel("Recenter map")
            MapCompass(scope: scope)
        }
        .padding(12)
    }

    private func move(to newPosition: MapCameraPosition) {
        withAnimation(reduceMotion ? nil : .default) {
            position = newPosition
        }
    }
}

private struct OriginDot: View {
    var body: some View {
        Circle()
            .fill(Theme.action)
            .stroke(.white, lineWidth: 3)
            .frame(width: 18, height: 18)
            .shadow(radius: 2)
    }
}

private extension MapCameraPosition {
    /// The origin and the closest pharmacies, with some room around them.
    static func fitting(_ origin: Origin?, _ pharmacies: [Pharmacy]) -> MapCameraPosition {
        let coordinates = [origin?.coordinate].compactMap(\.self) + pharmacies.prefix(5).map(\.coordinate)
        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        guard let south = latitudes.min(), let north = latitudes.max(),
              let west = longitudes.min(), let east = longitudes.max(),
              // Wider than half the globe means the points straddle the antimeridian.
              east - west <= 180
        else { return .automatic }

        let center = CLLocationCoordinate2D(latitude: (south + north) / 2, longitude: (west + east) / 2)
        let smallest = MKCoordinateRegion(center: center, latitudinalMeters: 500, longitudinalMeters: 500).span
        let padding = 1.3
        return .region(MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(
                latitudeDelta: max((north - south) * padding, smallest.latitudeDelta),
                longitudeDelta: max((east - west) * padding, smallest.longitudeDelta)
            )
        ))
    }

    static func region(around pharmacy: Pharmacy) -> MapCameraPosition {
        .region(MKCoordinateRegion(
            center: pharmacy.coordinate.clLocationCoordinate,
            latitudinalMeters: 800,
            longitudinalMeters: 800
        ))
    }
}
