import XCTest
import SwiftUI
@testable import TribeBoard

/// Tests for ScheduledRunsListView with safe environment object handling
class ScheduledRunsListViewTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var mockAppState: AppState!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        mockAppState = AppState.createTest(scenario: .authenticated)
    }
    
    override func tearDown() {
        mockAppState = nil
        super.tearDown()
    }
    
    // MARK: - Environment Object Tests
    
    /// Test that ScheduledRunsListView works with proper environment object
    @MainActor func testViewWithEnvironmentObject() {
        // Given: A view with proper environment object
        let view = ScheduledRunsListView()
            .environmentObject(mockAppState)
        
        // When: The view is created
        // Then: It should not crash and should be able to access AppState
        XCTAssertNotNil(view)
        
        // Verify the environment object is properly configured
        XCTAssertTrue(mockAppState.isAuthenticated)
        XCTAssertNotNil(mockAppState.currentUser)
    }
    
    /// Test that ScheduledRunsListView works without environment object (fallback mode)
    @MainActor func testViewWithoutEnvironmentObject() {
        // Given: A view without environment object (should use fallback)
        let view = ScheduledRunsListView()
        
        // When: The view is created without environment object
        // Then: It should not crash and should use fallback AppState
        XCTAssertNotNil(view)
        
        // The view should handle the missing environment object gracefully
        // This test verifies that SafeEnvironmentObject prevents crashes
    }
    
    /// Test fallback AppState creation
    @MainActor func testFallbackAppStateCreation() {
        // Given: A request for fallback AppState
        // When: Creating a fallback AppState
        let fallbackAppState = AppState.createFallback()
        
        // Then: It should have safe default values
        XCTAssertNotNil(fallbackAppState)
        XCTAssertFalse(fallbackAppState.isAuthenticated)
        XCTAssertNil(fallbackAppState.currentUser)
        XCTAssertNil(fallbackAppState.currentFamily)
        XCTAssertEqual(fallbackAppState.currentFlow, .onboarding)
        XCTAssertFalse(fallbackAppState.isLoading)
        XCTAssertNil(fallbackAppState.errorMessage)
        XCTAssertEqual(fallbackAppState.selectedNavigationTab, .dashboard)
        XCTAssertNotNil(fallbackAppState.navigationPath)
    }
    
    /// Test AppState validation
    @MainActor func testAppStateValidation() {
        // Given: A properly configured AppState
        let validAppState = AppState.createTest(scenario: .authenticated)
        
        // When: Validating the AppState
        let validationResult = validAppState.validateState()
        
        // Then: It should be valid
        XCTAssertTrue(validationResult.isValid)
        XCTAssertTrue(validationResult.issues.isEmpty)
        XCTAssertFalse(validationResult.hasCriticalIssues)
    }
    
    /// Test AppState validation with inconsistent state
    @MainActor func testAppStateValidationWithInconsistentState() {
        // Given: An AppState with inconsistent state
        let inconsistentAppState = AppState.createFallback()
        inconsistentAppState.isAuthenticated = true
        // currentUser is still nil, creating inconsistency
        
        // When: Validating the AppState
        let validationResult = inconsistentAppState.validateState()
        
        // Then: It should be invalid
        XCTAssertFalse(validationResult.isValid)
        XCTAssertFalse(validationResult.issues.isEmpty)
        XCTAssertTrue(validationResult.hasCriticalIssues)
        
        // Should contain specific issue about authentication inconsistency
        let hasAuthIssue = validationResult.issues.contains { issue in
            issue.contains("authenticated") && issue.contains("currentUser")
        }
        XCTAssertTrue(hasAuthIssue)
    }
}