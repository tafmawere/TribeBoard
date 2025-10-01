import XCTest
import SwiftData
@testable import TribeBoard

/// Integration tests for end-to-end authentication workflows
/// Tests complete authentication flows including onboarding, persistence, and state transitions
@MainActor
class AuthenticationIntegrationTests: TestBase {
    
    // MARK: - Properties
    
    private var appState: AppState!
    private var onboardingViewModel: OnboardingViewModel!
    private var createFamilyViewModel: CreateFamilyViewModel!
    private var joinFamilyViewModel: JoinFamilyViewModel!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        setupIntegrationTestEnvironment()
    }
    
    override func tearDown() {
        cleanupIntegrationTestEnvironment()
        super.tearDown()
    }
    
    // MARK: - Setup Methods
    
    private func setupIntegrationTestEnvironment() {
        // Create AppState with mock services
        appState = AppState()
        
        // Create ViewModels with mock services
        onboardingViewModel = OnboardingViewModel(authService: mockAuthService)
        onboardingViewModel.setAppState(appState)
        
        createFamilyViewModel = CreateFamilyViewModel(
            dataService: mockDataService,
            cloudKitService: MockCloudKitService(),
            syncManager: MockSyncManager(),
            qrCodeService: MockQRCodeService(),
            codeGenerator: MockCodeGenerator()
        )
        
        joinFamilyViewModel = JoinFamilyViewModel(
            dataService: mockDataService,
            cloudKitService: MockCloudKitService(),
            qrCodeService: MockQRCodeService()
        )
        
        // Configure mock services for integration testing
        configureMockServicesForIntegration()
    }
    
    private func configureMockServicesForIntegration() {
        // Configure mock auth service for successful authentication
        mockAuthService.shouldSucceed = true
        mockAuthService.setMockUserProfile(createTestUser(name: "Integration Test User"))
        
        // Configure mock data service
        mockDataService.shouldSucceed = true
        mockDataService.setUserToReturn(mockAuthService.mockUserProfile)
        
        // Set up dependencies
        mockAuthService.setMockDependencies(
            keychainService: mockKeychainService,
            dataService: mockDataService
        )
    }
    
    private func cleanupIntegrationTestEnvironment() {
        appState = nil
        onboardingViewModel = nil
        createFamilyViewModel = nil
        joinFamilyViewModel = nil
    }
    
    // MARK: - Complete Onboarding Flow Tests
    
    /// Test complete onboarding flow with authentication
    /// Requirements: 5.1 - Complete onboarding flow with authentication
    func testCompleteOnboardingFlowWithAuthentication() async {
        // Given: User starts onboarding flow
        XCTAssertFalse(appState.isAuthenticated, "Should start unauthenticated")
        XCTAssertEqual(appState.currentFlow, .onboarding, "Should start in onboarding flow")
        XCTAssertNil(appState.currentUser, "Should have no current user")
        
        // When: User completes Apple ID authentication
        await onboardingViewModel.signInWithApple()
        
        // Then: Authentication should succeed
        XCTAssertTrue(onboardingViewModel.authenticationSucceeded, "Authentication should succeed")
        XCTAssertNil(onboardingViewModel.errorMessage, "Should have no error message")
        XCTAssertFalse(onboardingViewModel.isLoading, "Should not be loading")
        
        // And: App state should be updated
        XCTAssertTrue(appState.isAuthenticated, "Should be authenticated")
        XCTAssertNotNil(appState.currentUser, "Should have current user")
        XCTAssertEqual(appState.currentUser?.displayName, "Integration Test User", "Should have correct user")
        
        // And: Should navigate to family selection
        XCTAssertEqual(appState.currentFlow, .familySelection, "Should navigate to family selection")
        
        // And: Authentication data should be stored
        XCTAssertEqual(mockAuthService.signInCallCount, 1, "Should call sign in once")
        XCTAssertTrue(mockKeychainService.hasStoredAppleUserId(), "Should store Apple user ID")
        XCTAssertTrue(mockKeychainService.hasStoredAppleUserIdHash(), "Should store Apple user ID hash")
    }
    
    /// Test onboarding flow with authentication failure
    /// Requirements: 5.1 - Complete onboarding flow with authentication
    func testOnboardingFlowWithAuthenticationFailure() async {
        // Given: Mock auth service configured to fail
        mockAuthService.shouldSucceed = false
        mockAuthService.setError(.authorizationFailed)
        
        // When: User attempts Apple ID authentication
        await onboardingViewModel.signInWithApple()
        
        // Then: Authentication should fail
        XCTAssertFalse(onboardingViewModel.authenticationSucceeded, "Authentication should fail")
        XCTAssertNotNil(onboardingViewModel.errorMessage, "Should have error message")
        XCTAssertFalse(onboardingViewModel.isLoading, "Should not be loading")
        
        // And: App state should remain unauthenticated
        XCTAssertFalse(appState.isAuthenticated, "Should remain unauthenticated")
        XCTAssertNil(appState.currentUser, "Should have no current user")
        XCTAssertEqual(appState.currentFlow, .onboarding, "Should remain in onboarding flow")
        
        // And: No authentication data should be stored
        XCTAssertFalse(mockKeychainService.hasStoredAppleUserId(), "Should not store Apple user ID")
        XCTAssertFalse(mockKeychainService.hasStoredAppleUserIdHash(), "Should not store Apple user ID hash")
    }
    
    /// Test onboarding flow with network error
    /// Requirements: 5.1 - Complete onboarding flow with authentication
    func testOnboardingFlowWithNetworkError() async {
        // Given: Mock auth service configured for network error
        mockAuthService.setNetworkAvailable(false)
        mockAuthService.setError(.networkUnavailable)
        
        // When: User attempts Apple ID authentication
        await onboardingViewModel.signInWithApple()
        
        // Then: Authentication should fail with network error
        XCTAssertFalse(onboardingViewModel.authenticationSucceeded, "Authentication should fail")
        XCTAssertNotNil(onboardingViewModel.errorMessage, "Should have error message")
        XCTAssertTrue(onboardingViewModel.errorMessage?.contains("network") == true, "Should indicate network error")
        
        // And: App state should remain unauthenticated
        XCTAssertFalse(appState.isAuthenticated, "Should remain unauthenticated")
        XCTAssertEqual(appState.currentFlow, .onboarding, "Should remain in onboarding flow")
    }
    
    // MARK: - Authentication Persistence Tests
    
    /// Test authentication persistence across app launches
    /// Requirements: 5.4 - Authentication persistence across app launches
    func testAuthenticationPersistenceAcrossAppLaunches() async {
        // Given: User is authenticated and data is stored
        await authenticateUserAndStoreData()
        
        // When: App is "relaunched" (simulate by creating new AppState and checking existing auth)
        let newAppState = AppState()
        let newAuthService = MockAuthService()
        newAuthService.setMockDependencies(
            keychainService: mockKeychainService,
            dataService: mockDataService
        )
        
        // Configure stored authentication data
        mockKeychainService.setStoredAppleUserId("stored.apple.user.id")
        mockKeychainService.setStoredAppleUserIdHash("stored_hash_value")
        mockDataService.prePopulateUser(
            createTestUser(name: "Persisted User"),
            withHash: "stored_hash_value"
        )
        
        // Check existing authentication
        await newAuthService.checkExistingAuthentication()
        
        // Then: Authentication should be restored
        XCTAssertTrue(newAuthService.isAuthenticated, "Should restore authentication")
        XCTAssertNotNil(newAuthService.currentUser, "Should restore current user")
        XCTAssertEqual(newAuthService.currentUser?.displayName, "Persisted User", "Should restore correct user")
        
        // And: Call counts should reflect persistence check
        XCTAssertEqual(newAuthService.checkAuthCallCount, 1, "Should check existing auth once")
        XCTAssertEqual(newAuthService.signInCallCount, 0, "Should not perform new sign in")
    }
    
    /// Test authentication persistence with invalid stored data
    /// Requirements: 5.4 - Authentication persistence across app launches
    func testAuthenticationPersistenceWithInvalidStoredData() async {
        // Given: Invalid stored authentication data
        mockKeychainService.setStoredAppleUserId("invalid.apple.user.id")
        mockKeychainService.setStoredAppleUserIdHash("invalid_hash")
        // Don't populate user data in mock data service
        
        let authService = MockAuthService()
        authService.setMockDependencies(
            keychainService: mockKeychainService,
            dataService: mockDataService
        )
        
        // When: Checking existing authentication
        await authService.checkExistingAuthentication()
        
        // Then: Authentication should not be restored
        XCTAssertFalse(authService.isAuthenticated, "Should not restore invalid authentication")
        XCTAssertNil(authService.currentUser, "Should not restore user with invalid data")
        
        // And: Stored data should be cleared
        XCTAssertFalse(mockKeychainService.hasStoredAppleUserId(), "Should clear invalid Apple user ID")
        XCTAssertFalse(mockKeychainService.hasStoredAppleUserIdHash(), "Should clear invalid hash")
    }
    
    /// Test authentication persistence with expired credentials
    /// Requirements: 5.4 - Authentication persistence across app launches
    func testAuthenticationPersistenceWithExpiredCredentials() async {
        // Given: Stored authentication data but expired Apple credentials
        mockKeychainService.setStoredAppleUserId("expired.apple.user.id")
        mockKeychainService.setStoredAppleUserIdHash("expired_hash")
        mockDataService.prePopulateUser(
            createTestUser(name: "Expired User"),
            withHash: "expired_hash"
        )
        
        let authService = MockAuthService()
        authService.setAppleCredentialState(.revoked) // Simulate expired credentials
        authService.setMockDependencies(
            keychainService: mockKeychainService,
            dataService: mockDataService
        )
        
        // When: Checking existing authentication
        await authService.checkExistingAuthentication()
        
        // Then: Authentication should not be restored
        XCTAssertFalse(authService.isAuthenticated, "Should not restore expired authentication")
        XCTAssertNil(authService.currentUser, "Should not restore user with expired credentials")
        
        // And: Stored data should be cleared
        XCTAssertFalse(mockKeychainService.hasStoredAppleUserId(), "Should clear expired Apple user ID")
        XCTAssertFalse(mockKeychainService.hasStoredAppleUserIdHash(), "Should clear expired hash")
    }
    
    // MARK: - Offline/Online State Transition Tests
    
    /// Test authentication with offline to online state transition
    /// Requirements: 5.5 - Authentication with offline/online state transitions
    func testAuthenticationOfflineToOnlineTransition() async {
        // Given: User is authenticated while offline
        mockAuthService.setNetworkAvailable(false)
        await authenticateUserAndStoreData()
        
        XCTAssertTrue(appState.isAuthenticated, "Should be authenticated offline")
        XCTAssertNotNil(appState.currentUser, "Should have current user offline")
        
        // When: Network becomes available
        mockAuthService.setNetworkAvailable(true)
        
        // And: App checks authentication status
        await mockAuthService.checkExistingAuthentication()
        
        // Then: Authentication should remain valid
        XCTAssertTrue(mockAuthService.isAuthenticated, "Should remain authenticated online")
        XCTAssertNotNil(mockAuthService.currentUser, "Should keep current user online")
        
        // And: Authentication state should be consistent
        XCTAssertEqual(mockAuthService.currentUser?.displayName, "Integration Test User", "Should maintain same user")
    }
    
    /// Test authentication with online to offline state transition
    /// Requirements: 5.5 - Authentication with offline/online state transitions
    func testAuthenticationOnlineToOfflineTransition() async {
        // Given: User is authenticated while online
        mockAuthService.setNetworkAvailable(true)
        await authenticateUserAndStoreData()
        
        XCTAssertTrue(appState.isAuthenticated, "Should be authenticated online")
        
        // When: Network becomes unavailable
        mockAuthService.setNetworkAvailable(false)
        
        // And: App checks authentication status
        let isStillAuthenticated = mockAuthService.checkAuthenticationStatus()
        
        // Then: Authentication should remain valid offline
        XCTAssertTrue(isStillAuthenticated, "Should remain authenticated offline")
        XCTAssertTrue(mockAuthService.isAuthenticated, "Should maintain authentication state")
        XCTAssertNotNil(mockAuthService.currentUser, "Should keep current user offline")
    }
    
    /// Test authentication failure during offline state
    /// Requirements: 5.5 - Authentication with offline/online state transitions
    func testAuthenticationFailureDuringOfflineState() async {
        // Given: User attempts authentication while offline
        mockAuthService.setNetworkAvailable(false)
        mockAuthService.setError(.networkUnavailable)
        
        // When: User attempts to sign in
        await onboardingViewModel.signInWithApple()
        
        // Then: Authentication should fail with network error
        XCTAssertFalse(onboardingViewModel.authenticationSucceeded, "Should fail authentication offline")
        XCTAssertNotNil(onboardingViewModel.errorMessage, "Should have network error message")
        XCTAssertTrue(onboardingViewModel.errorMessage?.contains("network") == true, "Should indicate network issue")
        
        // And: App state should remain unauthenticated
        XCTAssertFalse(appState.isAuthenticated, "Should remain unauthenticated")
        XCTAssertNil(appState.currentUser, "Should have no current user")
    }
    
    /// Test authentication recovery when network returns
    /// Requirements: 5.5 - Authentication with offline/online state transitions
    func testAuthenticationRecoveryWhenNetworkReturns() async {
        // Given: Authentication failed due to network issues
        mockAuthService.setNetworkAvailable(false)
        mockAuthService.setError(.networkUnavailable)
        await onboardingViewModel.signInWithApple()
        
        XCTAssertFalse(onboardingViewModel.authenticationSucceeded, "Should fail initially")
        
        // When: Network becomes available and user retries
        mockAuthService.setNetworkAvailable(true)
        mockAuthService.shouldSucceed = true
        mockAuthService.setError(.authorizationFailed) // Reset error
        
        // Clear previous error state
        onboardingViewModel.clearError()
        
        // Retry authentication
        await onboardingViewModel.signInWithApple()
        
        // Then: Authentication should succeed
        XCTAssertTrue(onboardingViewModel.authenticationSucceeded, "Should succeed when network returns")
        XCTAssertNil(onboardingViewModel.errorMessage, "Should have no error message")
        XCTAssertTrue(appState.isAuthenticated, "Should be authenticated")
        XCTAssertNotNil(appState.currentUser, "Should have current user")
    }
    
    // MARK: - Helper Methods
    
    /// Authenticate user and store data for testing
    private func authenticateUserAndStoreData() async {
        // Configure mock services for successful authentication
        mockAuthService.shouldSucceed = true
        mockAuthService.setNetworkAvailable(true)
        
        // Perform authentication
        await onboardingViewModel.signInWithApple()
        
        // Verify authentication succeeded
        XCTAssertTrue(onboardingViewModel.authenticationSucceeded, "Authentication should succeed in setup")
        XCTAssertTrue(appState.isAuthenticated, "App state should be authenticated in setup")
    }
    
    /// Verify authentication state is consistent across services
    private func verifyAuthenticationStateConsistency() {
        let authServiceState = mockAuthService.checkAuthenticationStatus()
        let appStateAuthenticated = appState.isAuthenticated
        let hasCurrentUser = appState.currentUser != nil
        
        XCTAssertEqual(authServiceState, appStateAuthenticated, "Auth service and app state should be consistent")
        XCTAssertEqual(appStateAuthenticated, hasCurrentUser, "Authentication state and current user should be consistent")
    }
    
    /// Create test expectation for async operations
    private func createTestExpectation(description: String, timeout: TimeInterval = 5.0) -> XCTestExpectation {
        return expectation(description: description)
    }
}

// MARK: - Mock Services for Integration Testing

/// Mock CloudKit service for integration testing
private class MockCloudKitService {
    var shouldSucceed: Bool = true
    var errorToThrow: Error = CloudKitError.networkUnavailable
    
    func save<T>(_ record: T) async throws {
        if !shouldSucceed {
            throw errorToThrow
        }
        // Simulate successful save
    }
    
    func fetchFamily(byCode code: String) async throws -> CKRecord? {
        if !shouldSucceed {
            throw errorToThrow
        }
        return nil // Simulate not found for integration tests
    }
    
    func fetchActiveMemberships(forFamilyId familyId: String) async throws -> [CKRecord] {
        if !shouldSucceed {
            throw errorToThrow
        }
        return [] // Return empty for integration tests
    }
}

/// Mock Sync Manager for integration testing
private class MockSyncManager {
    var isOfflineMode: Bool = false
    
    func markRecordForSync<T>(_ record: T) {
        // Simulate marking for sync
    }
}

/// Mock QR Code Service for integration testing
private class MockQRCodeService {
    func generateQRCode(from code: String) -> Image? {
        // Return nil for integration tests
        return nil
    }
}

/// Mock Code Generator for integration testing
private class MockCodeGenerator {
    func generateUniqueCodeSafely(
        checkLocal: (String) throws -> Bool,
        checkRemote: (String) async throws -> Bool
    ) async throws -> String {
        return "TEST123" // Return fixed code for integration tests
    }
}

/// CloudKit error types for testing
enum CloudKitError: LocalizedError {
    case networkUnavailable
    case syncFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return "Network unavailable"
        case .syncFailed(let error):
            return "Sync failed: \(error.localizedDescription)"
        }
    }
}