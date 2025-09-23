import Foundation
import SwiftUI

/// Manages error recovery flows and user guidance for mock errors
@MainActor
class MockErrorRecoveryManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Currently active recovery flow
    @Published var activeRecoveryFlow: MockErrorRecoveryFlow?
    
    /// Recovery progress for current flow
    @Published var recoveryProgress: MockRecoveryProgress?
    
    /// Available recovery options
    @Published var availableRecoveryOptions: [MockRecoveryAction] = []
    
    /// Recovery history for analytics
    @Published private(set) var recoveryHistory: [MockRecoveryAttempt] = []
    
    // MARK: - Dependencies
    
    private let errorGenerator: MockErrorGenerator
    private let hapticManager = HapticManager.shared
    private let toastManager = ToastManager.shared
    
    // MARK: - Recovery State
    
    private var currentRecoveryStep: Int = 0
    private var recoveryStartTime: Date?
    private var recoveryAttempts: [String: Int] = [:]
    
    // MARK: - Initialization
    
    init(errorGenerator: MockErrorGenerator) {
        self.errorGenerator = errorGenerator
    }
    
    // MARK: - Recovery Flow Management
    
    /// Start recovery flow for an error
    func startRecoveryFlow(for error: MockError) {
        let flow = createRecoveryFlow(for: error)
        activeRecoveryFlow = flow
        recoveryProgress = MockRecoveryProgress(
            currentStep: 0,
            totalSteps: flow.steps.count,
            isComplete: false,
            hasSucceeded: false
        )
        
        currentRecoveryStep = 0
        recoveryStartTime = Date()
        
        // Track recovery attempt
        let attemptKey = "\(error.category.rawValue)_\(error.type.rawValue)"
        recoveryAttempts[attemptKey, default: 0] += 1
        
        // Update available options
        updateAvailableRecoveryOptions(for: error)
        
        // Provide haptic feedback
        hapticManager.lightImpact()
    }
    
    /// Execute a recovery action
    func executeRecoveryAction(_ action: MockRecoveryAction, for error: MockError) async -> MockRecoveryResult {
        let result = await performRecoveryAction(action, for: error)
        
        // Track the attempt
        let attempt = MockRecoveryAttempt(
            error: error,
            action: action,
            result: result,
            timestamp: Date(),
            duration: Date().timeIntervalSince(recoveryStartTime ?? Date())
        )
        
        recoveryHistory.append(attempt)
        
        // Update recovery progress
        if let flow = activeRecoveryFlow {
            updateRecoveryProgress(for: flow, with: result)
        }
        
        // Provide feedback based on result
        await provideFeedback(for: result, action: action)
        
        return result
    }
    
    /// Complete recovery flow
    func completeRecoveryFlow(success: Bool) {
        guard let flow = activeRecoveryFlow else { return }
        
        recoveryProgress?.isComplete = true
        recoveryProgress?.hasSucceeded = success
        
        // Provide completion feedback
        if success {
            hapticManager.successImpact()
            toastManager.success("Issue resolved successfully")
        } else {
            hapticManager.errorImpact()
            toastManager.error("Unable to resolve issue")
        }
        
        // Clean up after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.activeRecoveryFlow = nil
            self.recoveryProgress = nil
            self.currentRecoveryStep = 0
            self.recoveryStartTime = nil
        }
    }
    
    /// Cancel recovery flow
    func cancelRecoveryFlow() {
        activeRecoveryFlow = nil
        recoveryProgress = nil
        currentRecoveryStep = 0
        recoveryStartTime = nil
        availableRecoveryOptions = []
        
        hapticManager.lightImpact()
        toastManager.info("Recovery cancelled")
    }
    
    // MARK: - Recovery Flow Creation
    
    private func createRecoveryFlow(for error: MockError) -> MockErrorRecoveryFlow {
        let steps = createRecoverySteps(for: error)
        let fallbackOptions = createFallbackOptions(for: error)
        let successCriteria = createSuccessCriteria(for: error)
        
        return MockErrorRecoveryFlow(
            error: error,
            steps: steps,
            fallbackOptions: fallbackOptions,
            successCriteria: successCriteria
        )
    }
    
    private func createRecoverySteps(for error: MockError) -> [MockRecoveryStep] {
        switch error.category {
        case .authentication:
            return createAuthenticationRecoverySteps(for: error)
        case .network:
            return createNetworkRecoverySteps(for: error)
        case .validation:
            return createValidationRecoverySteps(for: error)
        case .permission:
            return createPermissionRecoverySteps(for: error)
        case .familyManagement:
            return createFamilyManagementRecoverySteps(for: error)
        case .sync:
            return createSyncRecoverySteps(for: error)
        case .qrCode:
            return createQRCodeRecoverySteps(for: error)
        case .prototype:
            return createPrototypeRecoverySteps(for: error)
        }
    }
    
    private func createAuthenticationRecoverySteps(for error: MockError) -> [MockRecoveryStep] {
        switch error.type {
        case .sessionExpired:
            return [
                MockRecoveryStep(
                    action: .signIn,
                    description: "Sign in again to restore your session",
                    estimatedTime: 30.0,
                    requiresUserInput: true,
                    successProbability: 0.95
                )
            ]
        case .accountNotFound:
            return [
                MockRecoveryStep(
                    action: .createAccount,
                    description: "Create a new TribeBoard account",
                    estimatedTime: 60.0,
                    requiresUserInput: true,
                    successProbability: 0.90
                ),
                MockRecoveryStep(
                    action: .tryDifferentAccount,
                    description: "Try signing in with a different account",
                    estimatedTime: 30.0,
                    requiresUserInput: true,
                    successProbability: 0.70
                )
            ]
        case .authenticationFailed:
            return [
                MockRecoveryStep(
                    action: .checkConnection,
                    description: "Check your internet connection",
                    estimatedTime: 10.0,
                    requiresUserInput: false,
                    successProbability: 0.60
                ),
                MockRecoveryStep(
                    action: .retry,
                    description: "Try signing in again",
                    estimatedTime: 20.0,
                    requiresUserInput: true,
                    successProbability: 0.80
                )
            ]
        default:
            return [
                MockRecoveryStep(
                    action: .retry,
                    description: "Try the authentication process again",
                    estimatedTime: 30.0,
                    requiresUserInput: true,
                    successProbability: 0.75
                )
            ]
        }
    }
    
    private func createNetworkRecoverySteps(for error: MockError) -> [MockRecoveryStep] {
        switch error.type {
        case .noConnection:
            return [
                MockRecoveryStep(
                    action: .checkConnection,
                    description: "Check your Wi-Fi or cellular connection",
                    estimatedTime: 15.0,
                    requiresUserInput: true,
                    successProbability: 0.70
                ),
                MockRecoveryStep(
                    action: .retry,
                    description: "Try connecting again",
                    estimatedTime: 10.0,
                    requiresUserInput: false,
                    successProbability: 0.80
                ),
                MockRecoveryStep(
                    action: .workOffline,
                    description: "Continue working offline",
                    estimatedTime: 0.0,
                    requiresUserInput: false,
                    successProbability: 1.0
                )
            ]
        case .serverUnavailable:
            return [
                MockRecoveryStep(
                    action: .checkStatus,
                    description: "Check TribeBoard server status",
                    estimatedTime: 5.0,
                    requiresUserInput: false,
                    successProbability: 0.50
                ),
                MockRecoveryStep(
                    action: .retry,
                    description: "Try again in a few minutes",
                    estimatedTime: 180.0,
                    requiresUserInput: false,
                    successProbability: 0.90
                )
            ]
        default:
            return [
                MockRecoveryStep(
                    action: .retry,
                    description: "Try the network operation again",
                    estimatedTime: 15.0,
                    requiresUserInput: false,
                    successProbability: 0.70
                )
            ]
        }
    }
    
    private func createValidationRecoverySteps(for error: MockError) -> [MockRecoveryStep] {
        return [
            MockRecoveryStep(
                action: .editInput,
                description: "Review and correct your input",
                estimatedTime: 30.0,
                requiresUserInput: true,
                successProbability: 0.95
            )
        ]
    }
    
    private func createPermissionRecoverySteps(for error: MockError) -> [MockRecoveryStep] {
        switch error.type {
        case .cameraPermission:
            return [
                MockRecoveryStep(
                    action: .openSettings,
                    description: "Enable camera permission in Settings",
                    estimatedTime: 45.0,
                    requiresUserInput: true,
                    successProbability: 0.90
                ),
                MockRecoveryStep(
                    action: .enterCodeManually,
                    description: "Enter the family code manually instead",
                    estimatedTime: 20.0,
                    requiresUserInput: true,
                    successProbability: 0.95
                )
            ]
        case .accessDenied:
            return [
                MockRecoveryStep(
                    action: .contactAdmin,
                    description: "Contact your family admin for permission",
                    estimatedTime: 300.0,
                    requiresUserInput: true,
                    successProbability: 0.80
                )
            ]
        default:
            return [
                MockRecoveryStep(
                    action: .requestPermission,
                    description: "Request the necessary permission",
                    estimatedTime: 60.0,
                    requiresUserInput: true,
                    successProbability: 0.75
                )
            ]
        }
    }
    
    private func createFamilyManagementRecoverySteps(for error: MockError) -> [MockRecoveryStep] {
        switch error.type {
        case .familyNotFound:
            return [
                MockRecoveryStep(
                    action: .tryDifferentCode,
                    description: "Double-check the family code and try again",
                    estimatedTime: 30.0,
                    requiresUserInput: true,
                    successProbability: 0.85
                ),
                MockRecoveryStep(
                    action: .scanQRCode,
                    description: "Scan the QR code instead of typing",
                    estimatedTime: 15.0,
                    requiresUserInput: true,
                    successProbability: 0.95
                )
            ]
        case .familyFull:
            return [
                MockRecoveryStep(
                    action: .contactAdmin,
                    description: "Contact the family admin to make space",
                    estimatedTime: 600.0,
                    requiresUserInput: true,
                    successProbability: 0.70
                )
            ]
        default:
            return [
                MockRecoveryStep(
                    action: .retry,
                    description: "Try the family operation again",
                    estimatedTime: 20.0,
                    requiresUserInput: true,
                    successProbability: 0.60
                )
            ]
        }
    }
    
    private func createSyncRecoverySteps(for error: MockError) -> [MockRecoveryStep] {
        switch error.type {
        case .syncFailed:
            return [
                MockRecoveryStep(
                    action: .checkConnection,
                    description: "Check your internet connection",
                    estimatedTime: 10.0,
                    requiresUserInput: false,
                    successProbability: 0.60
                ),
                MockRecoveryStep(
                    action: .forceSync,
                    description: "Force synchronization with iCloud",
                    estimatedTime: 30.0,
                    requiresUserInput: false,
                    successProbability: 0.85
                )
            ]
        case .quotaExceeded:
            return [
                MockRecoveryStep(
                    action: .manageStorage,
                    description: "Free up iCloud storage space",
                    estimatedTime: 180.0,
                    requiresUserInput: true,
                    successProbability: 0.80
                ),
                MockRecoveryStep(
                    action: .continueLocal,
                    description: "Continue saving data locally only",
                    estimatedTime: 0.0,
                    requiresUserInput: false,
                    successProbability: 1.0
                )
            ]
        default:
            return [
                MockRecoveryStep(
                    action: .forceSync,
                    description: "Attempt to sync again",
                    estimatedTime: 20.0,
                    requiresUserInput: false,
                    successProbability: 0.75
                )
            ]
        }
    }
    
    private func createQRCodeRecoverySteps(for error: MockError) -> [MockRecoveryStep] {
        return [
            MockRecoveryStep(
                action: .improveLight,
                description: "Improve lighting and try scanning again",
                estimatedTime: 15.0,
                requiresUserInput: true,
                successProbability: 0.80
            ),
            MockRecoveryStep(
                action: .enterCodeManually,
                description: "Enter the family code manually",
                estimatedTime: 30.0,
                requiresUserInput: true,
                successProbability: 0.95
            )
        ]
    }
    
    private func createPrototypeRecoverySteps(for error: MockError) -> [MockRecoveryStep] {
        return [
            MockRecoveryStep(
                action: .learnMore,
                description: "Learn about the full version features",
                estimatedTime: 60.0,
                requiresUserInput: true,
                successProbability: 1.0
            ),
            MockRecoveryStep(
                action: .continueDemo,
                description: "Continue with the prototype demo",
                estimatedTime: 0.0,
                requiresUserInput: false,
                successProbability: 1.0
            )
        ]
    }
    
    private func createFallbackOptions(for error: MockError) -> [MockRecoveryAction] {
        var fallbacks: [MockRecoveryAction] = [.dismiss]
        
        switch error.category {
        case .network:
            fallbacks.append(contentsOf: [.workOffline, .checkConnection])
        case .authentication:
            fallbacks.append(contentsOf: [.tryDifferentMethod, .signInManually])
        case .validation:
            fallbacks.append(.editInput)
        case .permission:
            fallbacks.append(contentsOf: [.contactAdmin, .openSettings])
        case .familyManagement:
            fallbacks.append(contentsOf: [.enterCodeManually, .contactSender])
        case .sync:
            fallbacks.append(contentsOf: [.continueOffline, .manageStorage])
        case .qrCode:
            fallbacks.append(.enterCodeManually)
        case .prototype:
            fallbacks.append(.continueDemo)
        }
        
        return fallbacks
    }
    
    private func createSuccessCriteria(for error: MockError) -> [String] {
        switch error.category {
        case .authentication:
            return ["User successfully authenticated", "Valid session established"]
        case .network:
            return ["Network connection restored", "Data successfully transmitted"]
        case .validation:
            return ["Input validation passed", "Data format is correct"]
        case .permission:
            return ["Required permission granted", "Access level sufficient"]
        case .familyManagement:
            return ["Family operation completed", "User successfully joined/created family"]
        case .sync:
            return ["Data synchronized successfully", "No sync conflicts remaining"]
        case .qrCode:
            return ["QR code successfully scanned", "Valid family code extracted"]
        case .prototype:
            return ["User understands limitation", "Demo continues smoothly"]
        }
    }
    
    // MARK: - Recovery Action Execution
    
    private func performRecoveryAction(_ action: MockRecoveryAction, for error: MockError) async -> MockRecoveryResult {
        // Simulate action execution time
        let executionTime = getExecutionTime(for: action)
        try? await Task.sleep(nanoseconds: UInt64(executionTime * 1_000_000_000))
        
        // Determine success probability
        let successProbability = getSuccessProbability(for: action, error: error)
        let isSuccessful = Double.random(in: 0...1) < successProbability
        
        // Create result
        let result = MockRecoveryResult(
            action: action,
            isSuccessful: isSuccessful,
            message: getResultMessage(for: action, success: isSuccessful),
            nextRecommendedAction: getNextRecommendedAction(for: action, success: isSuccessful, error: error),
            executionTime: executionTime
        )
        
        return result
    }
    
    private func getExecutionTime(for action: MockRecoveryAction) -> TimeInterval {
        switch action {
        case .retry, .tryAgain:
            return Double.random(in: 1.0...3.0)
        case .checkConnection:
            return Double.random(in: 2.0...5.0)
        case .signIn, .createAccount:
            return Double.random(in: 3.0...8.0)
        case .openSettings:
            return Double.random(in: 5.0...15.0)
        case .contactAdmin, .requestPermission:
            return Double.random(in: 1.0...2.0) // Immediate action, but response takes time
        case .editInput:
            return Double.random(in: 2.0...10.0)
        case .forceSync:
            return Double.random(in: 3.0...10.0)
        case .manageStorage:
            return Double.random(in: 10.0...30.0)
        default:
            return Double.random(in: 1.0...5.0)
        }
    }
    
    private func getSuccessProbability(for action: MockRecoveryAction, error: MockError) -> Double {
        // Base success probability
        var probability = 0.75
        
        // Adjust based on action type
        switch action {
        case .retry, .tryAgain:
            probability = 0.70
        case .editInput:
            probability = 0.95
        case .openSettings:
            probability = 0.90
        case .checkConnection:
            probability = 0.60
        case .forceSync:
            probability = 0.80
        case .continueDemo, .learnMore:
            probability = 1.0 // Always succeed for prototype actions
        default:
            probability = 0.75
        }
        
        // Adjust based on error severity
        switch error.severity {
        case .info, .low:
            probability += 0.1
        case .medium:
            break // No adjustment
        case .high:
            probability -= 0.1
        case .critical:
            probability -= 0.2
        }
        
        // Adjust based on retry attempts
        let attemptKey = "\(error.category.rawValue)_\(error.type.rawValue)"
        let attempts = recoveryAttempts[attemptKey, default: 0]
        probability -= Double(attempts) * 0.1
        
        return max(0.1, min(1.0, probability))
    }
    
    private func getResultMessage(for action: MockRecoveryAction, success: Bool) -> String {
        if success {
            switch action {
            case .retry, .tryAgain:
                return "Operation completed successfully"
            case .checkConnection:
                return "Connection restored"
            case .signIn:
                return "Successfully signed in"
            case .editInput:
                return "Input validated successfully"
            case .openSettings:
                return "Permission granted"
            case .forceSync:
                return "Data synchronized"
            case .contactAdmin:
                return "Request sent to admin"
            default:
                return "Action completed successfully"
            }
        } else {
            switch action {
            case .retry, .tryAgain:
                return "Operation failed, please try again"
            case .checkConnection:
                return "Connection still unavailable"
            case .signIn:
                return "Sign in failed"
            case .editInput:
                return "Input still invalid"
            case .openSettings:
                return "Permission not granted"
            case .forceSync:
                return "Sync failed"
            case .contactAdmin:
                return "Unable to contact admin"
            default:
                return "Action failed"
            }
        }
    }
    
    private func getNextRecommendedAction(for action: MockRecoveryAction, success: Bool, error: MockError) -> MockRecoveryAction? {
        if success {
            return nil // No further action needed
        }
        
        // Recommend next action based on failed action
        switch action {
        case .retry:
            return .checkConnection
        case .checkConnection:
            return .workOffline
        case .signIn:
            return .tryDifferentMethod
        case .editInput:
            return .generateNewCode
        case .forceSync:
            return .continueOffline
        case .scanQRCode:
            return .enterCodeManually
        default:
            return .dismiss
        }
    }
    
    // MARK: - Progress Management
    
    private func updateRecoveryProgress(for flow: MockErrorRecoveryFlow, with result: MockRecoveryResult) {
        guard var progress = recoveryProgress else { return }
        
        if result.isSuccessful {
            progress.currentStep += 1
            
            if progress.currentStep >= flow.steps.count {
                progress.isComplete = true
                progress.hasSucceeded = true
            }
        }
        
        recoveryProgress = progress
    }
    
    private func updateAvailableRecoveryOptions(for error: MockError) {
        availableRecoveryOptions = error.recoveryActions
    }
    
    // MARK: - Feedback
    
    private func provideFeedback(for result: MockRecoveryResult, action: MockRecoveryAction) async {
        if result.isSuccessful {
            hapticManager.successImpact()
            toastManager.success(result.message)
        } else {
            hapticManager.errorImpact()
            toastManager.error(result.message)
            
            // Suggest next action if available
            if let nextAction = result.nextRecommendedAction {
                do {
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                    toastManager.info("Try: \(nextAction.title)")
                } catch {
                    // Handle sleep error silently
                }
            }
        }
    }
    
    // MARK: - Analytics and Insights
    
    /// Get recovery success rate for a specific error category
    func getRecoverySuccessRate(for category: MockErrorCategory) -> Double {
        let categoryAttempts = recoveryHistory.filter { $0.error.category == category }
        guard !categoryAttempts.isEmpty else { return 0.0 }
        
        let successfulAttempts = categoryAttempts.filter { $0.result.isSuccessful }
        return Double(successfulAttempts.count) / Double(categoryAttempts.count)
    }
    
    /// Get most effective recovery action for an error type
    func getMostEffectiveAction(for errorType: MockErrorType) -> MockRecoveryAction? {
        let typeAttempts = recoveryHistory.filter { $0.error.type == errorType }
        
        let actionSuccessRates = Dictionary(grouping: typeAttempts, by: { $0.action })
            .mapValues { attempts in
                let successful = attempts.filter { $0.result.isSuccessful }
                return Double(successful.count) / Double(attempts.count)
            }
        
        return actionSuccessRates.max(by: { $0.value < $1.value })?.key
    }
    
    /// Get recovery insights for improving error handling
    func getRecoveryInsights() -> [MockRecoveryInsight] {
        var insights: [MockRecoveryInsight] = []
        
        // Analyze success rates by category
        for category in MockErrorCategory.allCases {
            let successRate = getRecoverySuccessRate(for: category)
            if successRate < 0.5 {
                insights.append(MockRecoveryInsight(
                    type: .lowSuccessRate,
                    category: category,
                    message: "Low recovery success rate (\(Int(successRate * 100))%) for \(category.displayName) errors",
                    recommendation: "Review recovery flows and improve guidance"
                ))
            }
        }
        
        // Analyze common failure patterns
        let failedAttempts = recoveryHistory.filter { !$0.result.isSuccessful }
        let commonFailures = Dictionary(grouping: failedAttempts, by: { $0.action })
            .filter { $0.value.count >= 3 }
        
        for (action, attempts) in commonFailures {
            insights.append(MockRecoveryInsight(
                type: .commonFailure,
                category: nil,
                message: "\(action.title) fails frequently (\(attempts.count) times)",
                recommendation: "Improve \(action.title) implementation or provide better alternatives"
            ))
        }
        
        return insights
    }
    
    /// Reset recovery tracking
    func resetRecoveryTracking() {
        recoveryHistory.removeAll()
        recoveryAttempts.removeAll()
        activeRecoveryFlow = nil
        recoveryProgress = nil
        availableRecoveryOptions = []
    }
}

// MARK: - Supporting Types

/// Progress tracking for recovery flows
struct MockRecoveryProgress {
    var currentStep: Int
    let totalSteps: Int
    var isComplete: Bool
    var hasSucceeded: Bool
    
    var progressPercentage: Double {
        guard totalSteps > 0 else { return 0.0 }
        return Double(currentStep) / Double(totalSteps)
    }
}

/// Result of a recovery action
struct MockRecoveryResult {
    let action: MockRecoveryAction
    let isSuccessful: Bool
    let message: String
    let nextRecommendedAction: MockRecoveryAction?
    let executionTime: TimeInterval
}

/// Recovery attempt for tracking
struct MockRecoveryAttempt {
    let error: MockError
    let action: MockRecoveryAction
    let result: MockRecoveryResult
    let timestamp: Date
    let duration: TimeInterval
}

/// Insights from recovery analysis
struct MockRecoveryInsight {
    let type: MockRecoveryInsightType
    let category: MockErrorCategory?
    let message: String
    let recommendation: String
}

enum MockRecoveryInsightType {
    case lowSuccessRate
    case commonFailure
    case slowRecovery
    case userFrustration
}