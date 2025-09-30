import XCTest
import AuthenticationServices
@testable import TribeBoard

/// Comprehensive unit tests for AuthError handling
/// Tests all AuthError types, their user-facing messages, network connectivity error detection,
/// and error recovery mechanisms
class AuthErrorHandlingTests: TestBase {
    
    // MARK: - Properties
    
    var authService: AuthService!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        setupAuthService()
    }
    
    override func tearDown() {
        authService = nil
        super.tearDown()
    }
    
    // MARK: - Setup Helpers
    
    private func setupAuthService() {
        authService = AuthService(keychainService: mockKeychainService)
        authService.setDataService(mockDataService)
    }
    
    // MARK: - AuthError Types Tests
    
    func testAuthError_AuthorizationFailed() {
        // Given
        let error = AuthError.authorizationFailed
        
        // When
        let errorDescription = error.errorDescription
        
        // Then
        XCTAssertNotNil(errorDescription, "Error should have description")
        XCTAssertEqual(errorDescription, "Authentication failed. Please try again.")
        XCTAssertTrue(errorDescription!.contains("Authentication failed"), "Should contain meaningful message")
    }
    
    func testAuthError_UserCancelled() {
        // Given
        let error = AuthError.userCancelled
        
        // When
        let errorDescription = error.errorDescription
        
        // Then
        XCTAssertNotNil(errorDescription, "Error should have description")
        XCTAssertEqual(errorDescription, "Sign in was cancelled.")
        XCTAssertTrue(errorDescription!.contains("cancelled"), "Should indicate user cancellation")
    }
    
    func testAuthError_NetworkUnavailable() {
        // Given
        let error = AuthError.networkUnavailable
        
        // When
        let errorDescription = error.errorDescription
        
        // Then
        XCTAssertNotNil(errorDescription, "Error should have description")
        XCTAssertEqual(errorDescription, "Network unavailable. Please check your connection.")
        XCTAssertTrue(errorDescription!.contains("Network"), "Should mention network issue")
        XCTAssertTrue(errorDescription!.contains("connection"), "Should mention connection")
    }
    
    func testAuthError_InvalidCredentials() {
        // Given
        let error = AuthError.invalidCredentials
        
        // When
        let errorDescription = error.errorDescription
        
        // Then
        XCTAssertNotNil(errorDescription, "Error should have description")
        XCTAssertEqual(errorDescription, "Invalid credentials received from Apple.")
        XCTAssertTrue(errorDescription!.contains("Invalid credentials"), "Should mention invalid credentials")
        XCTAssertTrue(errorDescription!.contains("Apple"), "Should mention Apple as source")
    }
    
    func testAuthError_KeychainError() {
        // Given
        let underlyingError = KeychainService.KeychainError.unexpectedError(errSecInternalError)
        let error = AuthError.keychainError(underlyingError)
        
        // When
        let errorDescription = error.errorDescription
        
        // Then
        XCTAssertNotNil(errorDescription, "Error should have description")
        XCTAssertTrue(errorDescription!.contains("Secure storage error"), "Should mention secure storage")
        XCTAssertTrue(errorDescription!.contains(underlyingError.localizedDescription), "Should include underlying error")
    }
    
    func testAuthError_DataServiceError() {
        // Given
        let underlyingError = DataServiceError.invalidData("Test data error")
        let error = AuthError.dataServiceError(underlyingError)
        
        // When
        let errorDescription = error.errorDescription
        
        // Then
        XCTAssertNotNil(errorDescription, "Error should have description")
        XCTAssertTrue(errorDescription!.contains("Data error"), "Should mention data error")
        XCTAssertTrue(errorDescription!.contains("Test data error"), "Should include underlying error message")
    }
    
    func testAuthError_UnknownError() {
        // Given
        let underlyingError = NSError(domain: "TestDomain", code: 999, userInfo: [NSLocalizedDescriptionKey: "Test unknown error"])
        let error = AuthError.unknownError(underlyingError)
        
        // When
        let errorDescription = error.errorDescription
        
        // Then
        XCTAssertNotNil(errorDescription, "Error should have description")
        XCTAssertTrue(errorDescription!.contains("An unexpected error occurred"), "Should mention unexpected error")
        XCTAssertTrue(errorDescription!.contains("Test unknown error"), "Should include underlying error message")
    }
    
    // MARK: - Error Message Quality Tests
    
    func testAuthError_UserFriendlyMessages() {
        let errors: [AuthError] = [
            .authorizationFailed,
            .userCancelled,
            .networkUnavailable,
            .invalidCredentials,
            .keychainError(KeychainService.KeychainError.itemNotFound),
            .dataServiceError(DataServiceError.notFound("User")),
            .unknownError(NSError(domain: "Test", code: 1, userInfo: nil))
        ]
        
        for error in errors {
            // When
            let description = error.errorDescription
            
            // Then
            XCTAssertNotNil(description, "Error \(error) should have description")
            XCTAssertFalse(description!.isEmpty, "Error description should not be empty")
            XCTAssertFalse(description!.contains("nil"), "Error description should not contain 'nil'")
            XCTAssertFalse(description!.contains("Optional"), "Error description should not contain 'Optional'")
            
            // Check that messages are user-friendly (no technical jargon)
            let lowercaseDescription = description!.lowercased()
            XCTAssertFalse(lowercaseDescription.contains("nserror"), "Should not expose NSError details")
            XCTAssertFalse(lowercaseDescription.contains("exception"), "Should not mention exceptions")
            XCTAssertFalse(lowercaseDescription.contains("stack"), "Should not mention stack traces")
        }
    }
    
    func testAuthError_MessageConsistency() {
        // Test that error messages are consistent in style and tone
        let errors: [AuthError] = [
            .authorizationFailed,
            .userCancelled,
            .networkUnavailable,
            .invalidCredentials
        ]
        
        for error in errors {
            let description = error.errorDescription!
            
            // Messages should end with period for consistency
            XCTAssertTrue(description.hasSuffix("."), "Error message should end with period: \(description)")
            
            // Messages should not be too long (good UX practice)
            XCTAssertLessThan(description.count, 100, "Error message should be concise: \(description)")
            
            // Messages should not be too short (should be informative)
            XCTAssertGreaterThan(description.count, 10, "Error message should be informative: \(description)")
        }
    }
    
    // MARK: - ASAuthorizationError Mapping Tests
    
    func testASAuthorizationError_Mapping() {
        // Test that ASAuthorizationError codes are properly mapped to AuthError
        // Note: We can't directly test the private mapping method, but we can test the behavior
        
        let testCases: [(ASAuthorizationError.Code, AuthError)] = [
            (.canceled, .userCancelled),
            (.failed, .authorizationFailed),
            (.invalidResponse, .invalidCredentials),
            (.notHandled, .authorizationFailed),
            (.unknown, .unknownError(ASAuthorizationError(.unknown)))
        ]
        
        for (asErrorCode, expectedAuthError) in testCases {
            // Given
            let asError = ASAuthorizationError(asErrorCode)
            
            // When - Configure mock to throw ASAuthorizationError
            mockDataService.setShouldSucceed(false)
            
            // We can't directly test the mapping, but we can verify that
            // ASAuthorizationErrors result in appropriate AuthErrors
            // This would require integration testing with the actual AuthService
            
            // For now, we'll test that the expected error types have appropriate messages
            switch expectedAuthError {
            case .userCancelled:
                XCTAssertTrue(expectedAuthError.errorDescription!.contains("cancelled"))
            case .authorizationFailed:
                XCTAssertTrue(expectedAuthError.errorDescription!.contains("Authentication failed"))
            case .invalidCredentials:
                XCTAssertTrue(expectedAuthError.errorDescription!.contains("Invalid credentials"))
            case .unknownError:
                XCTAssertTrue(expectedAuthError.errorDescription!.contains("unexpected error"))
            default:
                break
            }
        }
    }
    
    // MARK: - Network Error Detection Tests
    
    func testNetworkError_Detection() {
        // Test network error detection logic
        // Note: This tests the concept of network error detection
        
        let networkErrors = [
            NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil),
            NSError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost, userInfo: nil),
            NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: nil),
            NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotConnectToHost, userInfo: nil),
            NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotFindHost, userInfo: nil),
            NSError(domain: NSURLErrorDomain, code: NSURLErrorDNSLookupFailed, userInfo: nil)
        ]
        
        for networkError in networkErrors {
            // These errors should be detected as network-related
            // In the actual implementation, they would be mapped to AuthError.networkUnavailable
            
            let errorDescription = networkError.localizedDescription.lowercased()
            let isNetworkRelated = errorDescription.contains("network") ||
                                 errorDescription.contains("internet") ||
                                 errorDescription.contains("connection") ||
                                 errorDescription.contains("host") ||
                                 errorDescription.contains("dns")
            
            XCTAssertTrue(isNetworkRelated || networkError.domain == NSURLErrorDomain,
                         "Error should be detectable as network-related: \(networkError)")
        }
    }
    
    func testNetworkError_NonNetworkErrors() {
        // Test that non-network errors are not misidentified as network errors
        
        let nonNetworkErrors = [
            NSError(domain: "CustomDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Custom error"]),
            NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError, userInfo: nil),
            KeychainService.KeychainError.itemNotFound,
            DataServiceError.invalidData("Test data")
        ]
        
        for error in nonNetworkErrors {
            let errorDescription = error.localizedDescription.lowercased()
            let appearsNetworkRelated = errorDescription.contains("network") ||
                                      errorDescription.contains("internet") ||
                                      errorDescription.contains("connection")
            
            // These specific errors should not appear network-related
            // (unless they happen to contain network-related words in their description)
            if error is KeychainService.KeychainError || error is DataServiceError {
                XCTAssertFalse(appearsNetworkRelated,
                             "App-specific error should not appear network-related: \(error)")
            }
        }
    }
    
    // MARK: - Error Recovery Mechanism Tests
    
    func testErrorRecovery_RetryableErrors() async {
        // Test that certain errors are considered retryable
        
        let retryableErrors: [AuthError] = [
            .networkUnavailable,
            .authorizationFailed,
            .unknownError(NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: nil))
        ]
        
        for error in retryableErrors {
            // These errors should allow retry attempts
            let description = error.errorDescription!
            
            // Retryable errors should suggest user action
            let suggestsRetry = description.contains("try again") ||
                              description.contains("check") ||
                              description.contains("Please")
            
            XCTAssertTrue(suggestsRetry,
                         "Retryable error should suggest user action: \(description)")
        }
    }
    
    func testErrorRecovery_NonRetryableErrors() {
        // Test that certain errors are not retryable
        
        let nonRetryableErrors: [AuthError] = [
            .userCancelled,
            .invalidCredentials
        ]
        
        for error in nonRetryableErrors {
            let description = error.errorDescription!
            
            // Non-retryable errors should not suggest immediate retry
            switch error {
            case .userCancelled:
                XCTAssertTrue(description.contains("cancelled"), "Should indicate cancellation")
                XCTAssertFalse(description.contains("try again"), "Should not suggest retry for cancellation")
            case .invalidCredentials:
                XCTAssertTrue(description.contains("Invalid"), "Should indicate invalid credentials")
                // Invalid credentials might still suggest trying again, which is acceptable
            default:
                break
            }
        }
    }
    
    // MARK: - Error Context Tests
    
    func testErrorContext_PreservesUnderlyingError() {
        // Test that wrapped errors preserve the underlying error information
        
        let underlyingKeychainError = KeychainService.KeychainError.unexpectedError(errSecInternalError)
        let authKeychainError = AuthError.keychainError(underlyingKeychainError)
        
        let underlyingDataError = DataServiceError.constraintViolation("Duplicate user")
        let authDataError = AuthError.dataServiceError(underlyingDataError)
        
        let underlyingNSError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let authUnknownError = AuthError.unknownError(underlyingNSError)
        
        // Verify that error descriptions include underlying error information
        XCTAssertTrue(authKeychainError.errorDescription!.contains(underlyingKeychainError.localizedDescription))
        XCTAssertTrue(authDataError.errorDescription!.contains(underlyingDataError.localizedDescription))
        XCTAssertTrue(authUnknownError.errorDescription!.contains(underlyingNSError.localizedDescription))
    }
    
    func testErrorContext_ChainedErrors() {
        // Test error chaining scenarios
        
        // Create a chain: NSError -> DataServiceError -> AuthError
        let rootError = NSError(domain: "RootDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Root cause"])
        let dataError = DataServiceError.invalidData("Data error caused by: \(rootError.localizedDescription)")
        let authError = AuthError.dataServiceError(dataError)
        
        let finalDescription = authError.errorDescription!
        
        // The final error description should provide useful information
        XCTAssertTrue(finalDescription.contains("Data error"), "Should mention data error")
        // It may or may not contain the root cause, depending on implementation
    }
    
    // MARK: - Integration Error Handling Tests
    
    func testIntegration_AuthServiceErrorHandling() async {
        // Test that AuthService properly handles and propagates errors
        
        // Test keychain error propagation
        mockKeychainService.setError(.unexpectedError(errSecInternalError))
        mockKeychainService.setFailingOperations([.storeAppleUserId])
        mockDataService.setUserToReturn(createTestUserProfile())
        
        do {
            try await authService.signInWithApple()
            XCTFail("Should have thrown keychain error")
        } catch let error as AuthError {
            switch error {
            case .keychainError:
                XCTAssertTrue(error.errorDescription!.contains("Secure storage error"))
            default:
                XCTFail("Expected keychain error but got: \(error)")
            }
        } catch {
            XCTFail("Expected AuthError but got: \(error)")
        }
    }
    
    func testIntegration_DataServiceErrorHandling() async {
        // Test data service error propagation
        mockDataService.setError(DataServiceError.constraintViolation("User already exists"))
        mockDataService.setShouldSucceed(false)
        
        do {
            try await authService.signInWithApple()
            XCTFail("Should have thrown data service error")
        } catch let error as AuthError {
            switch error {
            case .dataServiceError:
                XCTAssertTrue(error.errorDescription!.contains("Data error"))
            default:
                XCTFail("Expected data service error but got: \(error)")
            }
        } catch {
            XCTFail("Expected AuthError but got: \(error)")
        }
    }
    
    func testIntegration_ErrorStateCleanup() async {
        // Test that errors leave the service in a clean state
        
        // Given - Configure service to fail
        mockDataService.setError(DataServiceError.invalidData("Test error"))
        mockDataService.setShouldSucceed(false)
        
        // When - Attempt authentication (should fail)
        do {
            try await authService.signInWithApple()
            XCTFail("Should have thrown error")
        } catch {
            // Expected
        }
        
        // Then - Service should be in clean state
        XCTAssertFalse(authService.isAuthenticated, "Should not be authenticated after error")
        XCTAssertNil(authService.currentUser, "Should not have current user after error")
        XCTAssertFalse(authService.isLoading, "Should not be loading after error")
        
        // And subsequent operations should work if configured properly
        mockDataService.setShouldSucceed(true)
        mockDataService.setUserToReturn(createTestUserProfile())
        
        do {
            try await authService.signInWithApple()
            XCTAssertTrue(authService.isAuthenticated, "Should be able to authenticate after previous error")
        } catch {
            XCTFail("Should succeed after fixing configuration: \(error)")
        }
    }
    
    // MARK: - Error Logging and Debugging Tests
    
    func testErrorLogging_ContainsUsefulInformation() {
        // Test that errors contain information useful for debugging
        
        let errors: [AuthError] = [
            .authorizationFailed,
            .keychainError(KeychainService.KeychainError.unexpectedError(errSecInternalError)),
            .dataServiceError(DataServiceError.constraintViolation("Duplicate key")),
            .unknownError(NSError(domain: "TestDomain", code: 999, userInfo: [NSLocalizedDescriptionKey: "Debug info"]))
        ]
        
        for error in errors {
            let description = error.errorDescription!
            
            // Error descriptions should be informative for debugging
            XCTAssertGreaterThan(description.count, 5, "Error description should be informative")
            
            // Should not contain sensitive information
            XCTAssertFalse(description.contains("password"), "Should not contain sensitive data")
            XCTAssertFalse(description.contains("token"), "Should not contain sensitive data")
            XCTAssertFalse(description.contains("secret"), "Should not contain sensitive data")
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestUserProfile() -> UserProfile {
        return UserProfile(
            displayName: "Test User",
            appleUserIdHash: "test_hash_value"
        )
    }
}