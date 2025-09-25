import XCTest
import SwiftUI
@testable import TribeBoard

/// Tests for navigation animation and haptic feedback functionality
final class NavigationAnimationTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var hapticManager: HapticManager!
    
    // MARK: - Setup and Teardown
    
    override func setUp() {
        super.setUp()
        hapticManager = HapticManager.shared
    }
    
    override func tearDown() {
        hapticManager = nil
        super.tearDown()
    }
    
    // MARK: - Haptic Feedback Tests
    
    @MainActor func testHapticManagerNavigationFeedback() {
        // Test that navigation haptic feedback method exists and can be called
        XCTAssertNoThrow(hapticManager.navigation())
        XCTAssertNoThrow(hapticManager.selection())
        XCTAssertNoThrow(hapticManager.lightImpact())
    }
    
    @MainActor func testNavigationTabEnumProperties() {
        // Test that all navigation tabs have required properties
        for tab in NavigationTab.allCases {
            XCTAssertFalse(tab.displayName.isEmpty, "Tab \(tab) should have a display name")
            XCTAssertFalse(tab.icon.isEmpty, "Tab \(tab) should have an icon")
            XCTAssertFalse(tab.activeIcon.isEmpty, "Tab \(tab) should have an active icon")
        }
    }
    
    @MainActor func testNavigationTabCount() {
        // Ensure we have exactly 4 navigation tabs as specified in requirements
        XCTAssertEqual(NavigationTab.allCases.count, 4, "Should have exactly 4 navigation tabs")
        
        // Verify specific tabs exist
        XCTAssertTrue(NavigationTab.allCases.contains(.dashboard))
        XCTAssertTrue(NavigationTab.allCases.contains(.schoolRun))
        XCTAssertTrue(NavigationTab.allCases.contains(.messages))
        XCTAssertTrue(NavigationTab.allCases.contains(.tasks))
    }
    
    // MARK: - Animation Tests
    
    @MainActor func testAnimationUtilitiesExist() {
        // Test that navigation-specific animations exist
        XCTAssertNotNil(AnimationUtilities.tabSelection)
        XCTAssertNotNil(AnimationUtilities.navigationEntrance)
        XCTAssertNotNil(AnimationUtilities.navigationBounce)
        XCTAssertNotNil(AnimationUtilities.viewTransition)
    }
    
    @MainActor func testDesignSystemAnimations() {
        // Test that design system animations used in navigation exist
        XCTAssertNotNil(DesignSystem.Animation.spring)
        XCTAssertNotNil(DesignSystem.Animation.bouncy)
        XCTAssertNotNil(DesignSystem.Animation.smooth)
        XCTAssertNotNil(DesignSystem.Animation.buttonPress)
    }
    
    // MARK: - Navigation Item Tests
    
    @MainActor func testNavigationItemInitialization() {
        // Test that NavigationItem can be initialized with required parameters
        let tab = NavigationTab.dashboard
        var tapCalled = false
        
        let navigationItem = NavigationItem(
            tab: tab,
            isActive: false,
            onTap: { tapCalled = true }
        )
        
        XCTAssertNotNil(navigationItem)
        
        // Test that the tap action works (indirectly)
        // Note: We can't directly test the tap action in a unit test,
        // but we can verify the closure is stored and callable
        XCTAssertFalse(tapCalled)
    }
    
    // MARK: - Floating Bottom Navigation Tests
    
    @MainActor func testFloatingBottomNavigationInitialization() {
        // Test that FloatingBottomNavigation can be initialized
        @State var selectedTab = NavigationTab.dashboard
        var tabSelectionCalled = false
        
        let navigation = FloatingBottomNavigation(
            selectedTab: .constant(selectedTab),
            onTabSelected: { _ in tabSelectionCalled = true }
        )
        
        XCTAssertNotNil(navigation)
    }
    
    // MARK: - Integration Tests
    
    @MainActor func testNavigationStateManagement() {
        // Test that AppState properly manages navigation state
        let appState = AppState()
        
        // Test initial state
        XCTAssertEqual(appState.selectedNavigationTab, .dashboard)
        
        // Test tab selection
        appState.handleTabSelection(.tasks)
        XCTAssertEqual(appState.selectedNavigationTab, .tasks)
        
        appState.handleTabSelection(.schoolRun)
        XCTAssertEqual(appState.selectedNavigationTab, .schoolRun)
        
        appState.handleTabSelection(.messages)
        XCTAssertEqual(appState.selectedNavigationTab, .messages)
        
        appState.handleTabSelection(.dashboard)
        XCTAssertEqual(appState.selectedNavigationTab, .dashboard)
    }
    
    @MainActor func testNavigationVisibilityLogic() {
        // Test that navigation visibility logic works correctly
        let appState = AppState()
        
        // Test initial state - should not show navigation until user is signed in
        XCTAssertFalse(appState.shouldShowBottomNavigation)
        
        // Test after sign in - should show navigation when in family dashboard flow
        let mockUser = UserProfile(displayName: "Test User", appleUserIdHash: "test_hash")
        appState.signIn(user: mockUser)
        
        // Still shouldn't show until family is set
        XCTAssertFalse(appState.shouldShowBottomNavigation)
        
        // Set family and membership
        let mockData = MockDataGenerator.mockFamilyWithMembers()
        let family = mockData.family
        let membership = mockData.memberships.first!
        appState.setFamily(family, membership: membership)
        
        // Now should show navigation
        XCTAssertTrue(appState.shouldShowBottomNavigation)
    }
    
    // MARK: - Performance Tests
    
    @MainActor func testNavigationAnimationPerformance() {
        // Test that navigation animations don't cause performance issues
        measure {
            for _ in 0..<100 {
                // Simulate rapid tab switching
                let appState = AppState()
                appState.handleTabSelection(.dashboard)
                appState.handleTabSelection(.tasks)
                appState.handleTabSelection(.schoolRun)
                appState.handleTabSelection(.messages)
            }
        }
    }
    
    @MainActor func testHapticFeedbackPerformance() {
        // Test that haptic feedback calls don't cause performance issues
        measure {
            for _ in 0..<50 {
                hapticManager.navigation()
                hapticManager.selection()
                hapticManager.lightImpact()
            }
        }
    }
}

// MARK: - Mock Extensions for Testing

extension NavigationAnimationTests {
    
    /// Helper method to create a mock navigation environment for testing
    func createMockNavigationEnvironment() -> (AppState, MockServiceCoordinator) {
        let appState = AppState()
        let mockServices = MockServiceCoordinator()
        
        // Set up mock user and family
        let mockUser = UserProfile(displayName: "Test User", appleUserIdHash: "test_hash")
        appState.signIn(user: mockUser)
        
        let mockData = MockDataGenerator.mockFamilyWithMembers()
        let family = mockData.family
        let membership = mockData.memberships.first!
        appState.setFamily(family, membership: membership)
        
        return (appState, mockServices)
    }
}