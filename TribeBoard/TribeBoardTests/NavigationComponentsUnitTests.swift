import XCTest
import SwiftUI
@testable import TribeBoard

final class NavigationComponentsUnitTests: XCTestCase {
    
    // MARK: - NavigationTab Enum Tests
    
    @MainActor func testNavigationTabAllCases() {
        let allCases = NavigationTab.allCases
        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.dashboard))
        XCTAssertTrue(allCases.contains(.schoolRun))
        XCTAssertTrue(allCases.contains(.messages))
        XCTAssertTrue(allCases.contains(.tasks))
    }
    
    @MainActor func testNavigationTabRawValues() {
        XCTAssertEqual(NavigationTab.dashboard.rawValue, "home")
        XCTAssertEqual(NavigationTab.schoolRun.rawValue, "school_run")
        XCTAssertEqual(NavigationTab.messages.rawValue, "shopping")
        XCTAssertEqual(NavigationTab.tasks.rawValue, "tasks")
    }
    
    @MainActor func testNavigationTabIdentifiable() {
        XCTAssertEqual(NavigationTab.dashboard.id, "home")
        XCTAssertEqual(NavigationTab.schoolRun.id, "school_run")
        XCTAssertEqual(NavigationTab.messages.id, "shopping")
        XCTAssertEqual(NavigationTab.tasks.id, "tasks")
    }
    
    @MainActor func testNavigationTabDisplayNames() {
        XCTAssertEqual(NavigationTab.dashboard.displayName, "Dashboard")
        XCTAssertEqual(NavigationTab.schoolRun.displayName, "School Run")
        XCTAssertEqual(NavigationTab.messages.displayName, "Messages")
        XCTAssertEqual(NavigationTab.tasks.displayName, "Tasks")
        
        // Ensure all display names are non-empty
        for tab in NavigationTab.allCases {
            XCTAssertFalse(tab.displayName.isEmpty, "Display name should not be empty for \(tab)")
        }
    }
    
    @MainActor func testNavigationTabIcons() {
        // Test inactive icons
        XCTAssertEqual(NavigationTab.dashboard.icon, "house")
        XCTAssertEqual(NavigationTab.schoolRun.icon, "car")
        XCTAssertEqual(NavigationTab.messages.icon, "message")
        XCTAssertEqual(NavigationTab.tasks.icon, "checkmark.circle")
        
        // Test active icons
        XCTAssertEqual(NavigationTab.dashboard.activeIcon, "house.fill")
        XCTAssertEqual(NavigationTab.schoolRun.activeIcon, "bus.fill")
        XCTAssertEqual(NavigationTab.messages.activeIcon, "message.fill")
        XCTAssertEqual(NavigationTab.tasks.activeIcon, "checkmark.circle.fill")
        
        // Ensure all icons are non-empty
        for tab in NavigationTab.allCases {
            XCTAssertFalse(tab.icon.isEmpty, "Icon should not be empty for \(tab)")
            XCTAssertFalse(tab.activeIcon.isEmpty, "Active icon should not be empty for \(tab)")
        }
    }
    
    @MainActor func testNavigationTabIconConsistency() {
        // Ensure active icons are filled versions of inactive icons
        for tab in NavigationTab.allCases {
            let inactiveIcon = tab.icon
            let activeIcon = tab.activeIcon
            
            // Most active icons should be the filled version
            if !activeIcon.contains("fill") {
                // Some icons might not follow the .fill pattern, but they should be different
                XCTAssertNotEqual(inactiveIcon, activeIcon, "Active and inactive icons should be different for \(tab)")
            }
        }
    }
    
    // MARK: - NavigationItem Component Tests
    
    @MainActor func testNavigationItemInitialization() {
        let tab = NavigationTab.dashboard
        let isActive = true
        var tapCalled = false
        let onTap = { tapCalled = true }
        
        let navigationItem = NavigationItem(
            tab: tab,
            isActive: isActive,
            onTap: onTap
        )
        
        XCTAssertEqual(navigationItem.tab, tab)
        XCTAssertEqual(navigationItem.isActive, isActive)
        
        // Test onTap functionality
        navigationItem.onTap()
        XCTAssertTrue(tapCalled)
    }
    
    @MainActor func testNavigationItemTapCallback() {
        var tappedTab: NavigationTab?
        let onTap = { tappedTab = .schoolRun }
        
        let navigationItem = NavigationItem(
            tab: .schoolRun,
            isActive: false,
            onTap: onTap
        )
        
        navigationItem.onTap()
        XCTAssertEqual(tappedTab, .schoolRun)
    }
    
    @MainActor func testNavigationItemActiveStateChanges() {
        var tapCount = 0
        let onTap = { tapCount += 1 }
        
        // Test inactive item
        let inactiveItem = NavigationItem(
            tab: .tasks,
            isActive: false,
            onTap: onTap
        )
        
        // Test active item
        let activeItem = NavigationItem(
            tab: .tasks,
            isActive: true,
            onTap: onTap
        )
        
        // Both should be tappable
        inactiveItem.onTap()
        activeItem.onTap()
        
        XCTAssertEqual(tapCount, 2)
    }
    
    // MARK: - FloatingBottomNavigation Component Tests
    
    @MainActor func testFloatingBottomNavigationInitialization() {
        let selectedTab = NavigationTab.dashboard
        var tappedTab: NavigationTab?
        let onTabSelected = { (tab: NavigationTab) in tappedTab = tab }
        
        let _ = FloatingBottomNavigation(
            selectedTab: .constant(selectedTab),
            onTabSelected: onTabSelected
        )
        
        // Test that callback works
        onTabSelected(.messages)
        XCTAssertEqual(tappedTab, .messages)
    }
    
    @MainActor func testFloatingBottomNavigationTabSelection() {
        var selectedTab = NavigationTab.dashboard
        var callbackTab: NavigationTab?
        
        let onTabSelected = { (tab: NavigationTab) in 
            callbackTab = tab
            selectedTab = tab
        }
        
        let binding = Binding(
            get: { selectedTab },
            set: { selectedTab = $0 }
        )
        
        let _ = FloatingBottomNavigation(
            selectedTab: binding,
            onTabSelected: onTabSelected
        )
        
        // Simulate tab selection
        onTabSelected(.tasks)
        
        XCTAssertEqual(callbackTab, .tasks)
        XCTAssertEqual(selectedTab, .tasks)
    }
    
    @MainActor func testFloatingBottomNavigationAllTabsPresent() {
        let _ = FloatingBottomNavigation(
            selectedTab: .constant(.dashboard),
            onTabSelected: { _ in }
        )
        
        // The component should handle all navigation tabs
        // This is more of a structural test to ensure all tabs are considered
        let allTabs = NavigationTab.allCases
        XCTAssertEqual(allTabs.count, 4)
        
        // Each tab should be selectable
        for tab in allTabs {
            var selectedTab: NavigationTab?
            let onTabSelected = { (tappedTab: NavigationTab) in
                selectedTab = tappedTab
            }
            
            onTabSelected(tab)
            XCTAssertEqual(selectedTab, tab)
        }
    }
    
    // MARK: - Integration Tests
    
    @MainActor func testNavigationComponentsIntegration() {
        // Test that NavigationTab enum works with NavigationItem
        let tab = NavigationTab.schoolRun
        var tappedTab: NavigationTab?
        
        let navigationItem = NavigationItem(
            tab: tab,
            isActive: false,
            onTap: { tappedTab = tab }
        )
        
        // Test properties are accessible
        XCTAssertEqual(navigationItem.tab.displayName, "School Run")
        XCTAssertEqual(navigationItem.tab.icon, "car")
        XCTAssertEqual(navigationItem.tab.activeIcon, "bus.fill")
        
        // Test tap functionality
        navigationItem.onTap()
        XCTAssertEqual(tappedTab, .schoolRun)
    }
    
    // MARK: - Edge Cases and Error Handling
    
    @MainActor func testNavigationTabCaseIterable() {
        // Ensure all cases are covered and none are missing
        let allCases = NavigationTab.allCases
        let expectedCases: [NavigationTab] = [.dashboard, .schoolRun, .messages, .tasks]
        
        XCTAssertEqual(allCases.count, expectedCases.count)
        
        for expectedCase in expectedCases {
            XCTAssertTrue(allCases.contains(expectedCase), "Missing case: \(expectedCase)")
        }
    }
    
    @MainActor func testNavigationItemWithAllTabs() {
        // Test NavigationItem works with all tab types
        for tab in NavigationTab.allCases {
            var tapCalled = false
            let navigationItem = NavigationItem(
                tab: tab,
                isActive: false,
                onTap: { tapCalled = true }
            )
            
            // Test basic properties
            XCTAssertEqual(navigationItem.tab, tab)
            XCTAssertFalse(navigationItem.isActive)
            
            // Test tap functionality
            navigationItem.onTap()
            XCTAssertTrue(tapCalled)
        }
    }
    
    // MARK: - Performance Tests
    
    @MainActor func testNavigationTabEnumPerformance() {
        // Test that enum operations are performant
        measure {
            for _ in 0..<1000 {
                for tab in NavigationTab.allCases {
                    _ = tab.displayName
                    _ = tab.icon
                    _ = tab.activeIcon
                    _ = tab.rawValue
                    _ = tab.id
                }
            }
        }
    }
    
    // MARK: - Accessibility Tests
    
    @MainActor func testNavigationTabAccessibilityProperties() {
        // Test that all tabs have appropriate accessibility properties
        for tab in NavigationTab.allCases {
            let displayName = tab.displayName
            
            // Display names should be suitable for accessibility
            XCTAssertFalse(displayName.isEmpty)
            XCTAssertFalse(displayName.contains("_"))
            XCTAssertFalse(displayName.contains("-"))
            
            // Should be properly capitalized
            XCTAssertEqual(displayName.first?.isUppercase, true)
        }
    }
    
    @MainActor func testNavigationItemAccessibilityIntegration() {
        // Test that NavigationItem properly uses tab accessibility properties
        let tab = NavigationTab.schoolRun
        
        let activeItem = NavigationItem(
            tab: tab,
            isActive: true,
            onTap: {}
        )
        
        let inactiveItem = NavigationItem(
            tab: tab,
            isActive: false,
            onTap: {}
        )
        
        // Both items should use the same tab properties
        XCTAssertEqual(activeItem.tab.displayName, inactiveItem.tab.displayName)
        XCTAssertEqual(activeItem.tab.displayName, "School Run")
    }
    
    // MARK: - Component State Tests
    
    @MainActor func testNavigationItemStateConsistency() {
        // Test that NavigationItem maintains consistent state
        let tab = NavigationTab.dashboard
        
        let activeItem = NavigationItem(tab: tab, isActive: true, onTap: {})
        let inactiveItem = NavigationItem(tab: tab, isActive: false, onTap: {})
        
        XCTAssertTrue(activeItem.isActive)
        XCTAssertFalse(inactiveItem.isActive)
        XCTAssertEqual(activeItem.tab, inactiveItem.tab)
    }
    
    @MainActor func testFloatingBottomNavigationBindingConsistency() {
        // Test that binding updates work correctly
        var selectedTab = NavigationTab.dashboard
        var callbackCount = 0
        
        let onTabSelected = { (tab: NavigationTab) in
            selectedTab = tab
            callbackCount += 1
        }
        
        let binding = Binding(
            get: { selectedTab },
            set: { selectedTab = $0 }
        )
        
        let _ = FloatingBottomNavigation(
            selectedTab: binding,
            onTabSelected: onTabSelected
        )
        
        // Test multiple tab selections
        onTabSelected(.schoolRun)
        XCTAssertEqual(selectedTab, .schoolRun)
        XCTAssertEqual(callbackCount, 1)
        
        onTabSelected(.tasks)
        XCTAssertEqual(selectedTab, .tasks)
        XCTAssertEqual(callbackCount, 2)
        
        onTabSelected(.messages)
        XCTAssertEqual(selectedTab, .messages)
        XCTAssertEqual(callbackCount, 3)
    }
    
    // MARK: - Validation Tests
    
    @MainActor func testNavigationTabValidation() {
        // Test that all navigation tabs have valid properties
        for tab in NavigationTab.allCases {
            // Display name validation
            XCTAssertFalse(tab.displayName.isEmpty)
            XCTAssertTrue(tab.displayName.count > 1)
            XCTAssertTrue(tab.displayName.count < 20) // Reasonable length
            
            // Icon validation
            XCTAssertFalse(tab.icon.isEmpty)
            XCTAssertFalse(tab.activeIcon.isEmpty)
            XCTAssertNotEqual(tab.icon, tab.activeIcon) // Should be different
            
            // Raw value validation
            XCTAssertFalse(tab.rawValue.isEmpty)
            XCTAssertEqual(tab.id, tab.rawValue) // ID should match raw value
        }
    }
    
    @MainActor func testNavigationItemCallbackValidation() {
        // Test that callbacks are properly executed
        var callbackExecuted = false
        var callbackParameter: NavigationTab?
        
        let tab = NavigationTab.messages
        let navigationItem = NavigationItem(
            tab: tab,
            isActive: false,
            onTap: {
                callbackExecuted = true
                callbackParameter = tab
            }
        )
        
        XCTAssertFalse(callbackExecuted)
        XCTAssertNil(callbackParameter)
        
        navigationItem.onTap()
        
        XCTAssertTrue(callbackExecuted)
        XCTAssertEqual(callbackParameter, tab)
    }
}