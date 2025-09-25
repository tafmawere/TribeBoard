import XCTest
import SwiftData
@testable import TribeBoard

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    
    var viewModel: OnboardingViewModel!
    var mockAuthService: MockAuthService!
    var mockAppState: OnboardingMockAppState!
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockAuthService = MockAuthService()
        mockAppState = OnboardingMockAppState()
        viewModel = OnboardingViewModel(authService: mockAuthService, appState: mockAppState)
    }
    
    override func tearDown() async throws {
        viewModel = nil
        mockAuthService = nil
        mockAppState = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    @MainActor func testInitialization() {
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.authenticationSucceeded)
    }
    
    // MARK: - Sign In Tests
    
    func testSignInWithApple_Success() async {
        // Setup mock to succeed
        let testUser = UserProfile(displayName: "Test User", appleUserIdHash: "test_hash")
        mockAuthService.mockUser = testUser
        mockAuthService.shouldSucceed = true
        
        // Perform sign in
        await viewModel.signInWithApple()
        
        // Verify success state
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.authenticationSucceeded)
        XCTAssertTrue(mockAppState.signInCalled)
        XCTAssertEqual(mockAppState.signedInUser?.id, testUser.id)
    }
    
    func testSignInWithApple_AuthServiceFailure() async {
        // Setup mock to fail
        mockAuthService.shouldSucceed = false
        mockAuthService.errorToThrow = AuthError.authorizationFailed
        
        // Perform sign in
        await viewModel.signInWithApple()
        
        // Verify failure state
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.authenticationSucceeded)
        XCTAssertFalse(mockAppState.signInCalled)
    }
    
    func testSignInWithApple_NoUserReturned() async {
        // Setup mock to succeed but return no user
        mockAuthService.shouldSucceed = true
        mockAuthService.mockUser = nil
        
        // Perform sign in
        await viewModel.signInWithApple()
        
        // Verify failure state
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.authenticationSucceeded)
        XCTAssertFalse(mockAppState.signInCalled)
    }
    
    func testSignInWithApple_LoadingState() async {
        // Setup mock with delay
        mockAuthService.shouldDelay = true
        
        // Start sign in
        let signInTask = Task {
            await viewModel.signInWithApple()
        }
        
        // Check loading state immediately
        do {
            try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        } catch {
            // Ignore sleep errors in tests
        }
        XCTAssertTrue(viewModel.isLoading)
        
        // Wait for completion
        await signInTask.value
        XCTAssertFalse(viewModel.isLoading)
    }
    
    // MARK: - Error Handling Tests
    
    @MainActor func testClearError() {
        // Set an error
        viewModel.errorMessage = "Test error"
        XCTAssertNotNil(viewModel.errorMessage)
        
        // Clear error
        viewModel.clearError()
        XCTAssertNil(viewModel.errorMessage)
    }
    
    @MainActor func testSetAppState() {
        let newAppState = OnboardingMockAppState()
        viewModel.setAppState(newAppState)
        
        // Test that app state is used in sign in
        let testUser = UserProfile(displayName: "Test User", appleUserIdHash: "test_hash")
        mockAuthService.mockUser = testUser
        mockAuthService.shouldSucceed = true
        
        Task {
            await viewModel.signInWithApple()
            XCTAssertTrue(newAppState.signInCalled)
        }
    }
}

// MARK: - Mock Classes

class MockAuthService: AuthService {
    var shouldSucceed = true
    var shouldDelay = false
    var mockUser: UserProfile?
    var errorToThrow: Error?
    
    init() {
        super.init()
    }
    
    override func signInWithApple() async throws {
        if shouldDelay {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        if !shouldSucceed {
            throw errorToThrow ?? AuthError.authorizationFailed
        }
        
        if let user = mockUser {
            self.currentUser = user
            self.isAuthenticated = true
        }
    }
    
    override func getCurrentUser() -> UserProfile? {
        return mockUser
    }
}

class OnboardingMockAppState: AppState {
    var signInCalled = false
    var signedInUser: UserProfile?
    
    override init() {
        super.init()
    }
    
    override func signIn(user: UserProfile) {
        signInCalled = true
        signedInUser = user
        super.signIn(user: user)
    }
}

class MockDataService: DataService {
    init() {
        // Create a mock model context
        let container = try! ModelContainerConfiguration.createInMemory()
        super.init(modelContext: container.mainContext)
    }
}