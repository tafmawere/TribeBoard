import XCTest
import SwiftUI
@testable import TribeBoard

/// Tests for navigation safety mechanisms and error handling
@MainActor
class NavigationSafetyTests: XCTestCase {
    
    var appState: AppState!
    var navigationManager: NavigationStateManager!
    var mockUser: UserProfile!
    var mockFamily: Family!
    var mockMembership: Membership!
    
    override func setUp() {
        super.setUp()
        
        // Create test data
        mockUser = UserProfile(
            name: "Test User",
            email: "test@example.com",
            phoneNumber: "1234567890"
        )
        
        mockFamily = Family(
            name: "Test Family",
            code: "TEST123"
        )
        
        mockMembership = Membership(
            family: mockFamily,
            user: mockUser,
            role: .parentAdmin,
            status: .active
        )
        
        // Initialize AppState
        appState = AppState()
        appState.isAuthenticated = true
        appState.currentUser = mockUser
        appState.currentFamily = mockFamily
        appState.currentMembership = mockMembership
        
        // Initialize NavigationStateManager
        navigationManager = NavigationStateManager(appState: appState)
    }
    
    override func tearDown() {
        appState = nil
        navigationManager = nil
        mockUser = nil
        mockFamily = nil
        mockMembership = nil
        super.tearDown()
    }
    
    // MARK: - NavigationStateManager Tests
    
    @MainActor func testNavigationManagerInitialization() {
        XCTAssertNotNil(navigationManager)
        XCTAssertTrue(navigationManager.isAtRoot)
        XCTAssertEqual(navigationManager.navigationDepth, 0)
        XCTAssertNil(navigationManager.navigationError)
    }
    
    @MainActor func testSuccessfulNavigation() {
        // Test navigation to dashboard
        navigationManager.navigate(to: .dashboard)
        
        XCTAssertEqual(navigationManager.navigationDepth, 1)
        XCTAssertEqual(navigationManager.currentRoute, .dashboard)
        XCTAssertNil(navigationManager.navigationError)
        XCTAssertFalse(navigationManager.isAtRoot)
    }
    
    @MainActor func testNavigationWithInvalidAppState() {
        // Create manager with nil app state
        let invalidManager = NavigationStateManager(appState: nil)
        
        invalidManager.navigate(to: .dashboard)
        
        XCTAssertEqual(invalidManager.navigationError, .invalidAppState)
        XCTAssertTrue(invalidManager.isAtRoot)
    }
    
    @MainActor func testNavigationStackOverflow() {
        // Add routes up to the limit
        for i in 0..<10 {
            navigationManager.navigate(to: .dashboard)
        }
        
        // Try to add one more (should fail)
        navigationManager.navigate(to: .scheduleNew)
        
        XCTAssertEqual(navigationManager.navigationError, .navigationStackOverflow)
        XCTAssertEqual(navigationManager.navigationDepth, 10)
    }
    
    @MainActor func testNavigateBack() {
        // Navigate to a route first
        navigationManager.navigate(to: .dashboard)
        navigationManager.navigate(to: .scheduledList)
        
        XCTAssertEqual(navigationManager.navigationDepth, 2)
        
        // Navigate back
        navigationManager.navigateBack()
        
        XCTAssertEqual(navigationManager.navigationDepth, 1)
        XCTAssertEqual(navigationManager.currentRoute, .dashboard)
    }
    
    @MainActor func testNavigateBackFromRoot() {
        // Try to navigate back from root
        navigationManager.navigateBack()
        
        XCTAssertEqual(navigationManager.navigationError, .cannotNavigateBack)
        XCTAssertTrue(navigationManager.isAtRoot)
    }
    
    @MainActor func testResetToRoot() {
        // Navigate to multiple routes
        navigationManager.navigate(to: .dashboard)
        navigationManager.navigate(to: .scheduledList)
        navigationManager.navigate(to: .scheduleNew)
        
        XCTAssertEqual(navigationManager.navigationDepth, 3)
        
        // Reset to root
        navigationManager.resetToRoot()
        
        XCTAssertTrue(navigationManager.isAtRoot)
        XCTAssertEqual(navigationManager.navigationDepth, 0)
        XCTAssertEqual(navigationManager.currentRoute, .dashboard)
    }
    
    @MainActor func testNavigateAndReset() {
        // Navigate to multiple routes first
        navigationManager.navigate(to: .dashboard)
        navigationManager.navigate(to: .scheduledList)
        
        // Navigate and reset
        navigationManager.navigateAndReset(to: .scheduleNew)
        
        XCTAssertEqual(navigationManager.navigationDepth, 1)
        XCTAssertEqual(navigationManager.currentRoute, .scheduleNew)
    }
    
    // MARK: - Permission-Based Navigation Tests
    
    @MainActor func testNavigationWithInsufficientPermissions() {
        // Set user as kid (cannot create runs)
        appState.currentMembership = Membership(
            family: mockFamily,
            user: mockUser,
            role: .kid,
            status: .active
        )
        
        navigationManager.setAppState(appState)
        navigationManager.navigate(to: .scheduleNew)
        
        XCTAssertEqual(navigationManager.navigationError, .insufficientPermissions)
        XCTAssertTrue(navigationManager.isAtRoot)
    }
    
    @MainActor func testNavigationWithSufficientPermissions() {
        // Parent admin should be able to create runs
        navigationManager.navigate(to: .scheduleNew)
        
        XCTAssertNil(navigationManager.navigationError)
        XCTAssertEqual(navigationManager.currentRoute, .scheduleNew)
    }
    
    @MainActor func testRunExecutionPermissions() {
        // Test with kid (should fail)
        appState.currentMembership = Membership(
            family: mockFamily,
            user: mockUser,
            role: .kid,
            status: .active
        )
        
        let testRun = ScheduledSchoolRun(
            name: "Test Run",
            scheduledDate: Date(),
            scheduledTime: Date(),
            stops: []
        )
        
        navigationManager.setAppState(appState)
        navigationManager.navigate(to: .runExecution(testRun))
        
        XCTAssertEqual(navigationManager.navigationError, .insufficientPermissions)
    }
    
    // MARK: - AppState Navigation Extension Tests
    
    @MainActor func testAppStateSafeNavigation() {
        appState.safeNavigate(to: .dashboard)
        
        XCTAssertEqual(appState.navigationPath.count, 1)
        XCTAssertNil(appState.getCurrentNavigationError())
    }
    
    @MainActor func testAppStateNavigationValidation() {
        // Test with valid state
        let result = appState.validateNavigationState()
        if case .valid = result {
            XCTAssertTrue(true)
        } else {
            XCTFail("Navigation state should be valid")
        }
        
        // Test with invalid state (not authenticated)
        appState.isAuthenticated = false
        let invalidResult = appState.validateNavigationState()
        if case .invalid(let reason) = invalidResult {
            XCTAssertEqual(reason, .notAuthenticated)
        } else {
            XCTFail("Navigation state should be invalid")
        }
    }
    
    @MainActor func testAppStateCanAccessRoute() {
        // Test dashboard access (should be true for all)
        XCTAssertTrue(appState.canAccess(route: .dashboard))
        XCTAssertTrue(appState.canAccess(route: .scheduledList))
        
        // Test schedule new access (should be true for parent admin)
        XCTAssertTrue(appState.canAccess(route: .scheduleNew))
        
        // Test with kid
        appState.currentMembership = Membership(
            family: mockFamily,
            user: mockUser,
            role: .kid,
            status: .active
        )
        
        XCTAssertFalse(appState.canAccess(route: .scheduleNew))
        XCTAssertTrue(appState.canAccess(route: .dashboard)) // Still can access dashboard
    }
    
    @MainActor func testAppStateSafeTabSelection() {
        appState.safeSelectTab(.schoolRun)
        
        XCTAssertEqual(appState.selectedNavigationTab, .schoolRun)
        XCTAssertNil(appState.getCurrentNavigationError())
    }
    
    @MainActor func testAppStateNavigationErrorHandling() {
        // Simulate navigation error
        let error = NavigationError.insufficientPermissions
        appState.handleNavigationError(error)
        
        XCTAssertNotNil(appState.errorMessage)
        XCTAssertEqual(appState.currentFlow, .familyDashboard)
        XCTAssertEqual(appState.selectedNavigationTab, .dashboard)
    }
    
    // MARK: - Error Recovery Tests
    
    @MainActor func testNavigationErrorRecovery() {
        // Create an error condition
        navigationManager.navigate(to: .scheduleNew)
        
        // Simulate insufficient permissions error
        navigationManager.navigationError = .insufficientPermissions
        
        // Attempt recovery
        navigationManager.attemptRecovery()
        
        XCTAssertNil(navigationManager.navigationError)
        XCTAssertTrue(navigationManager.isAtRoot)
    }
    
    @MainActor func testAppStateNavigationRecovery() {
        // Set up error condition
        appState.handleNavigationError(.navigationStackOverflow)
        
        // Attempt recovery
        appState.attemptNavigationRecovery()
        
        XCTAssertNil(appState.getCurrentNavigationError())
        XCTAssertNil(appState.errorMessage)
    }
    
    // MARK: - Navigation State Synchronization Tests
    
    @MainActor func testNavigationStateSynchronization() {
        // Navigate using AppState
        appState.safeNavigate(to: .dashboard)
        appState.safeNavigate(to: .scheduledList)
        
        // Check synchronization
        let manager = appState.getNavigationStateManager()
        XCTAssertEqual(appState.navigationPath.count, manager.navigationPath.count)
        XCTAssertEqual(manager.currentRoute, .scheduledList)
    }
    
    @MainActor func testNavigationStateQueries() {
        XCTAssertTrue(appState.isAtNavigationRoot())
        XCTAssertFalse(appState.canNavigateBack())
        XCTAssertEqual(appState.getNavigationDepth(), 0)
        
        // Navigate and test again
        appState.safeNavigate(to: .dashboard)
        
        XCTAssertFalse(appState.isAtNavigationRoot())
        XCTAssertTrue(appState.canNavigateBack())
        XCTAssertEqual(appState.getNavigationDepth(), 1)
    }
    
    // MARK: - Role Permission Tests
    
    @MainActor func testRolePermissions() {
        // Test parent admin permissions
        XCTAssertTrue(Role.parentAdmin.canCreateSchoolRuns)
        XCTAssertTrue(Role.parentAdmin.canExecuteSchoolRuns)
        
        // Test adult permissions
        XCTAssertTrue(Role.adult.canCreateSchoolRuns)
        XCTAssertTrue(Role.adult.canExecuteSchoolRuns)
        
        // Test kid permissions
        XCTAssertFalse(Role.kid.canCreateSchoolRuns)
        XCTAssertFalse(Role.kid.canExecuteSchoolRuns)
        
        // Test visitor permissions
        XCTAssertFalse(Role.visitor.canCreateSchoolRuns)
        XCTAssertFalse(Role.visitor.canExecuteSchoolRuns)
    }
    
    // MARK: - Edge Case Tests
    
    @MainActor func testNavigationWithMissingFamily() {
        appState.currentFamily = nil
        
        let result = appState.validateNavigationState()
        if case .invalid(let reason) = result {
            XCTAssertEqual(reason, .noFamilyMembership)
        } else {
            XCTFail("Should be invalid without family")
        }
    }
    
    @MainActor func testNavigationWithMissingUser() {
        appState.currentUser = nil
        
        let result = appState.validateNavigationState()
        if case .invalid(let reason) = result {
            XCTAssertEqual(reason, .noUserProfile)
        } else {
            XCTFail("Should be invalid without user")
        }
    }
    
    @MainActor func testNavigationWithMissingMembership() {
        appState.currentMembership = nil
        
        let result = appState.validateNavigationState()
        if case .invalid(let reason) = result {
            XCTAssertEqual(reason, .noMembershipRole)
        } else {
            XCTFail("Should be invalid without membership")
        }
    }
    
    // MARK: - Performance Tests
    
    @MainActor func testNavigationPerformance() {
        measure {
            for _ in 0..<100 {
                appState.safeNavigate(to: .dashboard)
                appState.safeNavigateBack()
            }
        }
    }
    
    @MainActor func testValidationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = appState.validateNavigationState()
            }
        }
    }
}