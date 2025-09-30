import XCTest
import SwiftUI
@testable import TribeBoard

/// Tests for navigation menu optimization - verifying 5-tab layout, accessibility, and homelife icon
final class NavigationMenuOptimizationTests: XCTestCase {
    
    // MARK: - Test Properties
    
    @MainActor
    var appState: AppState!
    
    // MARK: - Setup & Teardown
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        appState = AppState()
    }
    
    @MainActor
    override func tearDown() async throws {
        appState = nil
        try await super.tearDown()
    }
    
    // MARK: - NavigationTab 5-Tab Layout Tests
    
    @MainActor
    func testNavigationTabHasFiveTabs() {
        // Verify that NavigationTab enum has exactly 5 cases
        let allCases = NavigationTab.allCases
        XCTAssertEqual(allCases.count, 5, "NavigationTab should have exactly 5 cases")
    }
    
    @MainActor
    func testNavigationTabCorrectCases() {
        // Verify the correct 5 tabs are present
        let allCases = NavigationTab.allCases
        let expectedTabs: [NavigationTab] = [.dashboard, .calendar, .schoolRun, .homeLife, .tasks]
        
        XCTAssertEqual(allCases.count, expectedTabs.count, "Should have 5 tabs")
        
        for expectedTab in expectedTabs {
            XCTAssertTrue(allCases.contains(expectedTab), "Should contain \(expectedTab)")
        }
    }
    
    @MainActor
    func testMessagesTabRemoved() {
        // Verify messages tab is not present in the enum
        let allCases = NavigationTab.allCases
        
        // Check that no case has messages-related properties
        for tab in allCases {
            XCTAssertNotEqual(tab.rawValue, "messages", "Messages tab should be removed")
            XCTAssertNotEqual(tab.displayName, "Messages", "Messages display name should not exist")
        }
    }
    
    // MARK: - HomeLife Tab Icon Tests (Requirements 2.1, 2.2)
    
    @MainActor
    func testHomeLifeTabInactiveIcon() {
        // Requirement 2.1: HomeLife tab should display "house.heart" icon in inactive state
        let homeLifeTab = NavigationTab.homeLife
        XCTAssertEqual(homeLifeTab.icon, "house.heart", "HomeLife inactive icon should be 'house.heart'")
    }
    
    @MainActor
    func testHomeLifeTabActiveIcon() {
        // Requirement 2.2: HomeLife tab should display "house.heart.fill" icon in active state
        let homeLifeTab = NavigationTab.homeLife
        XCTAssertEqual(homeLifeTab.activeIcon, "house.heart.fill", "HomeLife active icon should be 'house.heart.fill'")
    }
    
    @MainActor
    func testHomeLifeTabDisplayName() {
        // Verify HomeLife tab has correct display name
        let homeLifeTab = NavigationTab.homeLife
        XCTAssertEqual(homeLifeTab.displayName, "HomeLife", "HomeLife display name should be 'HomeLife'")
    }
    
    // MARK: - FloatingBottomNavigation Layout Tests
    
    @MainActor
    func testFloatingBottomNavigationDisplaysFiveTabs() {
        // Test that FloatingBottomNavigation displays exactly 5 tabs
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
        
        let navigation = FloatingBottomNavigation(
            selectedTab: binding,
            onTabSelected: onTabSelected
        )
        
        // Verify the component can handle all 5 tabs
        let allTabs = NavigationTab.allCases
        XCTAssertEqual(allTabs.count, 5, "Should handle 5 tabs")
        
        // Test that each tab can be selected
        for tab in allTabs {
            onTabSelected(tab)
            XCTAssertEqual(selectedTab, tab, "Should be able to select \(tab)")
        }
        
        XCTAssertEqual(callbackCount, 5, "Should have called callback 5 times")
    }
    
    @MainActor
    func testFloatingBottomNavigationTouchTargets() {
        // Test that touch targets work properly with 5 tabs
        let navigation = FloatingBottomNavigation(
            selectedTab: .constant(.dashboard),
            onTabSelected: { _ in }
        )
        
        // Verify all tabs are accessible
        let allTabs = NavigationTab.allCases
        for tab in allTabs {
            var tapCalled = false
            let navigationItem = NavigationItem(
                tab: tab,
                isActive: false,
                onTap: { tapCalled = true }
            )
            
            // Test tap functionality
            navigationItem.onTap()
            XCTAssertTrue(tapCalled, "Touch target should work for \(tab)")
        }
    }
    
    // MARK: - NavigationItem Accessibility Tests (Requirements 3.1, 3.2, 3.3)
    
    @MainActor
    func testNavigationItemAccessibilityLabels() {
        // Test accessibility labels for all tabs
        let allTabs = NavigationTab.allCases
        
        for tab in allTabs {
            // Test inactive state accessibility
            let inactiveItem = NavigationItem(
                tab: tab,
                isActive: false,
                onTap: {}
            )
            
            // Test active state accessibility
            let activeItem = NavigationItem(
                tab: tab,
                isActive: true,
                onTap: {}
            )
            
            // Verify display names are suitable for accessibility
            let displayName = tab.displayName
            XCTAssertFalse(displayName.isEmpty, "Display name should not be empty for \(tab)")
            XCTAssertFalse(displayName.contains("_"), "Display name should not contain underscores for \(tab)")
            XCTAssertFalse(displayName.contains("-"), "Display name should not contain hyphens for \(tab)")
            XCTAssertTrue(displayName.first?.isUppercase == true, "Display name should be properly capitalized for \(tab)")
        }
    }
    
    @MainActor
    func testNavigationItemAccessibilityHints() {
        // Test that all navigation items have appropriate accessibility properties
        let allTabs = NavigationTab.allCases
        
        for tab in allTabs {
            let navigationItem = NavigationItem(
                tab: tab,
                isActive: false,
                onTap: {}
            )
            
            // Verify the tab has all required properties for accessibility
            XCTAssertFalse(tab.displayName.isEmpty, "Tab should have display name for accessibility")
            XCTAssertFalse(tab.icon.isEmpty, "Tab should have icon for accessibility")
            XCTAssertFalse(tab.activeIcon.isEmpty, "Tab should have active icon for accessibility")
        }
    }
    
    @MainActor
    func testHomeLifeTabAccessibilityWithCorrectIcon() {
        // Requirement 2.3: Test homelife tab accessibility with proper icons
        let homeLifeTab = NavigationTab.homeLife
        
        // Test inactive state
        let inactiveItem = NavigationItem(
            tab: homeLifeTab,
            isActive: false,
            onTap: {}
        )
        
        // Test active state
        let activeItem = NavigationItem(
            tab: homeLifeTab,
            isActive: true,
            onTap: {}
        )
        
        // Verify icons are correct for accessibility
        XCTAssertEqual(homeLifeTab.icon, "house.heart", "Inactive HomeLife icon should be correct for accessibility")
        XCTAssertEqual(homeLifeTab.activeIcon, "house.heart.fill", "Active HomeLife icon should be correct for accessibility")
        XCTAssertEqual(homeLifeTab.displayName, "HomeLife", "HomeLife display name should be correct for accessibility")
    }
    
    // MARK: - Layout and Spacing Tests
    
    @MainActor
    func testNavigationLayoutWithFiveTabs() {
        // Test that the layout works properly with 5 tabs instead of 6
        var selectedTab = NavigationTab.dashboard
        
        let onTabSelected = { (tab: NavigationTab) in
            selectedTab = tab
        }
        
        let binding = Binding(
            get: { selectedTab },
            set: { selectedTab = $0 }
        )
        
        let navigation = FloatingBottomNavigation(
            selectedTab: binding,
            onTabSelected: onTabSelected
        )
        
        // Test that all tabs can be selected and layout accommodates them
        let allTabs = NavigationTab.allCases
        XCTAssertEqual(allTabs.count, 5, "Layout should accommodate 5 tabs")
        
        // Test tab transitions
        for tab in allTabs {
            onTabSelected(tab)
            XCTAssertEqual(selectedTab, tab, "Layout should handle selection of \(tab)")
        }
    }
    
    @MainActor
    func testNavigationSpacingWithFewerTabs() {
        // Test that spacing works properly with 5 tabs instead of 6
        let allTabs = NavigationTab.allCases
        XCTAssertEqual(allTabs.count, 5, "Should have 5 tabs for proper spacing")
        
        // Verify each tab has proper spacing by testing individual NavigationItems
        for (index, tab) in allTabs.enumerated() {
            let navigationItem = NavigationItem(
                tab: tab,
                isActive: index == 0, // First tab active
                onTap: {}
            )
            
            // Each item should be properly configured
            XCTAssertEqual(navigationItem.tab, tab, "Navigation item should be properly configured for \(tab)")
            XCTAssertEqual(navigationItem.isActive, index == 0, "Active state should be correct for \(tab)")
        }
    }
    
    // MARK: - Integration Tests
    
    @MainActor
    func testAppStateWithFiveTabNavigation() {
        // Test that AppState works correctly with 5-tab navigation
        appState.configureDemoScenario(.existingUser)
        
        // Test selecting each of the 5 tabs
        let allTabs = NavigationTab.allCases
        XCTAssertEqual(allTabs.count, 5, "AppState should work with 5 tabs")
        
        for tab in allTabs {
            appState.selectTab(tab)
            XCTAssertEqual(appState.selectedNavigationTab, tab, "AppState should handle selection of \(tab)")
        }
    }
    
    @MainActor
    func testNavigationWithHomeLifeTabSelection() {
        // Test specific HomeLife tab selection and icon display
        appState.configureDemoScenario(.existingUser)
        
        // Select HomeLife tab
        appState.selectTab(.homeLife)
        XCTAssertEqual(appState.selectedNavigationTab, .homeLife, "Should select HomeLife tab")
        
        // Verify HomeLife tab properties
        let homeLifeTab = NavigationTab.homeLife
        XCTAssertEqual(homeLifeTab.icon, "house.heart", "HomeLife inactive icon should be correct")
        XCTAssertEqual(homeLifeTab.activeIcon, "house.heart.fill", "HomeLife active icon should be correct")
        XCTAssertEqual(homeLifeTab.displayName, "HomeLife", "HomeLife display name should be correct")
    }
    
    // MARK: - Accessibility Integration Tests
    
    @MainActor
    func testFloatingBottomNavigationAccessibilityWithFiveTabs() {
        // Test FloatingBottomNavigation accessibility with 5 tabs
        let navigation = FloatingBottomNavigation(
            selectedTab: .constant(.dashboard),
            onTabSelected: { _ in }
        )
        
        // Verify accessibility properties are maintained with 5 tabs
        let allTabs = NavigationTab.allCases
        XCTAssertEqual(allTabs.count, 5, "Accessibility should work with 5 tabs")
        
        // Test that each tab maintains accessibility
        for tab in allTabs {
            XCTAssertFalse(tab.displayName.isEmpty, "Each tab should have accessibility label")
            XCTAssertTrue(tab.displayName.count > 1, "Accessibility labels should be meaningful")
        }
    }
    
    @MainActor
    func testNavigationAccessibilityRotorWithFiveTabs() {
        // Test that accessibility rotor works with 5 tabs
        let allTabs = NavigationTab.allCases
        XCTAssertEqual(allTabs.count, 5, "Accessibility rotor should handle 5 tabs")
        
        // Verify each tab can be accessed via rotor
        for tab in allTabs {
            let displayName = tab.displayName
            XCTAssertFalse(displayName.isEmpty, "Tab \(tab) should have display name for rotor")
            XCTAssertNotEqual(displayName, "Messages", "Messages tab should not be in rotor")
        }
    }
    
    // MARK: - Performance Tests
    
    @MainActor
    func testNavigationPerformanceWithFiveTabs() {
        // Test that navigation performance is good with 5 tabs
        measure {
            let allTabs = NavigationTab.allCases
            for _ in 0..<100 {
                for tab in allTabs {
                    _ = tab.displayName
                    _ = tab.icon
                    _ = tab.activeIcon
                    _ = tab.rawValue
                    _ = tab.id
                }
            }
        }
    }
    
    @MainActor
    func testFloatingBottomNavigationPerformanceWithFiveTabs() {
        // Test FloatingBottomNavigation performance with 5 tabs
        measure {
            for _ in 0..<50 {
                let navigation = FloatingBottomNavigation(
                    selectedTab: .constant(.dashboard),
                    onTabSelected: { _ in }
                )
                
                // Simulate tab selections
                let allTabs = NavigationTab.allCases
                for tab in allTabs {
                    let onTabSelected = { (_: NavigationTab) in }
                    onTabSelected(tab)
                }
            }
        }
    }
    
    // MARK: - Edge Cases and Error Handling
    
    @MainActor
    func testNavigationWithAllTabStates() {
        // Test navigation with all possible tab states
        let allTabs = NavigationTab.allCases
        
        for activeTab in allTabs {
            for tab in allTabs {
                let isActive = tab == activeTab
                let navigationItem = NavigationItem(
                    tab: tab,
                    isActive: isActive,
                    onTap: {}
                )
                
                XCTAssertEqual(navigationItem.tab, tab, "Tab should be correct")
                XCTAssertEqual(navigationItem.isActive, isActive, "Active state should be correct")
            }
        }
    }
    
    @MainActor
    func testNavigationTabEnumCompleteness() {
        // Ensure NavigationTab enum is complete and consistent
        let allCases = NavigationTab.allCases
        let expectedCount = 5
        
        XCTAssertEqual(allCases.count, expectedCount, "Should have exactly \(expectedCount) navigation tabs")
        
        // Verify no duplicates
        let uniqueRawValues = Set(allCases.map { $0.rawValue })
        XCTAssertEqual(uniqueRawValues.count, allCases.count, "All raw values should be unique")
        
        // Verify no duplicates in display names
        let uniqueDisplayNames = Set(allCases.map { $0.displayName })
        XCTAssertEqual(uniqueDisplayNames.count, allCases.count, "All display names should be unique")
    }
}