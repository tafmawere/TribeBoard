//
//  ErrorHandlingCoordinator.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/04.
//

import Foundation
import Combine

/// Coordinator that manages all error handling services and provides a unified interface
/// Integrates ErrorHandlingService, ErrorRecoveryService, and PrivacyPreservingLogger
/// Implements Requirements 9.1, 9.2, 9.3, 9.4, 9.5
@MainActor
class ErrorHandlingCoordinator: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentError: TribeboardError?
    @Published var isRecovering: Bool = false
    @Published var systemHealth: SystemHealth = .healthy
    
    // MARK: - Services
    
    let errorHandlingService: ErrorHandlingService
    let errorRecoveryService: ErrorRecoveryService
    let logger: PrivacyPreservingLogger
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let healthCheckInterval: TimeInterval = 60.0 // 1 minute
    private var healthCheckTimer: Timer?
    
    // MARK: - Initialization
    
    init(firebaseService: MockFirebaseRunService) {
        self.errorHandlingService = ErrorHandlingService()
        self.logger = PrivacyPreservingLogger()
        self.errorRecoveryService = ErrorRecoveryService(
            firebaseService: firebaseService,
            errorHandlingService: errorHandlingService
        )
        
        setupBindings()
        startHealthMonitoring()
    }
    
    // MARK: - Public Interface
    
    /// Handle any error with automatic routing to appropriate service
    func handleError(_ error: Error, context: ErrorContext) async {
        logger.logError(
            error,
            context: context.logContext,
            additionalInfo: context.additionalInfo
        )
        
        switch context.type {
        case .stateTransition(let runId):
            if let stateError = error as? StateTransitionError {
                let userError = errorHandlingService.handleStateTransitionError(stateError, for: runId)
                currentError = .userFacing(userError)
            }
            
        case .networkOperation(let operation):
            await errorHandlingService.handleNetworkError(error, operation: operation) {
                // Retry logic would be provided by the caller
                throw error
            }
            
        case .dataInconsistency(let localRun, let backendRun):
            isRecovering = true
            let result = await errorRecoveryService.detectAndRecoverInconsistentState(
                localRun: localRun,
                backendRun: backendRun
            )
            isRecovering = false
            
            switch result {
            case .noActionNeeded:
                logger.logInfo(message: "No inconsistencies detected", context: .errorRecovery)
                
            case .fullRecovery(let recovered):
                logger.logInfo(
                    message: "Full recovery successful",
                    context: .errorRecovery,
                    additionalInfo: ["recoveredCount": recovered.count]
                )
                
            case .partialRecovery(let recovered, let failed):
                logger.logWarning(
                    message: "Partial recovery completed",
                    context: .errorRecovery,
                    additionalInfo: [
                        "recoveredCount": recovered.count,
                        "failedCount": failed.count
                    ]
                )
                
            case .recoveryFailed(let inconsistencies):
                let systemError = NSError(
                    domain: "TribeboardRecovery",
                    code: 1001,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Recovery failed for \(inconsistencies.count) inconsistencies",
                        NSUnderlyingErrorKey: error
                    ]
                )
                logger.logError(
                    systemError,
                    context: .errorRecovery
                )
            }
            
        case .general:
            let userError = UserFacingError(
                id: UUID().uuidString,
                title: "Unexpected Error",
                message: "An unexpected error occurred. Please try again.",
                severity: .error,
                isRetryable: true,
                actionContext: .general
            )
            currentError = .userFacing(userError)
        }
        
        await updateSystemHealth()
    }
    
    /// Clear current error
    func clearError() {
        currentError = nil
        errorHandlingService.clearError()
    }
    
    /// Get comprehensive error statistics
    func getErrorStatistics() -> ComprehensiveErrorStatistics {
        let errorStats = errorHandlingService.getErrorStatistics()
        let recoveryStats = errorRecoveryService.getRecoveryStatistics()
        let loggingStats = logger.getLoggingStatistics()
        
        return ComprehensiveErrorStatistics(
            errorHandling: errorStats,
            recovery: recoveryStats,
            logging: loggingStats,
            systemHealth: systemHealth
        )
    }
    
    /// Export comprehensive error report for debugging
    func exportErrorReport() -> String {
        var report = "TribeBoard Comprehensive Error Report\n"
        report += "Generated: \(Date())\n"
        report += "System Health: \(systemHealth.rawValue)\n\n"
        
        // Error handling statistics
        let errorStats = errorHandlingService.getErrorStatistics()
        report += "=== ERROR HANDLING STATISTICS ===\n"
        report += "Total Errors: \(errorStats.totalErrors)\n"
        report += "Recent Errors (24h): \(errorStats.recentErrors)\n"
        report += "Network Errors: \(errorStats.networkErrors)\n"
        report += "State Transition Errors: \(errorStats.stateTransitionErrors)\n"
        report += "Operation Failure Errors: \(errorStats.operationFailureErrors)\n\n"
        
        // Recovery statistics
        let recoveryStats = errorRecoveryService.getRecoveryStatistics()
        report += "=== RECOVERY STATISTICS ===\n"
        report += "Total Recovery Attempts: \(recoveryStats.totalRecoveryAttempts)\n"
        report += "Success Rate: \(String(format: "%.1f%%", recoveryStats.successRate * 100))\n"
        report += "Pending Escalations: \(recoveryStats.pendingEscalations)\n"
        report += "Average Recovery Time: \(String(format: "%.2f", recoveryStats.averageRecoveryTime))s\n\n"
        
        // Sanitized logs
        report += "=== SANITIZED ERROR LOGS ===\n"
        report += logger.exportSanitizedLogs()
        
        return report
    }
    
    /// Perform system health check
    func performHealthCheck() async -> SystemHealth {
        let errorStats = errorHandlingService.getErrorStatistics()
        let recoveryStats = errorRecoveryService.getRecoveryStatistics()
        
        // Calculate health based on error rates and recovery success
        let recentErrorRate = errorStats.recentErrors > 0 ? 
            Double(errorStats.recentErrors) / 100.0 : 0.0 // Normalize to 100 operations
        
        let recoverySuccessRate = recoveryStats.successRate
        let pendingEscalations = recoveryStats.pendingEscalations
        
        if recentErrorRate > 0.5 || recoverySuccessRate < 0.5 || pendingEscalations > 5 {
            return .critical
        } else if recentErrorRate > 0.2 || recoverySuccessRate < 0.8 || pendingEscalations > 2 {
            return .degraded
        } else if recentErrorRate > 0.1 || pendingEscalations > 0 {
            return .warning
        } else {
            return .healthy
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Bind error handling service
        errorHandlingService.$currentError
            .sink { [weak self] error in
                if let error = error {
                    self?.currentError = error
                }
            }
            .store(in: &cancellables)
        
        // Bind recovery service
        errorRecoveryService.$isRecovering
            .sink { [weak self] isRecovering in
                self?.isRecovering = isRecovering
            }
            .store(in: &cancellables)
    }
    
    private func startHealthMonitoring() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: healthCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateSystemHealth()
            }
        }
    }
    
    private func updateSystemHealth() async {
        let newHealth = await performHealthCheck()
        
        if newHealth != systemHealth {
            let previousHealth = systemHealth
            systemHealth = newHealth
            
            logger.logInfo(
                message: "System health changed",
                context: .system,
                additionalInfo: [
                    "previousHealth": previousHealth.rawValue,
                    "newHealth": newHealth.rawValue
                ]
            )
            
            // Log critical health changes
            if newHealth == .critical {
                let systemError = NSError(
                    domain: "TribeboardSystem",
                    code: 2001,
                    userInfo: [
                        NSLocalizedDescriptionKey: "System health is now critical"
                    ]
                )
                logger.logError(
                    systemError,
                    context: .system
                )
            }
        }
    }
    
    deinit {
        healthCheckTimer?.invalidate()
        cancellables.removeAll()
    }
}

// MARK: - Supporting Types

struct ErrorContext {
    let type: ErrorContextType
    let additionalInfo: [String: Any]
    
    var logContext: LogContext {
        switch type {
        case .stateTransition:
            return .stateTransition
        case .networkOperation:
            return .networkOperation
        case .dataInconsistency:
            return .dataSync
        case .general:
            return .system
        }
    }
}

enum ErrorContextType {
    case stateTransition(runId: String)
    case networkOperation(NetworkOperation)
    case dataInconsistency(localRun: Run, backendRun: Run?)
    case general
}

enum SystemHealth: String, CaseIterable {
    case healthy = "healthy"
    case warning = "warning"
    case degraded = "degraded"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .healthy: return "Healthy"
        case .warning: return "Warning"
        case .degraded: return "Degraded"
        case .critical: return "Critical"
        }
    }
    
    var color: String {
        switch self {
        case .healthy: return "green"
        case .warning: return "yellow"
        case .degraded: return "orange"
        case .critical: return "red"
        }
    }
}

struct ComprehensiveErrorStatistics {
    let errorHandling: ErrorStatistics
    let recovery: RecoveryStatistics
    let logging: LoggingStatistics
    let systemHealth: SystemHealth
    
    var overallHealthScore: Double {
        let errorScore = max(0, 1.0 - (Double(errorHandling.recentErrors) / 100.0))
        let recoveryScore = recovery.successRate
        let loggingScore = logging.errorRate < 0.1 ? 1.0 : max(0, 1.0 - logging.errorRate)
        
        return (errorScore + recoveryScore + loggingScore) / 3.0
    }
}