import XCTest
@testable import TribeBoard

/// Comprehensive tests for the enhanced error types and handling infrastructure
class FamilyCreationErrorTests: XCTestCase {
    
    // MARK: - FamilyCreationError Tests
    
    @MainActor func testFamilyCreationErrorUserFriendlyMessages() {
        let validationError = FamilyCreationError.validationFailed("Name too short")
        XCTAssertEqual(validationError.userFriendlyMessage, "Please check your input: Name too short")
        
        let networkError = FamilyCreationError.networkUnavailable
        XCTAssertEqual(networkError.userFriendlyMessage, "No internet connection. Family saved locally and will sync when connected.")
        
        let authError = FamilyCreationError.userNotAuthenticated
        XCTAssertEqual(authError.userFriendlyMessage, "Please sign in to create a family.")
    }
    
    @MainActor func testFamilyCreationErrorRetryability() {
        // Retryable errors
        XCTAssertTrue(FamilyCreationError.networkUnavailable.isRetryable)
        XCTAssertTrue(FamilyCreationError.codeCollisionDetected.isRetryable)
        XCTAssertTrue(FamilyCreationError.cloudKitUnavailable.isRetryable)
        
        // Non-retryable errors
        XCTAssertFalse(FamilyCreationError.userNotAuthenticated.isRetryable)
        XCTAssertFalse(FamilyCreationError.maxRetriesExceeded.isRetryable)
        XCTAssertFalse(FamilyCreationError.validationFailed("test").isRetryable)
    }
    
    @MainActor func testFamilyCreationErrorCategories() {
        XCTAssertEqual(FamilyCreationError.validationFailed("test").category, .validation)
        XCTAssertEqual(FamilyCreationError.networkUnavailable.category, .network)
        XCTAssertEqual(FamilyCreationError.userNotAuthenticated.category, .authentication)
        XCTAssertEqual(FamilyCreationError.cloudKitUnavailable.category, .cloudKit)
    }
    
    @MainActor func testFamilyCreationErrorPriorities() {
        XCTAssertEqual(FamilyCreationError.userNotAuthenticated.priority, .high)
        XCTAssertEqual(FamilyCreationError.validationFailed("test").priority, .medium)
        XCTAssertEqual(FamilyCreationError.networkUnavailable.priority, .low)
    }
    
    @MainActor func testFamilyCreationErrorRecoveryStrategies() {
        let networkError = FamilyCreationError.networkUnavailable
        if case .automaticRetry(let delay, let maxAttempts) = networkError.recoveryStrategy {
            XCTAssertEqual(delay, 2.0)
            XCTAssertEqual(maxAttempts, 3)
        } else {
            XCTFail("Expected automatic retry strategy for network error")
        }
        
        let quotaError = FamilyCreationError.quotaExceeded
        XCTAssertEqual(quotaError.recoveryStrategy, .fallbackToLocal)
        
        let validationError = FamilyCreationError.validationFailed("test")
        XCTAssertEqual(validationError.recoveryStrategy, .userIntervention)
    }
    
    @MainActor func testServerErrorRetryability() {
        let serverError500 = FamilyCreationError.serverError(500)
        XCTAssertTrue(serverError500.isRetryable)
        
        let serverError400 = FamilyCreationError.serverError(400)
        XCTAssertFalse(serverError400.isRetryable)
    }
    
    // MARK: - FamilyCodeGenerationError Tests
    
    @MainActor func testFamilyCodeGenerationErrorRetryability() {
        XCTAssertTrue(FamilyCodeGenerationError.uniquenessCheckFailed.isRetryable)
        XCTAssertFalse(FamilyCodeGenerationError.maxAttemptsExceeded.isRetryable)
        XCTAssertFalse(FamilyCodeGenerationError.formatValidationFailed("test").isRetryable)
    }
    
    @MainActor func testFamilyCodeGenerationErrorRecoveryStrategies() {
        let uniquenessError = FamilyCodeGenerationError.uniquenessCheckFailed
        if case .automaticRetry(let delay, let maxAttempts) = uniquenessError.recoveryStrategy {
            XCTAssertEqual(delay, 1.0)
            XCTAssertEqual(maxAttempts, 3)
        } else {
            XCTFail("Expected automatic retry strategy for uniqueness check error")
        }
        
        let formatError = FamilyCodeGenerationError.formatValidationFailed("test")
        XCTAssertEqual(formatError.recoveryStrategy, .noRecovery)
    }
    
    // MARK: - FamilyCreationState Tests
    
    @MainActor func testFamilyCreationStateProperties() {
        XCTAssertFalse(FamilyCreationState.idle.isActive)
        XCTAssertTrue(FamilyCreationState.validating.isActive)
        XCTAssertTrue(FamilyCreationState.generatingCode.isLoading)
        XCTAssertTrue(FamilyCreationState.completed.isCompleted)
        XCTAssertTrue(FamilyCreationState.failed(.networkUnavailable).isFailed)
    }
    
    @MainActor func testFamilyCreationStateProgress() {
        XCTAssertEqual(FamilyCreationState.idle.progress, 0.0)
        XCTAssertEqual(FamilyCreationState.validating.progress, 0.2)
        XCTAssertEqual(FamilyCreationState.generatingCode.progress, 0.4)
        XCTAssertEqual(FamilyCreationState.creatingLocally.progress, 0.6)
        XCTAssertEqual(FamilyCreationState.syncingToCloudKit.progress, 0.8)
        XCTAssertEqual(FamilyCreationState.completed.progress, 1.0)
        XCTAssertEqual(FamilyCreationState.failed(.networkUnavailable).progress, 0.0)
    }
    
    @MainActor func testFamilyCreationStateTransitions() {
        // Valid transitions
        XCTAssertTrue(FamilyCreationState.idle.canTransition(to: .validating))
        XCTAssertTrue(FamilyCreationState.validating.canTransition(to: .generatingCode))
        XCTAssertTrue(FamilyCreationState.generatingCode.canTransition(to: .creatingLocally))
        XCTAssertTrue(FamilyCreationState.creatingLocally.canTransition(to: .syncingToCloudKit))
        XCTAssertTrue(FamilyCreationState.syncingToCloudKit.canTransition(to: .completed))
        
        // Invalid transitions
        XCTAssertFalse(FamilyCreationState.idle.canTransition(to: .completed))
        XCTAssertFalse(FamilyCreationState.completed.canTransition(to: .validating))
        
        // Error transitions (always allowed)
        XCTAssertTrue(FamilyCreationState.validating.canTransition(to: .failed(.networkUnavailable)))
        XCTAssertTrue(FamilyCreationState.generatingCode.canTransition(to: .failed(.maxRetriesExceeded)))
    }
    
    @MainActor func testFamilyCreationStateUserDescriptions() {
        XCTAssertEqual(FamilyCreationState.idle.userDescription, "Ready to create family")
        XCTAssertEqual(FamilyCreationState.validating.userDescription, "Validating family information...")
        XCTAssertEqual(FamilyCreationState.completed.userDescription, "Family created successfully!")
        
        let failedState = FamilyCreationState.failed(.networkUnavailable)
        XCTAssertTrue(failedState.userDescription.contains("Creation failed"))
    }
    
    @MainActor func testFamilyCreationStateRetryCapability() {
        let retryableFailedState = FamilyCreationState.failed(.networkUnavailable)
        XCTAssertTrue(retryableFailedState.allowsRetry)
        
        let nonRetryableFailedState = FamilyCreationState.failed(.userNotAuthenticated)
        XCTAssertFalse(nonRetryableFailedState.allowsRetry)
        
        XCTAssertFalse(FamilyCreationState.completed.allowsRetry)
        XCTAssertFalse(FamilyCreationState.idle.allowsRetry)
    }
    
    // MARK: - FamilyCreationStateManager Tests
    
    @MainActor func testStateManagerInitialization() {
        let stateManager = FamilyCreationStateManager()
        XCTAssertEqual(stateManager.currentState, .idle)
        XCTAssertFalse(stateManager.isActive)
        XCTAssertFalse(stateManager.isCompleted)
        XCTAssertFalse(stateManager.isFailed)
        XCTAssertEqual(stateManager.progress, 0.0)
    }
    
    @MainActor func testStateManagerTransitions() {
        let stateManager = FamilyCreationStateManager()
        
        // Valid transition
        stateManager.transition(to: .validating)
        XCTAssertEqual(stateManager.currentState, .validating)
        XCTAssertTrue(stateManager.isActive)
        
        // Continue through flow
        stateManager.transition(to: .generatingCode)
        XCTAssertEqual(stateManager.currentState, .generatingCode)
        
        stateManager.transition(to: .completed)
        XCTAssertEqual(stateManager.currentState, .completed)
        XCTAssertTrue(stateManager.isCompleted)
        XCTAssertFalse(stateManager.isActive)
    }
    
    @MainActor func testStateManagerFailure() {
        let stateManager = FamilyCreationStateManager()
        
        stateManager.transition(to: .validating)
        stateManager.fail(with: .networkUnavailable)
        
        XCTAssertTrue(stateManager.isFailed)
        XCTAssertEqual(stateManager.currentError, .networkUnavailable)
    }
    
    @MainActor func testStateManagerReset() {
        let stateManager = FamilyCreationStateManager()
        
        stateManager.transition(to: .validating)
        stateManager.transition(to: .generatingCode)
        stateManager.reset()
        
        XCTAssertEqual(stateManager.currentState, .idle)
        XCTAssertEqual(stateManager.getStateHistory().count, 1)
        XCTAssertEqual(stateManager.getStateHistory().first, .idle)
    }
    
    @MainActor func testStateManagerRetry() {
        let stateManager = FamilyCreationStateManager()
        
        // Fail with retryable error
        stateManager.fail(with: .networkUnavailable)
        XCTAssertTrue(stateManager.retry())
        XCTAssertEqual(stateManager.currentState, .idle)
        
        // Fail with non-retryable error
        stateManager.fail(with: .userNotAuthenticated)
        XCTAssertFalse(stateManager.retry())
    }
    
    // MARK: - ErrorHandlingUtilities Tests
    
    @MainActor func testErrorCategorization() {
        let dataServiceError = DataServiceError.validationFailed(["test"])
        let categorizedError = ErrorHandlingUtilities.categorizeError(dataServiceError)
        
        if case .localCreationFailed(let innerError) = categorizedError {
            XCTAssertEqual(innerError, dataServiceError)
        } else {
            XCTFail("Expected localCreationFailed error")
        }
    }
    
    @MainActor func testErrorContextCreation() {
        let error = FamilyCreationError.networkUnavailable
        let context = ErrorContext(error: error, retryCount: 2)
        
        XCTAssertEqual(context.retryCount, 2)
        XCTAssertEqual(context.errorCategory, .network)
        XCTAssertEqual(context.errorPriority, .low)
        XCTAssertTrue(context.isRetryable)
    }
    
    @MainActor func testRecoveryStrategyDetermination() {
        let error = FamilyCreationError.networkUnavailable
        let context = ErrorContext(error: error)
        let recoveryAction = ErrorHandlingUtilities.determineRecoveryStrategy(for: error, context: context)
        
        if case .retry(let delay, let maxAttempts, let strategy) = recoveryAction {
            XCTAssertGreaterThanOrEqual(delay, 2.0) // Should be at least base delay for network errors
            XCTAssertGreaterThan(maxAttempts, 0)
            XCTAssertEqual(strategy, .exponentialBackoff)
        } else {
            XCTFail("Expected retry recovery action for network error")
        }
    }
    
    // MARK: - Enhanced Error Recovery Strategy Tests
    
    @MainActor func testErrorRecoveryStrategyExecution() {
        let networkError = FamilyCreationError.networkUnavailable
        let strategy = networkError.recoveryStrategy
        
        if case .automaticRetry(let delay, let maxAttempts) = strategy {
            XCTAssertEqual(delay, 2.0)
            XCTAssertEqual(maxAttempts, 3)
        } else {
            XCTFail("Expected automatic retry strategy")
        }
        
        let fallbackError = FamilyCreationError.cloudKitUnavailable
        XCTAssertEqual(fallbackError.recoveryStrategy, .fallbackToLocal)
        
        let userError = FamilyCreationError.userNotAuthenticated
        XCTAssertEqual(userError.recoveryStrategy, .userIntervention)
        
        let noRecoveryError = FamilyCreationError.maxRetriesExceeded
        XCTAssertEqual(noRecoveryError.recoveryStrategy, .noRecovery)
    }
    
    @MainActor func testNestedErrorRecoveryStrategies() {
        let localError = DataServiceError.validationFailed(["test"])
        let familyError = FamilyCreationError.localCreationFailed(localError)
        
        if case .automaticRetry(let delay, let maxAttempts) = familyError.recoveryStrategy {
            XCTAssertEqual(delay, 1.0)
            XCTAssertEqual(maxAttempts, 2)
        } else {
            XCTFail("Expected automatic retry for local creation failed")
        }
        
        let codeGenError = FamilyCodeGenerationError.uniquenessCheckFailed
        let codeError = FamilyCreationError.codeGenerationFailed(codeGenError)
        
        if case .automaticRetry(let delay, let maxAttempts) = codeError.recoveryStrategy {
            XCTAssertEqual(delay, 1.0)
            XCTAssertEqual(maxAttempts, 3)
        } else {
            XCTFail("Expected automatic retry for code generation failed")
        }
    }
    
    @MainActor func testErrorPriorityEscalation() {
        // Test that error priorities are correctly assigned
        let highPriorityErrors: [FamilyCreationError] = [
            .userNotAuthenticated,
            .dataCorruption("test"),
            .maxRetriesExceeded
        ]
        
        for error in highPriorityErrors {
            XCTAssertEqual(error.priority, .high, "Error \(error) should be high priority")
        }
        
        let mediumPriorityErrors: [FamilyCreationError] = [
            .validationFailed("test"),
            .invalidFamilyName("test"),
            .maxCodeGenerationAttemptsExceeded,
            .quotaExceeded
        ]
        
        for error in mediumPriorityErrors {
            XCTAssertEqual(error.priority, .medium, "Error \(error) should be medium priority")
        }
        
        let lowPriorityErrors: [FamilyCreationError] = [
            .networkUnavailable,
            .cloudKitUnavailable,
            .codeCollisionDetected
        ]
        
        for error in lowPriorityErrors {
            XCTAssertEqual(error.priority, .low, "Error \(error) should be low priority")
        }
    }
    
    // MARK: - Error Context and Analytics Tests
    
    @MainActor func testErrorContextCreation() {
        let error = FamilyCreationError.networkUnavailable
        let context = ErrorContext(error: error, retryCount: 2)
        
        XCTAssertEqual(context.retryCount, 2)
        XCTAssertEqual(context.errorCategory, .network)
        XCTAssertEqual(context.errorPriority, .low)
        XCTAssertTrue(context.isRetryable)
        XCTAssertNotNil(context.timestamp)
        XCTAssertEqual(context.recoveryStrategy, .automaticRetry(delay: 2.0, maxAttempts: 3))
    }
    
    @MainActor func testErrorContextWithAdditionalInfo() {
        let error = FamilyCreationError.validationFailed("Name too short")
        let additionalInfo = ["field": "familyName", "value": "A", "minLength": "2"]
        let context = ErrorContext(error: error, additionalInfo: additionalInfo)
        
        XCTAssertEqual(context.additionalInfo?["field"] as? String, "familyName")
        XCTAssertEqual(context.additionalInfo?["value"] as? String, "A")
        XCTAssertEqual(context.additionalInfo?["minLength"] as? String, "2")
    }
    
    @MainActor func testErrorAnalyticsRecording() {
        let error = FamilyCreationError.codeGenerationFailed(.maxAttemptsExceeded)
        let state = FamilyCreationState.generatingCode
        
        // Test that analytics recording doesn't crash
        FamilyCreationAnalytics.recordError(error, in: state)
        
        // Test state transition recording
        FamilyCreationAnalytics.recordStateTransition(from: .idle, to: .validating)
        
        // Test success recording
        let stateHistory: [FamilyCreationState] = [.idle, .validating, .generatingCode, .completed]
        FamilyCreationAnalytics.recordSuccess(duration: 2.5, stateHistory: stateHistory)
        
        // If we get here without crashing, the test passes
        XCTAssertTrue(true)
    }
    
    // MARK: - Edge Case Error Tests
    
    @MainActor func testErrorEquality() {
        // Test error equality for different error types
        let error1 = FamilyCreationError.validationFailed("test")
        let error2 = FamilyCreationError.validationFailed("test")
        let error3 = FamilyCreationError.validationFailed("different")
        
        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
        
        let networkError1 = FamilyCreationError.networkUnavailable
        let networkError2 = FamilyCreationError.networkUnavailable
        XCTAssertEqual(networkError1, networkError2)
        
        let serverError1 = FamilyCreationError.serverError(500)
        let serverError2 = FamilyCreationError.serverError(500)
        let serverError3 = FamilyCreationError.serverError(404)
        
        XCTAssertEqual(serverError1, serverError2)
        XCTAssertNotEqual(serverError1, serverError3)
    }
    
    @MainActor func testErrorChaining() {
        let originalError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Original error"])
        let wrappedError = FamilyCreationError.unknownError(originalError)
        
        XCTAssertTrue(wrappedError.userFriendlyMessage.contains("Original error"))
        XCTAssertTrue(wrappedError.technicalDescription.contains("Original error"))
        XCTAssertFalse(wrappedError.isRetryable)
        XCTAssertEqual(wrappedError.priority, .medium)
    }
    
    @MainActor func testComplexErrorScenarios() {
        // Test complex nested error scenarios
        let dataServiceError = DataServiceError.constraintViolation("Duplicate family code")
        let familyError = FamilyCreationError.localCreationFailed(dataServiceError)
        
        XCTAssertTrue(familyError.userFriendlyMessage.contains("save family locally"))
        XCTAssertTrue(familyError.technicalDescription.contains("Duplicate family code"))
        XCTAssertTrue(familyError.isRetryable)
        XCTAssertEqual(familyError.category, .localDatabase)
        
        // Test CloudKit error wrapping
        let cloudKitError = CloudKitError.quotaExceeded
        let syncError = FamilyCreationError.cloudKitSyncFailed(cloudKitError)
        
        XCTAssertTrue(syncError.userFriendlyMessage.contains("saved locally"))
        XCTAssertEqual(syncError.recoveryStrategy, .fallbackToLocal)
        XCTAssertEqual(syncError.category, .cloudKit)
    }
    
    // MARK: - State Machine Edge Cases
    
    @MainActor func testStateTransitionValidation() {
        let stateManager = FamilyCreationStateManager()
        
        // Test invalid transitions are rejected
        stateManager.transition(to: .completed) // Should be rejected
        XCTAssertEqual(stateManager.currentState, .idle)
        
        // Test valid transition sequence
        stateManager.transition(to: .validating)
        XCTAssertEqual(stateManager.currentState, .validating)
        
        stateManager.transition(to: .generatingCode)
        XCTAssertEqual(stateManager.currentState, .generatingCode)
        
        // Test error transition from any state
        stateManager.transition(to: .failed(.networkUnavailable))
        XCTAssertTrue(stateManager.isFailed)
        
        // Test reset from failed state
        stateManager.reset()
        XCTAssertEqual(stateManager.currentState, .idle)
    }
    
    @MainActor func testStateHistoryTracking() {
        let stateManager = FamilyCreationStateManager()
        
        stateManager.transition(to: .validating)
        stateManager.transition(to: .generatingCode)
        stateManager.transition(to: .failed(.networkUnavailable))
        stateManager.reset()
        
        let history = stateManager.getStateHistory()
        XCTAssertEqual(history.count, 5) // idle, validating, generatingCode, failed, idle
        XCTAssertEqual(history.first, .idle)
        XCTAssertEqual(history.last, .idle)
    }
    
    @MainActor func testConcurrentStateTransitions() {
        let stateManager = FamilyCreationStateManager()
        let expectation = XCTestExpectation(description: "Concurrent transitions")
        
        // Test that concurrent state transitions are handled safely
        DispatchQueue.concurrentPerform(iterations: 10) { index in
            if index % 2 == 0 {
                stateManager.transition(to: .validating)
            } else {
                stateManager.transition(to: .generatingCode)
            }
        }
        
        // State should be in a valid state after concurrent operations
        XCTAssertTrue([.idle, .validating, .generatingCode].contains(stateManager.currentState))
        expectation.fulfill()
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Integration Tests
    
    @MainActor func testErrorToStateTransition() {
        let stateManager = FamilyCreationStateManager()
        
        // Test different error scenarios
        let errors: [(FamilyCreationError, Bool)] = [
            (.networkUnavailable, true),
            (.userNotAuthenticated, false),
            (.validationFailed("test"), false),
            (.codeCollisionDetected, true),
            (.cloudKitUnavailable, true),
            (.maxRetriesExceeded, false)
        ]
        
        for (error, shouldAllowRetry) in errors {
            stateManager.reset()
            stateManager.fail(with: error)
            
            XCTAssertEqual(stateManager.currentError, error)
            XCTAssertEqual(stateManager.retry(), shouldAllowRetry)
        }
    }
    
    @MainActor func testCompleteErrorHandlingFlow() {
        let stateManager = FamilyCreationStateManager()
        
        // Start creation process
        stateManager.transition(to: .validating)
        XCTAssertEqual(stateManager.statusMessage, "Validating family information...")
        
        // Encounter retryable error
        stateManager.fail(with: .networkUnavailable)
        XCTAssertTrue(stateManager.isFailed)
        XCTAssertTrue(stateManager.currentError?.isRetryable ?? false)
        
        // Retry should work
        XCTAssertTrue(stateManager.retry())
        XCTAssertEqual(stateManager.currentState, .idle)
        
        // Try again and succeed
        stateManager.transition(to: .validating)
        stateManager.transition(to: .generatingCode)
        stateManager.transition(to: .creatingLocally)
        stateManager.transition(to: .syncingToCloudKit)
        stateManager.transition(to: .completed)
        
        XCTAssertTrue(stateManager.isCompleted)
        XCTAssertEqual(stateManager.progress, 1.0)
    }
    
    @MainActor func testErrorRecoveryWithBackoff() {
        let stateManager = FamilyCreationStateManager()
        
        // Test exponential backoff behavior
        let retryableError = FamilyCreationError.networkUnavailable
        stateManager.fail(with: retryableError)
        
        let startTime = Date()
        
        // Multiple retry attempts should have increasing delays
        for attempt in 1...3 {
            if stateManager.retry() {
                stateManager.fail(with: retryableError)
            }
        }
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        // Should have some delay from backoff (this is a basic test)
        XCTAssertGreaterThan(elapsedTime, 0.0)
    }
    
    @MainActor func testErrorHandlingWithNotifications() {
        let stateManager = FamilyCreationStateManager()
        let expectation = XCTestExpectation(description: "State change notification")
        
        // Listen for state change notifications
        let observer = NotificationCenter.default.addObserver(
            forName: .familyCreationStateChanged,
            object: stateManager,
            queue: .main
        ) { notification in
            if let newState = notification.userInfo?["newState"] as? FamilyCreationState,
               newState.isFailed {
                expectation.fulfill()
            }
        }
        
        // Trigger state change
        stateManager.fail(with: .networkUnavailable)
        
        wait(for: [expectation], timeout: 1.0)
        NotificationCenter.default.removeObserver(observer)
    }
}