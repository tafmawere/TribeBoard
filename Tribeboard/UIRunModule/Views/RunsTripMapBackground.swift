import CoreLocation
import GoogleMaps
import SwiftUI
import UIKit

/// Full-bleed Google Maps layer for the Runs control center. Visual only — no routing polyline yet (runs, not turn-by-turn).
struct RunsTripMapBackground: View {
    @EnvironmentObject private var locationService: LocationReadinessService
    @Binding var camera: GoogleMapCameraState

    var body: some View {
        TribeGoogleMapView(
            markers: [],
            polylineCoordinates: [],
            strokeUIColor: .clear,
            lineWidth: 0,
            cameraHint: nil,
            externalCamera: camera,
            showsUserLocation: true,
            padding: .init(top: 52, left: 12, bottom: 120, right: 12),
            onMarkerIdTap: nil
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}

#Preview {
    RunsTripMapBackground(
        camera: .constant(
            GoogleMapCameraState(
                target: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090),
                zoom: 14
            )
        )
    )
    .environmentObject(LocationReadinessService())
}
