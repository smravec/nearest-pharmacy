import MapKit
import SwiftUI

struct PharmacyMap: View {
    let model: AppModel
    let origin: Origin
    let pharmacies: [Pharmacy]

    @State private var position: MapCameraPosition
    @Namespace private var scope
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(model: AppModel, origin: Origin, pharmacies: [Pharmacy]) {
        self.model = model
        self.origin = origin
        self.pharmacies = pharmacies
        _position = State(initialValue: .fitting(origin, pharmacies))
    }

    var body: some View {
        map
            .ignoresSafeArea(edges: .horizontal)
            .overlay(alignment: .topTrailing) { controls }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Map of nearby pharmacies")
            .mapScope(scope)
            .onChange(of: model.selectedID) { showSelected() }
            .onChange(of: model.listSelectionCount) { showSelected() }
    }

    private var map: some View {
        @Bindable var model = model

        return Map(position: $position, selection: $model.selectedID, scope: scope) {
            Annotation(origin.placeName ?? "Your location", coordinate: origin.coordinate.clLocationCoordinate) {
                OriginDot()
            }
            ForEach(pharmacies) { pharmacy in
                let isNearest = pharmacy.id == pharmacies.first?.id
                // The symbol differs too, so color isn't the only difference.
                Marker(
                    pharmacy.name,
                    systemImage: isNearest ? "cross.case.fill" : "cross.fill",
                    coordinate: pharmacy.coordinate.clLocationCoordinate
                )
                .tint(isNearest ? Theme.nearestPin : Theme.teal)
                .tag(pharmacy.id)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .mapControls { MapScaleView() }
    }

    /// The compass is placed here because its default spot is under the recenter button.
    private var controls: some View {
        VStack(spacing: 8) {
            Button {
                move(to: .fitting(origin, pharmacies))
            } label: {
                Image(systemName: "scope")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.action)
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .frame(width: Theme.minimumTarget, height: Theme.minimumTarget)
                    .background(.regularMaterial, in: .circle)
                    .contentShape(.circle)
            }
            .accessibilityLabel("Recenter map")
            MapCompass(scope: scope)
        }
        .padding(12)
    }

    private func showSelected() {
        guard let selected = pharmacies.first(where: { $0.id == model.selectedID }) else { return }
        move(to: .region(MKCoordinateRegion(
            center: selected.coordinate.clLocationCoordinate,
            latitudinalMeters: 800,
            longitudinalMeters: 800
        )))
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
            .fill(Theme.originFill)
            .stroke(Theme.originRing, lineWidth: 3)
            .frame(width: 18, height: 18)
            .shadow(radius: 2)
    }
}

private extension MapCameraPosition {
    /// The origin and the closest pharmacies, with some room around them.
    static func fitting(_ origin: Origin, _ pharmacies: [Pharmacy]) -> MapCameraPosition {
        let coordinates = [origin.coordinate] + pharmacies.prefix(5).map(\.coordinate)
        var rect = coordinates.reduce(MKMapRect.null) { rect, coordinate in
            rect.union(MKMapRect(origin: MKMapPoint(coordinate.clLocationCoordinate), size: MKMapSize()))
        }
        // Wider than half the globe means the points straddle the antimeridian.
        guard rect.width <= MKMapSize.world.width / 2 else { return .automatic }

        // Pins stand above their point, so the northernmost one needs headroom.
        let headroom = rect.height * 0.35
        rect.origin.y -= headroom
        rect.size.height += headroom

        let smallest = 500 * MKMapPointsPerMeterAtLatitude(origin.coordinate.latitude)
        return .rect(rect.insetBy(
            dx: -max(rect.width * 0.15, (smallest - rect.width) / 2),
            dy: -max(rect.height * 0.15, (smallest - rect.height) / 2)
        ))
    }
}
