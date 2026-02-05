//
//  LocationService.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/03.
//

import Foundation
import CoreLocation
import Combine

@MainActor
class LocationService: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()
    private var locationUpdateTimer: Timer?
    
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isTracking = false
    
    // Callback for location updates during active runs
    var onLocationUpdate: ((CLLocationCoordinate2D) -> Void)?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10 // Update every 10 meters
        authorizationStatus = locationManager.authorizationStatus
    }
    
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startTracking() {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            requestLocationPermission()
            return
        }
        
        isTracking = true
        locationManager.startUpdatingLocation()
        
        // Start periodic location updates for Firebase
        locationUpdateTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                guard let location = self.currentLocation else { return }
                self.onLocationUpdate?(location)
            }
        }
    }
    
    func stopTracking() {
        isTracking = false
        locationManager.stopUpdatingLocation()
        locationUpdateTimer?.invalidate()
        locationUpdateTimer = nil
    }
    
    func stopLocationUpdates() {
        stopTracking()
    }
    
    func getCurrentLocation() async throws -> CLLocationCoordinate2D {
        guard authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways else {
            throw LocationError.permissionDenied
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            locationManager.requestLocation()
            
            // Store continuation for completion in delegate
            self.locationContinuation = continuation
        }
    }
    
    private var locationContinuation: CheckedContinuation<CLLocationCoordinate2D, Error>?
    
    deinit {
        locationUpdateTimer?.invalidate()
        locationUpdateTimer = nil
        locationManager.stopUpdatingLocation()
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        let coordinate = location.coordinate
        currentLocation = coordinate
        
        // Complete any pending location request
        if let continuation = locationContinuation {
            locationContinuation = nil
            continuation.resume(returning: coordinate)
        }
        
        // Notify callback for active tracking
        if isTracking {
            onLocationUpdate?(coordinate)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
        
        // Complete any pending location request with error
        if let continuation = locationContinuation {
            locationContinuation = nil
            continuation.resume(throwing: error)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        authorizationStatus = status
        
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            if isTracking {
                locationManager.startUpdatingLocation()
            }
        case .denied, .restricted:
            stopTracking()
            if let continuation = locationContinuation {
                locationContinuation = nil
                continuation.resume(throwing: LocationError.permissionDenied)
            }
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
}

enum LocationError: LocalizedError {
    case permissionDenied
    case locationUnavailable
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Location permission denied"
        case .locationUnavailable:
            return "Location unavailable"
        case .timeout:
            return "Location request timed out"
        }
    }
}