//
//  RunMaterializer.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/03.
//

import Foundation

/// Converts ScheduledRunPreview objects into executable Run objects
/// Implements Requirements 4.1, 4.2, 4.3, 4.4, 4.8
class RunMaterializer {
    
    // MARK: - Dependencies
    
    private let firebaseService: MockFirebaseRunService
    private let roleContext: RoleContext
    
    // MARK: - Initialization
    
    init(firebaseService: MockFirebaseRunService, roleContext: RoleContext) {
        self.firebaseService = firebaseService
        self.roleContext = roleContext
    }
    
    // MARK: - Public Interface
    
    /// Materialize a ScheduledRunPreview into a Run object
    /// - Parameter preview: The preview to materialize
    /// - Returns: The created or existing Run
    /// - Throws: Error if materialization fails
    ///
    /// This method implements idempotent materialization:
    /// 1. Checks for existing runs with same title, time (±5min), and driver
    /// 2. Returns existing run if found (prevents duplicates)
    /// 3. Creates new run if no duplicate exists
    /// 4. Returns the created or existing run in .scheduled state
    func materialize(_ preview: ScheduledRunPreview) async throws -> Run {
        // Check for existing duplicate run
        if let existingRun = try await findExistingRun(
            title: preview.title,
            scheduledTime: preview.occurrenceDateTime,
            driverId: preview.driverUserId
        ) {
            // Return existing run instead of creating duplicate
            return existingRun
        }
        
        // No duplicate found - create new run
        let run = mapPreviewToRun(preview)
        
        // Create run using existing Firebase service
        let createdRun = try await firebaseService.createRun(run)
        
        return createdRun
    }
    
    // MARK: - Private Methods
    
    /// Find existing run that matches the preview criteria
    /// - Parameters:
    ///   - title: Run title to match
    ///   - scheduledTime: Scheduled time to match (±5 minutes)
    ///   - driverId: Driver ID to match
    /// - Returns: Existing run if found, nil otherwise
    private func findExistingRun(
        title: String,
        scheduledTime: Date,
        driverId: String
    ) async throws -> Run? {
        // Get all runs for the family
        let runs = try await firebaseService.listRuns(forFamilyId: roleContext.familyId)
        
        // Define time tolerance (±5 minutes)
        let timeTolerance: TimeInterval = 5 * 60 // 5 minutes in seconds
        
        // Find matching run
        let matchingRun = runs.first { run in
            // Check title match
            guard run.title == title else { return false }
            
            // Check driver match
            guard run.driverId == driverId else { return false }
            
            // Check time match (within ±5 minutes)
            let timeDifference = abs(run.scheduledTime.timeIntervalSince(scheduledTime))
            guard timeDifference <= timeTolerance else { return false }
            
            return true
        }
        
        return matchingRun
    }
    
    /// Map ScheduledRunPreview to Run object
    /// - Parameter preview: The preview to map
    /// - Returns: Run object ready for creation
    private func mapPreviewToRun(_ preview: ScheduledRunPreview) -> Run {
        // Convert ScheduleStop to RunStop
        let runStops = preview.stops.enumerated().map { index, scheduleStop in
            // Calculate scheduled time for each stop
            // First stop is at the preview occurrence time
            // Subsequent stops are spaced 15 minutes apart (reasonable default)
            let stopTime = preview.occurrenceDateTime.addingTimeInterval(TimeInterval(index * 15 * 60))
            
            return RunStop(
                type: scheduleStop.type,
                label: scheduleStop.label,
                scheduledTime: stopTime,
                requiredPassengerIds: preview.passengerUserIds,
                location: scheduleStop.location,
                notes: scheduleStop.notes
            )
        }
        
        // Convert passenger IDs to MemberSummary objects
        // Use demo user display names for known demo users
        let passengers = preview.passengerUserIds.map { passengerId in
            let displayName = getDisplayName(for: passengerId)
            return MemberSummary(
                id: passengerId,
                displayName: displayName,
                role: .passenger,
                status: .waiting
            )
        }
        
        // Create Run object in .scheduled state
        return Run(
            title: preview.title,
            scheduledTime: preview.occurrenceDateTime,
            driverId: preview.driverUserId,
            status: .scheduled,
            stops: runStops,
            passengers: passengers,
            createdBy: roleContext.userId,
            familyId: roleContext.familyId
        )
    }
    
    /// Get display name for a user ID
    /// - Parameter userId: The user ID
    /// - Returns: Display name for the user
    private func getDisplayName(for userId: String) -> String {
        // Map demo user IDs to display names
        // In a production implementation, this would fetch from a user service
        switch userId {
        case "demo-tafadzwa":
            return "Tafadzwa"
        case "demo-rue":
            return "Rue"
        case "demo-tj":
            return "TJ"
        case "demo-tawana":
            return "Tawana"
        default:
            // Fallback for unknown users
            return "Passenger"
        }
    }
}
