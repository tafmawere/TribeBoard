import Foundation
import CloudKit

/// Comprehensive error handling utilities for family creation
struct ErrorHandlingUtilities {
    
    // MARK: - Error Categorization
    
    /// Categorizes any error into a FamilyCreationError
    static func categorizeError(_ error: Error) -> FamilyCreationError {
        // Handle already categorized errors
        if let familyCreationError = error as? FamilyCreationError {
            return familyCreationError
        }
        
        // Handle specific error types
        if let dataServiceError = error as? DataServiceError {
            return .localCreationFailed(dataServiceError)
        }
        
        if let cloudKitError = error as? CloudKitError {
            return .cloudKitSyncFailed(cloudKitError)
        }
        
        if let codeGenerationError = error as? FamilyCodeGenerationError {
            return .codeGenerationFailed(codeGenerationError)
        }
        
        // Handle CloudKit CKError
        if let ckError = error as? CKError {
            return categorizeCloudKitError(ckError)
        }
        
        // Handle NSError and other system errors
        if let nsError = error as? NSError {
            return categorizeNSError(nsError)
        }
        
        // Handle validation errors
        if error.localizedDescription.lowercased().contains("validation") {
            return .validationFailed(error.localizedDescription)
        }
        
        // Handle network errors
        if isNetworkError(error) {
            return .networkUnavailable
        }
        
        // Default to unknown error
        return .unknownError(error)
    }
    
    /// Categorizes CloudKit CKError into FamilyCreationError
    private static func categorizeCloudKitError(_ ckError: CKError) -> FamilyCreationError {
        switch ckError.code {
        case .networkUnavailable, .networkFailure:
            return .networkUnavailable
        case .serviceUnavailable:
            return .cloudKitUnavailable
        case .quotaExceeded:
            return .quotaExceeded
        case .unknownItem:
            return .cloudKitSyncFailed(.recordNotFound)
        case .serverRecordChanged:
            return .cloudKitSyncFailed(.conflictResolution)
        case .badContainer:
            return .cloudKitSyncFailed(.containerNotFound)
        case .notAuthenticated:
            return .userNotAuthenticated
        case .permissionFailure:
            return .insufficientPermissions
        case .requestRateLimited:
            return .cloudKitSyncFailed(.retryLimitExceeded)
        case .zoneBusy:
            return .cloudKitUnavailable
        case .badDatabase:
            return .cloudKitSyncFailed(.invalidRecord)
        case .constraintViolation:
            return .constraintViolation("CloudKit constraint violation: \(ckError.localizedDescription)")
        case .incompatibleVersion:
            return .cloudKitSyncFailed(.syncFailed(ckError))
        case .assetFileNotFound:
            return .cloudKitSyncFailed(.recordNotFound)
        case .assetFileModified:
            return .cloudKitSyncFailed(.conflictResolution)
        case .invalidArguments:
            return .cloudKitSyncFailed(.invalidRecord)
        case .resultsTruncated:
            return .cloudKitSyncFailed(.syncFailed(ckError))
        case .serverResponseLost:
            return .connectionTimeout
        case .changeTokenExpired:
            return .cloudKitSyncFailed(.syncFailed(ckError))
        case .operationCancelled:
            return .operationCancelled
        default:
            return .cloudKitSyncFailed(.syncFailed(ckError))
        }
    }
    
    /// Categorizes NSError into FamilyCreationError
    private static func categorizeNSError(_ nsError: NSError) -> FamilyCreationError {
        switch nsError.domain {
        case NSURLErrorDomain:
            return categorizeURLError(nsError)
        case NSCocoaErrorDomain:
            return categorizeCocoaError(nsError)
        default:
            return .unknownError(nsError)
        }
    }
    
    /// Categorizes URL errors (network-related)
    private static func categorizeURLError(_ error: NSError) -> FamilyCreationError {
        switch error.code {
        case NSURLErrorNotConnectedToInternet,
             NSURLErrorNetworkConnectionLost,
             NSURLErrorDataNotAllowed:
            return .networkUnavailable
        case NSURLErrorTimedOut:
            return .connectionTimeout
        case NSURLErrorCannotFindHost,
             NSURLErrorCannotConnectToHost,
             NSURLErrorDNSLookupFailed:
            return .serverError(error.code)
        case NSURLErrorHTTPTooManyRedirects:
            return .serverError(error.code)
        case NSURLErrorBadServerResponse:
            return .serverError(500)
        case NSURLErrorUserCancelledAuthentication:
            return .userNotAuthenticated
        case NSURLErrorUserAuthenticationRequired:
            return .insufficientPermissions
        case NSURLErrorCancelled:
            return .operationCancelled
        default:
            return .networkUnavailable
        }
    }
    
    /// Categorizes Cocoa framework errors
    private static func categorizeCocoaError(_ error: NSError) -> FamilyCreationError {
        // Simplified error categorization to avoid missing constants
        let errorDescription = error.localizedDescription.lowercased()
        
        if errorDescription.contains("validation") {
            return .validationFailed(error.localizedDescription)
        } else if errorDescription.contains("constraint") {
            return .constraintViolation("Data constraint violation")
        } else if errorDescription.contains("corrupt") || errorDescription.contains("schema") {
            return .dataCorruption("Database schema mismatch")
        } else if errorDescription.contains("permission") {
            return .insufficientPermissions
        } else if errorDescription.contains("cancel") {
            return .operationCancelled
        } else {
            return .unknownError(error)
        }
    }
    
    /// Determines if an error is network-related
    private static func isNetworkError(_ error: Error) -> Bool {
        let errorDescription = error.localizedDescription.lowercased()
        let networkKeywords = [
            "network", "internet", "connection", "offline", "unreachable",
            "timeout", "dns", "host", "server", "connectivity"
        ]
        
        return networkKeywords.contains { keyword in
            errorDescription.contains(keyword)
        }
    }
    
    // MARK: - Recovery Strategy Determination
    
    /// Determines the appropriate recovery strategy for an error
    static func determineRecoveryStrategy(for error: FamilyCreationError, 
                                        context: ErrorContext) -> ErrorRecoveryAction {
        let baseStrategy = error.recoveryStrategy
        
        // Modify strategy based on context
        switch baseStrategy {
        case .automaticRetry(let delay, let maxAttempts):
            // Adjust retry parameters based on context
            let adjustedDelay = adjustRetryDelay(delay, for: context)
            let adjustedAttempts = adjustMaxAttempts(maxAttempts, for: context)
            
            return .retry(
                delay: adjustedDelay,
                maxAttempts: adjustedAttempts,
                strategy: determineRetryStrategy(for: error, context: context)
            )
            
        case .fallbackToLocal:
            return .fallbackToLocal(
                message: "Working offline. Changes will sync when connection is restored.",
                allowContinue: true
            )
            
        case .userIntervention:
            return .requireUserAction(
                message: error.userFriendlyMessage,
                actions: determineUserActions(for: error, context: context)
            )
            
        case .noRecovery:
            return .abort(
                message: error.userFriendlyMessage,
                allowRetry: false
            )
        }
    }
    
    /// Adjusts retry delay based on context
    private static func adjustRetryDelay(_ baseDelay: TimeInterval, 
                                       for context: ErrorContext) -> TimeInterval {
        var adjustedDelay = baseDelay
        
        // Increase delay for repeated failures
        if context.retryCount > 0 {
            adjustedDelay *= pow(2.0, Double(context.retryCount)) // Exponential backoff
        }
        
        // Adjust based on error category
        switch context.errorCategory {
        case .network:
            adjustedDelay = max(adjustedDelay, 2.0) // Minimum 2 seconds for network errors
        case .cloudKit:
            adjustedDelay = max(adjustedDelay, 1.0) // Minimum 1 second for CloudKit
        case .codeGeneration:
            adjustedDelay = min(adjustedDelay, 0.5) // Quick retry for code generation
        default:
            break
        }
        
        // Cap maximum delay
        return min(adjustedDelay, 30.0)
    }
    
    /// Adjusts maximum retry attempts based on context
    private static func adjustMaxAttempts(_ baseAttempts: Int, 
                                        for context: ErrorContext) -> Int {
        var adjustedAttempts = baseAttempts
        
        // Reduce attempts for high-priority errors
        if context.errorPriority == .high {
            adjustedAttempts = min(adjustedAttempts, 2)
        }
        
        // Increase attempts for low-priority, retryable errors
        if context.errorPriority == .low && context.isRetryable {
            adjustedAttempts = min(adjustedAttempts + 1, 5)
        }
        
        return adjustedAttempts
    }
    
    /// Determines the retry strategy based on error and context
    private static func determineRetryStrategy(for error: FamilyCreationError, 
                                             context: ErrorContext) -> RetryStrategy {
        switch error.category {
        case .network:
            return .exponentialBackoff
        case .cloudKit:
            return .linearBackoff
        case .codeGeneration:
            return .immediate
        case .localDatabase:
            return .exponentialBackoff
        default:
            return .exponentialBackoff
        }
    }
    
    /// Determines available user actions for an error
    private static func determineUserActions(for error: FamilyCreationError, 
                                           context: ErrorContext) -> [UserAction] {
        var actions: [UserAction] = []
        
        // Always allow dismissal
        actions.append(.dismiss)
        
        // Add retry if error is retryable
        if error.isRetryable {
            actions.append(.retry)
        }
        
        // Add specific actions based on error type
        switch error {
        case .userNotAuthenticated:
            actions.append(.signIn)
        case .networkUnavailable:
            actions.append(.checkConnection)
            actions.append(.workOffline)
        case .quotaExceeded:
            actions.append(.manageStorage)
        case .accountNotAvailable:
            actions.append(.checkiCloudSettings)
        case .validationFailed, .invalidFamilyName:
            actions.append(.editInput)
        default:
            break
        }
        
        return actions
    }
    
    // MARK: - Error Context Analysis
    
    /// Analyzes error patterns to provide insights
    static func analyzeErrorPattern(errors: [FamilyCreationError]) -> ErrorPattern {
        guard !errors.isEmpty else {
            return ErrorPattern(type: .none, frequency: 0, recommendation: .none)
        }
        
        let errorCategories = errors.map { $0.category }
        _ = mostFrequent(in: errorCategories) // Most common category for future use
        
        // Analyze patterns
        if errors.count >= 3 {
            let recentErrors = Array(errors.suffix(3))
            
            // Check for repeated network errors
            if recentErrors.allSatisfy({ $0.category == .network }) {
                return ErrorPattern(
                    type: .repeatedNetworkFailure,
                    frequency: recentErrors.count,
                    recommendation: .checkConnectivity
                )
            }
            
            // Check for repeated CloudKit errors
            if recentErrors.allSatisfy({ $0.category == .cloudKit }) {
                return ErrorPattern(
                    type: .repeatedCloudKitFailure,
                    frequency: recentErrors.count,
                    recommendation: .fallbackToLocal
                )
            }
            
            // Check for repeated validation errors
            if recentErrors.allSatisfy({ $0.category == .validation }) {
                return ErrorPattern(
                    type: .repeatedValidationFailure,
                    frequency: recentErrors.count,
                    recommendation: .reviewInput
                )
            }
        }
        
        return ErrorPattern(
            type: .sporadic,
            frequency: errors.count,
            recommendation: .monitor
        )
    }
    
    /// Finds the most frequent item in an array
    private static func mostFrequent<T: Hashable>(in array: [T]) -> T? {
        let counts = array.reduce(into: [:]) { counts, item in
            counts[item, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }
    
    // MARK: - Error Logging and Reporting
    
    /// Logs error with appropriate level and context
    static func logError(_ error: FamilyCreationError, 
                        context: ErrorContext,
                        additionalInfo: [String: Any] = [:]) {
        let logLevel = determineLogLevel(for: error)
        let logMessage = formatLogMessage(error: error, context: context, additionalInfo: additionalInfo)
        
        switch logLevel {
        case .debug:
            print("🐛 DEBUG: \(logMessage)")
        case .info:
            print("ℹ️ INFO: \(logMessage)")
        case .warning:
            print("⚠️ WARNING: \(logMessage)")
        case .error:
            print("❌ ERROR: \(logMessage)")
        case .critical:
            print("🚨 CRITICAL: \(logMessage)")
        }
        
        // Send to crash reporting service if critical
        if logLevel == .critical {
            reportCriticalError(error, context: context, additionalInfo: additionalInfo)
        }
    }
    
    /// Determines appropriate log level for an error
    private static func determineLogLevel(for error: FamilyCreationError) -> LogLevel {
        switch error.priority {
        case .low:
            return .info
        case .medium:
            return .warning
        case .high:
            switch error.category {
            case .system, .authentication:
                return .critical
            default:
                return .error
            }
        }
    }
    
    /// Formats error message for logging
    private static func formatLogMessage(error: FamilyCreationError, 
                                       context: ErrorContext,
                                       additionalInfo: [String: Any]) -> String {
        var components: [String] = []
        
        components.append("Category: \(error.category.rawValue)")
        components.append("Priority: \(error.priority)")
        components.append("Retryable: \(error.isRetryable)")
        components.append("Description: \(error.technicalDescription)")
        
        if context.retryCount > 0 {
            components.append("Retry Count: \(context.retryCount)")
        }
        
        if !additionalInfo.isEmpty {
            let additionalString = additionalInfo.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
            components.append("Additional Info: \(additionalString)")
        }
        
        return components.joined(separator: " | ")
    }
    
    /// Reports critical errors to external service
    private static func reportCriticalError(_ error: FamilyCreationError, 
                                          context: ErrorContext,
                                          additionalInfo: [String: Any]) {
        // Implementation would depend on crash reporting service (e.g., Crashlytics, Sentry)
        print("🚨 CRITICAL ERROR REPORTED: \(error.technicalDescription)")
    }
}

// MARK: - Supporting Types

/// Context information for error handling decisions
struct ErrorContext {
    let retryCount: Int
    let errorCategory: ErrorCategory
    let errorPriority: ErrorPriority
    let isRetryable: Bool
    let timestamp: Date
    let userContext: [String: Any]
    
    init(error: FamilyCreationError, 
         retryCount: Int = 0, 
         userContext: [String: Any] = [:]) {
        self.retryCount = retryCount
        self.errorCategory = error.category
        self.errorPriority = error.priority
        self.isRetryable = error.isRetryable
        self.timestamp = Date()
        self.userContext = userContext
    }
}

/// Recovery actions that can be taken
enum ErrorRecoveryAction {
    case retry(delay: TimeInterval, maxAttempts: Int, strategy: RetryStrategy)
    case fallbackToLocal(message: String, allowContinue: Bool)
    case requireUserAction(message: String, actions: [UserAction])
    case abort(message: String, allowRetry: Bool)
}

/// Retry strategies
enum RetryStrategy {
    case immediate
    case linearBackoff
    case exponentialBackoff
}

/// User actions available for error recovery
enum UserAction {
    case dismiss
    case retry
    case signIn
    case checkConnection
    case workOffline
    case manageStorage
    case checkiCloudSettings
    case editInput
    
    var title: String {
        switch self {
        case .dismiss:
            return "Dismiss"
        case .retry:
            return "Try Again"
        case .signIn:
            return "Sign In"
        case .checkConnection:
            return "Check Connection"
        case .workOffline:
            return "Work Offline"
        case .manageStorage:
            return "Manage Storage"
        case .checkiCloudSettings:
            return "Check iCloud Settings"
        case .editInput:
            return "Edit Input"
        }
    }
}

/// Error patterns for analysis
struct ErrorPattern {
    let type: ErrorPatternType
    let frequency: Int
    let recommendation: ErrorRecommendation
}

enum ErrorPatternType {
    case none
    case sporadic
    case repeatedNetworkFailure
    case repeatedCloudKitFailure
    case repeatedValidationFailure
}

enum ErrorRecommendation {
    case none
    case monitor
    case checkConnectivity
    case fallbackToLocal
    case reviewInput
}

/// Log levels for error reporting
enum LogLevel {
    case debug
    case info
    case warning
    case error
    case critical
}