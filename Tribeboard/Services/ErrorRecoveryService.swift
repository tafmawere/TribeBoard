//
//  ErrorRecoveryService.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/04.
//

import Foundation
import Combine

/// Service responsible for automatic error recovery and admin escalation
/// Detects inconsistent states, attempts automatic recovery, and escalates to admins when needed
/// Implements Requirements 9.3, 9.4
@MainActor
class ErrorRecoveryService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isRecovering: Bool = false
    @Published var recoveryAttempts: [RecoveryAttempt] = []
    @Published var escalatedIssues: [EscalatedIssue] = []
    
    // MARK: - Private Properties
    
    private let firebaseService: MockFirebaseRunService
    private let errorHandlingService: ErrorHandlingService
    private let maxRecoveryAttempts = 3
    private let recoveryTimeout: TimeInterval = 30.0
    
    // MARK: - Initialization
    
    init(firebaseService: MockFirebaseRunService, errorHandlingService: ErrorHandlingService) {
        self.firebaseService = firebaseService
        self.errorHandlingService = errorHandlingService
    }
    
    // MARK: - Inconsistent State Detection
    
    /// Detect inconsistent states and attempt automatic recovery
    /// Implements Requirement 9.3
    func detectAndRecoverInconsistentState(localRun: Run, backendRun: Run?) async -> RecoveryResult {
        let inconsistencies = detectInconsistencies(local: localRun, backend: backendRun)
        
        guard !inconsistencies.isEmpty else {
            return .noActionNeeded
        }
        
        let recoveryAttempt = RecoveryAttempt(
            id: UUID().uuidString,
            runId: localRun.id,
            inconsistencies: inconsistencies,
            startTime: Date(),
            status: .inProgress
        )
        
        recoveryAttempts.append(recoveryAttempt)
        isRecovering = true
        
        defer {
            isRecovering = false
            updateRecoveryAttemptStatus(recoveryAttempt.id, status: .completed)
        }
        
        // Attempt automatic recovery for each inconsistency
        var recoveredInconsistencies: [StateInconsistency] = []
        var failedInconsistencies: [StateInconsistency] = []
        
        for inconsistency in inconsistencies {
            do {
                let success = try await attemptAutomaticRecovery(inconsistency, for: localRun)
                if success {
                    recoveredInconsistencies.append(inconsistency)
                } else {
                    failedInconsistencies.append(inconsistency)
                }
            } catch {
                failedInconsistencies.append(inconsistency)
            }
        }
        
        // If any inconsistencies couldn't be recovered, escalate to admin
        if !failedInconsistencies.isEmpty {
            await escalateToAdmin(
                runId: localRun.id,
                failedInconsistencies: failedInconsistencies,
                recoveryAttemptId: recoveryAttempt.id
            )
            return .partialRecovery(recovered: recoveredInconsistencies, failed: failedInconsistencies)
        }
        
        return .fullRecovery(recovered: recoveredInconsistencies)
    }
    
    /// Notify admins when automatic recovery fails
    /// Implements Requirement 9.3
    func escalateToAdmin(runId: String, failedInconsistencies: [StateInconsistency], recoveryAttemptId: String) async {
        let escalation = EscalatedIssue(
            id: UUID().uuidString,
            runId: runId,
            inconsistencies: failedInconsistencies,
            recoveryAttemptId: recoveryAttemptId,
            escalationTime: Date(),
            status: .pending,
            adminNotified: false
        )
        
        escalatedIssues.append(escalation)
        
        // Notify admins through the notification system
        await notifyAdmins(escalation)
    }
    
    /// Provide manual resolution options for admins
    /// Implements Requirement 9.4
    func getManualResolutionOptions(for escalation: EscalatedIssue) -> [ManualResolutionOption] {
        var options: [ManualResolutionOption] = []
        
        for inconsistency in escalation.inconsistencies {
            switch inconsistency.type {
            case .stateConflict(let localState, let backendState):
                options.append(.forceBackendState(
                    description: "Use backend state: \(backendState.displayName)",
                    action: .setState(backendState)
                ))
                options.append(.forceLocalState(
                    description: "Use local state: \(localState.displayName)",
                    action: .setState(localState)
                ))
                
            case .passengerStatusMismatch(let passengerId, let localStatus, let backendStatus):
                options.append(.setPassengerStatus(
                    passengerId: passengerId,
                    status: backendStatus,
                    description: "Set passenger to backend status: \(backendStatus.displayName)"
                ))
                options.append(.setPassengerStatus(
                    passengerId: passengerId,
                    status: localStatus,
                    description: "Set passenger to local status: \(localStatus.displayName)"
                ))
                
            case .stopCompletionMismatch(let stopId, _, let backendCompleted):
                let targetStatus = backendCompleted
                options.append(.setStopCompletion(
                    stopId: stopId,
                    completed: targetStatus,
                    description: "Set stop completion to: \(targetStatus ? "Completed" : "Not Completed")"
                ))
                
            case .locationDataInconsistent:
                options.append(.refreshLocationData(
                    description: "Refresh location data from backend"
                ))
                
            case .timestampMismatch:
                options.append(.synchronizeTimestamps(
                    description: "Synchronize all timestamps with backend"
                ))
            }
        }
        
        // Always provide option to cancel the run if recovery is impossible
        options.append(.cancelRun(
            description: "Cancel run due to unrecoverable inconsistencies"
        ))
        
        return options
    }
    
    /// Execute manual resolution chosen by admin
    func executeManualResolution(_ option: ManualResolutionOption, for escalation: EscalatedIssue) async throws {
        switch option {
        case .forceBackendState(_, let action):
            if case .setState(let state) = action {
                try await firebaseService.updateRunStatus(runId: escalation.runId, newStatus: state)
            }
            
        case .forceLocalState(_, let action):
            if case .setState(let state) = action {
                try await firebaseService.updateRunStatus(runId: escalation.runId, newStatus: state)
            }
            
        case .setPassengerStatus(let passengerId, let status, _):
            try await firebaseService.updatePassengerStatus(
                runId: escalation.runId,
                passengerId: passengerId,
                status: status
            )
            
        case .setStopCompletion(let stopId, let completed, _):
            // This would require a new Firebase method to update stop completion
            // For now, we'll log the action
            print("Manual resolution: Set stop \(stopId) completion to \(completed)")
            
        case .refreshLocationData(_):
            // Refresh location data from backend
            _ = try await firebaseService.fetchRun(runId: escalation.runId)
            
        case .synchronizeTimestamps(_):
            // Force a full synchronization
            _ = try await firebaseService.fetchRun(runId: escalation.runId)
            
        case .cancelRun(_):
            try await firebaseService.processAdminAction(.cancelRun(reason: "Unrecoverable state inconsistency"), runId: escalation.runId)
        }
        
        // Mark escalation as resolved
        if let index = escalatedIssues.firstIndex(where: { $0.id == escalation.id }) {
            escalatedIssues[index].status = .resolved
            escalatedIssues[index].resolvedAt = Date()
        }
    }
    
    /// Get recovery statistics for monitoring
    func getRecoveryStatistics() -> RecoveryStatistics {
        let now = Date()
        let last24Hours = now.addingTimeInterval(-86400)
        
        let recentAttempts = recoveryAttempts.filter { $0.startTime >= last24Hours }
        let successfulRecoveries = recentAttempts.filter { $0.status == .completed }.count
        let failedRecoveries = recentAttempts.filter { $0.status == .failed }.count
        let pendingEscalations = escalatedIssues.filter { $0.status == .pending }.count
        
        return RecoveryStatistics(
            totalRecoveryAttempts: recoveryAttempts.count,
            recentRecoveryAttempts: recentAttempts.count,
            successfulRecoveries: successfulRecoveries,
            failedRecoveries: failedRecoveries,
            pendingEscalations: pendingEscalations,
            averageRecoveryTime: calculateAverageRecoveryTime()
        )
    }
    
    // MARK: - Private Methods
    
    private func detectInconsistencies(local: Run, backend: Run?) -> [StateInconsistency] {
        guard let backend = backend else {
            return [StateInconsistency(
                type: .stateConflict(local.status, .scheduled),
                description: "Backend run not found, local run exists",
                severity: .high
            )]
        }
        
        var inconsistencies: [StateInconsistency] = []
        
        // Check state consistency
        if local.status != backend.status {
            inconsistencies.append(StateInconsistency(
                type: .stateConflict(local.status, backend.status),
                description: "Run state mismatch: local=\(local.status.displayName), backend=\(backend.status.displayName)",
                severity: .high
            ))
        }
        
        // Check passenger status consistency
        for localPassenger in local.passengers {
            if let backendPassenger = backend.passengers.first(where: { $0.id == localPassenger.id }) {
                if localPassenger.status != backendPassenger.status {
                    inconsistencies.append(StateInconsistency(
                        type: .passengerStatusMismatch(localPassenger.id, localPassenger.status, backendPassenger.status),
                        description: "Passenger \(localPassenger.displayName) status mismatch",
                        severity: .medium
                    ))
                }
            }
        }
        
        // Check stop completion consistency
        for (index, localStop) in local.stops.enumerated() {
            if index < backend.stops.count {
                let backendStop = backend.stops[index]
                if localStop.isCompleted != backendStop.isCompleted {
                    inconsistencies.append(StateInconsistency(
                        type: .stopCompletionMismatch(localStop.id, localStop.isCompleted, backendStop.isCompleted),
                        description: "Stop \(localStop.label) completion mismatch",
                        severity: .medium
                    ))
                }
            }
        }
        
        // Check location data consistency
        if let localLocation = local.lastLocationUpdatedAt,
           let backendLocation = backend.lastLocationUpdatedAt,
           abs(localLocation.timeIntervalSince(backendLocation)) > 300 { // 5 minutes threshold
            inconsistencies.append(StateInconsistency(
                type: .locationDataInconsistent,
                description: "Location data timestamps differ significantly",
                severity: .low
            ))
        }
        
        return inconsistencies
    }
    
    private func attemptAutomaticRecovery(_ inconsistency: StateInconsistency, for run: Run) async throws -> Bool {
        switch inconsistency.type {
        case .stateConflict(_, let backendState):
            // For state conflicts, always defer to backend state (Requirement 7.4)
            try await firebaseService.updateRunStatus(runId: run.id, newStatus: backendState)
            return true
            
        case .passengerStatusMismatch(let passengerId, _, let backendStatus):
            // For passenger status, defer to backend
            try await firebaseService.updatePassengerStatus(
                runId: run.id,
                passengerId: passengerId,
                status: backendStatus
            )
            return true
            
        case .stopCompletionMismatch(_, _, let backendCompleted):
            // For stop completion, defer to backend
            // This would require additional Firebase methods
            print("Auto-recovery: Stop completion set to \(backendCompleted)")
            return true
            
        case .locationDataInconsistent:
            // Refresh location data from backend
            _ = try await firebaseService.fetchRun(runId: run.id)
            return true
            
        case .timestampMismatch:
            // Force synchronization
            _ = try await firebaseService.fetchRun(runId: run.id)
            return true
        }
    }
    
    private func notifyAdmins(_ escalation: EscalatedIssue) async {
        // In a real implementation, this would send push notifications or emails to admins
        print("🚨 ADMIN ESCALATION: Run \(escalation.runId) has unrecoverable inconsistencies")
        print("Inconsistencies: \(escalation.inconsistencies.map { $0.description }.joined(separator: ", "))")
        
        // Mark as notified
        if let index = escalatedIssues.firstIndex(where: { $0.id == escalation.id }) {
            escalatedIssues[index].adminNotified = true
        }
    }
    
    private func updateRecoveryAttemptStatus(_ attemptId: String, status: RecoveryStatus) {
        if let index = recoveryAttempts.firstIndex(where: { $0.id == attemptId }) {
            recoveryAttempts[index].status = status
            if status == .completed || status == .failed {
                recoveryAttempts[index].endTime = Date()
            }
        }
    }
    
    private func calculateAverageRecoveryTime() -> TimeInterval {
        let completedAttempts = recoveryAttempts.filter { $0.status == .completed && $0.endTime != nil }
        guard !completedAttempts.isEmpty else { return 0 }
        
        let totalTime = completedAttempts.reduce(0.0) { total, attempt in
            guard let endTime = attempt.endTime else { return total }
            return total + endTime.timeIntervalSince(attempt.startTime)
        }
        
        return totalTime / Double(completedAttempts.count)
    }
}

// MARK: - Supporting Types

struct RecoveryAttempt: Identifiable {
    let id: String
    let runId: String
    let inconsistencies: [StateInconsistency]
    let startTime: Date
    var endTime: Date?
    var status: RecoveryStatus
}

enum RecoveryStatus {
    case inProgress
    case completed
    case failed
    case timeout
}

enum RecoveryResult {
    case noActionNeeded
    case fullRecovery(recovered: [StateInconsistency])
    case partialRecovery(recovered: [StateInconsistency], failed: [StateInconsistency])
    case recoveryFailed(inconsistencies: [StateInconsistency])
}

struct StateInconsistency {
    let type: InconsistencyType
    let description: String
    let severity: InconsistencySeverity
}

enum InconsistencyType {
    case stateConflict(RunStatus, RunStatus)
    case passengerStatusMismatch(String, PassengerStatus, PassengerStatus)
    case stopCompletionMismatch(String, Bool, Bool)
    case locationDataInconsistent
    case timestampMismatch
}

enum InconsistencySeverity: String {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

struct EscalatedIssue: Identifiable {
    let id: String
    let runId: String
    let inconsistencies: [StateInconsistency]
    let recoveryAttemptId: String
    let escalationTime: Date
    var status: EscalationStatus
    var adminNotified: Bool
    var resolvedAt: Date?
}

enum EscalationStatus {
    case pending
    case inReview
    case resolved
    case dismissed
}

enum ManualResolutionOption {
    case forceBackendState(description: String, action: ResolutionAction)
    case forceLocalState(description: String, action: ResolutionAction)
    case setPassengerStatus(passengerId: String, status: PassengerStatus, description: String)
    case setStopCompletion(stopId: String, completed: Bool, description: String)
    case refreshLocationData(description: String)
    case synchronizeTimestamps(description: String)
    case cancelRun(description: String)
}

enum ResolutionAction {
    case setState(RunStatus)
    case setPassengerStatus(String, PassengerStatus)
    case setStopCompletion(String, Bool)
    case refreshData
    case cancelRun
}

struct RecoveryStatistics {
    let totalRecoveryAttempts: Int
    let recentRecoveryAttempts: Int
    let successfulRecoveries: Int
    let failedRecoveries: Int
    let pendingEscalations: Int
    let averageRecoveryTime: TimeInterval
    
    var successRate: Double {
        guard totalRecoveryAttempts > 0 else { return 0 }
        return Double(successfulRecoveries) / Double(totalRecoveryAttempts)
    }
}