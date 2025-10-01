import XCTest
import SwiftData
@testable import TribeBoard

/// Integration tests for user journey testing with authentication integration
/// Tests authentication integration with family creation, joining flows, and error recovery
@MainActor
class OnboardingIntegrationTests: TestBase {
    
    // MARK: - Properties
    
    private var appState: AppState!
    private var onboardingViewModel: OnboardingViewModel!
    private var createFamilyViewModel: CreateFamilyViewModel!
    private var joinFamilyViewModel: JoinFamilyViewModel!
    private var mockCloudKitService: MockCloudKitService!
    private var mockSyncManager: MockSyncManager!
    private var mockQRCodeService: MockQRCodeService!
    private var mockCodeGenerator: MockCodeGenerator!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        setupOnboardingIntegrationEnvironment()
    }
    
    override func tearDown() {
        cleanupOnboardingIntegrationEnvironment()
        super.tearDown()
    }
    
    // MARK: - Setup Methods
    
    private func setupOnboardingIntegrationEnvironment() {
        // Create mock services
        mockCloudKitService = MockCloudKitService()
        mockSyncManager = MockSyncManager()
        mockQRCodeService = MockQRCodeService()
        mockCodeGenerator = MockCodeGenerator()
        
        // Create AppState
        appState = AppState()
        
        // Create ViewModels with mock services
        onboardingViewModel = OnboardingViewModel(authService: mockAuthService)
        onboardingViewModel.setAppState(appState)
        
        createFamilyViewModel = CreateFamilyViewModel(
            dataService: mockDataService,
            cloudKitService: mockCloudKitService,
            syncManager: mockSyncManager,
            qrCodeService: mockQRCodeService,
            codeGenerator: mockCodeGenerator
        )
        
        joinFamilyViewModel = JoinFamilyViewModel(
            dataService: mockDataService,
            cloudKitService: mockCloudKitService,
            qrCodeService: mockQRCodeService
        )
        
        // Configure mock services for onboarding integration
        configureMockServicesForOnboarding()
    }
    
    private func configureMockServicesForOnboarding() {
        // Configure successful authentication by default
        mockAuthService.shouldSucceed = true
        mockAuthService.setMockUserProfile(createTestUser(name: "Onboarding Test User"))
        mockAuthService.setNetworkAvailable(true)
        
        // Configure data service
        mockDataService.shouldSucceed = true
        mockDataService.setUserToReturn(mockAuthService.mockUserProfile)
        
        // Configure CloudKit service
        mockCloudKitService.shouldSucceed = true
        
        // Set up dependencies
        mockAuthService.setMockDependencies(
            keychainService: mockKeychainService,
            dataService: mockDataService
        )
    }
    
    private func cleanupOnboardingIntegrationEnvironment() {
        appState = nil
        onboardingViewModel = nil
        createFamilyViewModel = nil
        joinFamilyViewModel = nil
        mockCloudKitService = nil
        mockSyncManager = nil
        mockQRCodeService = nil
        mockCodeGenerator = nil
    }
    
    // MARK: - Authentication Integration with Family Creation Tests
    
    /// Test authentication integration with family creation
    /// Requirements: 5.2 - Authentication integration with family creation
    func testAuthenticationIntegrationWithFamilyCreation() async {
        // Given: User starts onboarding flow
        XCTAssertFalse(appState.isAuthenticated, "Should start unauthenticated")
        XCTAssertEqual(appState.currentFlow, .onboarding, "Should start in onboarding")
        
        // When: User completes authentication
        await onboardingViewModel.signInWithApple()
        
        // Then: Authentication should succeed
        XCTAssertTrue(onboardingViewModel.authenticationSucceeded, "Authentication should succeed")
        XCTAssertTrue(appState.isAuthenticated, "Should be authenticated")
        XCTAssertNotNil(appState.currentUser, "Should have current user")
        
        // And: User navigates to family creation
        appState.navigateTo(.createFamily)
        XCTAssertEqual(appState.currentFlow, .createFamily, "Should navigate to family creation")
        
        // When: User creates a family
        createFamilyViewModel.familyName = "Test Integration Family"
        await createFamilyViewModel.createFamily(with: appState)
        
        // Then: Family creation should succeed
        XCTAssertTrue(createFamilyViewModel.isCompleted, "Family creation should complete")
        XCTAssertNotNil(createFamilyViewModel.createdFamily, "Should have created family")
        XCTAssertEqual(createFamilyViewModel.createdFamily?.name, "Test Integration Family", "Should have correct family name")
        
        // And: App state should be updated with family
        XCTAssertNotNil(appState.currentFamily, "Should have current family")
        XCTAssertNotNil(appState.currentMembership, "Should have current membership")
        XCTAssertEqual(appState.currentMembership?.role, .parentAdmin, "Creator should be parent admin")
        XCTAssertEqual(appState.currentFlow, .familyDashboard, "Should navigate to family dashboard")
        
        // And: Data should be persisted
        XCTAssertEqual(mockDataService.createFamilyCallCount, 1, "Should create family in data service")
        XCTAssertEqual(mockDataService.createMembershipCallCount, 1, "Should create membership in data service")
        XCTAssertTrue(mockKeychainService.hasStoredAppleUserId(), "Should store authentication data")
    }
    
    /// Test authentication integration with family creation failure
    /// Requirements: 5.2 - Authentication integration with family creation
    func testAuthenticationIntegrationWithFamilyCreationFailure() async {
        // Given: User is authenticated
        await authenticateUser()
        appState.navigateTo(.createFamily)
        
        // And: Family creation is configured to fail
        mockDataService.setShouldSucceed(false)
        mockDataService.setError(.invalidData("Family creation failed"))
        
        // When: User attempts to create a family
        createFamilyViewModel.familyName = "Test Failed Family"
        await createFamilyViewModel.createFamily(with: appState)
        
        // Then: Family creation should fail
        XCTAssertTrue(createFamilyViewModel.isFailed, "Family creation should fail")
        XCTAssertNotNil(createFamilyViewModel.currentError, "Should have error")
        XCTAssertNil(createFamilyViewModel.createdFamily, "Should not have created family")
        
        // And: App state should remain in creation flow
        XCTAssertEqual(appState.currentFlow, .createFamily, "Should remain in family creation")
        XCTAssertNil(appState.currentFamily, "Should not have current family")
        XCTAssertNil(appState.currentMembership, "Should not have current membership")
        
        // But: User should remain authenticated
        XCTAssertTrue(appState.isAuthenticated, "Should remain authenticated")
        XCTAssertNotNil(appState.currentUser, "Should keep current user")
    }
    
    /// Test authentication integration with family creation retry
    /// Requirements: 5.2 - Authentication integration with family creation
    func testAuthenticationIntegrationWithFamilyCreationRetry() async {
        // Given: User is authenticated
        await authenticateUser()
        appState.navigateTo(.createFamily)
        
        // And: Family creation fails initially
        mockDataService.setShouldSucceed(false)
        mockDataService.setError(.networkError("Network temporarily unavailable"))
        
        createFamilyViewModel.familyName = "Test Retry Family"
        await createFamilyViewModel.createFamily(with: appState)
        
        XCTAssertTrue(createFamilyViewModel.isFailed, "Initial creation should fail")
        XCTAssertTrue(createFamilyViewModel.canRetry, "Should allow retry")
        
        // When: Network recovers and user retries
        mockDataService.setShouldSucceed(true)
        await createFamilyViewModel.retryCreation(with: appState)
        
        // Then: Family creation should succeed on retry
        XCTAssertTrue(createFamilyViewModel.isCompleted, "Retry should succeed")
        XCTAssertNotNil(createFamilyViewModel.createdFamily, "Should have created family")
        XCTAssertEqual(appState.currentFlow, .familyDashboard, "Should navigate to dashboard")
        
        // And: User should remain authenticated throughout
        XCTAssertTrue(appState.isAuthenticated, "Should remain authenticated")
        XCTAssertNotNil(appState.currentUser, "Should keep current user")
    }
    
    // MARK: - Authentication Integration with Family Joining Tests
    
    /// Test authentication integration with family joining flows
    /// Requirements: 5.3 - Authentication integration with family joining flows
    func testAuthenticationIntegrationWithFamilyJoining() async {
        // Given: User is authenticated
        await authenticateUser()
        
        // And: A family exists to join
        let existingFamily = createTestFamily(name: "Existing Family")
        existingFamily.code = "JOIN123"
        mockDataService.prePopulateFamily(existingFamily)
        
        // When: User navigates to join family
        appState.navigateTo(.joinFamily)
        XCTAssertEqual(appState.currentFlow, .joinFamily, "Should navigate to join family")
        
        // And: User searches for family
        await joinFamilyViewModel.searchFamily(by: "JOIN123")
        
        // Then: Family should be found
        XCTAssertNotNil(joinFamilyViewModel.foundFamily, "Should find family")
        XCTAssertEqual(joinFamilyViewModel.foundFamily?.name, "Existing Family", "Should find correct family")
        XCTAssertTrue(joinFamilyViewModel.showConfirmation, "Should show confirmation")
        
        // When: User confirms joining
        await joinFamilyViewModel.joinFamily(with: appState)
        
        // Then: Join should succeed
        XCTAssertFalse(joinFamilyViewModel.isJoining, "Should complete joining")
        XCTAssertNil(joinFamilyViewModel.errorMessage, "Should have no error")
        
        // And: App state should be updated
        XCTAssertNotNil(appState.currentFamily, "Should have current family")
        XCTAssertNotNil(appState.currentMembership, "Should have current membership")
        XCTAssertEqual(appState.currentMembership?.role, .adult, "Joiner should be adult by default")
        XCTAssertEqual(appState.currentFlow, .familyDashboard, "Should navigate to dashboard")
        
        // And: User should remain authenticated
        XCTAssertTrue(appState.isAuthenticated, "Should remain authenticated")
        XCTAssertNotNil(appState.currentUser, "Should keep current user")
    }
    
    /// Test authentication integration with family joining failure
    /// Requirements: 5.3 - Authentication integration with family joining flows
    func testAuthenticationIntegrationWithFamilyJoiningFailure() async {
        // Given: User is authenticated
        await authenticateUser()
        appState.navigateTo(.joinFamily)
        
        // When: User searches for non-existent family
        await joinFamilyViewModel.searchFamily(by: "NOTFOUND")
        
        // Then: Family should not be found
        XCTAssertNil(joinFamilyViewModel.foundFamily, "Should not find family")
        XCTAssertNotNil(joinFamilyViewModel.errorMessage, "Should have error message")
        XCTAssertFalse(joinFamilyViewModel.showConfirmation, "Should not show confirmation")
        
        // And: App state should remain in join flow
        XCTAssertEqual(appState.currentFlow, .joinFamily, "Should remain in join family")
        XCTAssertNil(appState.currentFamily, "Should not have current family")
        XCTAssertNil(appState.currentMembership, "Should not have current membership")
        
        // But: User should remain authenticated
        XCTAssertTrue(appState.isAuthenticated, "Should remain authenticated")
        XCTAssertNotNil(appState.currentUser, "Should keep current user")
    }
    
    /// Test authentication integration with family joining network error
    /// Requirements: 5.3 - Authentication integration with family joining flows
    func testAuthenticationIntegrationWithFamilyJoiningNetworkError() async {
        // Given: User is authenticated
        await authenticateUser()
        appState.navigateTo(.joinFamily)
        
        // And: Network is unavailable
        mockCloudKitService.shouldSucceed = false
        mockCloudKitService.errorToThrow = CloudKitError.networkUnavailable
        
        // When: User searches for family
        await joinFamilyViewModel.searchFamily(by: "NET123")
        
        // Then: Search should fail with network error
        XCTAssertNil(joinFamilyViewModel.foundFamily, "Should not find family due to network error")
        XCTAssertNotNil(joinFamilyViewModel.errorMessage, "Should have network error message")
        XCTAssertTrue(joinFamilyViewModel.errorMessage?.contains("network") == true, "Should indicate network issue")
        
        // And: User should remain authenticated
        XCTAssertTrue(appState.isAuthenticated, "Should remain authenticated despite network error")
        XCTAssertNotNil(appState.currentUser, "Should keep current user")
    }
    
    // MARK: - Authentication Error Recovery Tests
    
    /// Test authentication error recovery in onboarding context
    /// Requirements: 5.6 - Authentication error recovery in onboarding context
    func testAuthenticationErrorRecoveryInOnboardingContext() async {
        // Given: Authentication fails initially
        mockAuthService.shouldSucceed = false
        mockAuthService.setError(.authorizationFailed)
        
        // When: User attempts authentication
        await onboardingViewModel.signInWithApple()
        
        // Then: Authentication should fail
        XCTAssertFalse(onboardingViewModel.authenticationSucceeded, "Initial authentication should fail")
        XCTAssertNotNil(onboardingViewModel.errorMessage, "Should have error message")
        XCTAssertFalse(appState.isAuthenticated, "Should remain unauthenticated")
        
        // When: User clears error and retries with fixed configuration
        onboardingViewModel.clearError()
        mockAuthService.shouldSucceed = true
        mockAuthService.setError(.authorizationFailed) // Reset error state
        
        await onboardingViewModel.signInWithApple()
        
        // Then: Authentication should succeed on retry
        XCTAssertTrue(onboardingViewModel.authenticationSucceeded, "Retry should succeed")
        XCTAssertNil(onboardingViewModel.errorMessage, "Should clear error message")
        XCTAssertTrue(appState.isAuthenticated, "Should be authenticated")
        XCTAssertNotNil(appState.currentUser, "Should have current user")
        
        // And: Should proceed to family selection
        XCTAssertEqual(appState.currentFlow, .familySelection, "Should navigate to family selection")
    }
    
    /// Test authentication error recovery during family operations
    /// Requirements: 5.6 - Authentication error recovery in onboarding context
    func testAuthenticationErrorRecoveryDuringFamilyOperations() async {
        // Given: User is authenticated and in family creation
        await authenticateUser()
        appState.navigateTo(.createFamily)
        
        // And: Authentication expires during family creation
        mockAuthService.simulateAuthenticationFailure(with: .tokenExpired)
        
        // When: User attempts family creation
        createFamilyViewModel.familyName = "Test Auth Recovery Family"
        await createFamilyViewModel.createFamily(with: appState)
        
        // Then: Family creation should fail due to auth error
        XCTAssertTrue(createFamilyViewModel.isFailed, "Family creation should fail")
        XCTAssertNotNil(createFamilyViewModel.currentError, "Should have error")
        
        // When: User re-authenticates
        mockAuthService.shouldSucceed = true
        mockAuthService.setError(.authorizationFailed) // Reset error state
        await onboardingViewModel.signInWithApple()
        
        // Then: Authentication should be restored
        XCTAssertTrue(onboardingViewModel.authenticationSucceeded, "Re-authentication should succeed")
        XCTAssertTrue(appState.isAuthenticated, "Should be authenticated again")
        
        // And: User can retry family creation
        createFamilyViewModel.resetCreationState()
        await createFamilyViewModel.createFamily(with: appState)
        
        XCTAssertTrue(createFamilyViewModel.isCompleted, "Family creation should succeed after re-auth")
        XCTAssertNotNil(appState.currentFamily, "Should have current family")
    }
    
    /// Test authentication error recovery with network issues
    /// Requirements: 5.6 - Authentication error recovery in onboarding context
    func testAuthenticationErrorRecoveryWithNetworkIssues() async {
        // Given: Network is unavailable during authentication
        mockAuthService.setNetworkAvailable(false)
        mockAuthService.setError(.networkUnavailable)
        
        // When: User attempts authentication
        await onboardingViewModel.signInWithApple()
        
        // Then: Authentication should fail with network error
        XCTAssertFalse(onboardingViewModel.authenticationSucceeded, "Should fail due to network")
        XCTAssertNotNil(onboardingViewModel.errorMessage, "Should have network error message")
        XCTAssertTrue(onboardingViewModel.errorMessage?.contains("network") == true, "Should indicate network issue")
        
        // When: Network recovers and user retries
        mockAuthService.setNetworkAvailable(true)
        mockAuthService.shouldSucceed = true
        onboardingViewModel.clearError()
        
        await onboardingViewModel.signInWithApple()
        
        // Then: Authentication should succeed
        XCTAssertTrue(onboardingViewModel.authenticationSucceeded, "Should succeed when network recovers")
        XCTAssertNil(onboardingViewModel.errorMessage, "Should clear error message")
        XCTAssertTrue(appState.isAuthenticated, "Should be authenticated")
        
        // And: User can proceed with onboarding
        XCTAssertEqual(appState.currentFlow, .familySelection, "Should proceed to family selection")
    }
    
    /// Test authentication error recovery with multiple error types
    /// Requirements: 5.6 - Authentication error recovery in onboarding context
    func testAuthenticationErrorRecoveryWithMultipleErrorTypes() async {
        // Given: Multiple error scenarios
        let errorScenarios: [(AuthError, String)] = [
            (.authorizationFailed, "authorization"),
            (.networkUnavailable, "network"),
            (.userCancelled, "cancelled"),
            (.tokenExpired, "token")
        ]
        
        for (error, expectedMessageContent) in errorScenarios {
            // Reset state for each test
            appState.signOut()
            onboardingViewModel.clearError()
            
            // Configure error
            mockAuthService.shouldSucceed = false
            mockAuthService.setError(error)
            
            // When: User attempts authentication
            await onboardingViewModel.signInWithApple()
            
            // Then: Authentication should fail with appropriate error
            XCTAssertFalse(onboardingViewModel.authenticationSucceeded, "Should fail with \(error)")
            XCTAssertNotNil(onboardingViewModel.errorMessage, "Should have error message for \(error)")
            
            // When: Error is resolved and user retries
            onboardingViewModel.clearError()
            mockAuthService.shouldSucceed = true
            mockAuthService.setNetworkAvailable(true)
            
            await onboardingViewModel.signInWithApple()
            
            // Then: Authentication should succeed
            XCTAssertTrue(onboardingViewModel.authenticationSucceeded, "Should recover from \(error)")
            XCTAssertNil(onboardingViewModel.errorMessage, "Should clear error for \(error)")
            XCTAssertTrue(appState.isAuthenticated, "Should be authenticated after recovering from \(error)")
        }
    }
    
    // MARK: - Complete User Journey Tests
    
    /// Test complete user journey from onboarding to family dashboard
    /// Requirements: 5.2, 5.3, 5.6 - Complete integration flow
    func testCompleteUserJourneyFromOnboardingToFamilyDashboard() async {
        // Given: User starts completely unauthenticated
        XCTAssertFalse(appState.isAuthenticated, "Should start unauthenticated")
        XCTAssertEqual(appState.currentFlow, .onboarding, "Should start in onboarding")
        
        // Step 1: User completes authentication
        await onboardingViewModel.signInWithApple()
        
        XCTAssertTrue(onboardingViewModel.authenticationSucceeded, "Authentication should succeed")
        XCTAssertTrue(appState.isAuthenticated, "Should be authenticated")
        XCTAssertEqual(appState.currentFlow, .familySelection, "Should navigate to family selection")
        
        // Step 2: User chooses to create a family
        appState.navigateTo(.createFamily)
        createFamilyViewModel.familyName = "Complete Journey Family"
        
        await createFamilyViewModel.createFamily(with: appState)
        
        XCTAssertTrue(createFamilyViewModel.isCompleted, "Family creation should complete")
        XCTAssertEqual(appState.currentFlow, .familyDashboard, "Should navigate to family dashboard")
        
        // Step 3: Verify final state
        XCTAssertTrue(appState.isAuthenticated, "Should remain authenticated")
        XCTAssertNotNil(appState.currentUser, "Should have current user")
        XCTAssertNotNil(appState.currentFamily, "Should have current family")
        XCTAssertNotNil(appState.currentMembership, "Should have current membership")
        XCTAssertEqual(appState.currentMembership?.role, .parentAdmin, "Should be parent admin")
        
        // Step 4: Verify data persistence
        XCTAssertTrue(mockKeychainService.hasStoredAppleUserId(), "Should store auth data")
        XCTAssertEqual(mockDataService.createFamilyCallCount, 1, "Should create family")
        XCTAssertEqual(mockDataService.createMembershipCallCount, 1, "Should create membership")
    }
    
    /// Test complete user journey with joining existing family
    /// Requirements: 5.2, 5.3, 5.6 - Complete integration flow
    func testCompleteUserJourneyWithJoiningExistingFamily() async {
        // Given: An existing family to join
        let existingFamily = createTestFamily(name: "Existing Journey Family")
        existingFamily.code = "JOURNEY123"
        mockDataService.prePopulateFamily(existingFamily)
        
        // Step 1: User authenticates
        await onboardingViewModel.signInWithApple()
        
        XCTAssertTrue(appState.isAuthenticated, "Should be authenticated")
        XCTAssertEqual(appState.currentFlow, .familySelection, "Should be in family selection")
        
        // Step 2: User chooses to join family
        appState.navigateTo(.joinFamily)
        
        await joinFamilyViewModel.searchFamily(by: "JOURNEY123")
        XCTAssertNotNil(joinFamilyViewModel.foundFamily, "Should find family")
        
        await joinFamilyViewModel.joinFamily(with: appState)
        
        // Step 3: Verify final state
        XCTAssertEqual(appState.currentFlow, .familyDashboard, "Should navigate to dashboard")
        XCTAssertTrue(appState.isAuthenticated, "Should remain authenticated")
        XCTAssertNotNil(appState.currentFamily, "Should have joined family")
        XCTAssertEqual(appState.currentFamily?.name, "Existing Journey Family", "Should join correct family")
        XCTAssertEqual(appState.currentMembership?.role, .adult, "Should be adult member")
        
        // Step 4: Verify data persistence
        XCTAssertTrue(mockKeychainService.hasStoredAppleUserId(), "Should store auth data")
        XCTAssertEqual(mockDataService.createMembershipCallCount, 1, "Should create membership")
    }
    
    // MARK: - Helper Methods
    
    /// Authenticate user for testing
    private func authenticateUser() async {
        mockAuthService.shouldSucceed = true
        mockAuthService.setNetworkAvailable(true)
        
        await onboardingViewModel.signInWithApple()
        
        XCTAssertTrue(onboardingViewModel.authenticationSucceeded, "Authentication should succeed in helper")
        XCTAssertTrue(appState.isAuthenticated, "Should be authenticated in helper")
    }
    
    /// Verify complete integration state
    private func verifyCompleteIntegrationState() {
        XCTAssertTrue(appState.isAuthenticated, "Should be authenticated")
        XCTAssertNotNil(appState.currentUser, "Should have current user")
        XCTAssertNotNil(appState.currentFamily, "Should have current family")
        XCTAssertNotNil(appState.currentMembership, "Should have current membership")
        XCTAssertEqual(appState.currentFlow, .familyDashboard, "Should be in family dashboard")
    }
}

// MARK: - Mock Services Extensions

/// Mock CloudKit service for onboarding integration testing
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
        return nil // Return nil for most tests
    }
    
    func fetchActiveMemberships(forFamilyId familyId: String) async throws -> [CKRecord] {
        if !shouldSucceed {
            throw errorToThrow
        }
        return [] // Return empty for tests
    }
}

/// Mock Sync Manager for onboarding integration testing
private class MockSyncManager {
    var isOfflineMode: Bool = false
    
    func markRecordForSync<T>(_ record: T) {
        // Simulate marking for sync
    }
}

/// Mock QR Code Service for onboarding integration testing
private class MockQRCodeService {
    func generateQRCode(from code: String) -> Image? {
        return nil // Return nil for tests
    }
}

/// Mock Code Generator for onboarding integration testing
private class MockCodeGenerator {
    func generateUniqueCodeSafely(
        checkLocal: (String) throws -> Bool,
        checkRemote: (String) async throws -> Bool
    ) async throws -> String {
        return "TEST123" // Return fixed code for tests
    }
}

/// CloudKit error types for onboarding testing
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

/// Auth error extension for testing
extension AuthError {
    static let tokenExpired = AuthError.authorizationFailed // Simulate token expiration
}