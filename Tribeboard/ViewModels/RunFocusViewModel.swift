//
//  RunFocusViewModel.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/05.
//

import Foundation
import Combine
import CoreLocation
import UIKit

/// ViewModel for Run Focus screen (pre-start run details)
/// Implements Requirement 4
@MainActor
class RunFocusViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var run: Run?
    @Published var isLoading: Bool = false
    @Published var error: RunFocusError?
    
    // MARK: - Private Properties
    
    private let runId: String
    private let firebaseService: MockFirebaseRunService
    private let roleManagementService: RoleManagementService
    private let runEventService: RunEventService
    private var cancellables = Set<AnyCancellable>()
    
    private var roleContext: RoleContext {
        RoleContext(
            userId: roleManagementService.currentUserId,
            role: roleManagementService.currentUserRole,
            familyId: roleManagementService.currentFamilyId
        )
    }
    
    // MARK: - Initialization
    
    init(runId: String, firebaseService: MockFirebaseRunService, roleManagementService: RoleManagementService, runEventService: RunEventService) {
        self.runId = runId
        self.firebaseService = firebaseService
        self.roleManagementService = roleManagementService
        self.runEventService = runEventService
        
        setupDataBinding()
        loadRun()
    }
    
    // MARK: - Public Methods
    
    /// Load run data from service
    func loadRun() {
        Task {
            await fetchRun()
        }
    }
    
    /// Check if current user can start the run
    func canStartRun() -> Bool {
        guard let run = run else { return false }
        
        // Only driver can start run
        guard run.driverId == roleContext.userId else { return false }
        
        // Run must be in scheduled state
        guard run.status == .scheduled else { return false }
        
        return true
    }
    
    /// Calculate total distance from all stops
    func calculateTotalDistance() -> Double {
        guard let run = run else { return 0.0 }
        
        var totalDistance: Double = 0.0
        
        for i in 0..<run.stops.count - 1 {
            let start = run.stops[i].location.coordinate
            let end = run.stops[i + 1].location.coordinate
            totalDistance += distance(from: start, to: end)
        }
        
        return totalDistance
    }
    
    /// Calculate estimated time of arrival
    func calculateETA() -> Date {
        guard let run = run else { return Date() }
        
        // Use the last stop's scheduled time as ETA
        if let lastStop = run.stops.last {
            return lastStop.scheduledTime
        }
        
        return run.scheduledTime
    }
    
    /// Start the run (driver only)
    func startRun() async {
        guard let run = run else {
            error = .runNotFound
            return
        }
        
        guard canStartRun() else {
            error = .permissionDenied("Only the assigned driver can start this run")
            return
        }
        
        do {
            // Process start run action through intent pipeline
            try await runEventService.processDriverAction(.startRun, runId: run.id)
            
            // Reload run to get updated state
            await fetchRun()
        } catch {
            self.error = .startRunFailed(error.localizedDescription)
        }
    }
    
    /// Open route in Apple Maps
    func openInMaps() {
        guard let run = run else { return }
        
        // Get all stop coordinates
        let coordinates = run.stops.map { $0.location.coordinate }
        
        guard !coordinates.isEmpty else { return }
        
        // Create Apple Maps URL with waypoints
        var urlComponents = URLComponents(string: "http://maps.apple.com/")
        
        // Add destination (last stop)
        if let lastStop = run.stops.last {
            urlComponents?.queryItems = [
                URLQueryItem(name: "daddr", value: "\(lastStop.location.latitude),\(lastStop.location.longitude)"),
                URLQueryItem(name: "dirflg", value: "d") // driving directions
            ]
        }
        
        if let url = urlComponents?.url {
            #if os(iOS)
            UIApplication.shared.open(url)
            #endif
        }
    }
    
    // MARK: - Private Methods
    
    private func setupDataBinding() {
        // Listen to run state changes
        runEventService.stateChangePublisher
            .filter { [weak self] stateChange in
                stateChange.runId == self?.runId
            }
            .sink { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    await self.fetchRun()
                }
            }
            .store(in: &cancellables)
    }
    
    private func fetchRun() async {
        isLoading = true
        error = nil
        
        do {
            if let fetchedRun = try await firebaseService.getRun(runId: runId) {
                self.run = fetchedRun
            } else {
                self.error = .runNotFound
            }
        } catch {
            self.error = .loadingFailed(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    /// Calculate distance between two coordinates using Haversine formula
    private func distance(from start: CLLocationCoordinate2D, to end: CLLocationCoordinate2D) -> Double {
        let earthRadius = 6371000.0 // meters
        
        let lat1 = start.latitude * .pi / 180
        let lat2 = end.latitude * .pi / 180
        let deltaLat = (end.latitude - start.latitude) * .pi / 180
        let deltaLon = (end.longitude - start.longitude) * .pi / 180
        
        let a = sin(deltaLat / 2) * sin(deltaLat / 2) +
                cos(lat1) * cos(lat2) *
                sin(deltaLon / 2) * sin(deltaLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        
        return earthRadius * c
    }
}

// MARK: - Error Types

enum RunFocusError: LocalizedError {
    case runNotFound
    case loadingFailed(String)
    case permissionDenied(String)
    case startRunFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .runNotFound:
            return "Run not found"
        case .loadingFailed(let message):
            return "Failed to load run: \(message)"
        case .permissionDenied(let message):
            return "Permission denied: \(message)"
        case .startRunFailed(let message):
            return "Failed to start run: \(message)"
        }
    }
}
