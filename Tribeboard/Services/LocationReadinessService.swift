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

    private let manager = CLLocationManager()
    private let speedEstimator = SpeedEstimationService()
    private var cancellables: Set<AnyCancellable> = []

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
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
        refreshAuthorizationState()
    }

    func requestWhenInUseAccess() {
        manager.requestWhenInUseAuthorization()
    }

    func refreshAuthorizationState() {
        authorizationState = Self.mapAuthorization(manager.authorizationStatus)
    }

    func startUpdatingLocation() {
        refreshAuthorizationState()
        guard authorizationState == .authorizedWhenInUse || authorizationState == .authorizedAlways else { return }
        manager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        manager.stopUpdatingLocation()
    }

    func startRunTracking() {
        guard !trackingActive else { return }
        refreshAuthorizationState()
        if authorizationState != .authorizedWhenInUse && authorizationState != .authorizedAlways {
            requestWhenInUseAccess()
        }
        manager.startUpdatingLocation()
        trackingActive = true
    }

    func stopRunTracking() {
        guard trackingActive else { return }
        manager.stopUpdatingLocation()
        trackingActive = false
        speedEstimator.reset()
    }

    func resetSpeedEstimate() {
        speedEstimator.reset()
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationState = Self.mapAuthorization(manager.authorizationStatus)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        Task { @MainActor in
            if let previous = self.currentLocation,
               let previousTimestamp = self.lastLocationTimestamp {
                let movedDistance = latest.distance(from: previous)
                let elapsed = latest.timestamp.timeIntervalSince(previousTimestamp)
                if movedDistance < 5, elapsed < 1 {
                    return
                }
            }
            self.currentLocation = latest
            self.lastLocationTimestamp = latest.timestamp
            self.speedEstimator.ingestLocation(latest, at: latest.timestamp)
            self.lastError = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        Task { @MainActor in
            self.lastError = error.localizedDescription
        }
    }

#if DEBUG
    func simulateLocation(latitude: Double, longitude: Double) {
        let simulated = CLLocation(latitude: latitude, longitude: longitude)
        currentLocation = simulated
        lastLocationTimestamp = Date()
        trackingActive = true
        speedEstimator.ingestLocation(simulated, at: Date())
        lastError = nil
    }
#endif

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
