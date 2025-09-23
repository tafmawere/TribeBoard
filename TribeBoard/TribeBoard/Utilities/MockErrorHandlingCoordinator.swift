import Foundation
import SwiftUI

// MockErrorScenario enum is defined in MockErrorTypes.swift

/// Coordinates comprehensive error handling across the prototype app
@MainActor
class MockErrorHandlingCoordinator: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Currently displayed error
    @Published var currentError: MockError?
    
    /// Error presentation style
    @Published var presentationStyle: MockErrorPresentationStyle = .modal
    
    /// Error queue for managing multiple errors
    @Published private(set) var errorQueue: [MockError] = []
    
    /// Global error handling enabled state
    @Published var isErrorHandlingEnabled: Bool = true
    
    /// Error statistics
    @Published private(set) var errorStatistics: MockErrorStatistics?
    
    // MARK: - Dependencies
    
    let errorGenerator: MockErrorGenerator
    private let recoveryManager: MockErrorRecoveryManager
    private let hapticManager = HapticManager.shared
    private let toastManager = ToastManager.shared
    
    // MARK: - Error Display State
    
    private var errorDisplayTimer: Timer?
    private var errorHistory: [MockError] = []
    private var errorSuppressionRules: [MockErrorSuppressionRule] = []
    
    // MARK: - Initialization
    
    init() {
        self.errorGenerator = MockErrorGenerator()
        self.recoveryManager = MockErrorRecoveryManager(errorGenerator: errorGenerator)
        
        setupDefaultSuppressionRules()
        startErrorStatisticsTracking()
    }
    
    // MARK: - Error Display Management
    
    /// Display an error to the user
    func displayError(_ error: MockError, style: MockErrorPresentationStyle = .modal) {
        guard isErrorHandlingEnabled else { return }
        
        // Check suppression rules
        if shouldSuppressError(error) {
            return
        }
        
        // Add to history
        errorHistory.append(error)
        
        // Handle based on presentation style
        switch style {
        case .toast:
            displayToastError(error)
        case .modal:
            displayModalError(error)
        case .inline:
            displayInlineError(error)
        case .banner:
            displayBannerError(error)
        case .fullScreen:
            displayFullScreenError(error)
        }
        
        // Update statistics
        updateErrorStatistics()
        
        // Provide haptic feedback
        provideHapticFeedback(for: error)
    }
    
    /// Generate and display a random error for testing
    func generateAndDisplayRandomError() {
        guard let error = errorGenerator.generateRandomError() else { return }
        displayError(error)
    }
    
    /// Display a specific error type for testing
    func displaySpecificError(category: MockErrorCategory, type: MockErrorType) {
        let error = errorGenerator.generateError(for: category)
        displayError(error)
    }
    
    /// Dismiss current error
    func dismissCurrentError() {
        currentError = nil
        errorDisplayTimer?.invalidate()
        errorDisplayTimer = nil
        
        // Process next error in queue if available
        processNextErrorInQueue()
    }
    
    /// Clear all errors
    func clearAllErrors() {
        currentError = nil
        errorQueue.removeAll()
        errorDisplayTimer?.invalidate()
        errorDisplayTimer = nil
    }
    
    // MARK: - Error Presentation Methods
    
    private func displayToastError(_ error: MockError) {
        let message = "\(error.title): \(error.message)"
        
        switch error.severity {
        case .info, .low:
            toastManager.info(message)
        case .medium:
            toastManager.warning(message)
        case .high, .critical:
            toastManager.error(message)
        }
    }
    
    private func displayModalError(_ error: MockError) {
        currentError = error
        presentationStyle = .modal
        
        // Auto-dismiss for low severity errors
        if error.severity <= .low, let duration = MockErrorPresentationStyle.modal.duration {
            errorDisplayTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
                Task { @MainActor in
                    self.dismissCurrentError()
                }
            }
        }
    }
    
    private func displayInlineError(_ error: MockError) {
        currentError = error
        presentationStyle = .inline
    }
    
    private func displayBannerError(_ error: MockError) {
        currentError = error
        presentationStyle = .banner
        
        // Auto-dismiss banner errors
        if let duration = MockErrorPresentationStyle.banner.duration {
            errorDisplayTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { _ in
                Task { @MainActor in
                    self.dismissCurrentError()
                }
            }
        }
    }
    
    private func displayFullScreenError(_ error: MockError) {
        currentError = error
        presentationStyle = .fullScreen
    }
    
    // MARK: - Error Queue Management
    
    private func processNextErrorInQueue() {
        guard currentError == nil, !errorQueue.isEmpty else { return }
        
        let nextError = errorQueue.removeFirst()
        displayError(nextError)
    }
    
    private func addToQueue(_ error: MockError) {
        // Limit queue size
        if errorQueue.count >= 5 {
            errorQueue.removeFirst()
        }
        
        errorQueue.append(error)
    }
    
    // MARK: - Error Suppression
    
    private func setupDefaultSuppressionRules() {
        errorSuppressionRules = [
            // Suppress duplicate errors within 30 seconds
            MockErrorSuppressionRule(
                type: .duplicateWithinTimeframe,
                timeframe: 30.0,
                maxOccurrences: 1
            ),
            
            // Suppress low severity errors if too many occur
            MockErrorSuppressionRule(
                type: .severityBasedRateLimit,
                timeframe: 60.0,
                maxOccurrences: 3,
                severityThreshold: .low
            ),
            
            // Suppress prototype errors after user has seen them
            MockErrorSuppressionRule(
                type: .categoryBasedLimit,
                timeframe: 300.0,
                maxOccurrences: 2,
                category: .prototype
            )
        ]
    }
    
    private func shouldSuppressError(_ error: MockError) -> Bool {
        for rule in errorSuppressionRules {
            if rule.shouldSuppress(error, history: errorHistory) {
                return true
            }
        }
        return false
    }
    
    // MARK: - Haptic Feedback
    
    private func provideHapticFeedback(for error: MockError) {
        switch error.severity {
        case .info:
            hapticManager.lightImpact()
        case .low:
            hapticManager.lightImpact()
        case .medium:
            hapticManager.mediumImpact()
        case .high:
            hapticManager.heavyImpact()
        case .critical:
            hapticManager.errorImpact()
        }
    }
    
    // MARK: - Error Statistics
    
    private func startErrorStatisticsTracking() {
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            Task { @MainActor in
                self.updateErrorStatistics()
            }
        }
    }
    
    private func updateErrorStatistics() {
        errorStatistics = errorGenerator.getErrorStatistics()
    }
    
    // MARK: - Error Scenario Management
    
    /// Start a specific error scenario for testing
    func startErrorScenario(_ scenario: MockErrorScenario) {
        errorGenerator.startErrorScenario(scenario)
        toastManager.info("Started \(scenario.displayName) scenario")
    }
    
    /// Stop current error scenario
    func stopErrorScenario() {
        errorGenerator.stopErrorScenario()
        toastManager.info("Stopped error scenario")
    }
    
    /// Get available error scenarios
    func getAvailableScenarios() -> [MockErrorScenario] {
        return MockErrorScenario.allCases
    }
    
    // MARK: - Context-Aware Error Generation
    
    /// Generate error based on current app context
    func generateContextualError(context: MockErrorContext) -> MockError? {
        // Determine appropriate error category based on context
        let appropriateCategories = determineAppropriateCategories(for: context)
        
        guard let category = appropriateCategories.randomElement() else {
            return nil
        }
        
        return errorGenerator.generateError(for: category)
    }
    
    private func determineAppropriateCategories(for context: MockErrorContext) -> [MockErrorCategory] {
        var categories: [MockErrorCategory] = []
        
        // Network errors more likely when network status is poor
        if context.networkStatus == "poor" || context.networkStatus == "offline" {
            categories.append(.network)
        }
        
        // Authentication errors when not authenticated
        if context.authenticationStatus == "unauthenticated" {
            categories.append(.authentication)
        }
        
        // Permission errors for restricted users
        if context.userRole == "child" || context.userRole == "restricted" {
            categories.append(.permission)
        }
        
        // Validation errors on form views
        if context.currentView.contains("form") || context.currentView.contains("create") {
            categories.append(.validation)
        }
        
        // Family management errors on family-related views
        if context.currentView.contains("family") || context.currentView.contains("join") {
            categories.append(.familyManagement)
        }
        
        // QR code errors on scanning views
        if context.currentView.contains("scan") || context.currentView.contains("qr") {
            categories.append(.qrCode)
        }
        
        // Sync errors if there's a history of sync issues
        if context.errorHistory.contains(where: { $0.category == .sync }) {
            categories.append(.sync)
        }
        
        // Prototype errors for demo purposes
        categories.append(.prototype)
        
        return categories.isEmpty ? [.prototype] : categories
    }
    
    // MARK: - Error Recovery Integration
    
    /// Get recovery manager for external use
    func getRecoveryManager() -> MockErrorRecoveryManager {
        return recoveryManager
    }
    
    /// Execute recovery action for current error
    func executeRecoveryAction(_ action: MockRecoveryAction) async -> MockRecoveryResult? {
        guard let error = currentError else { return nil }
        
        let result = await recoveryManager.executeRecoveryAction(action, for: error)
        
        // Dismiss error if recovery was successful and action warrants it
        if result.isSuccessful && shouldDismissOnSuccess(action) {
            dismissCurrentError()
        }
        
        return result
    }
    
    private func shouldDismissOnSuccess(_ action: MockRecoveryAction) -> Bool {
        switch action {
        case .dismiss, .continueDemo, .workOffline, .acceptMerge, .continueLocal:
            return true
        case .retry, .signIn, .editInput, .forceSync:
            return true
        default:
            return false
        }
    }
    
    // MARK: - Demo and Testing Utilities
    
    /// Generate a sequence of errors for demo purposes
    func runErrorDemo() {
        let demoErrors = errorGenerator.generateDemoErrorSequence()
        
        for (index, error) in demoErrors.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index * 3)) {
                self.displayError(error, style: .modal)
            }
        }
    }
    
    /// Enable/disable error handling globally
    func setErrorHandlingEnabled(_ enabled: Bool) {
        isErrorHandlingEnabled = enabled
        
        if !enabled {
            clearAllErrors()
        }
        
        toastManager.info(enabled ? "Error handling enabled" : "Error handling disabled")
    }
    
    /// Get error handling insights
    func getErrorHandlingInsights() -> [MockRecoveryInsight] {
        return recoveryManager.getRecoveryInsights()
    }
    
    /// Reset all error tracking
    func resetErrorTracking() {
        errorHistory.removeAll()
        errorQueue.removeAll()
        currentError = nil
        errorGenerator.resetErrorTracking()
        recoveryManager.resetRecoveryTracking()
        errorStatistics = nil
        
        toastManager.info("Error tracking reset")
    }
    
    // MARK: - Error Export for Analysis
    
    /// Export error data for analysis
    func exportErrorData() -> MockErrorExportData {
        return MockErrorExportData(
            errors: errorHistory,
            statistics: errorStatistics,
            recoveryAttempts: recoveryManager.recoveryHistory,
            insights: getErrorHandlingInsights(),
            exportDate: Date()
        )
    }
}

// MARK: - Supporting Types

/// Error suppression rule
struct MockErrorSuppressionRule {
    let type: MockErrorSuppressionType
    let timeframe: TimeInterval
    let maxOccurrences: Int
    let severityThreshold: MockErrorSeverity?
    let category: MockErrorCategory?
    
    init(
        type: MockErrorSuppressionType,
        timeframe: TimeInterval,
        maxOccurrences: Int,
        severityThreshold: MockErrorSeverity? = nil,
        category: MockErrorCategory? = nil
    ) {
        self.type = type
        self.timeframe = timeframe
        self.maxOccurrences = maxOccurrences
        self.severityThreshold = severityThreshold
        self.category = category
    }
    
    func shouldSuppress(_ error: MockError, history: [MockError]) -> Bool {
        let cutoffTime = Date().addingTimeInterval(-timeframe)
        let recentErrors = history.filter { $0.timestamp >= cutoffTime }
        
        switch type {
        case .duplicateWithinTimeframe:
            let duplicates = recentErrors.filter { 
                $0.category == error.category && $0.type == error.type 
            }
            return duplicates.count >= maxOccurrences
            
        case .severityBasedRateLimit:
            guard let threshold = severityThreshold else { return false }
            let severityErrors = recentErrors.filter { $0.severity <= threshold }
            return severityErrors.count >= maxOccurrences
            
        case .categoryBasedLimit:
            guard let targetCategory = category else { return false }
            let categoryErrors = recentErrors.filter { $0.category == targetCategory }
            return categoryErrors.count >= maxOccurrences
            
        case .totalRateLimit:
            return recentErrors.count >= maxOccurrences
        }
    }
}

enum MockErrorSuppressionType {
    case duplicateWithinTimeframe
    case severityBasedRateLimit
    case categoryBasedLimit
    case totalRateLimit
}

/// Error export data structure
struct MockErrorExportData {
    let errors: [MockError]
    let statistics: MockErrorStatistics?
    let recoveryAttempts: [MockRecoveryAttempt]
    let insights: [MockRecoveryInsight]
    let exportDate: Date
}

// MARK: - Button Styles for Recovery Actions
// Button styles are defined in TribeBoard/Views/Components/ButtonStyles.swift