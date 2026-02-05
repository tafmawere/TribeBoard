//
//  ActivityStreamViewModel.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/04.
//

import Foundation
import Combine

/// ViewModel for the Activity Stream that displays run events in chronological order
/// Implements Requirements 8.1, 8.2, 8.3, 8.4, 8.5
@MainActor
class ActivityStreamViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var events: [RunEvent] = []
    @Published var isLoading: Bool = false
    @Published var error: ActivityStreamError?
    @Published var acknowledgedEvents: Set<String> = []
    @Published var eventComments: [String: String] = [:]
    
    // MARK: - Private Properties
    
    private let runEventService: RunEventService
    private let runId: String
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(runId: String, runEventService: RunEventService) {
        self.runId = runId
        self.runEventService = runEventService
        setupEventSubscription()
        loadEvents()
    }
    
    // MARK: - Public Methods
    
    /// Load all events for the run
    func loadEvents() {
        isLoading = true
        error = nil
        
        // Start listening to real-time updates
        runEventService.startListening(to: runId)
        
        // In a real implementation, this would fetch from backend
        // For now, we'll simulate loading events
        Task {
            await MainActor.run {
                // Simulate loading delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Acknowledge an event
    /// Implements Requirement 8.5 - Allow users to acknowledge events
    func acknowledgeEvent(_ eventId: String) {
        acknowledgedEvents.insert(eventId)
        
        // Log the acknowledgment
        let acknowledgmentEvent = RunEvent(
            runId: runId,
            type: .locationUpdated, // Using existing type for acknowledgment
            actorId: "current_user", // In real app, this would be the actual user ID
            stateBefore: nil,
            stateAfter: .scheduled, // This would be the current state
            currentStopIndex: 0,
            note: "Event acknowledged by user"
        )
        
        // In a real implementation, this would be sent to the backend
        runEventService.broadcastEvent(acknowledgmentEvent)
    }
    
    /// Add a comment to an event
    /// Implements Requirement 8.5 - Allow users to add comments
    func addComment(to eventId: String, comment: String) {
        guard !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        eventComments[eventId] = comment
        
        // Create a comment event
        let commentEvent = RunEvent(
            runId: runId,
            type: .locationUpdated, // Using existing type for comments
            actorId: "current_user", // In real app, this would be the actual user ID
            stateBefore: nil,
            stateAfter: .scheduled, // This would be the current state
            currentStopIndex: 0,
            note: "Comment: \(comment)"
        )
        
        // In a real implementation, this would be sent to the backend
        runEventService.broadcastEvent(commentEvent)
    }
    
    /// Get events sorted chronologically (newest first for display)
    var sortedEvents: [RunEvent] {
        return events.sorted { $0.timestamp > $1.timestamp }
    }
    
    /// Get events grouped by date
    var eventsByDate: [Date: [RunEvent]] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: sortedEvents) { event in
            calendar.startOfDay(for: event.timestamp)
        }
        return grouped
    }
    
    /// Check if an event has been acknowledged
    func isEventAcknowledged(_ eventId: String) -> Bool {
        return acknowledgedEvents.contains(eventId)
    }
    
    /// Get comment for an event
    func getComment(for eventId: String) -> String? {
        return eventComments[eventId]
    }
    
    /// Format timestamp for display
    func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /// Format date for section headers
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    // MARK: - Private Methods
    
    private func setupEventSubscription() {
        // Subscribe to real-time events
        runEventService.eventPublisher
            .filter { $0.runId == self.runId }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                self.addEvent(event)
            }
            .store(in: &cancellables)
        
        // Subscribe to state changes
        runEventService.stateChangePublisher
            .filter { $0.runId == self.runId }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stateChange in
                guard let self = self else { return }
                self.handleStateChange(stateChange)
            }
            .store(in: &cancellables)
    }
    
    private func addEvent(_ event: RunEvent) {
        // Avoid duplicates
        guard !events.contains(where: { $0.id == event.id }) else { return }
        
        events.append(event)
        
        // Log all state transitions and user actions as per Requirement 8.1
        print("Activity Stream: Added event \(event.type.displayName) for run \(runId)")
    }
    
    private func handleStateChange(_ stateChange: RunStateChange) {
        // Create an event for the state change if one doesn't already exist
        let stateChangeEvent = RunEvent(
            runId: stateChange.runId,
            type: stateChange.eventType,
            timestamp: stateChange.timestamp,
            actorId: stateChange.actorId,
            stateBefore: stateChange.fromState,
            stateAfter: stateChange.toState,
            currentStopIndex: 0 // This would be provided by the state change
        )
        
        addEvent(stateChangeEvent)
    }
    
    deinit {
        runEventService.stopListening(to: runId)
        cancellables.removeAll()
    }
}

// MARK: - Supporting Types

enum ActivityStreamError: LocalizedError {
    case loadingFailed(Error)
    case acknowledgmentFailed(Error)
    case commentFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .loadingFailed(let error):
            return "Failed to load activity stream: \(error.localizedDescription)"
        case .acknowledgmentFailed(let error):
            return "Failed to acknowledge event: \(error.localizedDescription)"
        case .commentFailed(let error):
            return "Failed to add comment: \(error.localizedDescription)"
        }
    }
}