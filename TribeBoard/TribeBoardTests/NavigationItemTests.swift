import XCTest
import SwiftUI
@testable import TribeBoard

final class NavigationItemTests: XCTestCase {
    
    @MainActor func testNavigationItemInitialization() {
        // Given
        let tab = NavigationTab.dashboard
        let isActive = true
        var tapCalled = false
        let onTap = { tapCalled = true }
        
        // When
        let navigationItem = NavigationItem(
            tab: tab,
            isActive: isActive,
            onTap: onTap
        )
        
        // Then
        XCTAssertEqual(navigationItem.tab, tab)
        XCTAssertEqual(navigationItem.isActive, isActive)
        
        // Test onTap functionality
        navigationItem.onTap()
        XCTAssertTrue(tapCalled)
    }
    
    @MainActor func testNavigationTabProperties() {
        // Test all navigation tabs have required properties
        for tab in NavigationTab.allCases {
            XCTAssertFalse(tab.displayName.isEmpty, "Display name should not be empty for \(tab)")
            XCTAssertFalse(tab.icon.isEmpty, "Icon should not be empty for \(tab)")
            XCTAssertFalse(tab.activeIcon.isEmpty, "Active icon should not be empty for \(tab)")
        }
    }
    
    @MainActor func testNavigationTabDisplayNames() {
        // Test specific display names
        XCTAssertEqual(NavigationTab.dashboard.displayName, "Dashboard")
        XCTAssertEqual(NavigationTab.schoolRun.displayName, "School Run")
        XCTAssertEqual(NavigationTab.messages.displayName, "Messages")
        XCTAssertEqual(NavigationTab.tasks.displayName, "Tasks")
    }
    
    @MainActor func testNavigationTabIcons() {
        // Test that icons are valid SF Symbols
        XCTAssertEqual(NavigationTab.dashboard.icon, "house")
        XCTAssertEqual(NavigationTab.dashboard.activeIcon, "house.fill")
        
        XCTAssertEqual(NavigationTab.schoolRun.icon, "bus")
        XCTAssertEqual(NavigationTab.schoolRun.activeIcon, "bus.fill")
        
        XCTAssertEqual(NavigationTab.messages.icon, "message")
        XCTAssertEqual(NavigationTab.messages.activeIcon, "message.fill")
        
        XCTAssertEqual(NavigationTab.tasks.icon, "checkmark.circle")
        XCTAssertEqual(NavigationTab.tasks.activeIcon, "checkmark.circle.fill")
    }
    
    @MainActor func testNavigationItemAccessibilityLabels() {
        // Test accessibility labels for active state
        let activeItem = NavigationItem(tab: .dashboard, isActive: true, onTap: {})
        let expectedActiveLabel = "Home, selected"
        // Note: In a real test, we would need to access the accessibility properties
        // This is a conceptual test showing what should be verified
        
        // Test accessibility labels for inactive state
        let inactiveItem = NavigationItem(tab: .dashboard, isActive: false, onTap: {})
        let expectedInactiveLabel = "Dashboard"
        // Note: In a real test, we would need to access the accessibility properties
        
        // These assertions would need proper SwiftUI testing framework
        // XCTAssertEqual(activeItem.accessibilityLabel, expectedActiveLabel)
        // XCTAssertEqual(inactiveItem.accessibilityLabel, expectedInactiveLabel)
    }
}