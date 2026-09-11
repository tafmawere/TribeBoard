import CoreLocation
import GoogleMaps
import SwiftUI
import UIKit

/// Map for an in-progress run: route polyline, numbered stops, driver pin, tap for callout selection.
struct ActiveRunRouteMapView: View {
    let run: SystemDomain.RunInstance
    let currentLocation: CLLocation?
    var roadPolylineCoordinates: [CLLocationCoordinate2D] = []
    var routeContext: RunRouteValidationContext = RunRouteValidationContext()
    var followNavigation: Bool = false
    var navigationCamera: GoogleMapCameraState?
    var routeStatusMessage: String?
    var isRouteLoading: Bool = false
    @Binding var selectedStopId: UUID?

    private let mapAdapter = RunMapAdapter()

    private var routeCoordinates: [CLLocationCoordinate2D] {
        let leg = roadPolylineCoordinates
        if !leg.isEmpty {
            return leg
        }
        return mapAdapter.remainingRouteCoordinates(for: run, context: routeContext)
    }

    private var sortedStops: [SystemDomain.Stop] {
        run.stopSnapshots.sorted { $0.order < $1.order }
    }

    private var progressByStopId: [UUID: SystemDomain.RunStopProgress] {
        Dictionary(uniqueKeysWithValues: run.stops.map { ($0.stopId, $0) })
    }

    private var activeDestinationCoordinate: CLLocationCoordinate2D? {
        guard let idx = run.activeStopIndex else { return nil }
        let stops = sortedStops
        guard stops.indices.contains(idx) else { return nil }
        let stop = stops[idx]
        let coordinate = CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)
        return RunRouteValidator.isPlausibleCoordinate(coordinate) ? coordinate : nil
    }

    private var usableDriverLocation: CLLocation? {
        guard let currentLocation,
              RunCoordinateGuard.isUsableForActiveRunRouting(currentLocation.coordinate) else {
            return nil
        }
        return currentLocation
    }

    private var legCameraHint: CoordinateRegionDegrees? {
        guard let destination = activeDestinationCoordinate else { return nil }
        return ActiveRunNavigationCamera.legRegion(
            driver: usableDriverLocation?.coordinate,
            destination: destination
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            TribeGoogleMapView(
                markers: googleMarkers,
                polylineCoordinates: routeCoordinates,
                strokeUIColor: UIColor.systemBlue.withAlphaComponent(0.85),
                lineWidth: 6,
                cameraHint: navigationCamera == nil ? legCameraHint : nil,
                externalCamera: navigationCamera,
                showsUserLocation: usableDriverLocation != nil,
                padding: .init(top: 56, left: 28, bottom: 52, right: 28),
                onMarkerIdTap: { id in
                    if sortedStops.contains(where: { $0.id == id }) {
                        selectedStopId = selectedStopId == id ? nil : id
                    }
                }
            )

            if isRouteLoading {
                routeBanner(
                    icon: "arrow.triangle.2.circlepath",
                    message: "Calculating route…",
                    tint: .blue
                )
            } else if let routeStatusMessage {
                routeBanner(
                    icon: "exclamationmark.triangle.fill",
                    message: routeStatusMessage,
                    tint: .orange
                )
            }
        }
    }

    private func routeBanner(icon: String, message: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(message)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var googleMarkers: [GoogleMapMarkerModel] {
        var markers: [GoogleMapMarkerModel] = []

        if let usableDriverLocation {
            markers.append(
                GoogleMapMarkerModel(
                    id: RunMapAdapter.driverPointID,
                    title: "You",
                    coordinate: usableDriverLocation.coordinate,
                    kind: .driver,
                    orderLabel: nil,
                    isSelected: false
                )
            )
        }

        let activeIndex = run.activeStopIndex

        for (index, stop) in sortedStops.enumerated() {
            let coordinate = CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)
            guard RunRouteValidator.isPlausibleCoordinate(coordinate) else { continue }
            let order = index + 1
            let progress = progressByStopId[stop.id]
            let isCurrent = isActiveStop(stopId: stop.id, activeIndex: activeIndex)
            let kind = googleKind(
                progress: progress,
                isCurrent: isCurrent,
                stop: stop,
                index: index,
                totalStops: sortedStops.count
            )
            let isSelected = selectedStopId == stop.id

            markers.append(
                GoogleMapMarkerModel(
                    id: stop.id,
                    title: stop.name,
                    coordinate: coordinate,
                    kind: kind,
                    orderLabel: "\(order)",
                    isSelected: isSelected
                )
            )
        }

        return markers
    }

    private func isActiveStop(stopId: UUID, activeIndex: Int?) -> Bool {
        guard let activeIndex,
              run.stops.indices.contains(activeIndex) else { return false }
        return run.stops[activeIndex].stopId == stopId
    }

    private func googleKind(
        progress: SystemDomain.RunStopProgress?,
        isCurrent: Bool,
        stop: SystemDomain.Stop,
        index: Int,
        totalStops: Int
    ) -> GoogleMapMarkerModel.Kind {
        let locationKind = StopLocationClassifier.kind(for: stop, index: index, totalStops: totalStops)
        switch progress?.status {
        case .completed, .skipped:
            return progress?.status == .skipped ? .stopSkipped : .stopCompleted
        default:
            break
        }
        if isCurrent {
            return .destination
        }
        switch locationKind {
        case .home: return .routeStart
        case .school: return .destination
        case .other: return .stopPending
        }
    }
}
