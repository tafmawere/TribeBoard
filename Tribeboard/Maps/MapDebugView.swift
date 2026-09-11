import SwiftUI

#if DEBUG
/// Toggle in `TribeboardApp` / here to open the app straight into a full-screen map with no shell, tabs, or Runs UI.
enum MapDebugLaunchGate {
    static let launchStraightIntoMapDebug = false
}

/// Minimal host for `TribeGoogleMapView` (default camera from the representable; no bindings).
struct GoogleMapView: View {
    var body: some View {
        TribeGoogleMapView(
            markers: [],
            polylineCoordinates: [],
            strokeUIColor: .clear,
            lineWidth: 0,
            cameraHint: nil,
            externalCamera: nil,
            showsUserLocation: true,
            padding: .zero,
            onMarkerIdTap: nil
        )
    }
}

/// Standalone map surface for isolating SwiftUI / layer issues from Runs overlays.
struct MapDebugView: View {
    var body: some View {
        GoogleMapView()
            .ignoresSafeArea()
    }
}
#endif
