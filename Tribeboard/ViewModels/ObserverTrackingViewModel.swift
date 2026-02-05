//
//  ObserverTrackingViewModel.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/04.
//

import Foundation
import Combine
import CoreLocation

/// ViewModel for Observer Tracking screen
/// Implements ObserverTrackingContract with real-time monitoring capabilities
/// Requirements 5.1, 5.5, 3.1, 3.2, 3.3, 3.4
@MainActor
class ObserverTrackingViewModel: ObservableObject, ObserverTrackingContract {
    
    // MARK: - Published Properties
    
    @Published var isLoading: Bool = false
    @Published var error: ObserverTrackingError?
    @Published var isConnected: Bool = true
    @Published var lastUpdateTime: Date?
    
    // Contract inputs (computed from internal state)
    var runId: String { _runId }
    var driverLocation: CLLocationCoordinate2D? { _driverLocation }
    var runState: RunStatus { _runState }
    var eta: Date? { _eta }
    var timelineEvents: [RunEvent] { _timelineEvents }
    
    // MARK: - Private Properties
    
    private let _runId: String
    private var _driverLocation: CLLocationCoordinate2D?
    private var _runState: RunStatus = .scheduled
    private var _eta: Date?
    private var _timelineEvents: [RunEvent] = []
    
    private let runEventService: RunEventService
    private let roleContext: RoleContext
    private var cancellables = Set<AnyCancellable>()
    
    // Current run data
    private var currentRun: Run?
    var acknowledgedEvents: Set<String> = []
    
    // MARK: - Initialization
    
    init(runId: String, runEventService: RunEventService, roleContext: RoleContext) {
        self._runId = runId
        self.runEventService = runEventService
        self.roleContext = roleContext
        
        setupDataBinding()
        loadRunData()
    }
    
    // MARK: - ObserverTrackingContract Implementation
    
    func acknowledgeUpdate() {
        // Mark the latest event as acknowledged
        if let latestEvent = _timelineEvents.last {
            acknowledgedEvents.insert(latestEvent.id)
            print("Acknowledged event: \(latestEvent.type.displayName)")
        }
    }
    
    func contactDriver() {
        // External action - would typically open messaging or calling interface
        print("Contacting driver for run: \(_runId)")
        // This would be handled by the parent coordinator to open external apps
    }
    
    // MARK: - Public Interface
    
    /// Get unacknowledged events count
    func getUnacknowledgedEventsCount() -> Int {
        return _timelineEvents.filter { !acknowledgedEvents.contains($0.id) }.count
    }
    
    /// Get the latest unacknowledged event
    func getLatestUnacknowledgedEvent() -> RunEvent? {
        return _timelineEvents.last { !acknowledgedEvents.contains($0.id) }
    }
    
    /// Get current run information for display
    func getCurrentRunInfo() -> RunInfo? {
        guard let run = currentRun else { return nil }
        
        let currentStop = run.currentStopIndex < run.stops.count ? run.stops[run.currentStopIndex] : nil
        let progress = calculateRunProgress(run)
        
        return RunInfo(
            run: run,
            currentStop: currentStop,
            progress: progress,
            isDelayed: run.isDelayed,
            delayReason: run.delayReason
        )
    }
    
    /// Get passenger status summary
    func getPassengerStatusSummary() -> PassengerStatusSummary? {
        guard let run = currentRun else { return nil }
        
        let waitingCount = run.passengers.filter { $0.status == .waiting }.count
        let onboardCount = run.passengers.filter { $0.status == .onboard }.count
        let droppedOffCount = run.passengers.filter { $0.status == .droppedOff }.count
        
        return PassengerStatusSummary(
            total: run.passengers.count,
            waiting: waitingCount,
            onboard: onboardCount,
            droppedOff: droppedOffCount
        )
    }
    
    /// Get timeline events grouped by type
    func getGroupedTimelineEvents() -> [EventGroup] {
        // Filter timeline events based on role permissions
        let filteredEvents = RoleBasedDataFilter.filterTimelineEvents(_timelineEvents, for: roleContext)
        
        let groupedDict = Dictionary(grouping: filteredEvents) { event in
            Calendar.current.startOfDay(for: event.timestamp)
        }
        
        return groupedDict.map { date, events in
            EventGroup(
                date: date,
                events: events.sorted { $0.timestamp < $1.timestamp }
            )
        }.sorted { $0.date > $1.date }
    }
    
    /// Refresh tracking data
    func refresh() async {
        loadRunData()
    }
    
    /// Check if user can contact driver
    func canContactDriver() -> Bool {
        guard let run = currentRun else { return false }
        
        // Observers can contact driver during active runs
        return run.status.isActive && 
               PermissionValidator.canPerformOperation(.contactDriver, role: roleContext.role, userId: roleContext.userId, run: run)
    }
    
    /// Get filtered run data for display based on role
    func getFilteredRunData() -> FilteredRunData? {
        guard let run = currentRun else { return nil }
        return RoleBasedDataFilter.filterRunDataForDisplay(run, roleContext: roleContext)
    }
    
    /// Get available observer actions for current run
    func getAvailableObserverActions() -> [ObserverAction] {
        guard let run = currentRun else { return [] }
        let actionSet = RoleBasedDataFilter.getAvailableActions(for: run, roleContext: roleContext)
        return actionSet.observerActions
    }
    
    // MARK: - Private Methods
    
    private func setupDataBinding() {
        // Listen to run events for real-time updates - Requirements 3.1, 3.2, 3.3
        runEventService.eventPublisher
            .filter { $0.runId == self._runId }
            .sink { [weak self] event in
                guard let self = self else { return }
                Task { @MainActor in
                    await self.handleRunEvent(event)
                }
            }
            .store(in: &cancellables)
        
        // Listen to state changes - Requirements 3.1, 3.2, 3.3
        runEventService.stateChangePublisher
            .filter { $0.runId == self._runId }
            .sink { [weak self] stateChange in
                guard let self = self else { return }
                Task { @MainActor in
                    self.handleStateChange(stateChange)
                }
            }
            .store(in: &cancellables)
        
        // Monitor connection status
        runEventService.$isConnected
            .sink { [weak self] isConnected in
                guard let self = self else { return }
                self.isConnected = isConnected
            }
            .store(in: &cancellables)
        
        // Start listening to this run
        runEventService.startListening(to: _runId)
    }
    
    private func loadRunData() {
        Task {
            await refreshTrackingData()
        }
    }
    
    private func refreshTrackingData() async {
        isLoading = true
        error = nil
        
        // Load current run data
        await loadCurrentRun()
        
        // Load timeline events
        await loadTimelineEvents()
        
        // Update ETA calculation
        updateETA()
        
        lastUpdateTime = Date()
        
        isLoading = false
    }
    
    private func loadCurrentRun() async {
        // This would typically fetch from a service
        // For now, we'll simulate loading run data
        // In real implementation: currentRun = try await runService.fetchRun(runId: _runId)
        
        // Update state from loaded run
        if let run = currentRun {
            _runState = run.status
            _driverLocation = run.lastLocation?.coordinate
        }
    }
    
    private func loadTimelineEvents() async {
        // This would typically fetch from a service
        // For now, we'll simulate loading timeline events
        // In real implementation: _timelineEvents = try await runService.fetchRunEvents(runId: _runId)
        
        // Sort events by timestamp
        _timelineEvents.sort { $0.timestamp < $1.timestamp }
    }
    
    private func updateETA() {
        guard let run = currentRun,
              run.status.isActive,
              run.currentStopIndex < run.stops.count else {
            _eta = nil
            return
        }
        
        // Calculate ETA based on current location and next stop
        // This would typically use routing services
        // For now, provide a simple estimate
        _ = run.stops[run.currentStopIndex]
        let estimatedTravelTime: TimeInterval = 600 // 10 minutes
        _eta = Date().addingTimeInterval(estimatedTravelTime)
    }
    
    private func calculateRunProgress(_ run: Run) -> Double {
        guard !run.stops.isEmpty else { return 0.0 }
        
        let completedStops = run.stops.prefix(run.currentStopIndex).count
        return Double(completedStops) / Double(run.stops.count)
    }
    
    private func handleRunEvent(_ event: RunEvent) async {
        // Add new event to timeline - Requirements 3.1, 3.2, 3.3
        if !_timelineEvents.contains(where: { $0.id == event.id }) {
            _timelineEvents.append(event)
            _timelineEvents.sort { $0.timestamp < $1.timestamp }
        }
        
        // Update driver location if available
        if let location = event.location {
            _driverLocation = location.coordinate
        }
        
        // Refresh full data for significant events
        switch event.type {
        case .runStarted, .runArrivedStop, .passengerPickedUp, .passengerDroppedOff, .runCompleted, .runCancelled:
            await refreshTrackingData()
        default:
            break
        }
    }
    
    private func handleStateChange(_ stateChange: RunStateChange) {
        // Update state immediately for responsive UI - Requirements 3.1, 3.2, 3.3
        _runState = stateChange.toState
        
        // Update ETA when state changes
        updateETA()
        
        // Refresh full data
        Task {
            await refreshTrackingData()
        }
    }
    
    deinit {
        // Stop listening when view model is deallocated
        runEventService.stopListening(to: _runId)
    }
}

// MARK: - Supporting Types

/// Information about the current run for display
struct RunInfo {
    let run: Run
    let currentStop: RunStop?
    let progress: Double
    let isDelayed: Bool
    let delayReason: String?
    
    var statusDescription: String {
        if isDelayed, let reason = delayReason {
            return "Delayed: \(reason)"
        }
        
        switch run.status {
        case .scheduled:
            return "Scheduled for \(formatTime(run.scheduledTime))"
        case .activeEnroute:
            if let stop = currentStop {
                return "En route to \(stop.label)"
            } else {
                return "En route"
            }
        case .arrivedAtStop:
            if let stop = currentStop {
                return "Arrived at \(stop.label)"
            } else {
                return "Arrived at stop"
            }
        case .paused:
            return "Paused"
        case .completed:
            return "Completed"
        case .cancelled:
            return "Cancelled"
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// Summary of passenger statuses
struct PassengerStatusSummary {
    let total: Int
    let waiting: Int
    let onboard: Int
    let droppedOff: Int
    
    var completionPercentage: Double {
        guard total > 0 else { return 0.0 }
        return Double(droppedOff) / Double(total)
    }
    
    var statusText: String {
        if total == droppedOff {
            return "All passengers delivered"
        } else if onboard > 0 {
            return "\(onboard) onboard, \(waiting) waiting"
        } else {
            return "\(waiting) waiting for pickup"
        }
    }
}

/// Grouped timeline events for display
struct EventGroup {
    let date: Date
    let events: [RunEvent]
    
    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Error Types

enum ObserverTrackingError: LocalizedError {
    case loadingFailed(String)
    case permissionDenied(String)
    case networkError(String)
    case runNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .loadingFailed(let message):
            return "Failed to load tracking data: \(message)"
        case .permissionDenied(let message):
            return "Permission denied: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .runNotFound(let message):
            return "Run not found: \(message)"
        }
    }
}

// MARK: - Core Location Extension

extension GeoPoint {
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}