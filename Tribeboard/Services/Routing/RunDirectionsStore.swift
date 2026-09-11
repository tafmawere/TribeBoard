import Combine
import CoreLocation
import Foundation

@MainActor
final class RunDirectionsStore: ObservableObject {
    @Published private(set) var roadCoordinates: [CLLocationCoordinate2D] = []
    @Published private(set) var distanceMeters: Double?
    @Published private(set) var travelTimeSeconds: TimeInterval?
    @Published private(set) var loadState: RunRouteLoadState = .idle

    private let service: RouteDirectionsService
    private let cache = RunRouteCache()
    private var loadTask: Task<Void, Never>?
    private var lastRefreshOrigin: CLLocationCoordinate2D?
    private var lastRefreshAt: Date?

    private let minRefreshIntervalSeconds: TimeInterval = 8
    private let minRefreshMovementMeters: Double = 20

    init(service: RouteDirectionsService = MKDirectionsRouteService()) {
        self.service = service
    }

    func refresh(run: SystemDomain.RunInstance, origin location: CLLocation?, force: Bool = false) {
        if !force, !shouldRefresh(origin: location?.coordinate) { return }
        lastRefreshOrigin = location?.coordinate
        lastRefreshAt = Date()
        loadTask?.cancel()
        loadTask = Task { await load(run: run, origin: location) }
    }

    func clear() {
        loadTask?.cancel()
        roadCoordinates = []
        distanceMeters = nil
        travelTimeSeconds = nil
        loadState = .idle
        lastRefreshOrigin = nil
        lastRefreshAt = nil
    }

    private func shouldRefresh(origin: CLLocationCoordinate2D?) -> Bool {
        guard let lastRefreshAt else { return true }
        if Date().timeIntervalSince(lastRefreshAt) >= minRefreshIntervalSeconds { return true }
        guard let origin, let last = lastRefreshOrigin else { return false }
        let moved = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
            .distance(from: CLLocation(latitude: last.latitude, longitude: last.longitude))
        return moved >= minRefreshMovementMeters
    }

    private func load(run: SystemDomain.RunInstance, origin location: CLLocation?) async {
        guard run.status == .inProgress else {
            clear()
            return
        }

        loadState = .loading

        guard let idx = run.activeStopIndex else {
            fail(runId: run.id, message: "No active stop for this run.")
            applyStopsOnlyFallback(run: run)
            return
        }

        let stops = run.stopSnapshots.sorted { $0.order < $1.order }
        guard stops.indices.contains(idx) else {
            fail(runId: run.id, message: "Active stop is missing from the route.")
            applyStopsOnlyFallback(run: run)
            return
        }

        let destination = stops[idx]
        let destCoord = CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude)

        RunRouteDebugLogger.logRouteAttempt(
            runId: run.id,
            stopIndex: idx,
            origin: resolvedOrigin(location: location, run: run, stopIndex: idx, stops: stops),
            destination: destCoord,
            currentLocation: location
        )

        if let reason = RunCoordinateGuard.rejectionReason(for: destCoord, label: "destination") {
            fail(runId: run.id, message: friendlyFailureMessage(for: reason))
            applyStopsOnlyFallback(run: run, focusDestination: destCoord)
            return
        }

        guard RunRouteValidator.isPlausibleCoordinate(destCoord) else {
            fail(runId: run.id, message: "Destination location is missing or invalid.")
            applyStopsOnlyFallback(run: run)
            return
        }

        if let cached = await cache.result(runId: run.id, stopIndex: idx) {
            apply(cached, runId: run.id, source: "cache")
            return
        }

        guard let routingOrigin = resolvedOrigin(location: location, run: run, stopIndex: idx, stops: stops) else {
            let message = originFailureMessage(location: location)
            fail(runId: run.id, message: message)
            applyStopsOnlyFallback(run: run, focusDestination: destCoord)
            return
        }

        if let reason = RunCoordinateGuard.rejectionReason(for: routingOrigin, label: "origin") {
            fail(runId: run.id, message: friendlyFailureMessage(for: reason))
            applyStopsOnlyFallback(run: run, focusDestination: destCoord)
            return
        }

        let legDistance = CLLocation(latitude: routingOrigin.latitude, longitude: routingOrigin.longitude)
            .distance(from: CLLocation(latitude: destCoord.latitude, longitude: destCoord.longitude))
        guard ActiveRunNavigationCamera.isReasonableLegDistance(meters: legDistance) else {
            fail(
                runId: run.id,
                message: "Route looks too long (\(Int(legDistance / 1000)) km). Check stop locations."
            )
            applyStopsOnlyFallback(run: run, focusDestination: destCoord)
            return
        }

        do {
            let result = try await service.fetchRoute(from: routingOrigin, to: destCoord)
            guard !Task.isCancelled else { return }
            await cache.store(result, runId: run.id, stopIndex: idx)
            apply(result, runId: run.id, source: "mkdirections")
        } catch {
            fail(runId: run.id, message: "Could not calculate a driving route. Showing stops on the map.")
            applyStopsOnlyFallback(run: run, from: routingOrigin, to: destCoord)
        }
    }

    /// Prefer live GPS when valid; otherwise fall back to previous completed stop.
    private func resolvedOrigin(
        location: CLLocation?,
        run: SystemDomain.RunInstance,
        stopIndex: Int,
        stops: [SystemDomain.Stop]
    ) -> CLLocationCoordinate2D? {
        if let coordinate = location?.coordinate,
           RunCoordinateGuard.isUsableForActiveRunRouting(coordinate) {
            return coordinate
        }
        if stopIndex > 0 {
            let previous = stops[stopIndex - 1]
            let coord = CLLocationCoordinate2D(latitude: previous.latitude, longitude: previous.longitude)
            if RunCoordinateGuard.isUsableForActiveRunRouting(coord) {
                return coord
            }
        }
        return nil
    }

    private func originFailureMessage(location: CLLocation?) -> String {
        if let coordinate = location?.coordinate {
            if let reason = RunCoordinateGuard.rejectionReason(for: coordinate, label: "current location") {
                return friendlyFailureMessage(for: reason)
            }
        }
        return "Waiting for a valid location signal to calculate your route."
    }

    private func friendlyFailureMessage(for technicalReason: String) -> String {
        if technicalReason.contains("outside South Africa") {
            return "Location signal looks incorrect for this route. " +
                "On the simulator, set Features → Location → Custom Location near your stop."
        }
        return technicalReason
    }

    private func apply(_ result: RouteDirectionsResult, runId: UUID, source: String) {
        guard ActiveRunNavigationCamera.isReasonableLegDistance(meters: result.distanceMeters),
              !result.coordinates.isEmpty else {
            fail(runId: runId, message: "Route calculation returned an unrealistic distance.")
            roadCoordinates = []
            distanceMeters = nil
            travelTimeSeconds = nil
            return
        }
        roadCoordinates = result.coordinates
        distanceMeters = result.distanceMeters
        travelTimeSeconds = result.expectedTravelTimeSeconds
        loadState = .ready
        RunRouteDebugLogger.logRouteResult(
            runId: runId,
            distanceMeters: result.distanceMeters,
            etaSeconds: result.expectedTravelTimeSeconds,
            polylinePointCount: result.coordinates.count,
            source: source
        )
    }

    private func fail(runId: UUID, message: String) {
        loadState = .failed(message: message)
        distanceMeters = nil
        travelTimeSeconds = nil
        RunRouteDebugLogger.logRouteFailure(runId: runId, message: message)
    }

    private func applyStopsOnlyFallback(
        run: SystemDomain.RunInstance,
        from: CLLocationCoordinate2D? = nil,
        to: CLLocationCoordinate2D? = nil,
        focusDestination: CLLocationCoordinate2D? = nil
    ) {
        let adapter = RunMapAdapter()
        let remaining = adapter.remainingRouteCoordinates(for: run)

        if let from, let to,
           RunCoordinateGuard.isUsableForActiveRunRouting(from),
           RunCoordinateGuard.isUsableForActiveRunRouting(to) {
            let legDistance = CLLocation(latitude: from.latitude, longitude: from.longitude)
                .distance(from: CLLocation(latitude: to.latitude, longitude: to.longitude))
            if ActiveRunNavigationCamera.isReasonableLegDistance(meters: legDistance) {
                roadCoordinates = [from, to]
                if case .failed = loadState {
                    distanceMeters = nil
                    travelTimeSeconds = nil
                }
                return
            }
        }

        if let focusDestination, remaining.isEmpty {
            roadCoordinates = [focusDestination]
        } else {
            roadCoordinates = remaining
        }

        if case .failed = loadState {
            distanceMeters = nil
            travelTimeSeconds = nil
        } else if remaining.count >= 2 {
            let total = RunRouteValidator.polylineDistanceMeters(remaining)
            if ActiveRunNavigationCamera.isReasonableLegDistance(meters: total) {
                distanceMeters = total
            }
        }
    }
}
