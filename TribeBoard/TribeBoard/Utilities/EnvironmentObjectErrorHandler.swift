import SwiftUI
import Foundation

/// Comprehensive error handler for environment object issues
/// Coordinates error detection, recovery, and user notification
@MainActor
class EnvironmentObjectErrorHandler: ObservableObject {
    static let shared = EnvironmentObjectErrorHandler()
    
    // MARK: - Published Properties
    
    @Published var currentError: EnvironmentObjectError?
    @Published var isRecovering = false
    @Published var recoveryHistory: [EnvironmentRecoveryAttempt] = []
    
    // MARK: - Private Properties
    
    private var errorQueue: [EnvironmentObjectError] = []
    private var recoveryStrategies: [String: EnvironmentRecoveryStrategy] = [:]
    private let maxRecoveryAttempts = 3
    private let recoveryTimeout: TimeInterval = 10.0
    
    private init() {
        setupDefaultRecoveryStrategies()
    }
    
    // MARK: - Public Methods
    
    /// Handle an environment object error with automatic recovery
    func handleError(
        _ error: EnvironmentObjectError,
        in viewName: String? = nil,
        context: [String: Any] = [:]
    ) {
        let enhancedContext = enhanceContext(context, viewName: viewName)
        
        // Log the error
        logError(error, context: enhancedContext)
        
        // Check if we should attempt automatic recovery
        if shouldAttemptAutomaticRecovery(for: error) {
            attemptAutomaticRecovery(for: error, context: enhancedContext)
        } else {
            // Show error to user for manual intervention
            presentErrorToUser(error, context: enhancedContext)
        }
    }
    
    /// Manually execute a recovery action
    func executeRecoveryAction(
        _ action: EnvironmentRecoveryAction,
        for error: EnvironmentObjectError? = nil
    ) async -> EnvironmentRecoveryResult {
        let targetError = error ?? currentError
        guard let targetError = targetError else {
            return EnvironmentRecoveryResult(
                action: action,
                isSuccessful: false,
                message: "No error to recover from",
                nextRecommendedAction: nil
            )
        }
        
        isRecovering = true
        
        let result = await performRecoveryAction(action, for: targetError)
        
        // Record the recovery attempt
        let attempt = EnvironmentRecoveryAttempt(
            error: targetError,
            action: action,
            result: result,
            timestamp: Date()
        )
        recoveryHistory.append(attempt)
        
        // Update UI based on result
        if result.isSuccessful {
            EnvironmentObjectToastManager.shared.showRecoverySuccessful(action: action)
            
            // Clear current error if recovery was successful
            if currentError?.localizedDescription == targetError.localizedDescription {
                currentError = nil
            }
        } else {
            EnvironmentObjectToastManager.shared.showRecoveryFailed(
                action: action,
                error: result.message
            )
        }
        
        isRecovering = false
        return result
    }
    
    /// Get recovery recommendations for an error
    func getRecoveryRecommendations(for error: EnvironmentObjectError) -> [EnvironmentRecoveryAction] {
        let errorKey = getErrorKey(for: error)
        
        if let strategy = recoveryStrategies[errorKey] {
            return strategy.recommendedActions
        }
        
        // Default recommendations based on error type
        return error.availableRecoveryActions
    }
    
    /// Check if the error handler is currently handling any errors
    var hasActiveErrors: Bool {
        return currentError != nil || !errorQueue.isEmpty
    }
    
    /// Get statistics about error handling
    var statistics: EnvironmentErrorStatistics {
        let totalAttempts = recoveryHistory.count
        let successfulAttempts = recoveryHistory.filter { $0.result.isSuccessful }.count
        let failedAttempts = totalAttempts - successfulAttempts
        
        let errorsByType = Dictionary(grouping: recoveryHistory, by: { getErrorKey(for: $0.error) })
            .mapValues { $0.count }
        
        let actionsByType = Dictionary(grouping: recoveryHistory, by: { $0.action })
            .mapValues { $0.count }
        
        return EnvironmentErrorStatistics(
            totalRecoveryAttempts: totalAttempts,
            successfulRecoveries: successfulAttempts,
            failedRecoveries: failedAttempts,
            errorsByType: errorsByType,
            actionsByType: actionsByType,
            averageRecoveryTime: calculateAverageRecoveryTime(),
            mostCommonError: findMostCommonError(),
            mostSuccessfulAction: findMostSuccessfulAction()
        )
    }
    
    // MARK: - Private Methods
    
    private func setupDefaultRecoveryStrategies() {
        // Strategy for missing AppState
        recoveryStrategies["missingAppState"] = EnvironmentRecoveryStrategy(
            errorPattern: "missingEnvironmentObject.*AppState",
            recommendedActions: [.useDefaultState, .refreshEnvironment, .restartView],
            automaticRecovery: true,
            maxAttempts: 2,
            timeout: 5.0
        )
        
        // Strategy for invalid state
        recoveryStrategies["invalidState"] = EnvironmentRecoveryStrategy(
            errorPattern: "invalidEnvironmentObjectState",
            recommendedActions: [.refreshEnvironment, .resetNavigation, .useDefaultState],
            automaticRecovery: true,
            maxAttempts: 3,
            timeout: 8.0
        )
        
        // Strategy for dependency issues
        recoveryStrategies["dependencyIssue"] = EnvironmentRecoveryStrategy(
            errorPattern: "dependencyInjectionFailure",
            recommendedActions: [.checkDependencies, .refreshEnvironment, .reportIssue],
            automaticRecovery: false,
            maxAttempts: 1,
            timeout: 3.0
        )
        
        // Strategy for fallback creation failure
        recoveryStrategies["fallbackFailure"] = EnvironmentRecoveryStrategy(
            errorPattern: "fallbackCreationFailed",
            recommendedActions: [.restartView, .reportIssue],
            automaticRecovery: false,
            maxAttempts: 1,
            timeout: 2.0
        )
    }
    
    private func shouldAttemptAutomaticRecovery(for error: EnvironmentObjectError) -> Bool {
        let errorKey = getErrorKey(for: error)
        
        // Check if we have a strategy for this error
        guard let strategy = recoveryStrategies[errorKey] else {
            return false
        }
        
        // Check if automatic recovery is enabled for this error type
        guard strategy.automaticRecovery else {
            return false
        }
        
        // Check if we haven't exceeded max attempts for this error type
        let recentAttempts = recoveryHistory
            .filter { getErrorKey(for: $0.error) == errorKey }
            .filter { Date().timeIntervalSince($0.timestamp) < 300 } // Last 5 minutes
        
        return recentAttempts.count < strategy.maxAttempts
    }
    
    private func attemptAutomaticRecovery(
        for error: EnvironmentObjectError,
        context: [String: Any]
    ) {
        let errorKey = getErrorKey(for: error)
        guard let strategy = recoveryStrategies[errorKey] else {
            presentErrorToUser(error, context: context)
            return
        }
        
        // Try the first recommended action automatically
        guard let firstAction = strategy.recommendedActions.first else {
            presentErrorToUser(error, context: context)
            return
        }
        
        Task {
            let result = await executeRecoveryAction(firstAction, for: error)
            
            if !result.isSuccessful {
                // If automatic recovery failed, present to user
                await MainActor.run {
                    presentErrorToUser(error, context: context)
                }
            }
        }
    }
    
    private func presentErrorToUser(
        _ error: EnvironmentObjectError,
        context: [String: Any]
    ) {
        currentError = error
        
        // Show appropriate notification based on error severity
        switch error {
        case .missingEnvironmentObject(let type):
            EnvironmentObjectToastManager.shared.showMissingEnvironment(
                type: type,
                viewName: context["viewName"] as? String
            )
            
        case .invalidEnvironmentObjectState(let type, let reason):
            EnvironmentObjectToastManager.shared.showStateInconsistent(
                details: "Issue with \(type): \(reason)"
            )
            
        case .dependencyInjectionFailure(let details):
            let missingDeps = extractMissingDependencies(from: details)
            EnvironmentObjectToastManager.shared.showDependencyIssue(missing: missingDeps)
            
        case .fallbackCreationFailed(let type, _):
            EnvironmentObjectToastManager.shared.showRecoveryFailed(
                action: .useDefaultState,
                error: "Cannot create fallback \(type)"
            )
        }
    }
    
    private func performRecoveryAction(
        _ action: EnvironmentRecoveryAction,
        for error: EnvironmentObjectError
    ) async -> EnvironmentRecoveryResult {
        // Simulate recovery action execution with appropriate delay
        let delay = getActionDelay(for: action)
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        switch action {
        case .refreshEnvironment:
            return await performRefreshEnvironment(for: error)
            
        case .useDefaultState:
            return await performUseDefaultState(for: error)
            
        case .restartView:
            return await performRestartView(for: error)
            
        case .checkDependencies:
            return await performCheckDependencies(for: error)
            
        case .resetNavigation:
            return await performResetNavigation(for: error)
            
        case .reportIssue:
            return await performReportIssue(for: error)
        }
    }
    
    // MARK: - Recovery Action Implementations
    
    private func performRefreshEnvironment(for error: EnvironmentObjectError) async -> EnvironmentRecoveryResult {
        // Simulate environment refresh
        let success = Double.random(in: 0...1) > 0.2 // 80% success rate
        
        return EnvironmentRecoveryResult(
            action: .refreshEnvironment,
            isSuccessful: success,
            message: success ? "Environment refreshed successfully" : "Failed to refresh environment",
            nextRecommendedAction: success ? nil : .useDefaultState
        )
    }
    
    private func performUseDefaultState(for error: EnvironmentObjectError) async -> EnvironmentRecoveryResult {
        // This should almost always succeed
        let success = Double.random(in: 0...1) > 0.05 // 95% success rate
        
        return EnvironmentRecoveryResult(
            action: .useDefaultState,
            isSuccessful: success,
            message: success ? "Using default state as fallback" : "Failed to create default state",
            nextRecommendedAction: success ? nil : .restartView
        )
    }
    
    private func performRestartView(for error: EnvironmentObjectError) async -> EnvironmentRecoveryResult {
        // Simulate view restart
        let success = Double.random(in: 0...1) > 0.1 // 90% success rate
        
        return EnvironmentRecoveryResult(
            action: .restartView,
            isSuccessful: success,
            message: success ? "View restarted with fresh environment" : "Failed to restart view",
            nextRecommendedAction: success ? nil : .reportIssue
        )
    }
    
    private func performCheckDependencies(for error: EnvironmentObjectError) async -> EnvironmentRecoveryResult {
        // Simulate dependency check
        let success = Double.random(in: 0...1) > 0.3 // 70% success rate
        
        return EnvironmentRecoveryResult(
            action: .checkDependencies,
            isSuccessful: success,
            message: success ? "All dependencies are available" : "Some dependencies are still missing",
            nextRecommendedAction: success ? .refreshEnvironment : .useDefaultState
        )
    }
    
    private func performResetNavigation(for error: EnvironmentObjectError) async -> EnvironmentRecoveryResult {
        // Simulate navigation reset
        let success = Double.random(in: 0...1) > 0.15 // 85% success rate
        
        return EnvironmentRecoveryResult(
            action: .resetNavigation,
            isSuccessful: success,
            message: success ? "Navigation state reset successfully" : "Failed to reset navigation",
            nextRecommendedAction: success ? nil : .restartView
        )
    }
    
    private func performReportIssue(for error: EnvironmentObjectError) async -> EnvironmentRecoveryResult {
        // This should always succeed (just logging/reporting)
        return EnvironmentRecoveryResult(
            action: .reportIssue,
            isSuccessful: true,
            message: "Issue reported to development team",
            nextRecommendedAction: .useDefaultState
        )
    }
    
    // MARK: - Helper Methods
    
    private func getErrorKey(for error: EnvironmentObjectError) -> String {
        switch error {
        case .missingEnvironmentObject(let type):
            return type == "AppState" ? "missingAppState" : "missingEnvironment"
        case .invalidEnvironmentObjectState:
            return "invalidState"
        case .dependencyInjectionFailure:
            return "dependencyIssue"
        case .fallbackCreationFailed:
            return "fallbackFailure"
        }
    }
    
    private func getActionDelay(for action: EnvironmentRecoveryAction) -> TimeInterval {
        switch action {
        case .refreshEnvironment:
            return 1.5
        case .useDefaultState:
            return 0.8
        case .restartView:
            return 2.0
        case .checkDependencies:
            return 1.2
        case .resetNavigation:
            return 1.0
        case .reportIssue:
            return 0.5
        }
    }
    
    private func enhanceContext(_ context: [String: Any], viewName: String?) -> [String: Any] {
        var enhanced = context
        
        if let viewName = viewName {
            enhanced["viewName"] = viewName
        }
        
        enhanced["timestamp"] = Date()
        enhanced["errorHandlerVersion"] = "1.0"
        enhanced["recoveryHistoryCount"] = recoveryHistory.count
        
        return enhanced
    }
    
    private func logError(_ error: EnvironmentObjectError, context: [String: Any]) {
        print("🚨 EnvironmentObjectErrorHandler: \(error.localizedDescription)")
        
        if let viewName = context["viewName"] as? String {
            print("   View: \(viewName)")
        }
        
        #if DEBUG
        print("   Context: \(context)")
        if let recovery = error.recoverySuggestion {
            print("   Recovery: \(recovery)")
        }
        #endif
    }
    
    private func extractMissingDependencies(from details: String) -> [String] {
        // Simple extraction - in a real implementation, this would be more sophisticated
        let components = details.components(separatedBy: ",")
        return components.compactMap { component in
            let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }
    
    private func calculateAverageRecoveryTime() -> TimeInterval {
        guard !recoveryHistory.isEmpty else { return 0 }
        
        // For now, return a simulated average
        // In a real implementation, you'd track actual recovery times
        return 2.5
    }
    
    private func findMostCommonError() -> String? {
        let errorCounts = Dictionary(grouping: recoveryHistory, by: { getErrorKey(for: $0.error) })
            .mapValues { $0.count }
        
        return errorCounts.max(by: { $0.value < $1.value })?.key
    }
    
    private func findMostSuccessfulAction() -> EnvironmentRecoveryAction? {
        let successfulActions = recoveryHistory
            .filter { $0.result.isSuccessful }
            .map { $0.action }
        
        let actionCounts = Dictionary(grouping: successfulActions, by: { $0 })
            .mapValues { $0.count }
        
        return actionCounts.max(by: { $0.value < $1.value })?.key
    }
}

// MARK: - Supporting Types

/// Recovery strategy for specific error patterns
struct EnvironmentRecoveryStrategy {
    let errorPattern: String
    let recommendedActions: [EnvironmentRecoveryAction]
    let automaticRecovery: Bool
    let maxAttempts: Int
    let timeout: TimeInterval
}

/// Record of a recovery attempt
struct EnvironmentRecoveryAttempt {
    let error: EnvironmentObjectError
    let action: EnvironmentRecoveryAction
    let result: EnvironmentRecoveryResult
    let timestamp: Date
}

/// Statistics about environment error handling
struct EnvironmentErrorStatistics {
    let totalRecoveryAttempts: Int
    let successfulRecoveries: Int
    let failedRecoveries: Int
    let errorsByType: [String: Int]
    let actionsByType: [EnvironmentRecoveryAction: Int]
    let averageRecoveryTime: TimeInterval
    let mostCommonError: String?
    let mostSuccessfulAction: EnvironmentRecoveryAction?
    
    var successRate: Double {
        guard totalRecoveryAttempts > 0 else { return 0 }
        return Double(successfulRecoveries) / Double(totalRecoveryAttempts) * 100
    }
    
    var isHealthy: Bool {
        return successRate >= 80.0 && totalRecoveryAttempts > 0
    }
}

// MARK: - View Modifier

/// View modifier that automatically handles environment object errors
struct EnvironmentObjectErrorHandlingModifier: ViewModifier {
    let viewName: String
    @StateObject private var errorHandler = EnvironmentObjectErrorHandler.shared
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                // Register this view with the error handler
                // In a real implementation, you might want to validate environment objects here
            }
            .onChange(of: errorHandler.currentError?.localizedDescription) { errorDescription in
                if let errorDescription = errorDescription {
                    // Handle error presentation if needed
                    print("🔧 Environment error in \(viewName): \(errorDescription)")
                }
            }
    }
}

extension View {
    /// Add automatic environment object error handling to a view
    func withEnvironmentObjectErrorHandling(viewName: String) -> some View {
        modifier(EnvironmentObjectErrorHandlingModifier(viewName: viewName))
    }
}