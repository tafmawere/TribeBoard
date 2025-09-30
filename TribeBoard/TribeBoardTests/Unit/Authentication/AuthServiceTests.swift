import XCTest
import AuthenticationServices
@testable import TribeBoard

/// Comprehensive unit tests for AuthService
/// Tests Apple ID sign-in success and failure scenarios, authentication state management,
/// and keychain integration
@MainActor
class AuthServiceTests: TestBase {
    
    // MARK: - Properties
    
    var authService: AuthService!
    var originalNetworkMonitor: NetworkMonitor!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        setupAuthService()
        setupMockNetworkMonitor()
    }
    
    override func tearDown() {
        authService = nil
        originalNetworkMonitor = nil
        super.tearDown()
    }
    
    // MARK: - Setup Helpers
    
    private func setupAuthService() {
        authService = AuthService(keychainService: mockKeychainService)
        authService.setDataService(mockDataService)
    }
    
    private func setupMockNetworkMonitor() {
        // Store original for restoration
        originalNetworkMonitor = NetworkMonitor.shared
        // For now, we'll work with the actual NetworkMonitor
        // In a real implementation, we'd need dependency injection
    }
    
    // MARK: - Sign In Success Tests
    
    func testSignInWithApple_Success_NewUser() async {
        // Given
        let expectedUser = createTestUserProfile()
        mockDataService.setUserToReturn(expectedUser)
        mockDataService.setShouldReturnExistingUser(false) // New user scenario
        
        // When
        do {
            try await authService.signInWithApple()
        } catch {
            XCTFail("Sign in should succeed but threw: \(error)")
            return
        }
        
        // Then
        XCTAssertTrue(authService.isAuthenticated, "User should be authenticated")
        XCTAssertNotNil(authService.currentUser, "Current user should be set")
        XCTAssertEqual(authService.currentUser?.displayName, expectedUser.displayName)
        XCTAssertFalse(authService.isLoading, "Loading should be false after completion")
        
        // Verify keychain storage
        XCTAssertTrue(mockKeychainService.hasData(for: KeychainService.appleUserIdKey))
        XCTAssertTrue(mockKeychainService.hasData(for: KeychainService.appleUserIdHashKey))
    }
    
    func testSignInWithApple_Success_ExistingUser() async {
        // Given
        let existingUser = createTestUserProfile()
        mockDataService.setUserToReturn(existingUser)
        mockDataService.setShouldReturnExistingUser(true) // Existing user scenario
        
        // When
        do {
            try await authService.signInWithApple()
        } catch {
            XCTFail("Sign in should succeed but threw: \(error)")
            return
        }
        
        // Then
        XCTAssertTrue(authService.isAuthenticated, "User should be authenticated")
        XCTAssertNotNil(authService.currentUser, "Current user should be set")
        XCTAssertEqual(authService.currentUser?.id, existingUser.id)
        XCTAssertFalse(authService.isLoading, "Loading should be false after completion")
    }
    
    func testSignInWithApple_LoadingStateManagement() async {
        // Given
        mockDataService.setUserToReturn(createTestUserProfile())
        mockDataService.setSimulatedDelay(0.2) // Add delay to test loading state
        
        // When
        let signInTask = Task {
            try await authService.signInWithApple()
        }
        
        // Then - Check loading state during operation
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        XCTAssertTrue(authService.isLoading, "Should be loading during sign in")
        
        // Wait for completion
        do {
            try await signInTask.value
        } catch {
            XCTFail("Sign in should succeed but threw: \(error)")
        }
        
        XCTAssertFalse(authService.isLoading, "Loading should be false after completion")
    }
    
    // MARK: - Sign In Failure Tests
    
    // TODO: Implement network unavailable test when NetworkMonitor can be mocked
    // func testSignInWithApple_NetworkUnavailable() async {
    //     // This test requires dependency injection for NetworkMonitor
    // }
    
    func testSignInWithApple_AuthorizationFailed() async {
        // Given
        mockDataService.setError(AuthError.authorizationFailed)
        mockDataService.setShouldSucceed(false)
        
        // When & Then
        do {
            try await authService.signInWithApple()
            XCTFail("Should have thrown authorization failed error")
        } catch let error as AuthError {
            switch error {
            case .authorizationFailed, .dataServiceError:
                break // Expected
            default:
                XCTFail("Expected authorization failed error but got: \(error)")
            }
        } catch {
            XCTFail("Expected AuthError but got: \(error)")
        }
        
        XCTAssertFalse(authService.isAuthenticated, "User should not be authenticated")
        XCTAssertNil(authService.currentUser, "Current user should be nil")
    }
    
    func testSignInWithApple_UserCancelled() async {
        // Given
        mockDataService.setError(AuthError.userCancelled)
        mockDataService.setShouldSucceed(false)
        
        // When & Then
        do {
            try await authService.signInWithApple()
            XCTFail("Should have thrown user cancelled error")
        } catch let error as AuthError {
            switch error {
            case .userCancelled, .dataServiceError:
                break // Expected
            default:
                XCTFail("Expected user cancelled error but got: \(error)")
            }
        } catch {
            XCTFail("Expected AuthError but got: \(error)")
        }
        
        XCTAssertFalse(authService.isAuthenticated, "User should not be authenticated")
        XCTAssertNil(authService.currentUser, "Current user should be nil")
    }
    
    func testSignInWithApple_InvalidCredentials() async {
        // Given
        mockDataService.setError(AuthError.invalidCredentials)
        mockDataService.setShouldSucceed(false)
        
        // When & Then
        do {
            try await authService.signInWithApple()
            XCTFail("Should have thrown invalid credentials error")
        } catch let error as AuthError {
            switch error {
            case .invalidCredentials, .dataServiceError:
                break // Expected
            default:
                XCTFail("Expected invalid credentials error but got: \(error)")
            }
        } catch {
            XCTFail("Expected AuthError but got: \(error)")
        }
        
        XCTAssertFalse(authService.isAuthenticated, "User should not be authenticated")
        XCTAssertNil(authService.currentUser, "Current user should be nil")
    }
    
    func testSignInWithApple_KeychainError() async {
        // Given
        mockDataService.setUserToReturn(createTestUserProfile())
        mockKeychainService.setError(.unexpectedError(errSecInternalError))
        mockKeychainService.setFailingOperations([.storeAppleUserId])
        
        // When & Then
        do {
            try await authService.signInWithApple()
            XCTFail("Should have thrown keychain error")
        } catch let error as AuthError {
            switch error {
            case .keychainError:
                break // Expected
            default:
                XCTFail("Expected keychain error but got: \(error)")
            }
        } catch {
            XCTFail("Expected AuthError.keychainError but got: \(error)")
        }
    }
    
    func testSignInWithApple_DataServiceError() async {
        // Given
        mockDataService.setError(AuthError.dataServiceError(DataServiceError.invalidData("Test error")))
        mockDataService.setShouldSucceed(false)
        
        // When & Then
        do {
            try await authService.signInWithApple()
            XCTFail("Should have thrown data service error")
        } catch let error as AuthError {
            switch error {
            case .dataServiceError:
                break // Expected
            default:
                XCTFail("Expected data service error but got: \(error)")
            }
        } catch {
            XCTFail("Expected AuthError.dataServiceError but got: \(error)")
        }
    }
    
    // MARK: - Sign Out Tests
    
    func testSignOut_Success() async {
        // Given - Set up authenticated state
        await setupAuthenticatedState()
        
        // When
        do {
            try await authService.signOut()
        } catch {
            XCTFail("Sign out should succeed but threw: \(error)")
            return
        }
        
        // Then
        XCTAssertFalse(authService.isAuthenticated, "User should not be authenticated")
        XCTAssertNil(authService.currentUser, "Current user should be nil")
        XCTAssertFalse(authService.isLoading, "Loading should be false after completion")
        
        // Verify keychain is cleared
        XCTAssertFalse(mockKeychainService.hasData(for: KeychainService.appleUserIdKey))
        XCTAssertFalse(mockKeychainService.hasData(for: KeychainService.appleUserIdHashKey))
    }
    
    func testSignOut_KeychainError() async {
        // Given - Set up authenticated state
        await setupAuthenticatedState()
        mockKeychainService.setError(.unexpectedError(errSecInternalError))
        mockKeychainService.setFailingOperations([.clearAll])
        
        // When & Then
        do {
            try await authService.signOut()
            XCTFail("Should have thrown keychain error")
        } catch let error as AuthError {
            switch error {
            case .keychainError:
                break // Expected
            default:
                XCTFail("Expected keychain error but got: \(error)")
            }
        } catch {
            XCTFail("Expected AuthError.keychainError but got: \(error)")
        }
    }
    
    // MARK: - Authentication State Management Tests
    
    func testGetCurrentUser_Authenticated() {
        // Given
        let testUser = createTestUserProfile()
        authService.currentUser = testUser
        authService.isAuthenticated = true
        
        // When
        let currentUser = authService.getCurrentUser()
        
        // Then
        XCTAssertNotNil(currentUser, "Should return current user")
        XCTAssertEqual(currentUser?.id, testUser.id)
    }
    
    func testGetCurrentUser_NotAuthenticated() {
        // Given
        authService.currentUser = nil
        authService.isAuthenticated = false
        
        // When
        let currentUser = authService.getCurrentUser()
        
        // Then
        XCTAssertNil(currentUser, "Should return nil when not authenticated")
    }
    
    func testCheckAuthenticationStatus_Authenticated() {
        // Given
        authService.currentUser = createTestUserProfile()
        authService.isAuthenticated = true
        
        // When
        let isAuthenticated = authService.checkAuthenticationStatus()
        
        // Then
        XCTAssertTrue(isAuthenticated, "Should return true when authenticated")
    }
    
    func testCheckAuthenticationStatus_NotAuthenticated() {
        // Given
        authService.currentUser = nil
        authService.isAuthenticated = false
        
        // When
        let isAuthenticated = authService.checkAuthenticationStatus()
        
        // Then
        XCTAssertFalse(isAuthenticated, "Should return false when not authenticated")
    }
    
    func testCheckAuthenticationStatus_AuthenticatedButNoUser() {
        // Given
        authService.currentUser = nil
        authService.isAuthenticated = true
        
        // When
        let isAuthenticated = authService.checkAuthenticationStatus()
        
        // Then
        XCTAssertFalse(isAuthenticated, "Should return false when authenticated but no user")
    }
    
    // MARK: - Check Existing Authentication Tests
    
    func testCheckExistingAuthentication_ValidCredentials() async {
        // Given
        let testUser = createTestUserProfile()
        let testAppleUserId = "test.apple.user.id"
        let testHash = "test_hash_value"
        
        // Pre-populate keychain with valid credentials
        try! mockKeychainService.storeAppleUserId(testAppleUserId)
        try! mockKeychainService.storeAppleUserIdHash(testHash)
        
        // Configure mock data service to return user
        mockDataService.setUserToReturn(testUser)
        mockDataService.setShouldReturnExistingUser(true)
        
        // Configure mock to simulate valid Apple credentials
        mockDataService.setAppleCredentialState(.authorized)
        
        // When
        await authService.checkExistingAuthentication()
        
        // Then
        XCTAssertTrue(authService.isAuthenticated, "Should be authenticated")
        XCTAssertNotNil(authService.currentUser, "Should have current user")
        XCTAssertEqual(authService.currentUser?.id, testUser.id)
    }
    
    func testCheckExistingAuthentication_InvalidCredentials() async {
        // Given
        let testAppleUserId = "test.apple.user.id"
        let testHash = "test_hash_value"
        
        // Pre-populate keychain with credentials
        try! mockKeychainService.storeAppleUserId(testAppleUserId)
        try! mockKeychainService.storeAppleUserIdHash(testHash)
        
        // Configure mock to simulate invalid Apple credentials
        mockDataService.setAppleCredentialState(.revoked)
        
        // When
        await authService.checkExistingAuthentication()
        
        // Then
        XCTAssertFalse(authService.isAuthenticated, "Should not be authenticated")
        XCTAssertNil(authService.currentUser, "Should not have current user")
        
        // Verify keychain is cleared
        XCTAssertFalse(mockKeychainService.hasData(for: KeychainService.appleUserIdKey))
        XCTAssertFalse(mockKeychainService.hasData(for: KeychainService.appleUserIdHashKey))
    }
    
    func testCheckExistingAuthentication_NoStoredCredentials() async {
        // Given - Empty keychain (default state)
        
        // When
        await authService.checkExistingAuthentication()
        
        // Then
        XCTAssertFalse(authService.isAuthenticated, "Should not be authenticated")
        XCTAssertNil(authService.currentUser, "Should not have current user")
    }
    
    func testCheckExistingAuthentication_UserProfileNotFound() async {
        // Given
        let testAppleUserId = "test.apple.user.id"
        let testHash = "test_hash_value"
        
        // Pre-populate keychain with credentials
        try! mockKeychainService.storeAppleUserId(testAppleUserId)
        try! mockKeychainService.storeAppleUserIdHash(testHash)
        
        // Configure mock to simulate valid Apple credentials but no user profile
        mockDataService.setAppleCredentialState(.authorized)
        mockDataService.setShouldReturnExistingUser(false)
        mockDataService.setUserToReturn(nil)
        
        // When
        await authService.checkExistingAuthentication()
        
        // Then
        XCTAssertFalse(authService.isAuthenticated, "Should not be authenticated")
        XCTAssertNil(authService.currentUser, "Should not have current user")
        
        // Verify keychain is cleared
        XCTAssertFalse(mockKeychainService.hasData(for: KeychainService.appleUserIdKey))
        XCTAssertFalse(mockKeychainService.hasData(for: KeychainService.appleUserIdHashKey))
    }
    
    func testCheckExistingAuthentication_KeychainError() async {
        // Given
        mockKeychainService.setError(.unexpectedError(errSecInternalError))
        mockKeychainService.setFailingOperations([.retrieveAppleUserId])
        
        // When
        await authService.checkExistingAuthentication()
        
        // Then
        XCTAssertFalse(authService.isAuthenticated, "Should not be authenticated")
        XCTAssertNil(authService.currentUser, "Should not have current user")
    }
    
    // MARK: - Integration Tests
    
    func testFullAuthenticationFlow_SignInAndSignOut() async {
        // Given
        let testUser = createTestUserProfile()
        mockDataService.setUserToReturn(testUser)
        
        // When - Sign in
        do {
            try await authService.signInWithApple()
        } catch {
            XCTFail("Sign in should succeed but threw: \(error)")
            return
        }
        
        // Then - Verify signed in state
        XCTAssertTrue(authService.isAuthenticated)
        XCTAssertNotNil(authService.currentUser)
        
        // When - Sign out
        do {
            try await authService.signOut()
        } catch {
            XCTFail("Sign out should succeed but threw: \(error)")
            return
        }
        
        // Then - Verify signed out state
        XCTAssertFalse(authService.isAuthenticated)
        XCTAssertNil(authService.currentUser)
    }
    
    func testAuthenticationPersistence_SignInCheckExisting() async {
        // Given
        let testUser = createTestUserProfile()
        mockDataService.setUserToReturn(testUser)
        
        // When - Sign in
        do {
            try await authService.signInWithApple()
        } catch {
            XCTFail("Sign in should succeed but threw: \(error)")
            return
        }
        
        // Simulate app restart by creating new auth service
        let newAuthService = AuthService(keychainService: mockKeychainService)
        newAuthService.setDataService(mockDataService)
        
        // Configure mock for existing authentication check
        mockDataService.setAppleCredentialState(.authorized)
        mockDataService.setShouldReturnExistingUser(true)
        
        // When - Check existing authentication
        await newAuthService.checkExistingAuthentication()
        
        // Then - Should restore authentication state
        XCTAssertTrue(newAuthService.isAuthenticated)
        XCTAssertNotNil(newAuthService.currentUser)
        XCTAssertEqual(newAuthService.currentUser?.id, testUser.id)
    }
    
    // MARK: - Helper Methods
    
    private func createTestUserProfile() -> UserProfile {
        return UserProfile(
            displayName: "Test User",
            appleUserIdHash: "test_hash_value"
        )
    }
    
    private func setupAuthenticatedState() async {
        let testUser = createTestUserProfile()
        authService.currentUser = testUser
        authService.isAuthenticated = true
        
        // Store credentials in keychain
        try! mockKeychainService.storeAppleUserId("test.apple.user.id")
        try! mockKeychainService.storeAppleUserIdHash(testUser.appleUserIdHash)
    }
}

