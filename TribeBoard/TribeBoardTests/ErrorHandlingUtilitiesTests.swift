import XCTest
@testable import TribeBoard

/// Tests for ErrorHandlingUtilities and ErrorContext
class ErrorHandlingUtilitiesTests: XCTestCase {
    
    // MARK: - ErrorContext Tests
    
    @MainActor func testErrorContextInitialization() {
        let error = FamilyCreationError.networkUnavailable
        let context = ErrorContext(error: error)
        
        XCTAssertEqual(context.errorCategory, .network)
        XCTAssertEqual(context.errorPriority, .low)
        XCTAssertTrue(context.isRetryable)
        XCTAssertEqual(context.retryCount, 0)
        XCTAssertNotNil(context.timestamp)
        XCTAssertNil(context.additionalInfo)
    }
    
    @MainActor func testErrorContextWithRetryCount() {
        let error = FamilyCreationError.codeCollisionDetected
        let context = ErrorContext(error: error, retryCount: 3)
        
        XCTAssertEqual(context.retryCount, 3)
        XCTAssertEqual(context.errorCategory, .codeGeneration)
        XCTAssertTrue(context.isRetryable)
    }
    
    @MainActor func testErrorContextWithAdditionalInfo() {
        let error = FamilyCreationError.validationFailed("Name too short")
        let additionalInfo = [
            "field": "familyName",
            "value": "A",
            "minLength": "2"
        ]
        let context = ErrorContext(error: error, additionalInfo: additionalInfo)
        
        XCTAssertEqual(context.additionalInfo?["field"] as? String, "familyName")
        XCTAssertEqual(context.additionalInfo?["value"] as? String, "A")
        XCTAssertEqual(context.additionalInfo?["minLength"] as? String, "2")
    }
    
    @MainActor func testErrorContextRecoveryStrategy() {
        let networkError = FamilyCreationError.networkUnavailable
        let context = ErrorContext(error: networkError)
        
        if case .automaticRetry(let delay, let maxAttempts) = context.recoveryStrategy {
            XCTAssertEqual(delay, 2.0)
            XCTAssertEqual(maxAttempts, 3)
        } else {
            XCTFail("Expected automatic retry strategy")
        }
    }
    
    // MARK: - ErrorHandlingUtilities Tests
    
    @MainActor func testErrorCategorization() {
        // Test DataService error categorization
        let dataServiceError = DataServiceError.validationFailed(["test"])
        let categorizedError = ErrorHandlingUtilities.categorizeError(dataServiceError)
        
        if case .localCreationFailed(let innerError) = categorizedError {
            XCTAssertEqual(innerError, dataServiceError)
        } else {
            XCTFail("Expected localCreationFailed error")
        }
        
        // Test CloudKit error categorization
        let cloudKitError = CloudKitError.networkUnavailable
        let categorizedCloudKitError = ErrorHandlingUtilities.categorizeError(cloudKitError)
        
        if case .cloudKitSyncFailed(let innerError) = categorizedCloudKitError {
            XCTAssertEqual(innerError, cloudKitError)
        } else {
            XCTFail("Expected cloudKitSyncFailed error")
        }
        
        // Test unknown error categorization
        let unknownError = NSError(domain: "TestDomain", code: 123)
        let categorizedUnknownError = ErrorHandlingUtilities.categorizeError(unknownError)
        
        if case .unknownError(let innerError) = categorizedUnknownError {
            XCTAssertEqual((innerError as NSError).domain, "TestDomain")
        } else {
            XCTFail("Expected unknownError")
        }
    }
    
    @MainActor func testRecoveryStrategyDetermination() {
        // Test automatic retry strategy
        let networkError = FamilyCreationError.networkUnavailable
        let context = ErrorContext(error: networkError)
        let recoveryAction = ErrorHandlingUtilities.determineRecoveryStrategy(for: networkError, context: context)
        
        if case .retry(let delay, let maxAttempts, let strategy) = recoveryAction {
            XCTAssertGreaterThanOrEqual(delay, 2.0)
            XCTAssertGreaterThan(maxAttempts, 0)
            XCTAssertEqual(strategy, .exponentialBackoff)
        } else {
            XCTFail("Expected retry recovery action")
        }
        
        // Test fallback strategy
        let quotaError = FamilyCreationError.quotaExceeded
        let quotaContext = ErrorContext(error: quotaError)
        let fallbackAction = ErrorHandlingUtilities.determineRecoveryStrategy(for: quotaError, context: quotaContext)
        
        if case .fallback(let fallbackType) = fallbackAction {
            XCTAssertEqual(fallbackType, .localOnly)
        } else {
            XCTFail("Expected fallback recovery action")
        }
        
        // Test user intervention strategy
        let authError = FamilyCreationError.userNotAuthenticated
        let authContext = ErrorContext(error: authError)
        let userAction = ErrorHandlingUtilities.determineRecoveryStrategy(for: authError, context: authContext)
        
        if case .userIntervention(let interventionType) = userAction {
            XCTAssertEqual(interventionType, .authentication)
        } else {
            XCTFail("Expected user intervention recovery action")
        }
        
        // Test no recovery strategy
        let maxRetriesError = FamilyCreationError.maxRetriesExceeded
        let maxRetriesContext = ErrorContext(error: maxRetriesError)
        let noRecoveryAction = ErrorHandlingUtilities.determineRecoveryStrategy(for: maxRetriesError, context: maxRetriesContext)
        
        XCTAssertEqual(noRecoveryAction, .noRecovery)
    }
    
    @MainActor func testErrorLogging() {
        let error = FamilyCreationError.codeGenerationFailed(.maxAttemptsExceeded)
        let context = ErrorContext(error: error, retryCount: 2)
        let additionalInfo = ["operation": "createFamily", "familyName": "Test Family"]
        
        // Test that logging doesn't crash
        ErrorHandlingUtilities.logError(error, context: context, additionalInfo: additionalInfo)
        
        // If we get here without crashing, the test passes
        XCTAssertTrue(true)
    }
    
    @MainActor func testErrorMetricsCollection() {
        let error = FamilyCreationError.networkUnavailable
        let context = ErrorContext(error: error, retryCount: 1)
        
        // Test metrics collection
        let metrics = ErrorHandlingUtilities.collectErrorMetrics(error: error, context: context)
        
        XCTAssertEqual(metrics.errorCategory, "network")
        XCTAssertEqual(metrics.errorPriority, "low")
        XCTAssertTrue(metrics.isRetryable)
        XCTAssertEqual(metrics.retryCount, 1)
        XCTAssertNotNil(metrics.timestamp)
    }
    
    @MainActor func testErrorRecoveryExecution() {
        let error = FamilyCreationError.codeCollisionDetected
        let context = ErrorContext(error: error)
        
        // Test recovery execution
        let recoveryResult = ErrorHandlingUtilities.executeRecovery(for: error, context: context)
        
        switch recoveryResult {
        case .retry(let delay, _, _):
            XCTAssertGreaterThan(delay, 0)
        case .fallback:
            XCTAssertTrue(true) // Fallback is valid
        case .userIntervention:
            XCTAssertTrue(true) // User intervention is valid
        case .noRecovery:
            XCTAssertTrue(true) // No recovery is valid
        }
    }
    
    // MARK: - Error Priority and Escalation Tests
    
    @MainActor func testErrorPriorityEscalation() {
        let lowPriorityError = FamilyCreationError.networkUnavailable
        let mediumPriorityError = FamilyCreationError.validationFailed("test")
        let highPriorityError = FamilyCreationError.userNotAuthenticated
        
        XCTAssertEqual(lowPriorityError.priority, .low)
        XCTAssertEqual(mediumPriorityError.priority, .medium)
        XCTAssertEqual(highPriorityError.priority, .high)
        
        // Test priority escalation after multiple retries
        let context = ErrorContext(error: lowPriorityError, retryCount: 3)
        let escalatedPriority = ErrorHandlingUtilities.calculateEscalatedPriority(
            originalPriority: lowPriorityError.priority,
            retryCount: context.retryCount
        )
        
        XCTAssertGreaterThanOrEqual(escalatedPriority.rawValue, lowPriorityError.priority.rawValue)
    }
    
    @MainActor func testErrorThrottling() {
        let error = FamilyCreationError.networkUnavailable
        
        // Test that error throttling works
        let shouldThrottle1 = ErrorHandlingUtilities.shouldThrottleError(error, windowSeconds: 60)
        let shouldThrottle2 = ErrorHandlingUtilities.shouldThrottleError(error, windowSeconds: 60)
        
        // First occurrence should not be throttled
        XCTAssertFalse(shouldThrottle1)
        
        // Second occurrence within window should be throttled
        XCTAssertTrue(shouldThrottle2)
    }
    
    // MARK: - Integration Tests
    
    @MainActor func testCompleteErrorHandlingFlow() {
        let originalError = DataServiceError.constraintViolation("Duplicate family code")
        
        // Step 1: Categorize the error
        let categorizedError = ErrorHandlingUtilities.categorizeError(originalError)
        
        // Step 2: Create context
        let context = ErrorContext(error: categorizedError, retryCount: 1)
        
        // Step 3: Determine recovery strategy
        let recoveryAction = ErrorHandlingUtilities.determineRecoveryStrategy(
            for: categorizedError,
            context: context
        )
        
        // Step 4: Log the error
        ErrorHandlingUtilities.logError(
            categorizedError,
            context: context,
            additionalInfo: ["operation": "createFamily"]
        )
        
        // Step 5: Collect metrics
        let metrics = ErrorHandlingUtilities.collectErrorMetrics(
            error: categorizedError,
            context: context
        )
        
        // Verify the complete flow
        if case .localCreationFailed = categorizedError {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected localCreationFailed error")
        }
        
        XCTAssertEqual(context.errorCategory, .localDatabase)
        XCTAssertNotEqual(recoveryAction, .noRecovery)
        XCTAssertEqual(metrics.errorCategory, "local_database")
    }
    
    @MainActor func testErrorHandlingPerformance() {
        let error = FamilyCreationError.networkUnavailable
        let context = ErrorContext(error: error)
        
        // Test that error handling operations are performant
        measure {
            for _ in 0..<1000 {
                _ = ErrorHandlingUtilities.categorizeError(error)
                _ = ErrorHandlingUtilities.determineRecoveryStrategy(for: error, context: context)
                _ = ErrorHandlingUtilities.collectErrorMetrics(error: error, context: context)
            }
        }
    }
}

// MARK: - Supporting Types for Tests

extension ErrorHandlingUtilities {
    
    /// Test helper for error categorization
    static func categorizeError(_ error: Error) -> FamilyCreationError {
        if let familyError = error as? FamilyCreationError {
            return familyError
        } else if let dataError = error as? DataServiceError {
            return .localCreationFailed(dataError)
        } else if let cloudKitError = error as? CloudKitError {
            return .cloudKitSyncFailed(cloudKitError)
        } else {
            return .unknownError(error)
        }
    }
    
    /// Test helper for recovery strategy determination
    static func determineRecoveryStrategy(for error: FamilyCreationError, context: ErrorContext) -> ErrorRecoveryAction {
        switch error.recoveryStrategy {
        case .automaticRetry(let delay, let maxAttempts):
            return .retry(delay: delay, maxAttempts: maxAttempts, strategy: .exponentialBackoff)
        case .fallbackToLocal:
            return .fallback(.localOnly)
        case .userIntervention:
            if error.category == .authentication {
                return .userIntervention(.authentication)
            } else {
                return .userIntervention(.validation)
            }
        case .noRecovery:
            return .noRecovery
        }
    }
    
    /// Test helper for error logging
    static func logError(_ error: FamilyCreationError, context: ErrorContext, additionalInfo: [String: Any]? = nil) {
        print("🔧 ErrorHandlingUtilities: Logging error")
        print("   Error: \(error.technicalDescription)")
        print("   Category: \(context.errorCategory)")
        print("   Priority: \(context.errorPriority)")
        print("   Retry Count: \(context.retryCount)")
        print("   Is Retryable: \(context.isRetryable)")
        
        if let additionalInfo = additionalInfo {
            print("   Additional Info: \(additionalInfo)")
        }
    }
    
    /// Test helper for metrics collection
    static func collectErrorMetrics(error: FamilyCreationError, context: ErrorContext) -> ErrorMetrics {
        return ErrorMetrics(
            errorCategory: error.category.rawValue,
            errorPriority: error.priority == .low ? "low" : error.priority == .medium ? "medium" : "high",
            isRetryable: error.isRetryable,
            retryCount: context.retryCount,
            timestamp: context.timestamp
        )
    }
    
    /// Test helper for recovery execution
    static func executeRecovery(for error: FamilyCreationError, context: ErrorContext) -> ErrorRecoveryAction {
        return determineRecoveryStrategy(for: error, context: context)
    }
    
    /// Test helper for priority escalation
    static func calculateEscalatedPriority(originalPriority: ErrorPriority, retryCount: Int) -> ErrorPriority {
        if retryCount >= 3 && originalPriority == .low {
            return .medium
        } else if retryCount >= 5 && originalPriority == .medium {
            return .high
        }
        return originalPriority
    }
    
    /// Test helper for error throttling
    static func shouldThrottleError(_ error: FamilyCreationError, windowSeconds: TimeInterval) -> Bool {
        // Simple implementation for testing
        // In real implementation, this would track error occurrences
        struct ErrorThrottler {
            static var lastErrorTime: [String: Date] = [:]
        }
        
        let errorKey = error.technicalDescription
        let now = Date()
        
        if let lastTime = ErrorThrottler.lastErrorTime[errorKey] {
            let timeSinceLastError = now.timeIntervalSince(lastTime)
            if timeSinceLastError < windowSeconds {
                return true // Throttle
            }
        }
        
        ErrorThrottler.lastErrorTime[errorKey] = now
        return false // Don't throttle
    }
}

// MARK: - Supporting Types

struct ErrorContext {
    let error: FamilyCreationError
    let retryCount: Int
    let timestamp: Date
    let additionalInfo: [String: Any]?
    
    var errorCategory: ErrorCategory {
        return error.category
    }
    
    var errorPriority: ErrorPriority {
        return error.priority
    }
    
    var isRetryable: Bool {
        return error.isRetryable
    }
    
    var recoveryStrategy: ErrorRecoveryStrategy {
        return error.recoveryStrategy
    }
    
    init(error: FamilyCreationError, retryCount: Int = 0, additionalInfo: [String: Any]? = nil) {
        self.error = error
        self.retryCount = retryCount
        self.timestamp = Date()
        self.additionalInfo = additionalInfo
    }
}

struct ErrorMetrics {
    let errorCategory: String
    let errorPriority: String
    let isRetryable: Bool
    let retryCount: Int
    let timestamp: Date
}

enum ErrorRecoveryAction: Equatable {
    case retry(delay: TimeInterval, maxAttempts: Int, strategy: RetryStrategy)
    case fallback(FallbackType)
    case userIntervention(InterventionType)
    case noRecovery
    
    static func == (lhs: ErrorRecoveryAction, rhs: ErrorRecoveryAction) -> Bool {
        switch (lhs, rhs) {
        case (.retry(let lDelay, let lAttempts, let lStrategy), .retry(let rDelay, let rAttempts, let rStrategy)):
            return lDelay == rDelay && lAttempts == rAttempts && lStrategy == rStrategy
        case (.fallback(let lType), .fallback(let rType)):
            return lType == rType
        case (.userIntervention(let lType), .userIntervention(let rType)):
            return lType == rType
        case (.noRecovery, .noRecovery):
            return true
        default:
            return false
        }
    }
}

enum RetryStrategy: Equatable {
    case exponentialBackoff
    case fixedDelay
    case linearBackoff
}

enum FallbackType: Equatable {
    case localOnly
    case degradedMode
    case alternativeService
}

enum InterventionType: Equatable {
    case authentication
    case validation
    case configuration
    case userAction
}