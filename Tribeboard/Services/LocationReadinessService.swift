import Foundation
import CoreLocation
import Combine

enum LocationAuthorizationState: String {
    case notDetermined
    case denied
    case restricted
    case authorizedWhenInUse
    case authorizedAlways
}

@MainActor
final class LocationReadinessService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationState: LocationAuthorizationState = .notDetermined
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var trackingActive: Bool = false
    @Published private(set) var lastLocationTimestamp: Date?
    @Published private(set) var estimatedSpeedMetersPerSecond: Double?
    @Published private(set) var speedSampleCount: Int = 0
    @Published private(set) var speedVariance: Double?
    @Published private(set) var lastError: String?
    /// Degrees clockwise from north (0–360). Uses `course` while moving, compass heading when idle — for navigation-style map markers.
    @Published private(set) var navigationBearingDegrees: Double = 0
#if DEBUG
    @Published private(set) var locationGPSourceLabel = "REAL GPS"
#endif

    private let manager = CLLocationManager()
    private var lastHeading: CLHeading?
    private let speedEstimator = SpeedEstimationService()
    private var cancellables: Set<AnyCancellable> = []
#if DEBUG
    private let debugLocationController = DebugLocationController()
    private var manualMockOverride = false
#endif

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 10
        manager.headingFilter = 5
        speedEstimator.$estimatedSpeedMetersPerSecond
            .sink { [weak self] speed in
                self?.estimatedSpeedMetersPerSecond = speed
            }
            .store(in: &cancellables)
        speedEstimator.$sampleCount
            .sink { [weak self] count in
                self?.speedSampleCount = count
            }
            .store(in: &cancellables)
        speedEstimator.$speedVariance
            .sink { [weak self] variance in
                self?.speedVariance = variance
            }
            .store(in: &cancellables)
#if DEBUG
        debugLocationController.onInjectLocation = { [weak self] location in
            self?.ingestLocationUpdate(location)
        }
        debugLocationController.applyPersistedPreset()
        refreshLocationGPSourceLabel()
        if isMockLocationActive {
            trackingActive = true
        }
#endif
        refreshAuthorizationState()
    }

    func requestWhenInUseAccess() {
        manager.requestWhenInUseAuthorization()
    }

    /// Call once when the main UI loads so maps can show **UserAnnotation** and ETA features use live coordinates.
    func prepareMapsAndLocation() {
#if DEBUG
        if isMockLocationActive {
            debugLocationController.applyPersistedPreset()
            return
        }
#endif
        refreshAuthorizationState()
        switch authorizationState {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
            manager.startUpdatingHeading()
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    func refreshAuthorizationState() {
        authorizationState = Self.mapAuthorization(manager.authorizationStatus)
    }

    func startUpdatingLocation() {
#if DEBUG
        if isMockLocationActive {
            debugLocationController.applyPersistedPreset()
            return
        }
#endif
        refreshAuthorizationState()
        guard authorizationState == .authorizedWhenInUse || authorizationState == .authorizedAlways else { return }
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
    }

    func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    func startRunTracking() {
        guard !trackingActive else { return }
#if DEBUG
        if isMockLocationActive {
            debugLocationController.applyPersistedPreset()
            trackingActive = true
            return
        }
#endif
        refreshAuthorizationState()
        if authorizationState != .authorizedWhenInUse && authorizationState != .authorizedAlways {
            requestWhenInUseAccess()
        }
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
        trackingActive = true
    }

    func stopRunTracking() {
        guard trackingActive else { return }
#if DEBUG
        if isMockLocationActive {
            trackingActive = false
            speedEstimator.reset()
            return
        }
#endif
        stopUpdatingLocation()
        trackingActive = false
        speedEstimator.reset()
    }

    func resetSpeedEstimate() {
        speedEstimator.reset()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationState = Self.mapAuthorization(manager.authorizationStatus)
#if DEBUG
            guard !self.isMockLocationActive else { return }
#endif
            switch self.authorizationState {
            case .authorizedWhenInUse, .authorizedAlways:
                self.manager.startUpdatingLocation()
                self.manager.startUpdatingHeading()
            case .denied, .restricted:
                self.manager.stopUpdatingLocation()
                self.manager.stopUpdatingHeading()
                self.currentLocation = nil
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in
#if DEBUG
            guard !self.isMockLocationActive else { return }
#endif
            self.ingestLocationUpdate(latest)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        Task { @MainActor in
            guard newHeading.headingAccuracy >= 0 else { return }
            self.lastHeading = newHeading
            self.applyNavigationBearing()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        Task { @MainActor in
            self.lastError = error.localizedDescription
        }
    }

#if DEBUG
    var debugLocationPreset: DebugLocationPreset {
        debugLocationController.selectedPreset
    }

    func setDebugLocationPreset(_ preset: DebugLocationPreset) {
        manualMockOverride = false
        if preset.isMock {
            manager.stopUpdatingLocation()
            manager.stopUpdatingHeading()
        } else {
            debugLocationController.stopMocking()
        }

        debugLocationController.apply(preset)
        refreshLocationGPSourceLabel()

        if preset == .device {
            refreshAuthorizationState()
            if authorizationState == .authorizedWhenInUse || authorizationState == .authorizedAlways {
                manager.startUpdatingLocation()
                manager.startUpdatingHeading()
            }
        } else {
            trackingActive = true
        }
    }

    func simulateLocation(latitude: Double, longitude: Double) {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
        manualMockOverride = true
        debugLocationController.injectManualLocation(latitude: latitude, longitude: longitude)
        trackingActive = true
        refreshLocationGPSourceLabel()
    }
#endif

    private func ingestLocationUpdate(_ latest: CLLocation) {
        if let previous = currentLocation,
           let previousTimestamp = lastLocationTimestamp {
            let movedDistance = latest.distance(from: previous)
            let elapsed = latest.timestamp.timeIntervalSince(previousTimestamp)
            if movedDistance < 5, elapsed < 1 {
                return
            }
        }
        currentLocation = latest
        lastLocationTimestamp = latest.timestamp
        speedEstimator.ingestLocation(latest, at: latest.timestamp)
        lastError = nil
        applyNavigationBearing()
    }

#if DEBUG
    private var isMockLocationActive: Bool {
        debugLocationController.isMockActive || manualMockOverride
    }

    private func refreshLocationGPSourceLabel() {
        locationGPSourceLabel = isMockLocationActive ? "MOCK GPS" : "REAL GPS"
    }
#endif

    private func applyNavigationBearing() {
        let movingThresholdMetersPerSecond = 1.0
        if let location = currentLocation,
           location.course >= 0,
           location.speed >= movingThresholdMetersPerSecond {
            navigationBearingDegrees = location.course
            return
        }
        if let heading = lastHeading {
            navigationBearingDegrees = heading.trueHeading >= 0 ? heading.trueHeading : heading.magneticHeading
        }
    }

    private static func mapAuthorization(_ status: CLAuthorizationStatus) -> LocationAuthorizationState {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorizedWhenInUse:
            return .authorizedWhenInUse
        case .authorizedAlways:
            return .authorizedAlways
        @unknown default:
            return .notDetermined
        }
    }
}
