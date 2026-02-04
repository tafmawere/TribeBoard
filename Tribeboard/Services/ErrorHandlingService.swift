//
//  ErrorHandlingService.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/04.
//

import Foundation
import Combine

/// Comprehensive error handling service for TribeBoard run state management
/// Handles state transition failures, network errors, and automatic retry with exponential backoff
/// Implements Requirements 9.1, 9.2
@MainActor
class ErrorHandlingService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentError: TribeboardError?
    @Published var isRetrying: Bool = false
    @Published var retryAttempts: Int = 0
    
    // MARK: - Private Properties
    
    private let maxRetryAttempts = 3
    private let baseRetryDelay: TimeInterval = 1.0
    private let maxRetryDelay: TimeInterval = 30.0
    private var retryTimers: [String: Timer] = [:]
    private var errorHistory: [ErrorRecord] = []
    
    // MARK: - Error Handling
    
    /// Handle state transition failures with appropriate error messages
    /// Implements Requirement 9.1
    func handleStateTransitionError(_ error: StateTransitionError, for runId: String) -> UserFacingError {
        let errorRecord = ErrorRecord(
            id: UUID().uuidString,
            type: .stateTransition,
            originalError: error,
            runId: runId,
            timestamp: Date(),
            retryCount: 0
        )
        
        errorHistory.append(errorRecord)
        
        let userError = UserFacingError(
            id: errorRecord.id,
            title: "Action Failed",
            message: getUserFriendlyMessage(for: error),
            severity: .error,
            isRetryable: error.isRetryable,
            actionContext: .runOperation(runId)
        )
        
        currentError = .userFacing(userError)
        return userError
    }
    
    /// Handle network errors with automatic retry and exponential backoff
    /// Implements Requirement 9.2
    func handleNetworkError(_ error: Error, operation: NetworkOperation, retryHandler: @escaping () async throws -> Void) async {
        let errorRecord = ErrorRecord(
            id: UUID().uuidString,
            type: .network,
            originalError: error,
            runId: operation.runId,
            timestamp: Date(),
            retryCount: 0
        )
        
        errorHistory.append(errorRecord)
        
        // Check if this is a retryable network error
        guard isRetryableNetworkError(error) else {
            let userError = UserFacingError(
                id: errorRecord.id,
                title: "Connection Error",
                message: "Unable to connect to the server. Please check your internet connection.",
                severity: .error,
                isRetryable: false,
                actionContext: .networkOperation(operation)
            )
            currentError = .userFacing(userError)
            return
        }
        
        // Start automatic retry with exponential backoff
        await performAutomaticRetry(errorRecord: errorRecord, operation: operation, retryHandler: retryHandler)
    }
    
    /// Maintain current state when operations fail
    /// Implements Requirement 9.1
    func maintainStateOnFailure<T>(
        currentState: T,
        operation: @escaping () async throws -> T,
        fallbackMessage: String = "Operation failed, maintaining current state"
    ) async -> T {
        do {
            return try await operation()
        } catch {
            // Log the error but maintain current state
            let errorRecord = ErrorRecord(
                id: UUID().uuidString,
                type: .operationFailure,
                originalError: error,
                runId: nil,
                timestamp: Date(),
                retryCount: 0
            )
            
            errorHistory.append(errorRecord)
            
            let userError = UserFacingError(
                id: errorRecord.id,
                title: "Operation Failed",
                message: fallbackMessage,
                severity: .warning,
                isRetryable: true,
                actionContext: .general
            )
            
            currentError = .userFacing(userError)
            return currentState
        }
    }
    
    /// Clear current error
    func clearError() {
        currentError = nil
        retryAttempts = 0
    }
    
    /// Get error history for debugging
    func getErrorHistory(limit: Int = 50) -> [ErrorRecord] {
        return Array(errorHistory.suffix(limit))
    }
    
    /// Get error statistics
    func getErrorStatistics() -> ErrorStatistics {
        let now = Date()
        let last24Hours = now.addingTimeInterval(-86400)
        
        let recentErrors = errorHistory.filter { $0.timestamp >= last24Hours }
        let networkErrors = recentErrors.filter { $0.type == .network }.count
        let stateErrors = recentErrors.filter { $0.type == .stateTransition }.count
        let operationErrors = recentErrors.filter { $0.type == .operationFailure }.count
        
        return ErrorStatistics(
            totalErrors: errorHistory.count,
            recentErrors: recentErrors.count,
            networkErrors: networkErrors,
            stateTransitionErrors: stateErrors,
            operationFailureErrors: operationErrors,
            lastErrorTime: errorHistory.last?.timestamp
        )
    }
    
    // MARK: - Private Methods
    
    private func performAutomaticRetry(
        errorRecord: ErrorRecord,
        operation: NetworkOperation,
        retryHandler: @escaping () async throws -> Void
    ) async {
        guard errorRecord.retryCount < maxRetryAttempts else {
            // Max retries reached, show permanent error
            let userError = UserFacingError(
                id: errorRecord.id,
                title: "Connection Failed",
                message: "Unable to complete the operation after multiple attempts. Please try again later.",
                severity: .error,
                isRetryable: true,
                actionContext: .networkOperation(operation)
            )
            currentError = .userFacing(userError)
            return
        }
        
        isRetrying = true
        retryAttempts = errorRecord.retryCount + 1
        
        // Calculate exponential backoff delay
        let delay = min(baseRetryDelay * pow(2.0, Double(errorRecord.retryCount)), maxRetryDelay)
        
        // Show retry message to user
        let retryError = UserFacingError(
            id: errorRecord.id,
            title: "Retrying...",
            message: "Attempting to reconnect (attempt \(retryAttempts) of \(maxRetryAttempts))",
            severity: .info,
            isRetryable: false,
            actionContext: .networkOperation(operation)
        )
        currentError = .userFacing(retryError)
        
        // Wait for backoff delay
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        do {
            try await retryHandler()
            // Success - clear error and retry state
            isRetrying = false
            retryAttempts = 0
            currentError = nil
        } catch {
            // Update retry count and try again
            if let index = errorHistory.firstIndex(where: { $0.id == errorRecord.id }) {
                errorHistory[index].retryCount += 1
                await performAutomaticRetry(
                    errorRecord: errorHistory[index],
                    operation: operation,
                    retryHandler: retryHandler
                )
            }
        }
    }
    
    private func isRetryableNetworkError(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .cannotConnectToHost, .networkConnectionLost, .notConnectedToInternet:
                return true
            default:
                return false
            }
        }
        
        if let firebaseError = error as? FirebaseError {
            switch firebaseError {
            case .networkError:
                return true
            default:
                return false
            }
        }
        
        return false
    }
    
    private func getUserFriendlyMessage(for error: StateTransitionError) -> String {
        switch error {
        case .invalidTransition(let from, let to):
            return "Cannot change from \(from.displayName) to \(to.displayName) at this time."
        case .invalidState(let message):
            return "This action is not available right now. \(message)"
        case .passengerNotFound:
            return "The selected passenger could not be found."
        case .stopNotCompleted:
            return "Please complete all required actions at this stop before continuing."
        case .permissionDenied:
            return "You don't have permission to perform this action."
        }
    }
}

// MARK: - Supporting Types

struct ErrorRecord {
    let id: String
    let type: ErrorType
    let originalError: Error
    let runId: String?
    let timestamp: Date
    var retryCount: Int
    
    var age: TimeInterval {
        Date().timeIntervalSince(timestamp)
    }
}

enum ErrorType {
    case network
    case stateTransition
    case operationFailure
    case recovery
    case validation
}

struct NetworkOperation {
    let type: NetworkOperationType
    let runId: String?
    let description: String
}

enum NetworkOperationType {
    case driverAction
    case adminAction
    case locationUpdate
    case runFetch
    case runCreate
    case runUpdate
}

enum TribeboardError {
    case userFacing(UserFacingError)
    case system(SystemError)
    case recovery(RecoveryError)
}

struct UserFacingError: Identifiable {
    let id: String
    let title: String
    let message: String
    let severity: ErrorSeverity
    let isRetryable: Bool
    let actionContext: ActionContext
    let timestamp: Date = Date()
}

enum ErrorSeverity {
    case info
    case warning
    case error
    case critical
    
    var displayColor: String {
        switch self {
        case .info: return "blue"
        case .warning: return "orange"
        case .error: return "red"
        case .critical: return "purple"
        }
    }
}

enum ActionContext {
    case runOperation(String)
    case networkOperation(NetworkOperation)
    case general
}

struct SystemError {
    let code: String
    let description: String
    let underlyingError: Error?
    let timestamp: Date = Date()
}

struct RecoveryError {
    let attemptId: String
    let description: String
    let originalError: Error
    let timestamp: Date = Date()
}

struct ErrorStatistics {
    let totalErrors: Int
    let recentErrors: Int
    let networkErrors: Int
    let stateTransitionErrors: Int
    let operationFailureErrors: Int
    let lastErrorTime: Date?
}

// MARK: - Extensions

extension StateTransitionError {
    var isRetryable: Bool {
        switch self {
        case .invalidTransition, .invalidState, .permissionDenied:
            return false
        case .passengerNotFound, .stopNotCompleted:
            return true
        }
    }
}