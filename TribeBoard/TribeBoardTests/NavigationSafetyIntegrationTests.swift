import XCTest
import SwiftUI
@testable import TribeBoard

/// Integration tests for navigation safety mechanisms
@MainActor
class NavigationSafetyIntegrationTests: XCTestCase {
    
    var appState: AppState!
    
    override func setUp() {
        super.setUp()
        appState = AppState()
    }
    
    override func tearDown() {
        appState = nil
        super.tearDown()
    }
    
    // MARK: - Basic Integration Tests
    
    @MainActor func testNavigationManagerIntegration() {
        // Test that AppState can create and use navigation manager
        let manager = appState.getNavigationStateManager()
        
        XCTAssertNotNil(manager)
        XCTAssertTrue(manager.isAtRoot)
        XCTAssertEqual(manager.navigationDepth, 0)
    }
    
    @MainActor func testSafeNavigationWithValidState() {
        // Set up valid app state
        setupValidAppState()
        
        // Test safe navigation
        appState.safeNavigate(to: .dashboard)
        
        XCTAssertEqual(appState.navigationPath.count, 1)
        XCTAssertNil(appState.getCurrentNavigationError())
    }
    
    @MainActor func testSafeNavigationWithInvalidState() {
        // Don't set up app state (invalid)
        
        // Test safe navigation with invalid state
        appState.safeNavigate(to: .dashboard)
        
        // Should handle error gracefully
        XCTAssertNotNil(appState.getCurrentNavigationError())
    }
    
    @MainActor func testNavigationValidation() {
        // Test with invalid state
        let invalidResult = appState.validateNavigationState()
        if case .invalid(let reason) = invalidResult {
            XCTAssertEqual(reason, .notAuthenticated)
        } else {
            XCTFail("Should be invalid when not authenticated")
        }
        
        // Set up valid state
        setupValidAppState()
        
        // Test with valid state
        let validResult = appState.validateNavigationState()
        if case .valid = validResult {
            XCTAssertTrue(true)
        } else {
            XCTFail("Should be valid with proper setup")
        }
    }
    
    @MainActor func testRouteAccessControl() {
        setupValidAppState()
        
        // Test basic routes (should be accessible)
        XCTAssertTrue(appState.canAccess(route: .dashboard))
        XCTAssertTrue(appState.canAccess(route: .scheduledList))
        
        // Test admin routes (should be accessible for parent admin)
        XCTAssertTrue(appState.canAccess(route: .scheduleNew))
        
        // Change to kid role
        let mockUser = UserProfile(displayName: "Test User", appleUserIdHash: "test123hash")
        let mockFamily = Family(name: "Test Family", code: "TEST123", createdByUserId: UUID())
        let kidMembership = Membership(family: mockFamily, user: mockUser, role: .kid)
        
        appState.currentUser = mockUser
        appState.currentMembership = kidMembership
        
        // Test that kid cannot access admin routes
        XCTAssertFalse(appState.canAccess(route: .scheduleNew))
        XCTAssertTrue(appState.canAccess(route: .dashboard)) // Still can access basic routes
    }
    
    @MainActor func testNavigationErrorHandling() {
        setupValidAppState()
        
        // Test error handling
        let error = NavigationError.insufficientPermissions
        appState.handleNavigationError(error)
        
        // Should show error message and navigate to safe location
        XCTAssertNotNil(appState.errorMessage)
        XCTAssertEqual(appState.currentFlow, .familyDashboard)
        XCTAssertEqual(appState.selectedNavigationTab, .dashboard)
    }
    
    @MainActor func testNavigationRecovery() {
        setupValidAppState()
        
        // Simulate navigation error
        appState.handleNavigationError(.navigationStackOverflow)
        
        // Attempt recovery
        appState.attemptNavigationRecovery()
        
        // Should clear error and reset navigation
        XCTAssertNil(appState.getCurrentNavigationError())
        XCTAssertTrue(appState.isAtNavigationRoot())
    }
    
    @MainActor func testSafeTabSelection() {
        setupValidAppState()
        
        // Test safe tab selection
        appState.safeSelectTab(.schoolRun)
        
        XCTAssertEqual(appState.selectedNavigationTab, .schoolRun)
        XCTAssertNil(appState.getCurrentNavigationError())
    }
    
    @MainActor func testNavigationStateQueries() {
        setupValidAppState()
        
        // Test initial state
        XCTAssertTrue(appState.isAtNavigationRoot())
        XCTAssertFalse(appState.canNavigateBack())
        XCTAssertEqual(appState.getNavigationDepth(), 0)
        XCTAssertFalse(appState.isNavigating())
        
        // Navigate and test again
        appState.safeNavigate(to: .dashboard)
        
        XCTAssertFalse(appState.isAtNavigationRoot())
        XCTAssertTrue(appState.canNavigateBack())
        XCTAssertEqual(appState.getNavigationDepth(), 1)
    }
    
    // MARK: - Error Scenario Tests
    
    @MainActor func testNavigationWithMissingFamily() {
        // Set up partially valid state (authenticated but no family)
        let mockUser = UserProfile(displayName: "Test User", appleUserIdHash: "test123hash")
        appState.isAuthenticated = true
        appState.currentUser = mockUser
        // Don't set family or membership
        
        let result = appState.validateNavigationState()
        if case .invalid(let reason) = result {
            XCTAssertEqual(reason, .noFamilyMembership)
        } else {
            XCTFail("Should be invalid without family")
        }
    }
    
    @MainActor func testNavigationWithMissingUser() {
        // Set up invalid state (authenticated but no user)
        appState.isAuthenticated = true
        // Don't set user
        
        let result = appState.validateNavigationState()
        if case .invalid(let reason) = result {
            XCTAssertEqual(reason, .noUserProfile)
        } else {
            XCTFail("Should be invalid without user")
        }
    }
    
    @MainActor func testNavigationWithMissingMembership() {
        // Set up partially valid state (user and family but no membership)
        let mockUser = UserProfile(displayName: "Test User", appleUserIdHash: "test123hash")
        let mockFamily = Family(name: "Test Family", code: "TEST123", createdByUserId: UUID())
        
        appState.isAuthenticated = true
        appState.currentUser = mockUser
        appState.currentFamily = mockFamily
        // Don't set membership
        
        let result = appState.validateNavigationState()
        if case .invalid(let reason) = result {
            XCTAssertEqual(reason, .noMembershipRole)
        } else {
            XCTFail("Should be invalid without membership")
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupValidAppState() {
        let mockUser = UserProfile(displayName: "Test User", appleUserIdHash: "test123hash")
        let mockFamily = Family(name: "Test Family", code: "TEST123", createdByUserId: UUID())
        let mockMembership = Membership(family: mockFamily, user: mockUser, role: .parentAdmin)
        
        appState.isAuthenticated = true
        appState.currentUser = mockUser
        appState.currentFamily = mockFamily
        appState.currentMembership = mockMembership
    }
}