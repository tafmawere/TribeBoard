import XCTest
import AuthenticationServices
@testable import TribeBoard

@MainActor
class MockAuthServiceTests: XCTestCase {
    
    var mockAuthService: MockAuthService!
    var mockKeychainService: MockKeychainService!
    var mockDataService: MockDataService!
    
    override func setUp() async throws {
        await super.setUp()
        mockAuthService = MockAuthService()
        mockKeychainService = MockKeychainService()
        mockDataService = MockDataService()
        
        mockAuthService.setMockDependencies(
            keychainService: mockKeychainService,
            dataService: mockDataService
        )
    }
    
    override func tearDown() async throws {
        mockAuthService = nil
        mockKeychainService = nil
        mockDataService = nil
        await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        // Then
        XCTAssertFalse(mockAuthService.isAuthenticated)
        XCTAssertNil(mockAuthService.currentUser)
        XCTAssertFalse(mockAuthService.isLoading)
        XCTAssertTrue(mockAuthService.shouldSucceed)
        XCTAssertTrue(mockAuthService.isNetworkAvailable)
        XCTAssertEqual(mockAuthService.appleCredentialState, .authorized)
    }
    
    // MARK: - Sign In Tests
    
    func testSignInWithAppleSuccess() async throws {
        // Given
        let expectedUser = UserProfile(
            id: UUID(),
            displayName: "Test User",
            appleUserIdHash: "test_hash",
            createdAt: Date(),
            updatedAt: Date()
        )
        mockAuthService.setMockUserProfile(expectedUser)
        
        // When
        try await mockAuthService.signInWithApple()
        
        // Then
        XCTAssertTrue(mockAuthService.isAuthenticated)
        XCTAssertEqual(mockAuthService.currentUser?.displayName, expectedUser.displayName)
        XCTAssertEqual(mockAuthService.signInCallCount, 1)
        XCTAssertFalse(mockAuthService.isLoading)
        
        // Verify keychain storage
        XCTAssertEqual(try mockKeychainService.retrieveAppleUserId(), mockAuthService.mockAppleUserId)
        XCTAssertEqual(try mockKeychainService.retrieveAppleUserIdHash(), mockAuthService.mockAppleUserIdHash)
    }
    
    func testSignInWithAppleNetworkUnavailable() async {
        // Given
        mockAuthService.setNetworkAvailable(false)
        
        // When/Then
        do {
            try await mockAuthService.signInWithApple()
            XCTFail("Expected networkUnavailable error")
        } catch let error as AuthError {
            XCTAssertEqual(error, .networkUnavailable)
            XCTAssertFalse(mockAuthService.isAuthenticated)
            XCTAssertNil(mockAuthService.currentUser)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testSignInWithAppleFailure() async {
        // Given
        mockAuthService.setError(.authorizationFailed)
        mockAuthService.shouldSucceed = false
        
        // When/Then
        do {
            try await mockAuthService.signInWithApple()
            XCTFail("Expected authorizationFailed error")
        } catch let error as AuthError {
            XCTAssertEqual(error, .authorizationFailed)
            XCTAssertFalse(mockAuthService.isAuthenticated)
            XCTAssertNil(mockAuthService.currentUser)
            XCTAssertEqual(mockAuthService.signInCallCount, 1)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    func testSignInWithSpecificOperationFailure() async {
        // Given
        mockAuthService.setFailingOperations([.signIn])
        mockAuthService.setError(.userCancelled)
        
        // When/Then
        do {
            try await mockAuthService.signInWithApple()
            XCTFail("Expected userCancelled error")
        } catch let error as AuthError {
            XCTAssertEqual(error, .userCancelled)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Sign Out Tests
    
    func testSignOutSuccess() async throws {
        // Given - first sign in
        try await mockAuthService.signInWithApple()
        XCTAssertTrue(mockAuthService.isAuthenticated)
        
        // When
        try await mockAuthService.signOut()
        
        // Then
        XCTAssertFalse(mockAuthService.isAuthenticated)
        XCTAssertNil(mockAuthService.currentUser)
        XCTAssertEqual(mockAuthService.signOutCallCount, 1)
        XCTAssertFalse(mockAuthService.isLoading)
        
        // Verify keychain cleared
        XCTAssertNil(try mockKeychainService.retrieveAppleUserId())
        XCTAssertNil(try mockKeychainService.retrieveAppleUserIdHash())
    }
    
    func testSignOutFailure() async throws {
        // Given - first sign in
        try await mockAuthService.signInWithApple()
        
        // Configure for failure
        mockAuthService.setError(.keychainError(KeychainService.KeychainError.itemNotFound))
        mockAuthService.shouldSucceed = false
        
        // When/Then
        do {
            try await mockAuthService.signOut()
            XCTFail("Expected keychainError")
        } catch let error as AuthError {
            if case .keychainError = error {
                // Expected error type
                XCTAssertEqual(mockAuthService.signOutCallCount, 1)
            } else {
                XCTFail("Expected keychainError, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
    
    // MARK: - Authentication Status Tests
    
    func testGetCurrentUserWhenAuthenticated() async throws {
        // Given
        try await mockAuthService.signInWithApple()
        
        // When
        let user = mockAuthService.getCurrentUser()
        
        // Then
        XCTAssertNotNil(user)
        XCTAssertEqual(user?.displayName, "Test User")
        XCTAssertEqual(mockAuthService.getCurrentUserCallCount, 1)
    }
    
    func testGetCurrentUserWhenNotAuthenticated() {
        // When
        let user = mockAuthService.getCurrentUser()
        
        // Then
        XCTAssertNil(user)
        XCTAssertEqual(mockAuthService.getCurrentUserCallCount, 1)
    }
    
    func testGetCurrentUserWithFailure() {
        // Given
        mockAuthService.setFailingOperations([.getCurrentUser])
        
        // When
        let user = mockAuthService.getCurrentUser()
        
        // Then
        XCTAssertNil(user)
    }
    
    func testCheckAuthenticationStatusWhenAuthenticated() async throws {
        // Given
        try await mockAuthService.signInWithApple()
        
        // When
        let isAuthenticated = mockAuthService.checkAuthenticationStatus()
        
        // Then
        XCTAssertTrue(isAuthenticated)
    }
    
    func testCheckAuthenticationStatusWhenNotAuthenticated() {
        // When
        let isAuthenticated = mockAuthService.checkAuthenticationStatus()
        
        // Then
        XCTAssertFalse(isAuthenticated)
    }
    
    // MARK: - Check Existing Authentication Tests
    
    func testCheckExistingAuthenticationWithValidCredentials() async throws {
        // Given - pre-populate keychain and data service
        let testUser = UserProfile(
            id: UUID(),
            displayName: "Existing User",
            appleUserIdHash: "existing_hash",
            createdAt: Date(),
            updatedAt: Date()
        )
        
        mockKeychainService.prePopulate(
            data: "existing.apple.id".data(using: .utf8)!,
            for: KeychainService.appleUserIdKey
        )
        mockKeychainService.prePopulate(
            data: "existing_hash".data(using: .utf8)!,
            for: KeychainService.appleUserIdHashKey
        )
        
        mockDataService.prePopulateUser(testUser, withHash: "existing_hash")
        mockAuthService.setAppleCredentialState(.authorized)
        
        // When
        await mockAuthService.checkExistingAuthentication()
        
        // Then
        XCTAssertTrue(mockAuthService.isAuthenticated)
        XCTAssertEqual(mockAuthService.currentUser?.displayName, "Existing User")
        XCTAssertEqual(mockAuthService.checkAuthCallCount, 1)
    }
    
    func testCheckExistingAuthenticationWithInvalidCredentials() async throws {
        // Given - pre-populate keychain but set credential state to not authorized
        mockKeychainService.prePopulate(
            data: "invalid.apple.id".data(using: .utf8)!,
            for: KeychainService.appleUserIdKey
        )
        mockKeychainService.prePopulate(
            data: "invalid_hash".data(using: .utf8)!,
            for: KeychainService.appleUserIdHashKey
        )
        
        mockAuthService.setAppleCredentialState(.notFound)
        
        // When
        await mockAuthService.checkExistingAuthentication()
        
        // Then
        XCTAssertFalse(mockAuthService.isAuthenticated)
        XCTAssertNil(mockAuthService.currentUser)
        
        // Verify keychain was cleared
        XCTAssertNil(try mockKeychainService.retrieveAppleUserId())
        XCTAssertNil(try mockKeychainService.retrieveAppleUserIdHash())
    }
    
    func testCheckExistingAuthenticationWithNoStoredCredentials() async {
        // Given - empty keychain
        
        // When
        await mockAuthService.checkExistingAuthentication()
        
        // Then
        XCTAssertFalse(mockAuthService.isAuthenticated)
        XCTAssertNil(mockAuthService.currentUser)
        XCTAssertEqual(mockAuthService.checkAuthCallCount, 1)
    }
    
    // MARK: - Configuration Tests
    
    func testReset() async throws {
        // Given - set up some state
        try await mockAuthService.signInWithApple()
        mockAuthService.setError(.networkUnavailable)
        mockAuthService.shouldSucceed = false
        
        // When
        mockAuthService.reset()
        
        // Then
        XCTAssertFalse(mockAuthService.isAuthenticated)
        XCTAssertNil(mockAuthService.currentUser)
        XCTAssertFalse(mockAuthService.isLoading)
        XCTAssertTrue(mockAuthService.shouldSucceed)
        XCTAssertEqual(mockAuthService.signInCallCount, 0)
        XCTAssertEqual(mockAuthService.signOutCallCount, 0)
        XCTAssertEqual(mockAuthService.checkAuthCallCount, 0)
        XCTAssertEqual(mockAuthService.getCurrentUserCallCount, 0)
    }
    
    func testSetMockUserProfile() {
        // Given
        let customUser = UserProfile(
            id: UUID(),
            displayName: "Custom User",
            appleUserIdHash: "custom_hash",
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // When
        mockAuthService.setMockUserProfile(customUser)
        
        // Then
        XCTAssertEqual(mockAuthService.mockUserProfile?.displayName, "Custom User")
    }
    
    // MARK: - Test Utility Tests
    
    func testSimulateSuccessfulAuthentication() {
        // Given
        let testUser = UserProfile(
            id: UUID(),
            displayName: "Simulated User",
            appleUserIdHash: "simulated_hash",
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // When
        mockAuthService.simulateSuccessfulAuthentication(with: testUser)
        
        // Then
        XCTAssertTrue(mockAuthService.isAuthenticated)
        XCTAssertEqual(mockAuthService.currentUser?.displayName, "Simulated User")
        XCTAssertTrue(mockAuthService.isInAuthenticationState(true))
    }
    
    func testSimulateAuthenticationFailure() {
        // Given
        let testError = AuthError.invalidCredentials
        
        // When
        mockAuthService.simulateAuthenticationFailure(with: testError)
        
        // Then
        XCTAssertFalse(mockAuthService.isAuthenticated)
        XCTAssertNil(mockAuthService.currentUser)
        XCTAssertFalse(mockAuthService.shouldSucceed)
        XCTAssertEqual(mockAuthService.errorToThrow, testError)
        XCTAssertTrue(mockAuthService.isInAuthenticationState(false))
    }
    
    func testGetCallCounts() async throws {
        // Given
        try await mockAuthService.signInWithApple()
        try await mockAuthService.signOut()
        _ = mockAuthService.getCurrentUser()
        await mockAuthService.checkExistingAuthentication()
        
        // When
        let callCounts = mockAuthService.getCallCounts()
        
        // Then
        XCTAssertEqual(callCounts["signIn"], 1)
        XCTAssertEqual(callCounts["signOut"], 1)
        XCTAssertEqual(callCounts["getCurrentUser"], 1)
        XCTAssertEqual(callCounts["checkAuth"], 1)
    }
    
    // MARK: - Delay Simulation Tests
    
    func testSimulatedDelay() async throws {
        // Given
        mockAuthService.simulatedDelay = 0.05 // 50ms
        let startTime = Date()
        
        // When
        try await mockAuthService.signInWithApple()
        
        // Then
        let elapsedTime = Date().timeIntervalSince(startTime)
        XCTAssertGreaterThanOrEqual(elapsedTime, 0.05)
    }
}