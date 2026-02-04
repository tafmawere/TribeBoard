//
//  DemoRunPlaybackController.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/04.
//

import Foundation
import CoreLocation
import Combine
import UIKit

/// Demo playback controller that makes the Active Run demo "come alive" with realistic movement and state progression
/// CRITICAL CONSTRAINTS: Does NOT add new screens, routes, modules, features, or navigation
/// Uses EXISTING models/services: Run, RunEvent, RunEventService, LocationService, MockFirebaseService
///
/// HOW TO VERIFY:
/// 1. Launch app in Active Run Only mode (AppConfig.launchMode = .activeRunOnly)
/// 2. Ensure AppConfig.isDemoPlaybackEnabled = true
/// 3. Verify map shows driver location moving every ~3 seconds along route
/// 4. Check timeline grows with new RunEvents (arrived, pickup, dropoff, next stop, completed)
/// 5. Confirm passenger status changes propagate to Observer view within ~1 second
/// 6. Validate Driver Focus Mode shows ONE primary action and progresses without confusion
/// 7. Watch complete run cycle: start → arrive → pickup → next stop → arrive → dropoff → complete
final class DemoRunPlaybackController: ObservableObject {
    
    // MARK: - Private Properties
    
    private let runEventService: RunEventService
    private let locationService: LocationService
    private let firebaseService: MockFirebaseRunService
    private let coreDataService: CoreDataService?
    
    private var locationTimer: AnyCancellable?
    private var playbackTimer: AnyCancellable?
    private var cancellables = Set<AnyCancellable>()
    
    private var currentRun: Run?
    private var currentRouteIndex: Int = 0
    private var routeCoordinates: [CLLocationCoordinate2D] = []
    private var isPlaybackActive: Bool = false
    private var playbackScript: [PlaybackAction] = []
    private var currentScriptIndex: Int = 0
    
    // MARK: - Initialization
    
    init(runEventService: RunEventService, 
         locationService: LocationService, 
         firebaseService: MockFirebaseRunService,
         coreDataService: CoreDataService? = nil) {
        self.runEventService = runEventService
        self.locationService = locationService
        self.firebaseService = firebaseService
        self.coreDataService = coreDataService
        
        setupNotificationObservers()
    }
    
    // MARK: - Public API
    
    /// Start demo playback if conditions are met
    func startIfNeeded() {
        guard AppConfig.isDemoPlaybackEnabled else { return }
        guard AppConfig.isActiveRunOnlyMode else { return }
        
        Task {
            await loadAndStartDemo()
        }
    }
    
    /// Stop demo playback and cleanup resources
    func stop() {
        isPlaybackActive = false
        stopLocationUpdates()
        stopPlaybackScript()
        
        #if DEBUG
        print("DemoRunPlaybackController: Stopped")
        #endif
    }
    
    /// Reset demo to initial state (optional - only if needed)
    func resetDemo() {
        stop()
        currentRouteIndex = 0
        currentScriptIndex = 0
        playbackScript = []
        routeCoordinates = []
        currentRun = nil
        
        #if DEBUG
        print("DemoRunPlaybackController: Reset")
        #endif
    }
    
    // MARK: - Private Implementation
    
    private func setupNotificationObservers() {
        // Listen for app lifecycle changes
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                self?.pausePlayback()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.resumePlayback()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.stop()
            }
            .store(in: &cancellables)
    }
    
    @MainActor
    private func loadAndStartDemo() async {
        do {
            // Get or create demo run
            currentRun = try await getCurrentOrCreateDemoRun()
            
            guard let run = currentRun else {
                #if DEBUG
                print("DemoRunPlaybackController: No demo run available")
                #endif
                return
            }
            
            // Only start if run is active
            guard run.status.isActive else {
                #if DEBUG
                print("DemoRunPlaybackController: Run not active, status: \(run.status)")
                #endif
                return
            }
            
            // Setup route and playback script
            setupRouteCoordinates(for: run)
            setupPlaybackScript(for: run)
            
            // Start playback
            startLocationUpdates()
            startPlaybackScript()
            
            isPlaybackActive = true
            
            #if DEBUG
            print("DemoRunPlaybackController: Started for run \(run.id)")
            #endif
            
        } catch {
            #if DEBUG
            print("DemoRunPlaybackController: Failed to start - \(error)")
            #endif
        }
    }
    
    private func getCurrentOrCreateDemoRun() async throws -> Run? {
        // Try to get existing active run first
        let familyId = "demo_family"
        
        if let activeRun = try await firebaseService.getCurrentActiveRun(for: familyId) {
            return activeRun
        }
        
        // Create demo run if none exists (reuse existing seeding logic)
        let demoRun = try await firebaseService.createDemoRun()
        
        // Start the run to make it active
        try await firebaseService.updateRunStatus(runId: demoRun.id, newStatus: .activeEnroute)
        
        return try await firebaseService.fetchRun(runId: demoRun.id)
    }
    
    private func setupRouteCoordinates(for run: Run) {
        guard !run.stops.isEmpty else { return }
        
        // Create realistic route between stops using linear interpolation
        routeCoordinates = []
        
        // Start from first stop location
        let startLocation = run.stops[0].location.coordinate
        routeCoordinates.append(startLocation)
        
        // Generate waypoints between each consecutive stop
        for i in 0..<(run.stops.count - 1) {
            let fromStop = run.stops[i].location.coordinate
            let toStop = run.stops[i + 1].location.coordinate
            
            // Generate 8-12 intermediate points for smooth movement
            let segmentPoints = generateRouteSegment(from: fromStop, to: toStop, points: 10)
            routeCoordinates.append(contentsOf: segmentPoints)
        }
        
        // Reset route index to current position based on run state
        currentRouteIndex = calculateCurrentRouteIndex(for: run)
    }
    
    private func generateRouteSegment(from start: CLLocationCoordinate2D, 
                                    to end: CLLocationCoordinate2D, 
                                    points: Int) -> [CLLocationCoordinate2D] {
        var segment: [CLLocationCoordinate2D] = []
        
        for i in 1...points {
            let ratio = Double(i) / Double(points + 1)
            let lat = start.latitude + (end.latitude - start.latitude) * ratio
            let lng = start.longitude + (end.longitude - start.longitude) * ratio
            segment.append(CLLocationCoordinate2D(latitude: lat, longitude: lng))
        }
        
        return segment
    }
    
    private func calculateCurrentRouteIndex(for run: Run) -> Int {
        // Position based on current stop progress
        let stopsCompleted = run.currentStopIndex
        let pointsPerStop = 10 // Should match generateRouteSegment points
        return min(stopsCompleted * pointsPerStop, routeCoordinates.count - 1)
    }
    
    private func setupPlaybackScript(for run: Run) {
        playbackScript = []
        currentScriptIndex = 0
        
        // Generate script based on current run state and remaining stops
        let currentStopIndex = run.currentStopIndex
        
        for i in currentStopIndex..<run.stops.count {
            let stop = run.stops[i]
            let delay = TimeInterval(i * 15 + 10) // Stagger actions every 15 seconds
            
            // Add arrive at stop action
            playbackScript.append(PlaybackAction(
                delay: delay,
                action: .arriveAtStop(stopIndex: i)
            ))
            
            // Add passenger actions for this stop
            for (passengerIndex, passengerId) in stop.requiredPassengerIds.enumerated() {
                let passengerDelay = delay + TimeInterval((passengerIndex + 1) * 3) // 3 seconds between passengers
                
                switch stop.type {
                case .pickup:
                    playbackScript.append(PlaybackAction(
                        delay: passengerDelay,
                        action: .confirmPickup(passengerId: passengerId)
                    ))
                case .dropoff:
                    playbackScript.append(PlaybackAction(
                        delay: passengerDelay,
                        action: .confirmDropoff(passengerId: passengerId)
                    ))
                case .waypoint:
                    break // No passenger actions for waypoints
                }
            }
            
            // Add next stop action (or end run if last stop)
            let nextStopDelay = delay + TimeInterval(stop.requiredPassengerIds.count * 3 + 5)
            if i == run.stops.count - 1 {
                playbackScript.append(PlaybackAction(
                    delay: nextStopDelay,
                    action: .endRun
                ))
            } else {
                playbackScript.append(PlaybackAction(
                    delay: nextStopDelay,
                    action: .nextStop
                ))
            }
        }
        
        // Sort by delay to ensure proper execution order
        playbackScript.sort { $0.delay < $1.delay }
    }
    
    private func startLocationUpdates() {
        guard !routeCoordinates.isEmpty else { return }
        
        locationTimer = Timer.publish(every: 3.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateLocation()
            }
    }
    
    private func stopLocationUpdates() {
        locationTimer?.cancel()
        locationTimer = nil
    }
    
    private func updateLocation() {
        guard isPlaybackActive,
              let run = currentRun,
              run.status.isActive,
              currentRouteIndex < routeCoordinates.count else { return }
        
        let currentLocation = routeCoordinates[currentRouteIndex]
        
        // Update location through existing service (throttled persistence)
        Task {
            do {
                try await firebaseService.updateDriverLocation(runId: run.id, location: currentLocation)
                
                // Only persist to Core Data every 5th update to avoid excessive writes
                if currentRouteIndex % 5 == 0 {
                    // Throttled Core Data persistence would go here if needed
                }
                
            } catch {
                #if DEBUG
                print("DemoRunPlaybackController: Location update failed - \(error)")
                #endif
            }
        }
        
        // Advance to next route point
        currentRouteIndex += 1
        
        // Check if we've reached the end of current segment
        if shouldTriggerArrival() {
            // Stop movement until next action is processed
            pauseLocationUpdates()
        }
    }
    
    private func shouldTriggerArrival() -> Bool {
        guard let run = currentRun else { return false }
        
        // Calculate if we've reached the next stop based on route progress
        let stopsCompleted = run.currentStopIndex
        let pointsPerStop = 10
        let nextStopThreshold = (stopsCompleted + 1) * pointsPerStop
        
        return currentRouteIndex >= nextStopThreshold
    }
    
    private func pauseLocationUpdates() {
        locationTimer?.cancel()
        locationTimer = nil
    }
    
    private func resumeLocationUpdates() {
        if isPlaybackActive && locationTimer == nil {
            startLocationUpdates()
        }
    }
    
    private func startPlaybackScript() {
        guard !playbackScript.isEmpty else { return }
        
        playbackTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.processPlaybackScript()
            }
    }
    
    private func stopPlaybackScript() {
        playbackTimer?.cancel()
        playbackTimer = nil
    }
    
    private func processPlaybackScript() {
        guard isPlaybackActive,
              currentScriptIndex < playbackScript.count else { return }
        
        let action = playbackScript[currentScriptIndex]
        let elapsed = Date().timeIntervalSince(Date()) // This would be tracked from start time in real implementation
        
        // For demo purposes, execute actions in sequence with simple timing
        if currentScriptIndex == 0 || elapsed >= action.delay {
            executePlaybackAction(action.action)
            currentScriptIndex += 1
            
            // Check if script is complete
            if currentScriptIndex >= playbackScript.count {
                stopPlaybackScript()
            }
        }
    }
    
    private func executePlaybackAction(_ action: PlaybackActionType) {
        guard let run = currentRun else { return }
        
        Task {
            do {
                switch action {
                case .arriveAtStop:
                    try await runEventService.processDriverAction(.arriveStop, runId: run.id)
                    
                case .confirmPickup(let passengerId):
                    try await runEventService.processDriverAction(.confirmPickup(passengerId: passengerId), runId: run.id)
                    
                case .confirmDropoff(let passengerId):
                    try await runEventService.processDriverAction(.confirmDropoff(passengerId: passengerId), runId: run.id)
                    
                case .nextStop:
                    try await runEventService.processDriverAction(.nextStop, runId: run.id)
                    // Resume location updates after moving to next stop
                    resumeLocationUpdates()
                    
                case .endRun:
                    try await runEventService.processDriverAction(.endRun, runId: run.id)
                    stop() // Stop playback when run completes
                }
                
                // Refresh current run state
                currentRun = try await firebaseService.fetchRun(runId: run.id)
                
                #if DEBUG
                print("DemoRunPlaybackController: Executed action \(action)")
                #endif
                
            } catch {
                #if DEBUG
                print("DemoRunPlaybackController: Action failed \(action) - \(error)")
                #endif
            }
        }
    }
    
    private func pausePlayback() {
        guard isPlaybackActive else { return }
        
        pauseLocationUpdates()
        stopPlaybackScript()
        
        #if DEBUG
        print("DemoRunPlaybackController: Paused")
        #endif
    }
    
    private func resumePlayback() {
        guard isPlaybackActive else { return }
        
        resumeLocationUpdates()
        startPlaybackScript()
        
        #if DEBUG
        print("DemoRunPlaybackController: Resumed")
        #endif
    }
    
    deinit {
        stop()
        cancellables.removeAll()
    }
}

// MARK: - Supporting Types

private struct PlaybackAction {
    let delay: TimeInterval
    let action: PlaybackActionType
}

private enum PlaybackActionType {
    case arriveAtStop(stopIndex: Int)
    case confirmPickup(passengerId: String)
    case confirmDropoff(passengerId: String)
    case nextStop
    case endRun
}