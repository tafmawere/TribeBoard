import SwiftUI
import Foundation

/// Comprehensive environment object validation utilities
/// Provides validation, logging, fallback creation, and error reporting for environment objects
struct EnvironmentValidator {
    
    // MARK: - Validation Methods
    
    /// Validate an AppState environment object
    /// - Parameter appState: The AppState to validate
    /// - Returns: Detailed validation result
    @MainActor
    static func validateAppState(_ appState: AppState?) -> EnvironmentValidationResult {
        guard let appState = appState else {
            let error = EnvironmentObjectError.missingEnvironmentObject(type: "AppState")
            logValidationError(error)
            return EnvironmentValidationResult(
                isValid: false,
                objectType: "AppState",
                error: error,
                issues: ["AppState environment object is nil"],
                recommendations: [
                    "Ensure AppState is injected using .environmentObject() in the parent view",
                    "Check that MainNavigationView properly provides AppState",
                    "Verify AppState is created before view hierarchy initialization"
                ],
                fallbackAvailable: true
            )
        }
        
        // Validate AppState internal consistency
        let stateValidation = appState.validateState()
        var issues: [String] = stateValidation.issues
        var recommendations: [String] = stateValidation.recommendations
        
        // Additional environment-specific validations
        if appState.isAuthenticated && appState.currentUser == nil {
            issues.append("AppState shows authenticated but currentUser is nil")
            recommendations.append("Synchronize authentication state with user data")
        }
        
        if appState.currentFlow == .familyDashboard && appState.currentFamily == nil {
            issues.append("AppState flow is familyDashboard but no family is set")
            recommendations.append("Ensure family data is loaded before setting dashboard flow")
        }
        
        // Check for navigation consistency
        if appState.navigationPath.count > 10 {
            issues.append("Navigation path is unusually deep (\(appState.navigationPath.count) levels)")
            recommendations.append("Consider resetting navigation path to prevent memory issues")
        }
        
        let isValid = issues.isEmpty
        let error: EnvironmentObjectError? = isValid ? nil : .invalidEnvironmentObjectState(
            type: "AppState",
            reason: issues.joined(separator: ", ")
        )
        
        if let error = error {
            logValidationError(error)
        }
        
        return EnvironmentValidationResult(
            isValid: isValid,
            objectType: "AppState",
            error: error,
            issues: issues,
            recommendations: recommendations,
            fallbackAvailable: true
        )
    }
    
    /// Validate any ObservableObject environment object
    /// - Parameter object: The environment object to validate
    /// - Returns: Generic validation result
    static func validateEnvironmentObject<T: ObservableObject>(_ object: T?) -> EnvironmentValidationResult {
        let typeName = String(describing: T.self)
        
        guard let object = object else {
            let error = EnvironmentObjectError.missingEnvironmentObject(type: typeName)
            logValidationError(error)
            return EnvironmentValidationResult(
                isValid: false,
                objectType: typeName,
                error: error,
                issues: ["\(typeName) environment object is nil"],
                recommendations: [
                    "Ensure \(typeName) is injected using .environmentObject() in the parent view",
                    "Check that the parent view properly provides \(typeName)",
                    "Verify \(typeName) is created before view hierarchy initialization"
                ],
                fallbackAvailable: false
            )
        }
        
        // Perform reflection-based validation
        var issues: [String] = []
        var recommendations: [String] = []
        
        let mirror = Mirror(reflecting: object)
        
        // Check if the object has @Published properties
        let publishedProperties = mirror.children.compactMap { child -> String? in
            let typeString = String(describing: type(of: child.value))
            return typeString.contains("Published") ? child.label : nil
        }
        
        if publishedProperties.isEmpty {
            issues.append("\(typeName) has no @Published properties")
            recommendations.append("Add @Published properties for proper SwiftUI integration")
        }
        
        // Check for potential memory leaks (retain cycles)
        let childCount = mirror.children.count
        if childCount > 50 {
            issues.append("\(typeName) has unusually many properties (\(childCount))")
            recommendations.append("Consider breaking down \(typeName) into smaller, focused objects")
        }
        
        let isValid = issues.isEmpty
        let error: EnvironmentObjectError? = isValid ? nil : .invalidEnvironmentObjectState(
            type: typeName,
            reason: issues.joined(separator: ", ")
        )
        
        if let error = error {
            logValidationError(error)
        }
        
        return EnvironmentValidationResult(
            isValid: isValid,
            objectType: typeName,
            error: error,
            issues: issues,
            recommendations: recommendations,
            fallbackAvailable: false
        )
    }
    
    /// Validate environment object dependency chain
    /// - Parameter dependencies: Array of environment objects to validate as a chain
    /// - Returns: Validation result for the entire dependency chain
    static func validateDependencyChain(_ dependencies: [Any?]) -> EnvironmentValidationResult {
        var allIssues: [String] = []
        var allRecommendations: [String] = []
        var hasErrors = false
        
        for (index, dependency) in dependencies.enumerated() {
            if dependency == nil {
                allIssues.append("Dependency at index \(index) is nil")
                allRecommendations.append("Ensure all required dependencies are properly injected")
                hasErrors = true
            }
        }
        
        let error: EnvironmentObjectError? = hasErrors ? .dependencyInjectionFailure(
            "Multiple dependencies missing: \(allIssues.joined(separator: ", "))"
        ) : nil
        
        if let error = error {
            logValidationError(error)
        }
        
        return EnvironmentValidationResult(
            isValid: !hasErrors,
            objectType: "DependencyChain",
            error: error,
            issues: allIssues,
            recommendations: allRecommendations,
            fallbackAvailable: false
        )
    }
    
    // MARK: - Fallback Creation
    
    /// Create fallback AppState with safe defaults
    /// - Returns: AppState instance configured with safe defaults
    @MainActor
    static func createFallbackAppState() -> AppState {
        logFallbackCreation(for: "AppState")
        return AppStateFactory.createFallbackAppState()
    }
    
    /// Create fallback AppState for specific context
    /// - Parameter context: The context for which to create the fallback
    /// - Returns: AppState instance configured for the context
    @MainActor
    static func createFallbackAppState(for context: EnvironmentContext) -> AppState {
        logFallbackCreation(for: "AppState", context: context)
        
        switch context {
        case .preview:
            return AppStateFactory.createPreviewAppState()
        case .testing:
            return AppStateFactory.createTestAppState(scenario: .authenticated)
        case .production:
            return AppStateFactory.createFallbackAppState()
        case .demo:
            let appState = AppStateFactory.createPreviewAppState()
            appState.configureDemoScenario(.newUser)
            return appState
        }
    }
    
    /// Attempt to create a fallback for any ObservableObject type
    /// - Parameter type: The type to create a fallback for
    /// - Returns: Optional fallback object
    @MainActor
    static func createFallback<T: ObservableObject>(for type: T.Type) -> T? {
        let typeName = String(describing: type)
        logFallbackCreation(for: typeName)
        
        // Only AppState has a known fallback implementation
        if type == AppState.self {
            return createFallbackAppState() as? T
        }
        
        // For other types, we cannot create a generic fallback
        logFallbackCreationFailure(for: typeName, reason: "No fallback implementation available")
        return nil
    }
    
    // MARK: - Error Reporting
    
    /// Report environment object error to logging system
    /// - Parameters:
    ///   - error: The environment object error
    ///   - context: Additional context information
    static func reportError(_ error: EnvironmentObjectError, context: [String: Any] = [:]) {
        let errorReport = EnvironmentErrorReport(
            error: error,
            timestamp: Date(),
            context: context,
            stackTrace: Thread.callStackSymbols
        )
        
        // Log the error
        logError(errorReport)
        
        // In a production app, you might also send this to a crash reporting service
        #if DEBUG
        print("🚨 Environment Object Error Report:")
        print("   Error: \(error.localizedDescription)")
        print("   Context: \(context)")
        print("   Timestamp: \(errorReport.timestamp)")
        #endif
    }
    
    /// Report validation failure with detailed information
    /// - Parameters:
    ///   - result: The validation result
    ///   - viewName: Name of the view where validation failed
    static func reportValidationFailure(_ result: EnvironmentValidationResult, in viewName: String) {
        guard !result.isValid else { return }
        
        let context: [String: Any] = [
            "viewName": viewName,
            "objectType": result.objectType,
            "issues": result.issues,
            "recommendations": result.recommendations
        ]
        
        if let error = result.error {
            reportError(error, context: context)
        }
    }
    
    // MARK: - Logging Methods
    
    /// Log environment object validation error
    /// - Parameter error: The error to log
    private static func logValidationError(_ error: EnvironmentObjectError) {
        print("❌ EnvironmentValidator: Validation failed - \(error.localizedDescription)")
        
        #if DEBUG
        if let recovery = error.recoverySuggestion {
            print("   💡 Recovery suggestion: \(recovery)")
        }
        #endif
    }
    
    /// Log fallback object creation
    /// - Parameters:
    ///   - typeName: Name of the type for which fallback is created
    ///   - context: Optional context information
    private static func logFallbackCreation(for typeName: String, context: EnvironmentContext? = nil) {
        let contextString = context?.rawValue ?? "default"
        print("🔄 EnvironmentValidator: Creating fallback \(typeName) for context: \(contextString)")
    }
    
    /// Log fallback creation failure
    /// - Parameters:
    ///   - typeName: Name of the type for which fallback creation failed
    ///   - reason: Reason for the failure
    private static func logFallbackCreationFailure(for typeName: String, reason: String) {
        print("⚠️ EnvironmentValidator: Cannot create fallback for \(typeName) - \(reason)")
    }
    
    /// Log detailed error report
    /// - Parameter report: The error report to log
    private static func logError(_ report: EnvironmentErrorReport) {
        print("📊 EnvironmentValidator: Error Report")
        print("   Type: \(report.error)")
        print("   Time: \(report.timestamp)")
        print("   Context: \(report.context)")
        
        #if DEBUG
        print("   Stack trace (first 5 frames):")
        report.stackTrace.prefix(5).forEach { frame in
            print("     \(frame)")
        }
        #endif
    }
    
    /// Log environment object usage statistics
    /// - Parameter stats: Usage statistics to log
    static func logUsageStatistics(_ stats: EnvironmentUsageStatistics) {
        print("📈 EnvironmentValidator: Usage Statistics")
        print("   Total validations: \(stats.totalValidations)")
        print("   Failed validations: \(stats.failedValidations)")
        print("   Fallbacks created: \(stats.fallbacksCreated)")
        print("   Success rate: \(String(format: "%.1f", stats.successRate))%")
        
        if !stats.mostCommonIssues.isEmpty {
            print("   Most common issues:")
            stats.mostCommonIssues.forEach { issue in
                print("     - \(issue)")
            }
        }
    }
}

// MARK: - Supporting Types

/// Context in which environment objects are used
enum EnvironmentContext: String, CaseIterable {
    case preview = "preview"
    case testing = "testing"
    case production = "production"
    case demo = "demo"
}

/// Comprehensive validation result for environment objects
struct EnvironmentValidationResult {
    /// Whether the environment object is valid
    let isValid: Bool
    
    /// Type name of the validated object
    let objectType: String
    
    /// Error if validation failed
    let error: EnvironmentObjectError?
    
    /// List of specific issues found
    let issues: [String]
    
    /// Recommendations to fix the issues
    let recommendations: [String]
    
    /// Whether a fallback is available for this type
    let fallbackAvailable: Bool
    
    /// Whether there are critical issues requiring immediate attention
    var hasCriticalIssues: Bool {
        return !isValid && error != nil
    }
    
    /// Summary of the validation result
    var summary: String {
        if isValid {
            return "\(objectType) validation passed"
        } else {
            let issueCount = issues.count
            return "\(objectType) validation failed with \(issueCount) issue\(issueCount == 1 ? "" : "s")"
        }
    }
}

/// Detailed error report for environment object issues
struct EnvironmentErrorReport {
    /// The environment object error
    let error: EnvironmentObjectError
    
    /// When the error occurred
    let timestamp: Date
    
    /// Additional context information
    let context: [String: Any]
    
    /// Stack trace at the time of error
    let stackTrace: [String]
    
    /// Unique identifier for this error report
    let id: UUID = UUID()
}

/// Statistics for environment object usage and validation
struct EnvironmentUsageStatistics {
    /// Total number of validations performed
    let totalValidations: Int
    
    /// Number of failed validations
    let failedValidations: Int
    
    /// Number of fallback objects created
    let fallbacksCreated: Int
    
    /// Most common validation issues
    let mostCommonIssues: [String]
    
    /// Success rate as a percentage
    var successRate: Double {
        guard totalValidations > 0 else { return 0.0 }
        return Double(totalValidations - failedValidations) / Double(totalValidations) * 100.0
    }
    
    /// Whether the statistics indicate healthy environment object usage
    var isHealthy: Bool {
        return successRate >= 95.0 && fallbacksCreated < Int(Double(totalValidations) * 0.1)
    }
}

// MARK: - Extensions

extension EnvironmentValidator {
    
    /// Validate multiple environment objects at once
    /// - Parameter objects: Dictionary of object names to objects
    /// - Returns: Dictionary of validation results
    @MainActor
    static func validateMultiple(_ objects: [String: Any?]) -> [String: EnvironmentValidationResult] {
        var results: [String: EnvironmentValidationResult] = [:]
        
        for (name, object) in objects {
            if let appState = object as? AppState {
                results[name] = validateAppState(appState)
            } else if let observableObject = object as? any ObservableObject {
                // Use type erasure to validate any ObservableObject
                results[name] = validateAnyObservableObject(observableObject, name: name)
            } else {
                let error = EnvironmentObjectError.missingEnvironmentObject(type: name)
                results[name] = EnvironmentValidationResult(
                    isValid: false,
                    objectType: name,
                    error: error,
                    issues: ["\(name) is nil or not an ObservableObject"],
                    recommendations: ["Ensure \(name) is properly injected and conforms to ObservableObject"],
                    fallbackAvailable: false
                )
            }
        }
        
        return results
    }
    
    /// Helper method to validate any ObservableObject using type erasure
    /// - Parameters:
    ///   - object: The observable object to validate
    ///   - name: Name of the object for reporting
    /// - Returns: Validation result
    private static func validateAnyObservableObject(_ object: any ObservableObject, name: String) -> EnvironmentValidationResult {
        var issues: [String] = []
        var recommendations: [String] = []
        
        // Basic validation using reflection
        let mirror = Mirror(reflecting: object)
        
        // Check for @Published properties
        let publishedProperties = mirror.children.compactMap { child -> String? in
            let typeString = String(describing: type(of: child.value))
            return typeString.contains("Published") ? child.label : nil
        }
        
        if publishedProperties.isEmpty {
            issues.append("\(name) has no @Published properties")
            recommendations.append("Add @Published properties for proper SwiftUI integration")
        }
        
        let isValid = issues.isEmpty
        let error: EnvironmentObjectError? = isValid ? nil : .invalidEnvironmentObjectState(
            type: name,
            reason: issues.joined(separator: ", ")
        )
        
        return EnvironmentValidationResult(
            isValid: isValid,
            objectType: name,
            error: error,
            issues: issues,
            recommendations: recommendations,
            fallbackAvailable: false
        )
    }
}