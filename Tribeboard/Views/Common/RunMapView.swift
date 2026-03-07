import SwiftUI
import MapKit

struct RunMapView: View, Equatable {
    let model: RunMapModel

    @State private var cameraPosition: MapCameraPosition = .automatic

    static func == (lhs: RunMapView, rhs: RunMapView) -> Bool {
        lhs.model == rhs.model
    }

    var body: some View {
        Group {
            if let region = model.region {
                Map(position: $cameraPosition) {
                    ForEach(model.points) { point in
                        Annotation(point.name, coordinate: point.coordinate) {
                            Image(systemName: symbol(for: point.kind))
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(8)
                                .background(color(for: point.kind))
                                .clipShape(Circle())
                                .overlay {
                                    Circle().stroke(Color.white.opacity(0.9), lineWidth: 1.5)
                                }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .flat))
                .onAppear {
                    cameraPosition = .region(region)
                }
                .onChange(of: model) { _, newValue in
                    if let newRegion = newValue.region {
                        updateCameraIfSignificant(to: newRegion)
                    }
                }
            } else {
                mapUnavailablePlaceholder
            }
        }
    }

    private var mapUnavailablePlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "map")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.secondary)
            Text("Map unavailable")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func symbol(for kind: RunMapPointKind) -> String {
        switch kind {
        case .driver:
            return "car.fill"
        case .stopActive:
            return "mappin.and.ellipse"
        case .stopPending:
            return "circle.fill"
        case .stopCompleted:
            return "checkmark"
        case .stopSkipped:
            return "forward.fill"
        }
    }

    private func color(for kind: RunMapPointKind) -> Color {
        switch kind {
        case .driver:
            return Color.blue
        case .stopActive:
            return Color.orange
        case .stopPending:
            return Color.gray
        case .stopCompleted:
            return Color.green
        case .stopSkipped:
            return Color.gray.opacity(0.65)
        }
    }

    private func updateCameraIfSignificant(to region: MKCoordinateRegion) {
        if let current = cameraPosition.region {
            let from = CLLocation(latitude: current.center.latitude, longitude: current.center.longitude)
            let to = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
            let centerDelta = to.distance(from: from)
            let spanDelta = abs(current.span.latitudeDelta - region.span.latitudeDelta)
                + abs(current.span.longitudeDelta - region.span.longitudeDelta)
            if centerDelta >= 15 || spanDelta >= 0.001 {
                cameraPosition = .region(region)
            }
        } else {
            cameraPosition = .region(region)
        }
    }
}

#Preview {
    RunMapView(
        model: RunMapModel(points: [], region: nil)
    )
    .frame(height: 220)
}
