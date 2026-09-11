import CoreLocation
import GoogleMaps
import SwiftUI
import UIKit

// MARK: - Camera

struct GoogleMapCameraState: Equatable {
    var target: CLLocationCoordinate2D
    var zoom: Float
    var bearing: Double?
    var viewingAngle: Double?

    init(
        target: CLLocationCoordinate2D,
        zoom: Float,
        bearing: Double? = nil,
        viewingAngle: Double? = nil
    ) {
        self.target = target
        self.zoom = zoom
        self.bearing = bearing
        self.viewingAngle = viewingAngle
    }

    /// Default map position (Johannesburg area) when no user location or run is selected.
    static let southAfricaJohannesburgDefault = GoogleMapCameraState(
        target: CLLocationCoordinate2D(latitude: -26.2041, longitude: 28.0473),
        zoom: 12
    )
}

// MARK: - Markers

struct GoogleMapMarkerModel: Identifiable, Equatable {
    enum Kind: Equatable {
        case driver
        case stopActive
        case stopPending
        case stopCompleted
        case stopSkipped
        case routeStart
        case routeEnd
        case destination
        case generic
    }

    let id: UUID
    var title: String
    var coordinate: CLLocationCoordinate2D
    var kind: Kind
    var orderLabel: String?
    var isSelected: Bool

    init(
        id: UUID,
        title: String,
        coordinate: CLLocationCoordinate2D,
        kind: Kind,
        orderLabel: String? = nil,
        isSelected: Bool = false
    ) {
        self.id = id
        self.title = title
        self.coordinate = coordinate
        self.kind = kind
        self.orderLabel = orderLabel
        self.isSelected = isSelected
    }
}

// MARK: - Map view

/// Hosts a `GMSMapView` only when `GoogleMapsBootstrap` has supplied an API key; otherwise shows a non-interactive placeholder so the app does not crash.
struct TribeGoogleMapView: View {
    var markers: [GoogleMapMarkerModel]
    var polylineCoordinates: [CLLocationCoordinate2D]
    var strokeUIColor: UIColor
    var lineWidth: CGFloat
    var cameraHint: CoordinateRegionDegrees?
    var externalCamera: GoogleMapCameraState?
    var showsUserLocation: Bool
    var padding: UIEdgeInsets
    /// When set, marker `id` is stored on `GMSMarker.userData` and taps invoke this closure.
    var onMarkerIdTap: ((UUID) -> Void)?

    var body: some View {
        Group {
            if GoogleMapsBootstrap.isConfigured {
                TribeGoogleMapViewRepresentable(
                    markers: markers,
                    polylineCoordinates: polylineCoordinates,
                    strokeUIColor: strokeUIColor,
                    lineWidth: lineWidth,
                    cameraHint: cameraHint,
                    externalCamera: externalCamera,
                    showsUserLocation: showsUserLocation,
                    padding: padding,
                    onMarkerIdTap: onMarkerIdTap
                )
            } else {
                googleMapsUnavailablePlaceholder
            }
        }
        .transaction { $0.animation = nil }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    private var googleMapsUnavailablePlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "map")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Maps unavailable")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            #if DEBUG
            Text("Add GOOGLE_MAPS_API_KEY (Secrets.xcconfig) to show the map.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
    }
}

// MARK: - Hosting view (UIKit layout for GMSMapView)

/// Pins `GMSMapView.frame` to the representable host on every layout pass so SwiftUI’s first non-zero size
/// reaches the map surface (zero-sized first pass commonly yields tiles “loaded” but a blank white view).
private final class TribeGoogleMapHostingView: UIView {
    let mapView: GMSMapView

    init(mapView: GMSMapView) {
        self.mapView = mapView
        super.init(frame: .zero)
        backgroundColor = .systemBackground
        isOpaque = true
        addSubview(mapView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        mapView.frame = bounds
    }
}

// MARK: - Representable

private struct TribeGoogleMapViewRepresentable: UIViewRepresentable {
    /// Used when both `externalCamera` and `cameraHint` are nil (e.g. first layout).
    private static let defaultCamera = GoogleMapCameraState.southAfricaJohannesburgDefault

    var markers: [GoogleMapMarkerModel]
    var polylineCoordinates: [CLLocationCoordinate2D]
    var strokeUIColor: UIColor
    var lineWidth: CGFloat
    var cameraHint: CoordinateRegionDegrees?
    var externalCamera: GoogleMapCameraState?
    var showsUserLocation: Bool
    var padding: UIEdgeInsets
    var onMarkerIdTap: ((UUID) -> Void)?

    func makeCoordinator() -> TribeGoogleMapViewCoordinator {
        TribeGoogleMapViewCoordinator()
    }

#if DEBUG
    /// Set `true` to test whether satellite rasters draw while `.normal` stays blank (styling vs. layer masking).
    private static let debugForceSatelliteMapType = false
#endif

    /// Standard road map: no custom `GMSMapStyle` JSON.
    private static func resetBasemapToSDKDefaults(_ mapView: GMSMapView) {
        mapView.mapStyle = nil
#if DEBUG
        if debugForceSatelliteMapType {
            mapView.mapType = .satellite
            return
        }
#endif
        mapView.mapType = .normal
    }

    /// Favor default UIKit compositing so the Metal/GL map surface is not unintentionally transparent or masked.
    private static func applyDefaultUIKitBasemapLayer(_ mapView: GMSMapView) {
        mapView.tintColor = nil
        mapView.backgroundColor = .systemBackground
        mapView.isOpaque = true
        mapView.alpha = 1.0
        mapView.layer.opacity = 1.0
        mapView.layer.mask = nil
        mapView.clipsToBounds = true
        if #available(iOS 13.0, *) {
            mapView.layer.compositingFilter = nil
        }
        mapView.layer.filters = nil
    }

    private static func syncMapViewRenderingDefaults(_ mapView: GMSMapView) {
        resetBasemapToSDKDefaults(mapView)
        applyDefaultUIKitBasemapLayer(mapView)
    }

    /// Host `GMSMapView` in `TribeGoogleMapHostingView` so `layoutSubviews` keeps the map sized with SwiftUI’s host bounds.
    func makeUIView(context: Context) -> UIView {
        #if DEBUG
        NSLog("GoogleMapView makeUIView called")
        #endif

        // Always boot the GL/Metal map at Johannesburg; `updateUIView` applies `externalCamera` / hints from SwiftUI.
        let camera = GMSCameraPosition.camera(withLatitude: -26.2041, longitude: 28.0473, zoom: 12)
        let mapView = GMSMapView(frame: .zero, camera: camera)
        Self.syncMapViewRenderingDefaults(mapView)
        #if DEBUG
        print(
            Self.debugForceSatelliteMapType
                ? "[GoogleMapView] mapStyle cleared, mapType satellite (DEBUG)"
                : "[GoogleMapView] mapStyle cleared, mapType normal"
        )
        #endif
        mapView.isMyLocationEnabled = showsUserLocation
        mapView.settings.myLocationButton = false
        mapView.settings.compassButton = true
        mapView.padding = padding
        mapView.translatesAutoresizingMaskIntoConstraints = true
        mapView.delegate = context.coordinator
        context.coordinator.mapView = mapView
#if DEBUG
        context.coordinator.attachDebugJohannesburgProbeIfNeeded(to: mapView)
        context.coordinator.attachDebugIdleCameraTestMarkerIfNeeded(to: mapView)
#endif

        let container = TribeGoogleMapHostingView(mapView: mapView)
        // Prime a non-zero size before the first SwiftUI layout pass so the renderer does not stay stuck at 0×0.
        let seedSize = UIScreen.main.bounds.size
        mapView.frame = CGRect(origin: .zero, size: seedSize)
        container.setNeedsLayout()
        container.layoutIfNeeded()

        return container
    }

    /// Rough zoom from span deltas when building from `cameraHint` only.
    private static func zoomLevelCovering(latitudeDelta: Double, longitudeDelta: Double) -> Float {
        let span = max(latitudeDelta, longitudeDelta, 0.001)
        let zoom = log2(360.0 / span) - 1
        return Float(min(20, max(2, zoom)))
    }

    func updateUIView(_ container: UIView, context: Context) {
        guard let mapView = context.coordinator.mapView else { return }

        #if DEBUG
        context.coordinator.logUpdateUIViewIfNeeded()
        #endif

        Self.syncMapViewRenderingDefaults(mapView)
        mapView.isMyLocationEnabled = showsUserLocation
        mapView.settings.myLocationButton = false
        mapView.settings.compassButton = true
        mapView.padding = padding

        context.coordinator.parentMarkers = markers
        context.coordinator.parentPolyline = polylineCoordinates
        context.coordinator.onMarkerIdTap = onMarkerIdTap

        let fingerprint = Self.overlayFingerprint(markers: markers, polyline: polylineCoordinates)
        if context.coordinator.lastOverlayFingerprint != fingerprint {
            context.coordinator.lastOverlayFingerprint = fingerprint
            mapView.clear()
            Self.syncMapViewRenderingDefaults(mapView)

            if polylineCoordinates.count >= 2 {
                let path = GMSMutablePath()
                for coordinate in polylineCoordinates {
                    path.add(coordinate)
                }
                let polyline = GMSPolyline(path: path)
                polyline.strokeWidth = lineWidth
                polyline.strokeColor = strokeUIColor
                polyline.map = mapView
            }

            for markerModel in markers {
                let marker = GMSMarker(position: markerModel.coordinate)
                marker.title = markerModel.title
                marker.icon = Self.markerIcon(for: markerModel)
                marker.zIndex = markerModel.isSelected ? 2 : 1
                marker.userData = markerModel.id.uuidString
                marker.map = mapView
            }
        }

        if let externalCamera {
            let camera: GMSCameraPosition
            if let bearing = externalCamera.bearing {
                camera = GMSCameraPosition.camera(
                    withTarget: externalCamera.target,
                    zoom: externalCamera.zoom,
                    bearing: bearing,
                    viewingAngle: externalCamera.viewingAngle ?? 0
                )
            } else {
                camera = GMSCameraPosition.camera(withTarget: externalCamera.target, zoom: externalCamera.zoom)
            }
            if !mapView.camera.target.isEqualCoordinate(externalCamera.target, tolerance: 0.000_01)
                || abs(mapView.camera.zoom - externalCamera.zoom) > 0.05
                || abs(mapView.camera.bearing - (externalCamera.bearing ?? mapView.camera.bearing)) > 2 {
                mapView.animate(to: camera)
            }
        } else if let hint = cameraHint {
            let ne = CLLocationCoordinate2D(
                latitude: hint.center.latitude + hint.latitudeDelta / 2,
                longitude: hint.center.longitude + hint.longitudeDelta / 2
            )
            let sw = CLLocationCoordinate2D(
                latitude: hint.center.latitude - hint.latitudeDelta / 2,
                longitude: hint.center.longitude - hint.longitudeDelta / 2
            )
            let bounds = GMSCoordinateBounds(coordinate: ne, coordinate: sw)
            let update = GMSCameraUpdate.fit(bounds, with: padding)
            mapView.animate(with: update)
        }

        Self.syncMapViewRenderingDefaults(mapView)

#if DEBUG
        context.coordinator.attachDebugJohannesburgProbeIfNeeded(to: mapView)
        context.coordinator.attachDebugIdleCameraTestMarkerIfNeeded(to: mapView)
#endif

        container.setNeedsLayout()
        container.layoutIfNeeded()
        mapView.setNeedsLayout()
        mapView.layoutIfNeeded()
    }

    private static func overlayFingerprint(markers: [GoogleMapMarkerModel], polyline: [CLLocationCoordinate2D]) -> String {
        let markerPart = markers
            .map {
                "\($0.id.uuidString)|\($0.coordinate.latitude)|\($0.coordinate.longitude)|\(String(describing: $0.kind))|\($0.isSelected)"
            }
            .joined(separator: ",")
        let polyPart = polyline.map { "\($0.latitude)|\($0.longitude)" }.joined(separator: ",")
        return markerPart + "@" + polyPart
    }

    private static func markerIcon(for model: GoogleMapMarkerModel) -> UIImage? {
        let diameter: CGFloat = model.isSelected ? 38 : 34
        let fill = uiColor(for: model.kind)
        let label = model.orderLabel

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: diameter, height: diameter))
        return renderer.image { ctx in
            let rect = CGRect(origin: .zero, size: renderer.format.bounds.size)
            ctx.cgContext.setFillColor(fill.cgColor)
            ctx.cgContext.fillEllipse(in: rect)
            ctx.cgContext.setStrokeColor(UIColor.white.withAlphaComponent(0.95).cgColor)
            ctx.cgContext.setLineWidth(model.isSelected ? 2.5 : 1.5)
            ctx.cgContext.strokeEllipse(in: rect.insetBy(dx: 1, dy: 1))

            if let label, !label.isEmpty {
                let paragraph = NSMutableParagraphStyle()
                paragraph.alignment = .center
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: model.isSelected ? 14 : 13, weight: .heavy),
                    .foregroundColor: UIColor.white,
                    .paragraphStyle: paragraph
                ]
                let text = NSString(string: label)
                let textSize = text.size(withAttributes: attrs)
                let textRect = CGRect(
                    x: (diameter - textSize.width) / 2,
                    y: (diameter - textSize.height) / 2,
                    width: textSize.width,
                    height: textSize.height
                )
                text.draw(in: textRect, withAttributes: attrs)
            } else {
                let symbolName: String
                switch model.kind {
                case .driver:
                    symbolName = "car.circle.fill"
                case .routeStart:
                    symbolName = "play.fill"
                case .routeEnd, .destination:
                    symbolName = "flag.checkered"
                default:
                    symbolName = "mappin.circle.fill"
                }
                let config = UIImage.SymbolConfiguration(pointSize: diameter * 0.38, weight: .bold)
                if let image = UIImage(systemName: symbolName, withConfiguration: config)?
                    .withTintColor(.white, renderingMode: .alwaysOriginal) {
                    let imageSize = image.size
                    let imageRect = CGRect(
                        x: (diameter - imageSize.width) / 2,
                        y: (diameter - imageSize.height) / 2,
                        width: imageSize.width,
                        height: imageSize.height
                    )
                    image.draw(in: imageRect)
                }
            }
        }
    }

    private static func uiColor(for kind: GoogleMapMarkerModel.Kind) -> UIColor {
        switch kind {
        case .driver:
            return .systemBlue
        case .stopActive:
            return .systemOrange
        case .stopPending:
            return .systemGray
        case .stopCompleted:
            return .systemGreen
        case .stopSkipped:
            return .systemGray.withAlphaComponent(0.65)
        case .routeStart:
            return .systemGreen
        case .routeEnd, .destination:
            return .systemRed
        case .generic:
            return .systemIndigo
        }
    }
}

/// Top-level `NSObject` delegate so optional `GMSMapViewDelegate` methods resolve through the Obj‑C runtime (nested coordinators can miss tile lifecycle callbacks).
@objcMembers
private final class TribeGoogleMapViewCoordinator: NSObject, GMSMapViewDelegate {
    var mapView: GMSMapView?
    var lastOverlayFingerprint: String?
    var parentMarkers: [GoogleMapMarkerModel] = []
    var parentPolyline: [CLLocationCoordinate2D] = []
    var onMarkerIdTap: ((UUID) -> Void)?

#if DEBUG
    private var debugJohannesburgProbeMarker: GMSMarker?
    private var debugIdleCameraTestMarker: GMSMarker?

    func attachDebugJohannesburgProbeIfNeeded(to mapView: GMSMapView) {
        if debugJohannesburgProbeMarker == nil {
            let marker = GMSMarker()
            marker.position = CLLocationCoordinate2D(latitude: -26.2041, longitude: 28.0473)
            marker.title = "Johannesburg"
            debugJohannesburgProbeMarker = marker
        }
        debugJohannesburgProbeMarker?.map = mapView
    }

    func attachDebugIdleCameraTestMarkerIfNeeded(to mapView: GMSMapView) {
        if debugIdleCameraTestMarker == nil {
            let marker = GMSMarker()
            marker.position = CLLocationCoordinate2D(latitude: -26.12719, longitude: 28.04319)
            marker.title = "Test Marker"
            debugIdleCameraTestMarker = marker
        }
        debugIdleCameraTestMarker?.map = mapView
    }
#endif

#if DEBUG
    private var updateUIViewLogBudget = 60
    private var didLogTileLifecycleHint = false
    private var idleCameraLogBudget = 12
#endif

#if DEBUG
    func mapViewDidStartTileRendering(_ mapView: GMSMapView) {
        NSLog("[GoogleMapView] tiles started id=%lld", Int64(ObjectIdentifier(mapView).hashValue))
    }

    func mapViewDidFinishTileRendering(_ mapView: GMSMapView) {
        NSLog("[GoogleMapView] tiles finished id=%lld", Int64(ObjectIdentifier(mapView).hashValue))
    }

    func mapViewSnapshotReady(_ mapView: GMSMapView) {
        if !didLogTileLifecycleHint {
            didLogTileLifecycleHint = true
            let bundleNote = Bundle.main.bundleIdentifier ?? "(nil bundle id)"
            NSLog(
                "[GoogleMapView] snapshot ready — if the basemap stayed gray, verify Cloud Console: " +
                "Maps SDK for iOS enabled, billing active, API key iOS restriction matches %@. " +
                "Watch Xcode for: API key not authorized, BillingNotEnabledMapError, RefererNotAllowedMapError.",
                bundleNote
            )
        }
    }

    func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
        guard idleCameraLogBudget > 0 else { return }
        idleCameraLogBudget -= 1
        NSLog(
            "[GoogleMapView] idleAtCamera lat=%.5f lon=%.5f zoom=%.2f",
            position.target.latitude,
            position.target.longitude,
            position.zoom
        )
    }

    func logUpdateUIViewIfNeeded() {
        guard updateUIViewLogBudget > 0 else { return }
        updateUIViewLogBudget -= 1
        NSLog("GoogleMapView updateUIView called")
    }
#endif

    func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
        if let uuidString = marker.userData as? String, let id = UUID(uuidString: uuidString) {
            onMarkerIdTap?(id)
            return true
        }
        mapView.selectedMarker = marker
        return false
    }
}

private extension CLLocationCoordinate2D {
    func isEqualCoordinate(_ other: CLLocationCoordinate2D, tolerance: Double) -> Bool {
        abs(latitude - other.latitude) < tolerance && abs(longitude - other.longitude) < tolerance
    }
}
