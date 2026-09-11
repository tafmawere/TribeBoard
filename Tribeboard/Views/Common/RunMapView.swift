import GoogleMaps
import SwiftUI
import UIKit

struct RunMapView: View, Equatable {
    let model: RunMapModel

    static func == (lhs: RunMapView, rhs: RunMapView) -> Bool {
        lhs.model == rhs.model
    }

    var body: some View {
        Group {
            if let region = model.region {
                TribeGoogleMapView(
                    markers: model.points.map(Self.googleMarker(from:)),
                    polylineCoordinates: [],
                    strokeUIColor: .clear,
                    lineWidth: 0,
                    cameraHint: region,
                    externalCamera: nil,
                    showsUserLocation: false,
                    padding: .init(top: 28, left: 24, bottom: 28, right: 24),
                    onMarkerIdTap: nil
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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

    private static func googleMarker(from point: RunMapPoint) -> GoogleMapMarkerModel {
        let kind: GoogleMapMarkerModel.Kind
        switch point.kind {
        case .driver:
            kind = .driver
        case .stopActive:
            kind = .stopActive
        case .stopPending:
            kind = .stopPending
        case .stopCompleted:
            kind = .stopCompleted
        case .stopSkipped:
            kind = .stopSkipped
        }
        return GoogleMapMarkerModel(
            id: point.id,
            title: point.name,
            coordinate: point.coordinate,
            kind: kind,
            orderLabel: nil,
            isSelected: false
        )
    }
}

#Preview {
    RunMapView(
        model: RunMapModel(points: [], region: nil)
    )
    .frame(height: 220)
}
