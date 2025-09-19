import XCTest
@testable import TribeBoard

/// Tests for the enhanced error types and handling infrastructure
class FamilyCreationErrorTests: XCTestCase {
    
    // MARK: - FamilyCreationError Tests
    
    func testFamilyCreationErrorUserFriendlyMessages() {
        let validationError = FamilyCreationError.validationFailed("Name too short")
        XCTAssertEqual(validationError.userFriendlyMessage, "Please check your input: Name too short")
        
        let networkError = FamilyCreationError.networkUnavailable
        XCTAssertEqual(networkError.userFriendlyMessage, "No internet connection. Family saved locally and will sync when connected.")
        
        let authError = FamilyCreationError.userNotAuthenticated
        XCTAssertEqual(authError.userFriendlyMessage, "Please sign in to create a family.")
    }
    
    func testFamilyCreationErrorRetryability() {
        // Retryable errors
        XCTAssertTrue(FamilyCreationError.networkUnavailable.isRetryable)
        XCTAssertTrue(FamilyCreationError.codeCollisionDetected.isRetryable)
        XCTAssertTrue(FamilyCreationError.cloudKitUnavailable.isRetryable)
        
        // Non-retryable errors
        XCTAssertFalse(FamilyCreationError.userNotAuthenticated.isRetryable)
        XCTAssertFalse(FamilyCreationError.maxRetriesExceeded.isRetryable)
        XCTAssertFalse(FamilyCreationError.validationFailed("test").isRetryable)
    }
    
    func testFamilyCreationErrorCategories() {
        XCTAssertEqual(FamilyCreationError.validationFailed("test").category, .validation)
        XCTAssertEqual(FamilyCreationError.networkUnavailable.category, .network)
        XCTAssertEqual(FamilyCreationError.userNotAuthenticated.category, .authentication)
        XCTAssertEqual(FamilyCreationError.cloudKitUnavailable.category, .cloudKit)
    }
    
    func testFamilyCreationErrorPriorities() {
        XCTAssertEqual(FamilyCreationError.userNotAuthenticated.priority, .high)
        XCTAssertEqual(FamilyCreationError.validationFailed("test").priority, .medium)
        XCTAssertEqual(FamilyCreationError.networkUnavailable.priority, .low)
    }
    
    func testFamilyCreationErrorRecoveryStrategies() {
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
    
    func testServerErrorRetryability() {
        let serverError500 = FamilyCreationError.serverError(500)
        XCTAssertTrue(serverError500.isRetryable)
        
        let serverError400 = FamilyCreationError.serverError(400)
        XCTAssertFalse(serverError400.isRetryable)
    }
    
    // MARK: - FamilyCodeGenerationError Tests
    
    func testFamilyCodeGenerationErrorRetryability() {
        XCTAssertTrue(FamilyCodeGenerationError.uniquenessCheckFailed.isRetryable)
        XCTAssertFalse(FamilyCodeGenerationError.maxAttemptsExceeded.isRetryable)
        XCTAssertFalse(FamilyCodeGenerationError.formatValidationFailed("test").isRetryable)
    }
    
    func testFamilyCodeGenerationErrorRecoveryStrategies() {
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
    
    func testFamilyCreationStateProperties() {
        XCTAssertFalse(FamilyCreationState.idle.isActive)
        XCTAssertTrue(FamilyCreationState.validating.isActive)
        XCTAssertTrue(FamilyCreationState.generatingCode.isLoading)
        XCTAssertTrue(FamilyCreationState.completed.isCompleted)
        XCTAssertTrue(FamilyCreationState.failed(.networkUnavailable).isFailed)
    }
    
    func testFamilyCreationStateProgress() {
        XCTAssertEqual(FamilyCreationState.idle.progress, 0.0)
        XCTAssertEqual(FamilyCreationState.validating.progress, 0.2)
        XCTAssertEqual(FamilyCreationState.generatingCode.progress, 0.4)
        XCTAssertEqual(FamilyCreationState.creatingLocally.progress, 0.6)
        XCTAssertEqual(FamilyCreationState.syncingToCloudKit.progress, 0.8)
        XCTAssertEqual(FamilyCreationState.completed.progress, 1.0)
        XCTAssertEqual(FamilyCreationState.failed(.networkUnavailable).progress, 0.0)
    }
    
    func testFamilyCreationStateTransitions() {
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
    
    func testFamilyCreationStateUserDescriptions() {
        XCTAssertEqual(FamilyCreationState.idle.userDescription, "Ready to create family")
        XCTAssertEqual(FamilyCreationState.validating.userDescription, "Validating family information...")
        XCTAssertEqual(FamilyCreationState.completed.userDescription, "Family created successfully!")
        
        let failedState = FamilyCreationState.failed(.networkUnavailable)
        XCTAssertTrue(failedState.userDescription.contains("Creation failed"))
    }
    
    func testFamilyCreationStateRetryCapability() {
        let retryableFailedState = FamilyCreationState.failed(.networkUnavailable)
        XCTAssertTrue(retryableFailedState.allowsRetry)
        
        let nonRetryableFailedState = FamilyCreationState.failed(.userNotAuthenticated)
        XCTAssertFalse(nonRetryableFailedState.allowsRetry)
        
        XCTAssertFalse(FamilyCreationState.completed.allowsRetry)
        XCTAssertFalse(FamilyCreationState.idle.allowsRetry)
    }
    
    // MARK: - FamilyCreationStateManager Tests
    
    func testStateManagerInitialization() {
        let stateManager = FamilyCreationStateManager()
        XCTAssertEqual(stateManager.currentState, .idle)
        XCTAssertFalse(stateManager.isActive)
        XCTAssertFalse(stateManager.isCompleted)
        XCTAssertFalse(stateManager.isFailed)
        XCTAssertEqual(stateManager.progress, 0.0)
    }
    
    func testStateManagerTransitions() {
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
    
    func testStateManagerFailure() {
        let stateManager = FamilyCreationStateManager()
        
        stateManager.transition(to: .validating)
        stateManager.fail(with: .networkUnavailable)
        
        XCTAssertTrue(stateManager.isFailed)
        XCTAssertEqual(stateManager.currentError, .networkUnavailable)
    }
    
    func testStateManagerReset() {
        let stateManager = FamilyCreationStateManager()
        
        stateManager.transition(to: .validating)
        stateManager.transition(to: .generatingCode)
        stateManager.reset()
        
        XCTAssertEqual(stateManager.currentState, .idle)
        XCTAssertEqual(stateManager.getStateHistory().count, 1)
        XCTAssertEqual(stateManager.getStateHistory().first, .idle)
    }
    
    func testStateManagerRetry() {
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
    
    func testErrorCategorization() {
        let dataServiceError = DataServiceError.validationFailed(["test"])
        let categorizedError = ErrorHandlingUtilities.categorizeError(dataServiceError)
        
        if case .localCreationFailed(let innerError) = categorizedError {
            XCTAssertEqual(innerError, dataServiceError)
        } else {
            XCTFail("Expected localCreationFailed error")
        }
    }
    
    func testErrorContextCreation() {
        let error = FamilyCreationError.networkUnavailable
        let context = ErrorContext(error: error, retryCount: 2)
        
        XCTAssertEqual(context.retryCount, 2)
        XCTAssertEqual(context.errorCategory, .network)
        XCTAssertEqual(context.errorPriority, .low)
        XCTAssertTrue(context.isRetryable)
    }
    
    func testRecoveryStrategyDetermination() {
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
    
    // MARK: - Integration Tests
    
    func testErrorToStateTransition() {
        let stateManager = FamilyCreationStateManager()
        
        // Test different error scenarios
        let errors: [(FamilyCreationError, Bool)] = [
            (.networkUnavailable, true),
            (.userNotAuthenticated, false),
            (.validationFailed("test"), false),
            (.codeCollisionDetected, true)
        ]
        
        for (error, shouldAllowRetry) in errors {
            stateManager.reset()
            stateManager.fail(with: error)
            
            XCTAssertEqual(stateManager.currentError, error)
            XCTAssertEqual(stateManager.retry(), shouldAllowRetry)
        }
    }
    
    func testCompleteErrorHandlingFlow() {
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
}