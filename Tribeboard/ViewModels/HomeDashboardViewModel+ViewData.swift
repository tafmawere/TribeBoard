//
//  HomeDashboardViewModel+ViewData.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/04.
//

import Foundation

// MARK: - View-Specific Data Models

/// Helper model for preparing featured card data
/// Requirements: 11.1, 11.3
struct EventCardData {
    let title: String
    let time: Date
    let location: String?
    let eventType: EventType
    let heroImageName: String
    let driverName: String?
    let participants: [User]
    let runId: String?
}

/// Helper model for preparing compact run card data
/// Requirements: 11.2, 11.4
struct RunCardData {
    let id: String
    let title: String
    let time: Date
    let status: RunStatus
    let participantCount: Int
    let statusText: String
}

// MARK: - HomeDashboardViewModel Extension

extension HomeDashboardViewModel {
    
    /// Convert nextRun to EventCardData for featured card display
    /// Requirements: 11.1, 11.3
    var featuredEventData: EventCardData? {
        guard let run = nextRun else { return nil }
        
        // Determine event type based on run status
        let eventType: EventType
        switch run.status {
        case .scheduled:
            eventType = .runScheduled
        case .activeEnroute, .arrivedAtStop:
            eventType = .runStarted
        case .completed:
            eventType = .runCompleted
        case .cancelled:
            eventType = .runCancelled
        case .paused:
            eventType = run.isDelayed ? .runDelayed : .runStarted
        }
        
        // Determine hero image based on event type or run title
        let heroImageName = determineHeroImage(for: run, eventType: eventType)
        
        // Get driver name from passengers
        let driverName = run.passengers.first { $0.role == .driver }?.displayName
        
        // Get location from first stop
        let location = run.stops.first?.location.address
        
        // Convert passengers to User objects
        let participants = run.passengers.map { passenger in
            User(
                id: passenger.id,
                displayName: passenger.displayName,
                role: convertMemberRoleToFamilyRole(passenger.role),
                familyId: familyId,
                avatarURL: passenger.avatarURL
            )
        }
        
        return EventCardData(
            title: run.title,
            time: run.scheduledTime,
            location: location,
            eventType: eventType,
            heroImageName: heroImageName,
            driverName: driverName,
            participants: participants,
            runId: run.id
        )
    }
    
    /// Convert todayEvents to RunCardData array for compact run cards
    /// Requirements: 11.2, 11.4
    var todayRunCards: [RunCardData] {
        return todayEvents.compactMap { event in
            guard let runId = event.runId,
                  let run = getDisplayRuns().first(where: { $0.id == runId }) else {
                return nil
            }
            
            let statusText = run.status.displayName
            let participantCount = run.passengers.count
            
            return RunCardData(
                id: run.id,
                title: event.title,
                time: event.time,
                status: run.status,
                participantCount: participantCount,
                statusText: statusText
            )
        }
    }
    
    /// Count of active runs
    /// Requirements: 11.3
    var activeRunCount: Int {
        return getDisplayRuns().filter { $0.status.isActive }.count
    }
    
    /// Last sync time (placeholder - would be tracked by data service)
    /// Requirements: 11.4
    var lastSyncTime: Date? {
        // In a real implementation, this would track the last data refresh time
        // For now, return current date when data is loaded
        return isLoading ? nil : Date()
    }
    
    // MARK: - Private Helper Methods
    
    /// Determine hero image name based on run and event type
    private func determineHeroImage(for run: Run, eventType: EventType) -> String {
        // Check run title for keywords to determine appropriate image
        let title = run.title.lowercased()
        
        if title.contains("soccer") || title.contains("football") {
            return "hero-soccer"
        } else if title.contains("school") || title.contains("bus") {
            return "hero-school"
        } else if title.contains("activity") || title.contains("practice") {
            return "hero-activity"
        } else {
            return "hero-default"
        }
    }
    
    /// Convert MemberRole to FamilyRole for User objects
    private func convertMemberRoleToFamilyRole(_ memberRole: MemberRole) -> FamilyRole {
        switch memberRole {
        case .driver:
            return .driver
        case .observer:
            return .observer
        case .passenger:
            return .observer // Passengers are treated as observers in family context
        }
    }
}
