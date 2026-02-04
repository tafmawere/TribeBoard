//
//  DriverFocusModeViewModel.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/04.
//

import Foundation
import Combine
import CoreLocation

/// ViewModel for Driver Focus Mode screen
/// Implements DriverFocusModeContract with Uber-like execution flow
/// Requirements 5.1, 5.5, 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7
@MainActor
class DriverFocusModeViewModel: ObservableObject, DriverFocusModeContract {
    
    // MARK: - Published Properties
    
    @Published var isLoading: Bool = false
    @Published var error: DriverFocusModeError?
    @Published var isProcessingAction: Bool = false
    
    // Contract inputs (computed from internal state)
    var runId: String { _runId }
    var currentStop: RunStop? { _currentStop }
    var nextStop: RunStop? { _nextStop }
    var passengers: [MemberSummary] { _passengers }
    var runState: RunStatus { _runState }
    
    // MARK: - Private Properties
    
    private let _runId: String
    private var _currentStop: RunStop?
    private var _nextStop: RunStop?
    private var _passengers: [MemberSummary] = []
    private var _runState: RunStatus = .scheduled
    
    private let runEventService: RunEventService
    private let roleContext: RoleContext
    private var cancellables = Set<AnyCancellable>()
    
    // Current run data
    private var currentRun: Run?
    private var availableActions: [DriverAction] = []
    
    // MARK: - Initialization
    
    init(runId: String, runEventService: RunEventService, roleContext: RoleContext) {
        self._runId = runId
        self.runEventService = runEventService
        self.roleContext = roleContext
        
        setupDataBinding()
        loadRunData()
    }
    
    // MARK: - DriverFocusModeContract Implementation
    
    func startRun() async throws {
        try await processDriverAction(.startRun)
    }
    
    func arrivedAtStop() async throws {
        try await processDriverAction(.arriveStop)
    }
    
    /// Confirm pickup with passenger status validation
    /// Implements Requirements 2.4, 2.5 - pickup confirmation and status updates
    func confirmPickup(passengerId: String) async throws {
        guard let currentStop = _currentStop else {
            throw DriverFocusModeError.stopNotCompleted("No current stop available")
        }
        
        guard currentStop.type == .pickup else {
            throw DriverFocusModeError.actionNotAllowed("Can only confirm pickup at pickup stops")
        }
        
        guard currentStop.requiredPassengerIds.contains(passengerId) else {
            throw DriverFocusModeError.actionNotAllowed("Passenger not required at this stop")
        }
        
        guard let passenger = _passengers.first(where: { $0.id == passengerId }) else {
            throw DriverFocusModeError.actionNotAllowed("Passenger not found")
        }
        
        guard passenger.status == .waiting else {
            throw DriverFocusModeError.actionNotAllowed("Passenger is not waiting for pickup")
        }
        
        try await processDriverAction(.confirmPickup(passengerId: passengerId))
    }
    
    /// Confirm dropoff with passenger status validation
    /// Implements Requirements 2.4, 2.5 - dropoff confirmation and status updates
    func confirmDropoff(passengerId: String) async throws {
        guard let currentStop = _currentStop else {
            throw DriverFocusModeError.stopNotCompleted("No current stop available")
        }
        
        guard currentStop.type == .dropoff else {
            throw DriverFocusModeError.actionNotAllowed("Can only confirm dropoff at dropoff stops")
        }
        
        guard currentStop.requiredPassengerIds.contains(passengerId) else {
            throw DriverFocusModeError.actionNotAllowed("Passenger not required at this stop")
        }
        
        guard let passenger = _passengers.first(where: { $0.id == passengerId }) else {
            throw DriverFocusModeError.actionNotAllowed("Passenger not found")
        }
        
        guard passenger.status == .onboard else {
            throw DriverFocusModeError.actionNotAllowed("Passenger is not onboard for dropoff")
        }
        
        try await processDriverAction(.confirmDropoff(passengerId: passengerId))
    }
    
    func markDelayed(reason: String) async throws {
        try await processDriverAction(.markDelayed(reason: reason))
    }
    
    func endRun() async throws {
        try await processDriverAction(.endRun)
    }
    
    // MARK: - Public Interface
    
    /// Get available actions for current run state
    func getAvailableActions() -> [DriverAction] {
        return availableActions
    }
    
    /// Get filtered run data for display based on role
    func getFilteredRunData() -> FilteredRunData? {
        guard let run = currentRun else { return nil }
        return RoleBasedDataFilter.filterRunDataForDisplay(run, roleContext: roleContext)
    }
    
    /// Get all available actions for current run (including admin actions if applicable)
    func getAllAvailableActions() -> RunActionSet {
        guard let run = currentRun else { return RunActionSet() }
        return RoleBasedDataFilter.getAvailableActions(for: run, roleContext: roleContext)
    }
    
    /// Check if a specific action is available
    func canPerformAction(_ action: DriverAction) -> Bool {
        return availableActions.contains { availableAction in
            switch (action, availableAction) {
            case (.startRun, .startRun),
                 (.arriveStop, .arriveStop),
                 (.nextStop, .nextStop),
                 (.pauseRun, .pauseRun),
                 (.resumeRun, .resumeRun),
                 (.endRun, .endRun),
                 (.clearDelayed, .clearDelayed):
                return true
            case (.confirmPickup(let id1), .confirmPickup(let id2)),
                 (.confirmDropoff(let id1), .confirmDropoff(let id2)):
                return id1 == id2
            case (.markDelayed(let reason1), .markDelayed(let reason2)):
                return reason1 == reason2
            default:
                return false
            }
        }
    }
    
    /// Get current stop information for UI display
    func getCurrentStopInfo() -> StopInfo? {
        guard let currentStop = _currentStop else { return nil }
        
        let requiredPassengers = _passengers.filter { passenger in
            currentStop.requiredPassengerIds.contains(passenger.id)
        }
        
        return StopInfo(
            stop: currentStop,
            requiredPassengers: requiredPassengers,
            isCompleted: isCurrentStopCompleted()
        )
    }
    
    /// Get next stop preview for UI display
    func getNextStopPreview() -> StopPreview? {
        guard let nextStop = _nextStop else { return nil }
        
        let requiredPassengers = _passengers.filter { passenger in
            nextStop.requiredPassengerIds.contains(passenger.id)
        }
        
        return StopPreview(
            stop: nextStop,
            requiredPassengers: requiredPassengers,
            estimatedArrival: calculateETA(for: nextStop)
        )
    }
    
    /// Move to next stop (if current stop is completed)
    /// Implements Requirements 2.4, 2.5, 2.6 - stop completion validation and progression
    func nextStop() async throws {
        guard let currentStop = _currentStop else {
            throw DriverFocusModeError.stopNotCompleted("No current stop available")
        }
        
        // Validate stop completion rules before allowing progression - Requirement 2.4, 2.5
        guard isCurrentStopCompleted() else {
            let reason = getStopCompletionRequirement(currentStop)
            throw DriverFocusModeError.stopNotCompleted(reason)
        }
        
        try await processDriverAction(.nextStop)
    }
    
    /// Get detailed stop completion requirement message
    /// Implements Requirements 2.4, 2.5, 2.6
    func getStopCompletionRequirement(_ stop: RunStop) -> String {
        switch stop.type {
        case .pickup:
            let waitingPassengers = _passengers.filter { passenger in
                stop.requiredPassengerIds.contains(passenger.id) && passenger.status == .waiting
            }
            if !waitingPassengers.isEmpty {
                let names = waitingPassengers.map { $0.displayName }.joined(separator: ", ")
                return "Complete pickup for: \(names)"
            }
            return "All passengers picked up"
            
        case .dropoff:
            let onboardPassengers = _passengers.filter { passenger in
                stop.requiredPassengerIds.contains(passenger.id) && passenger.status == .onboard
            }
            if !onboardPassengers.isEmpty {
                let names = onboardPassengers.map { $0.displayName }.joined(separator: ", ")
                return "Complete dropoff for: \(names)"
            }
            return "All passengers dropped off"
            
        case .waypoint:
            return "Waypoint completed"
        }
    }
    
    /// Validate stop completion with detailed feedback
    /// Implements Requirements 2.4, 2.5, 2.6
    func validateStopCompletion(_ stop: RunStop) -> StopCompletionResult {
        switch stop.type {
        case .pickup:
            let requiredPassengers = _passengers.filter { passenger in
                stop.requiredPassengerIds.contains(passenger.id)
            }
            
            let waitingPassengers = requiredPassengers.filter { $0.status == .waiting }
            let _ = requiredPassengers.filter { $0.status == .onboard }
            
            if waitingPassengers.isEmpty {
                return .completed(message: "All \(requiredPassengers.count) passengers picked up")
            } else {
                return .incomplete(
                    message: "\(waitingPassengers.count) of \(requiredPassengers.count) passengers waiting",
                    remainingActions: waitingPassengers.map { .confirmPickup(passengerId: $0.id) }
                )
            }
            
        case .dropoff:
            let requiredPassengers = _passengers.filter { passenger in
                stop.requiredPassengerIds.contains(passenger.id)
            }
            
            let onboardPassengers = requiredPassengers.filter { $0.status == .onboard }
            let _ = requiredPassengers.filter { $0.status == .droppedOff }
            
            if onboardPassengers.isEmpty {
                return .completed(message: "All \(requiredPassengers.count) passengers dropped off")
            } else {
                return .incomplete(
                    message: "\(onboardPassengers.count) of \(requiredPassengers.count) passengers still onboard",
                    remainingActions: onboardPassengers.map { .confirmDropoff(passengerId: $0.id) }
                )
            }
            
        case .waypoint:
            return .completed(message: "Waypoint ready to continue")
        }
    }
    
    /// Get completion progress for current stop
    /// Implements Requirements 2.4, 2.5, 2.6
    func getStopCompletionProgress() -> StopCompletionProgress? {
        guard let currentStop = _currentStop else { return nil }
        
        let validation = validateStopCompletion(currentStop)
        let requiredPassengers = _passengers.filter { passenger in
            currentStop.requiredPassengerIds.contains(passenger.id)
        }
        
        let completedCount: Int
        let totalCount = requiredPassengers.count
        
        switch currentStop.type {
        case .pickup:
            completedCount = requiredPassengers.filter { $0.status == .onboard }.count
        case .dropoff:
            completedCount = requiredPassengers.filter { $0.status == .droppedOff }.count
        case .waypoint:
            completedCount = 1
        }
        
        return StopCompletionProgress(
            completed: completedCount,
            total: max(totalCount, 1),
            isComplete: validation.isComplete,
            message: validation.message,
            remainingActions: validation.remainingActions
        )
    }
    
    /// Pause the current run
    func pauseRun() async throws {
        try await processDriverAction(.pauseRun)
    }
    
    /// Resume a paused run
    func resumeRun() async throws {
        try await processDriverAction(.resumeRun)
    }
    
    /// Clear delay status
    func clearDelayed() async throws {
        try await processDriverAction(.clearDelayed)
    }
    
    // MARK: - Private Methods
    
    private func setupDataBinding() {
        // Listen to run events for real-time updates
        runEventService.eventPublisher
            .filter { $0.runId == self._runId }
            .sink { [weak self] event in
                Task { @MainActor in
                    await self?.handleRunEvent(event)
                }
            }
            .store(in: &cancellables)
        
        // Listen to state changes
        runEventService.stateChangePublisher
            .filter { $0.runId == self._runId }
            .sink { [weak self] stateChange in
                Task { @MainActor in
                    self?.handleStateChange(stateChange)
                }
            }
            .store(in: &cancellables)
        
        // Start listening to this run
        runEventService.startListening(to: _runId)
    }
    
    private func loadRunData() {
        Task {
            await refreshRunData()
        }
    }
    
    private func refreshRunData() async {
        isLoading = true
        error = nil
        
        do {
            // In a real implementation, this would fetch from a service
            // For now, we'll simulate loading run data
            await loadCurrentRun()
            updateStopsAndPassengers()
            updateAvailableActions()
            
        } catch {
            self.error = .loadingFailed(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    private func loadCurrentRun() async {
        // This would typically fetch from a service
        // For now, we'll create a mock run for demonstration
        // In real implementation: currentRun = try await runService.fetchRun(runId: _runId)
    }
    
    private func updateStopsAndPassengers() {
        guard let run = currentRun else { return }
        
        _runState = run.status
        _passengers = run.passengers
        
        // Update current and next stops
        if run.currentStopIndex < run.stops.count {
            _currentStop = run.stops[run.currentStopIndex]
            
            if run.currentStopIndex + 1 < run.stops.count {
                _nextStop = run.stops[run.currentStopIndex + 1]
            } else {
                _nextStop = nil
            }
        } else {
            _currentStop = nil
            _nextStop = nil
        }
    }
    
    private func updateAvailableActions() {
        guard let run = currentRun else {
            availableActions = []
            return
        }
        
        // Get available actions using the state machine with role context
        availableActions = RunStateMachine.getAvailableDriverActions(for: run, roleContext: roleContext)
    }
    
    private func processDriverAction(_ action: DriverAction) async throws {
        guard !isProcessingAction else {
            throw DriverFocusModeError.actionInProgress("Another action is already in progress")
        }
        
        guard canPerformAction(action) else {
            throw DriverFocusModeError.actionNotAllowed("Action \(action) is not available in current state")
        }
        
        isProcessingAction = true
        error = nil
        
        do {
            // Process the action through the run event service
            try await runEventService.processDriverAction(action, runId: _runId)
            
            // Refresh data after successful action
            await refreshRunData()
            
        } catch {
            self.error = .actionFailed(error.localizedDescription)
            throw error
        }
        
        isProcessingAction = false
    }
    
    /// Check if current stop is completed according to stop completion rules
    /// Implements Requirements 2.4, 2.5, 2.6 - stop completion validation
    private func isCurrentStopCompleted() -> Bool {
        guard let currentStop = _currentStop,
              let run = currentRun else { return false }
        
        return validateStopCompletionRules(currentStop, in: run)
    }
    
    /// Validate stop completion rules according to stop type
    /// Implements Requirements 2.4, 2.5, 2.6
    private func validateStopCompletionRules(_ stop: RunStop, in run: Run) -> Bool {
        switch stop.type {
        case .pickup:
            // Pickup stops: All required passengers must be onboard - Requirement 2.4
            return stop.requiredPassengerIds.allSatisfy { passengerId in
                _passengers.first { $0.id == passengerId }?.status == .onboard
            }
            
        case .dropoff:
            // Dropoff stops: All required passengers must be dropped off - Requirement 2.5
            return stop.requiredPassengerIds.allSatisfy { passengerId in
                _passengers.first { $0.id == passengerId }?.status == .droppedOff
            }
            
        case .waypoint:
            // Waypoints: Completed when driver taps next stop - Requirement 2.6
            return true
        }
    }
    
    /// Advance to next stop with comprehensive validation
    /// Implements Requirements 2.4, 2.5, 2.6 - stop progression and validation
    func advanceToNextStop() async throws -> StopAdvancementResult {
        guard let currentStop = _currentStop else {
            throw DriverFocusModeError.stopNotCompleted("No current stop available")
        }
        
        guard let run = currentRun else {
            throw DriverFocusModeError.loadingFailed("Run data not available")
        }
        
        // Validate stop completion before advancing
        let completionResult = validateStopCompletion(currentStop)
        guard completionResult.isComplete else {
            throw DriverFocusModeError.stopNotCompleted(completionResult.message)
        }
        
        // Check if this is the last stop
        let isLastStop = run.currentStopIndex >= run.stops.count - 1
        
        if isLastStop {
            // Complete the run
            try await processDriverAction(.endRun)
            return .runCompleted(message: "Run completed successfully")
        } else {
            // Move to next stop
            try await processDriverAction(.nextStop)
            return .nextStopStarted(
                stopIndex: run.currentStopIndex + 1,
                stopLabel: run.stops[run.currentStopIndex + 1].label
            )
        }
    }
    
    /// Update passenger status with validation
    /// Implements Requirements 2.4, 2.5 - passenger status management
    func updatePassengerStatus(passengerId: String, newStatus: PassengerStatus) async throws {
        guard let currentStop = _currentStop else {
            throw DriverFocusModeError.actionNotAllowed("No current stop available")
        }
        
        guard currentStop.requiredPassengerIds.contains(passengerId) else {
            throw DriverFocusModeError.actionNotAllowed("Passenger not required at current stop")
        }
        
        guard let passengerIndex = _passengers.firstIndex(where: { $0.id == passengerId }) else {
            throw DriverFocusModeError.actionNotAllowed("Passenger not found")
        }
        
        let currentStatus = _passengers[passengerIndex].status
        
        // Validate status transition based on stop type
        switch (currentStop.type, currentStatus, newStatus) {
        case (.pickup, .waiting, .onboard):
            try await confirmPickup(passengerId: passengerId)
            
        case (.dropoff, .onboard, .droppedOff):
            try await confirmDropoff(passengerId: passengerId)
            
        default:
            throw DriverFocusModeError.actionNotAllowed(
                "Invalid status transition: \(currentStatus.displayName) → \(newStatus.displayName) at \(currentStop.type.displayName) stop"
            )
        }
    }
    
    /// Get all passengers requiring action at current stop
    /// Implements Requirements 2.4, 2.5
    func getPassengersRequiringAction() -> [PassengerActionItem] {
        guard let currentStop = _currentStop else { return [] }
        
        return currentStop.requiredPassengerIds.compactMap { passengerId in
            guard let passenger = _passengers.first(where: { $0.id == passengerId }) else { return nil }
            
            let requiredAction: DriverAction?
            let canPerformAction: Bool
            
            switch currentStop.type {
            case .pickup:
                if passenger.status == .waiting {
                    requiredAction = .confirmPickup(passengerId: passengerId)
                    canPerformAction = self.canPerformAction(.confirmPickup(passengerId: passengerId))
                } else {
                    requiredAction = nil
                    canPerformAction = false
                }
                
            case .dropoff:
                if passenger.status == .onboard {
                    requiredAction = .confirmDropoff(passengerId: passengerId)
                    canPerformAction = self.canPerformAction(.confirmDropoff(passengerId: passengerId))
                } else {
                    requiredAction = nil
                    canPerformAction = false
                }
                
            case .waypoint:
                requiredAction = nil
                canPerformAction = false
            }
            
            return PassengerActionItem(
                passenger: passenger,
                requiredAction: requiredAction,
                canPerformAction: canPerformAction,
                isCompleted: isPassengerActionCompleted(passenger, stopType: currentStop.type)
            )
        }
    }
    
    /// Check if passenger action is completed for the current stop type
    /// Implements Requirements 2.4, 2.5
    private func isPassengerActionCompleted(_ passenger: MemberSummary, stopType: StopType) -> Bool {
        switch stopType {
        case .pickup:
            return passenger.status == .onboard
        case .dropoff:
            return passenger.status == .droppedOff
        case .waypoint:
            return true
        }
    }
    
    private func calculateETA(for stop: RunStop) -> Date? {
        // This would typically use location services and routing
        // For now, return a simple estimate
        return Date().addingTimeInterval(600) // 10 minutes from now
    }
    
    private func handleRunEvent(_ event: RunEvent) async {
        // Refresh data when run events occur
        await refreshRunData()
    }
    
    private func handleStateChange(_ stateChange: RunStateChange) {
        // Update state immediately for responsive UI
        _runState = stateChange.toState
        
        // Refresh full data
        Task {
            await refreshRunData()
        }
    }
    
    deinit {
        // Stop listening when view model is deallocated
        Task { @MainActor in
            runEventService.stopListening(to: _runId)
        }
    }
}

// MARK: - Supporting Types

/// Information about the current stop for UI display
struct StopInfo {
    let stop: RunStop
    let requiredPassengers: [MemberSummary]
    let isCompleted: Bool
    
    var completionProgress: Double {
        guard !requiredPassengers.isEmpty else { return 1.0 }
        
        let completedCount: Int
        switch stop.type {
        case .pickup:
            completedCount = requiredPassengers.filter { $0.status == .onboard }.count
        case .dropoff:
            completedCount = requiredPassengers.filter { $0.status == .droppedOff }.count
        case .waypoint:
            completedCount = isCompleted ? 1 : 0
        }
        
        return Double(completedCount) / Double(requiredPassengers.count)
    }
}

/// Preview information for the next stop
struct StopPreview {
    let stop: RunStop
    let requiredPassengers: [MemberSummary]
    let estimatedArrival: Date?
    
    var passengerSummary: String {
        let names = requiredPassengers.map { $0.displayName }
        if names.count <= 2 {
            return names.joined(separator: ", ")
        } else {
            return "\(names.first ?? "") and \(names.count - 1) others"
        }
    }
}

/// Result of stop completion validation
/// Implements Requirements 2.4, 2.5, 2.6
enum StopCompletionResult {
    case completed(message: String)
    case incomplete(message: String, remainingActions: [DriverAction])
    
    var isComplete: Bool {
        switch self {
        case .completed:
            return true
        case .incomplete:
            return false
        }
    }
    
    var message: String {
        switch self {
        case .completed(let message), .incomplete(let message, _):
            return message
        }
    }
    
    var remainingActions: [DriverAction] {
        switch self {
        case .completed:
            return []
        case .incomplete(_, let actions):
            return actions
        }
    }
}

/// Progress information for stop completion
/// Implements Requirements 2.4, 2.5, 2.6
struct StopCompletionProgress {
    let completed: Int
    let total: Int
    let isComplete: Bool
    let message: String
    let remainingActions: [DriverAction]
    
    var progressPercentage: Double {
        guard total > 0 else { return 1.0 }
        return Double(completed) / Double(total)
    }
    
    var progressText: String {
        return "\(completed)/\(total)"
    }
}

/// Result of advancing to next stop
/// Implements Requirements 2.4, 2.5, 2.6
enum StopAdvancementResult {
    case nextStopStarted(stopIndex: Int, stopLabel: String)
    case runCompleted(message: String)
    
    var message: String {
        switch self {
        case .nextStopStarted(_, let stopLabel):
            return "Proceeding to: \(stopLabel)"
        case .runCompleted(let message):
            return message
        }
    }
}

/// Passenger action item for current stop
/// Implements Requirements 2.4, 2.5
struct PassengerActionItem {
    let passenger: MemberSummary
    let requiredAction: DriverAction?
    let canPerformAction: Bool
    let isCompleted: Bool
    
    var actionTitle: String? {
        guard let action = requiredAction else { return nil }
        
        switch action {
        case .confirmPickup:
            return "Pick Up"
        case .confirmDropoff:
            return "Drop Off"
        default:
            return nil
        }
    }
    
    var statusMessage: String {
        if isCompleted {
            return "Completed"
        } else if requiredAction != nil {
            return "Action Required"
        } else {
            return "No Action Needed"
        }
    }
}

// MARK: - Error Types

enum DriverFocusModeError: LocalizedError {
    case loadingFailed(String)
    case actionNotAllowed(String)
    case actionFailed(String)
    case actionInProgress(String)
    case stopNotCompleted(String)
    case permissionDenied(String)
    
    var errorDescription: String? {
        switch self {
        case .loadingFailed(let message):
            return "Failed to load run data: \(message)"
        case .actionNotAllowed(let message):
            return "Action not allowed: \(message)"
        case .actionFailed(let message):
            return "Action failed: \(message)"
        case .actionInProgress(let message):
            return "Action in progress: \(message)"
        case .stopNotCompleted(let message):
            return "Stop not completed: \(message)"
        case .permissionDenied(let message):
            return "Permission denied: \(message)"
        }
    }
}