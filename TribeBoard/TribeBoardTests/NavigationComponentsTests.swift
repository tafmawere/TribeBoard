import XCTest
import SwiftUI
@testable import TribeBoard

final class NavigationComponentsTests: XCTestCase {
    
    // MARK: - NavigationTab Enum Tests
    
    func testNavigationTabAllCases() {
        let allCases = NavigationTab.allCases
        XCTAssertEqual(allCases.count, 4)
        XCTAssertTrue(allCases.contains(.home))
        XCTAssertTrue(allCases.contains(.schoolRun))
        XCTAssertTrue(allCases.contains(.shopping))
        XCTAssertTrue(allCases.contains(.tasks))
    }
    
    func testNavigationTabRawValues() {
        XCTAssertEqual(NavigationTab.home.rawValue, "home")
        XCTAssertEqual(NavigationTab.schoolRun.rawValue, "school_run")
        XCTAssertEqual(NavigationTab.shopping.rawValue, "shopping")
        XCTAssertEqual(NavigationTab.tasks.rawValue, "tasks")
    }
    
    func testNavigationTabIdentifiable() {
        XCTAssertEqual(NavigationTab.home.id, "home")
        XCTAssertEqual(NavigationTab.schoolRun.id, "school_run")
        XCTAssertEqual(NavigationTab.shopping.id, "shopping")
        XCTAssertEqual(NavigationTab.tasks.id, "tasks")
    }
    
    func testNavigationTabDisplayNames() {
        XCTAssertEqual(NavigationTab.home.displayName, "Home")
        XCTAssertEqual(NavigationTab.schoolRun.displayName, "School Run")
        XCTAssertEqual(NavigationTab.shopping.displayName, "Shopping")
        XCTAssertEqual(NavigationTab.tasks.displayName, "Tasks")
        
        // Ensure all display names are non-empty
        for tab in NavigationTab.allCases {
            XCTAssertFalse(tab.displayName.isEmpty, "Display name should not be empty for \(tab)")
        }
    }
    
    func testNavigationTabIcons() {
        // Test inactive icons
        XCTAssertEqual(NavigationTab.home.icon, "house")
        XCTAssertEqual(NavigationTab.schoolRun.icon, "bus")
        XCTAssertEqual(NavigationTab.shopping.icon, "cart")
        XCTAssertEqual(NavigationTab.tasks.icon, "checkmark.circle")
        
        // Test active icons
        XCTAssertEqual(NavigationTab.home.activeIcon, "house.fill")
        XCTAssertEqual(NavigationTab.schoolRun.activeIcon, "bus.fill")
        XCTAssertEqual(NavigationTab.shopping.activeIcon, "cart.fill")
        XCTAssertEqual(NavigationTab.tasks.activeIcon, "checkmark.circle.fill")
        
        // Ensure all icons are non-empty
        for tab in NavigationTab.allCases {
            XCTAssertFalse(tab.icon.isEmpty, "Icon should not be empty for \(tab)")
            XCTAssertFalse(tab.activeIcon.isEmpty, "Active icon should not be empty for \(tab)")
        }
    }
    
    func testNavigationTabIconConsistency() {
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
    
    func testNavigationItemInitialization() {
        let tab = NavigationTab.home
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
    
    func testNavigationItemTapCallback() {
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
    
    func testNavigationItemActiveStateChanges() {
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
    
    func testFloatingBottomNavigationInitialization() {
        let selectedTab = NavigationTab.home
        var tappedTab: NavigationTab?
        let onTabSelected = { (tab: NavigationTab) in tappedTab = tab }
        
        let navigation = FloatingBottomNavigation(
            selectedTab: .constant(selectedTab),
            onTabSelected: onTabSelected
        )
        
        // Test that callback works
        onTabSelected(.shopping)
        XCTAssertEqual(tappedTab, .shopping)
    }
    
    func testFloatingBottomNavigationTabSelection() {
        var selectedTab = NavigationTab.home
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
    
    func testFloatingBottomNavigationAllTabsPresent() {
        let _ = FloatingBottomNavigation(
            selectedTab: .constant(.home),
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
    
    // MARK: - AppState Navigation Tests
    
    @MainActor
    var appState: AppState!
    
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
    
    func testAppStateNavigationTabInitialization() async {
        await MainActor.run {
            XCTAssertEqual(appState.selectedNavigationTab, .home)
        }
    }
    
    func testAppStateSelectTab() async {
        await MainActor.run {
            // Test selecting different tabs
            appState.selectTab(.schoolRun)
            XCTAssertEqual(appState.selectedNavigationTab, .schoolRun)
            
            appState.selectTab(.shopping)
            XCTAssertEqual(appState.selectedNavigationTab, .shopping)
            
            appState.selectTab(.tasks)
            XCTAssertEqual(appState.selectedNavigationTab, .tasks)
            
            appState.selectTab(.home)
            XCTAssertEqual(appState.selectedNavigationTab, .home)
        }
    }
    
    func testAppStateSelectTabNavigationLogic() async {
        await MainActor.run {
            // Test that selecting home tab sets appropriate flow
            appState.selectTab(.home)
            XCTAssertEqual(appState.selectedNavigationTab, .home)
            XCTAssertEqual(appState.currentFlow, .familyDashboard)
            
            // Test that navigation path is reset when selecting home
            appState.navigationPath.append("test")
            XCTAssertFalse(appState.navigationPath.isEmpty)
            
            appState.selectTab(.home)
            XCTAssertTrue(appState.navigationPath.isEmpty)
        }
    }
    
    func testAppStateHandleTabSelection() async {
        await MainActor.run {
            // Test the enhanced tab selection method
            appState.handleTabSelection(.schoolRun)
            XCTAssertEqual(appState.selectedNavigationTab, .schoolRun)
            XCTAssertTrue(appState.navigationPath.isEmpty)
            
            appState.handleTabSelection(.shopping)
            XCTAssertEqual(appState.selectedNavigationTab, .shopping)
            XCTAssertTrue(appState.navigationPath.isEmpty)
            
            appState.handleTabSelection(.tasks)
            XCTAssertEqual(appState.selectedNavigationTab, .tasks)
            XCTAssertTrue(appState.navigationPath.isEmpty)
        }
    }
    
    func testAppStateHandleTabSelectionWithNavigationPath() async {
        await MainActor.run {
            // Add some navigation path
            appState.navigationPath.append("detail1")
            appState.navigationPath.append("detail2")
            XCTAssertFalse(appState.navigationPath.isEmpty)
            
            // Selecting a tab should reset navigation path
            appState.handleTabSelection(.tasks)
            XCTAssertTrue(appState.navigationPath.isEmpty)
            XCTAssertEqual(appState.selectedNavigationTab, .tasks)
        }
    }
    
    func testAppStateShouldShowBottomNavigation() async {
        await MainActor.run {
            // Initially should not show navigation (not authenticated)
            XCTAssertFalse(appState.shouldShowBottomNavigation)
            
            // Set up authenticated state with family
            appState.isAuthenticated = true
            appState.currentFamily = Family(name: "Test Family", code: "TEST123", createdByUserId: UUID())
            appState.currentFlow = .familyDashboard
            
            XCTAssertTrue(appState.shouldShowBottomNavigation)
            
            // Should not show during onboarding
            appState.currentFlow = .onboarding
            XCTAssertFalse(appState.shouldShowBottomNavigation)
            
            // Should not show during family selection
            appState.currentFlow = .familySelection
            XCTAssertFalse(appState.shouldShowBottomNavigation)
            
            // Should not show during family creation
            appState.currentFlow = .createFamily
            XCTAssertFalse(appState.shouldShowBottomNavigation)
            
            // Should not show during join family
            appState.currentFlow = .joinFamily
            XCTAssertFalse(appState.shouldShowBottomNavigation)
            
            // Should not show during role selection
            appState.currentFlow = .roleSelection
            XCTAssertFalse(appState.shouldShowBottomNavigation)
        }
    }
    
    func testAppStateShouldShowBottomNavigationWithoutFamily() async {
        await MainActor.run {
            // Even if authenticated, should not show without family
            appState.isAuthenticated = true
            appState.currentFamily = nil
            appState.currentFlow = .familyDashboard
            
            XCTAssertFalse(appState.shouldShowBottomNavigation)
        }
    }
    
    func testAppStateShouldShowBottomNavigationWithoutAuthentication() async {
        await MainActor.run {
            // Should not show if not authenticated, even with family
            appState.isAuthenticated = false
            appState.currentFamily = Family(name: "Test Family", code: "TEST123", createdByUserId: UUID())
            appState.currentFlow = .familyDashboard
            
            XCTAssertFalse(appState.shouldShowBottomNavigation)
        }
    }
    
    func testAppStateResetNavigation() async {
        await MainActor.run {
            // Add some navigation path
            appState.navigationPath.append("detail1")
            appState.navigationPath.append("detail2")
            XCTAssertFalse(appState.navigationPath.isEmpty)
            
            // Reset navigation
            appState.resetNavigation()
            XCTAssertTrue(appState.navigationPath.isEmpty)
        }
    }
    
    func testAppStateNavigationTabPersistence() async {
        await MainActor.run {
            // Test that selected tab persists across other state changes
            appState.selectTab(.shopping)
            XCTAssertEqual(appState.selectedNavigationTab, .shopping)
            
            // Change other state
            appState.isLoading = true
            appState.errorMessage = "Test error"
            
            // Tab selection should persist
            XCTAssertEqual(appState.selectedNavigationTab, .shopping)
            
            // Clear error and loading
            appState.clearError()
            appState.isLoading = false
            
            // Tab selection should still persist
            XCTAssertEqual(appState.selectedNavigationTab, .shopping)
        }
    }
    
    // MARK: - Integration Tests
    
    func testNavigationComponentsIntegration() {
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
        XCTAssertEqual(navigationItem.tab.icon, "bus")
        XCTAssertEqual(navigationItem.tab.activeIcon, "bus.fill")
        
        // Test tap functionality
        navigationItem.onTap()
        XCTAssertEqual(tappedTab, .schoolRun)
    }
    
    func testFloatingBottomNavigationWithAppState() async {
        await MainActor.run {
            // Test integration between FloatingBottomNavigation and AppState
            var selectedTab = NavigationTab.home
            
            let onTabSelected = { (tab: NavigationTab) in
                selectedTab = tab
                self.appState.handleTabSelection(tab)
            }
            
            let binding = Binding(
                get: { selectedTab },
                set: { selectedTab = $0 }
            )
            
            let _ = FloatingBottomNavigation(
                selectedTab: binding,
                onTabSelected: onTabSelected
            )
            
            // Test tab selection updates both local state and AppState
            onTabSelected(.tasks)
            
            XCTAssertEqual(selectedTab, .tasks)
            XCTAssertEqual(appState.selectedNavigationTab, .tasks)
            XCTAssertTrue(appState.navigationPath.isEmpty)
        }
    }
    
    // MARK: - Edge Cases and Error Handling
    
    func testNavigationTabCaseIterable() {
        // Ensure all cases are covered and none are missing
        let allCases = NavigationTab.allCases
        let expectedCases: [NavigationTab] = [.home, .schoolRun, .shopping, .tasks]
        
        XCTAssertEqual(allCases.count, expectedCases.count)
        
        for expectedCase in expectedCases {
            XCTAssertTrue(allCases.contains(expectedCase), "Missing case: \(expectedCase)")
        }
    }
    
    func testNavigationItemWithAllTabs() {
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
    
    func testAppStateTabSelectionIdempotency() async {
        await MainActor.run {
            // Test that selecting the same tab multiple times is safe
            appState.selectTab(.shopping)
            XCTAssertEqual(appState.selectedNavigationTab, .shopping)
            
            appState.selectTab(.shopping)
            XCTAssertEqual(appState.selectedNavigationTab, .shopping)
            
            appState.selectTab(.shopping)
            XCTAssertEqual(appState.selectedNavigationTab, .shopping)
            
            // Should still be in correct state
            XCTAssertEqual(appState.currentFlow, .familyDashboard)
        }
    }
    
    func testAppStateNavigationWithMockServices() async {
        await MainActor.run {
            // Test navigation behavior with mock services enabled
            appState.configureDemoScenario(.existingUser)
            
            // Should be in family dashboard flow
            XCTAssertEqual(appState.currentFlow, .familyDashboard)
            XCTAssertTrue(appState.isAuthenticated)
            XCTAssertNotNil(appState.currentFamily)
            
            // Navigation should work
            appState.selectTab(.tasks)
            XCTAssertEqual(appState.selectedNavigationTab, .tasks)
            
            // Should show bottom navigation
            XCTAssertTrue(appState.shouldShowBottomNavigation)
        }
    }
    
    // MARK: - Performance Tests
    
    func testNavigationTabEnumPerformance() {
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
    
    func testAppStateNavigationPerformance() async {
        await MainActor.run {
            // Test that navigation state changes are performant
            measure {
                for _ in 0..<100 {
                    for tab in NavigationTab.allCases {
                        appState.selectTab(tab)
                        appState.resetNavigation()
                    }
                }
            }
        }
    }
    
    // MARK: - Accessibility Tests
    
    func testNavigationTabAccessibilityProperties() {
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
    
    func testNavigationItemAccessibilityIntegration() {
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
}