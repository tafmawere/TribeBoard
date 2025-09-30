import XCTest
@testable import TribeBoard

/// Tests for navigation state handling with 5-tab layout
@MainActor
final class NavigationStateHandlingTests: XCTestCase {
    
    var appState: AppState!
    
    override func setUp() {
        super.setUp()
        appState = AppState()
    }
    
    override func tearDown() {
        appState = nil
        super.tearDown()
    }
    
    // MARK: - Tab Validation Tests
    
    func testNavigationTabDefaultsToValidTab() {
        // Given: Fresh AppState
        // When: AppState is initialized
        // Then: selectedNavigationTab should be a valid tab
        XCTAssertTrue(NavigationTab.allCases.contains(appState.selectedNavigationTab))
        XCTAssertEqual(appState.selectedNavigationTab, .dashboard)
    }
    
    func testValidateNavigationTabWithValidTab() {
        // Given: AppState with valid tab
        appState.selectedNavigationTab = .homeLife
        
        // When: Validating navigation tab
        appState.validateNavigationTab()
        
        // Then: Tab should remain unchanged
        XCTAssertEqual(appState.selectedNavigationTab, .homeLife)
    }
    
    func testNavigationTabCountIs5() {
        // Given: NavigationTab enum
        // When: Checking all cases
        // Then: Should have exactly 5 tabs
        XCTAssertEqual(NavigationTab.allCases.count, 5)
        
        // Verify specific tabs exist
        XCTAssertTrue(NavigationTab.allCases.contains(.dashboard))
        XCTAssertTrue(NavigationTab.allCases.contains(.calendar))
        XCTAssertTrue(NavigationTab.allCases.contains(.schoolRun))
        XCTAssertTrue(NavigationTab.allCases.contains(.homeLife))
        XCTAssertTrue(NavigationTab.allCases.contains(.tasks))
    }
    
    // MARK: - Tab Selection Tests
    
    func testSelectTabWithValidTab() {
        // Given: AppState with dashboard selected
        XCTAssertEqual(appState.selectedNavigationTab, .dashboard)
        
        // When: Selecting a valid tab
        appState.selectTab(.homeLife)
        
        // Then: Tab should be updated
        XCTAssertEqual(appState.selectedNavigationTab, .homeLife)
    }
    
    func testHandleTabSelectionWithValidTab() {
        // Given: AppState with dashboard selected
        XCTAssertEqual(appState.selectedNavigationTab, .dashboard)
        
        // When: Handling tab selection
        appState.handleTabSelection(.tasks)
        
        // Then: Tab should be updated and navigation path reset
        XCTAssertEqual(appState.selectedNavigationTab, .tasks)
        XCTAssertTrue(appState.navigationPath.isEmpty)
    }
    
    func testHandleTabSelectionResetsNavigationPath() {
        // Given: AppState with non-empty navigation path
        appState.navigationPath.append("some-path")
        XCTAssertFalse(appState.navigationPath.isEmpty)
        
        // When: Handling tab selection
        appState.handleTabSelection(.calendar)
        
        // Then: Navigation path should be reset
        XCTAssertTrue(appState.navigationPath.isEmpty)
        XCTAssertEqual(appState.selectedNavigationTab, .calendar)
    }
    
    // MARK: - Navigation State Reset Tests
    
    func testResetNavigationState() {
        // Given: AppState with modified navigation state
        appState.selectedNavigationTab = .schoolRun
        appState.navigationPath.append("some-path")
        
        // When: Resetting navigation state
        appState.resetNavigationState()
        
        // Then: Navigation should be reset to defaults
        XCTAssertEqual(appState.selectedNavigationTab, .dashboard)
        XCTAssertTrue(appState.navigationPath.isEmpty)
    }
    
    func testValidateNavigationPath() {
        // Given: AppState with navigation path
        appState.navigationPath.append("some-path")
        XCTAssertFalse(appState.navigationPath.isEmpty)
        
        // When: Validating navigation path
        appState.validateNavigationPath()
        
        // Then: Navigation path should be reset for safety
        XCTAssertTrue(appState.navigationPath.isEmpty)
    }
    
    func testValidateNavigationPathWithEmptyPath() {
        // Given: AppState with empty navigation path
        XCTAssertTrue(appState.navigationPath.isEmpty)
        
        // When: Validating navigation path
        appState.validateNavigationPath()
        
        // Then: Navigation path should remain empty
        XCTAssertTrue(appState.navigationPath.isEmpty)
    }
    
    // MARK: - Family Management Integration Tests
    
    func testSetFamilyValidatesNavigationPath() {
        // Given: AppState with navigation path
        appState.navigationPath.append("some-path")
        let mockFamily = Family(name: "Test Family", code: "TEST123", createdByUserId: UUID())
        let mockUser = UserProfile(displayName: "Test User", appleUserIdHash: "test_hash")
        let mockMembership = Membership(family: mockFamily, user: mockUser, role: .parentAdmin)
        
        // When: Setting family
        appState.setFamily(mockFamily, membership: mockMembership)
        
        // Then: Navigation path should be validated (reset)
        XCTAssertTrue(appState.navigationPath.isEmpty)
        XCTAssertEqual(appState.currentFlow, .familyDashboard)
    }
    
    func testLeaveFamilyResetsNavigationState() {
        // Given: AppState with family and modified navigation
        let mockFamily = Family(name: "Test Family", code: "TEST123", createdByUserId: UUID())
        let mockUser = UserProfile(displayName: "Test User", appleUserIdHash: "test_hash")
        let mockMembership = Membership(family: mockFamily, user: mockUser, role: .parentAdmin)
        appState.setFamily(mockFamily, membership: mockMembership)
        appState.selectedNavigationTab = .homeLife
        appState.navigationPath.append("some-path")
        
        // When: Leaving family
        appState.leaveFamily()
        
        // Then: Navigation state should be reset
        XCTAssertEqual(appState.selectedNavigationTab, .dashboard)
        XCTAssertTrue(appState.navigationPath.isEmpty)
        XCTAssertEqual(appState.currentFlow, .familySelection)
        XCTAssertNil(appState.currentFamily)
        XCTAssertNil(appState.currentMembership)
    }
    
    // MARK: - Bottom Navigation Display Tests
    
    func testShouldShowBottomNavigationWithFamily() {
        // Given: Authenticated user with family
        let mockUser = UserProfile(displayName: "Test User", appleUserIdHash: "test_hash")
        let mockFamily = Family(name: "Test Family", code: "TEST123", createdByUserId: mockUser.id)
        let mockMembership = Membership(family: mockFamily, user: mockUser, role: .parentAdmin)
        
        appState.isAuthenticated = true
        appState.currentUser = mockUser
        appState.setFamily(mockFamily, membership: mockMembership)
        
        // When: Checking if bottom navigation should show
        // Then: Should show bottom navigation
        XCTAssertTrue(appState.shouldShowBottomNavigation)
    }
    
    func testShouldNotShowBottomNavigationWithoutFamily() {
        // Given: Authenticated user without family
        let mockUser = UserProfile(displayName: "Test User", appleUserIdHash: "test_hash")
        appState.isAuthenticated = true
        appState.currentUser = mockUser
        appState.currentFlow = .familySelection
        
        // When: Checking if bottom navigation should show
        // Then: Should not show bottom navigation
        XCTAssertFalse(appState.shouldShowBottomNavigation)
    }
    
    func testShouldNotShowBottomNavigationWhenNotAuthenticated() {
        // Given: Unauthenticated state
        appState.isAuthenticated = false
        appState.currentFlow = .onboarding
        
        // When: Checking if bottom navigation should show
        // Then: Should not show bottom navigation
        XCTAssertFalse(appState.shouldShowBottomNavigation)
    }
}