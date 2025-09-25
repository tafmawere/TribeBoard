import XCTest
import SwiftUI
@testable import TribeBoard

/// Integration tests for floating bottom navigation flow
/// Tests navigation between all four main sections, state synchronization,
/// visibility logic, and coordination with NavigationStack
@MainActor
final class FloatingBottomNavigationIntegrationTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var appState: AppState!
    var mockServiceCoordinator: MockServiceCoordinator!
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Initialize AppState and mock services
        appState = AppState()
        mockServiceCoordinator = MockServiceCoordinator()
        appState.setMockServiceCoordinator(mockServiceCoordinator)
        
        // Set up authenticated state with family for navigation tests
        await setupAuthenticatedUserWithFamily()
    }
    
    override func tearDown() async throws {
        appState = nil
        mockServiceCoordinator = nil
        try await super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    /// Set up authenticated user with family membership for navigation testing
    private func setupAuthenticatedUserWithFamily() async {
        let mockData = MockDataGenerator.mockFamilyWithMembers()
        
        // Set up authenticated state
        appState.isAuthenticated = true
        appState.currentUser = mockData.users[0] // Use first user as current user
        appState.currentFamily = mockData.family
        appState.currentMembership = mockData.memberships.first { $0.user?.id == mockData.users[0].id }
        appState.currentFlow = .familyDashboard
        
        // Ensure we start with home tab selected
        appState.selectedNavigationTab = .dashboard
    }
    
    /// Simulate tab selection with proper timing
    private func simulateTabSelection(_ tab: NavigationTab) async {
        appState.handleTabSelection(tab)
        
        // Allow time for state updates
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }
    
    // MARK: - Navigation Between All Four Main Sections Tests
    
    func testNavigationBetweenAllMainSections() async {
        // Test navigation from home to all other sections
        XCTAssertEqual(appState.selectedNavigationTab, .dashboard)
        
        // Navigate to School Run
        await simulateTabSelection(.schoolRun)
        XCTAssertEqual(appState.selectedNavigationTab, .schoolRun)
        XCTAssertTrue(appState.navigationPath.isEmpty, "Navigation path should be reset when switching tabs")
        
        // Navigate to Shopping
        await simulateTabSelection(.messages)
        XCTAssertEqual(appState.selectedNavigationTab, .messages)
        XCTAssertTrue(appState.navigationPath.isEmpty, "Navigation path should be reset when switching tabs")
        
        // Navigate to Tasks
        await simulateTabSelection(.tasks)
        XCTAssertEqual(appState.selectedNavigationTab, .tasks)
        XCTAssertTrue(appState.navigationPath.isEmpty, "Navigation path should be reset when switching tabs")
        
        // Navigate back to Home
        await simulateTabSelection(.dashboard)
        XCTAssertEqual(appState.selectedNavigationTab, .dashboard)
        XCTAssertEqual(appState.currentFlow, .familyDashboard, "Home tab should ensure family dashboard flow")
        XCTAssertTrue(appState.navigationPath.isEmpty, "Navigation path should be reset when switching tabs")
    }
    
    func testNavigationSequenceWithAllTabs() async {
        // Test a complete navigation sequence through all tabs
        let navigationSequence: [NavigationTab] = [.schoolRun, .messages, .tasks, .dashboard, .tasks, .schoolRun, .dashboard]
        
        for (index, tab) in navigationSequence.enumerated() {
            await simulateTabSelection(tab)
            
            XCTAssertEqual(appState.selectedNavigationTab, tab, "Failed at sequence step \(index): expected \(tab)")
            XCTAssertTrue(appState.navigationPath.isEmpty, "Navigation path should be empty at sequence step \(index)")
            
            // Verify flow state for home tab
            if tab == .dashboard {
                XCTAssertEqual(appState.currentFlow, .familyDashboard, "Home tab should maintain family dashboard flow at step \(index)")
            }
        }
    }
    
    func testNavigationWithRapidTabSwitching() async {
        // Test rapid tab switching to ensure state consistency
        let rapidSequence: [NavigationTab] = [.schoolRun, .dashboard, .tasks, .messages, .dashboard, .schoolRun]
        
        for tab in rapidSequence {
            appState.handleTabSelection(tab)
            // No delay to simulate rapid switching
        }
        
        // Allow final state to settle
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        
        // Final state should be consistent
        XCTAssertEqual(appState.selectedNavigationTab, .schoolRun)
        XCTAssertTrue(appState.navigationPath.isEmpty)
    }
    
    // MARK: - State Synchronization Tests
    
    func testStateSynchronizationWithCurrentView() async {
        // Test that navigation state stays synchronized with current view
        
        // Start at home
        XCTAssertEqual(appState.selectedNavigationTab, .dashboard)
        XCTAssertEqual(appState.currentFlow, .familyDashboard)
        
        // Navigate to tasks and verify synchronization
        await simulateTabSelection(.tasks)
        XCTAssertEqual(appState.selectedNavigationTab, .tasks)
        XCTAssertEqual(appState.currentFlow, .familyDashboard, "Flow should remain family dashboard")
        
        // Add navigation path and switch tabs - path should be reset
        appState.navigationPath.append("task-detail")
        appState.navigationPath.append("task-edit")
        XCTAssertFalse(appState.navigationPath.isEmpty)
        
        await simulateTabSelection(.messages)
        XCTAssertEqual(appState.selectedNavigationTab, .messages)
        XCTAssertTrue(appState.navigationPath.isEmpty, "Navigation path should be reset when switching tabs")
        
        // Verify state remains consistent after multiple operations
        await simulateTabSelection(.dashboard)
        XCTAssertEqual(appState.selectedNavigationTab, .dashboard)
        XCTAssertEqual(appState.currentFlow, .familyDashboard)
        XCTAssertTrue(appState.navigationPath.isEmpty)
    }
    
    func testStateSynchronizationWithAppStateChanges() async {
        // Test that navigation state persists through other app state changes
        
        // Set initial navigation state
        await simulateTabSelection(.schoolRun)
        XCTAssertEqual(appState.selectedNavigationTab, .schoolRun)
        
        // Change loading state
        appState.isLoading = true
        XCTAssertEqual(appState.selectedNavigationTab, .schoolRun, "Tab selection should persist during loading")
        
        appState.isLoading = false
        XCTAssertEqual(appState.selectedNavigationTab, .schoolRun, "Tab selection should persist after loading")
        
        // Change error state
        appState.showError("Test error")
        XCTAssertEqual(appState.selectedNavigationTab, .schoolRun, "Tab selection should persist during error")
        
        appState.clearError()
        XCTAssertEqual(appState.selectedNavigationTab, .schoolRun, "Tab selection should persist after error cleared")
        
        // Change user data (but maintain authentication)
        let newUser = UserProfile(displayName: "New User", appleUserIdHash: "new_hash")
        appState.currentUser = newUser
        XCTAssertEqual(appState.selectedNavigationTab, .schoolRun, "Tab selection should persist through user changes")
    }
    
    func testStateSynchronizationWithNavigationPathChanges() async {
        // Test that tab selection and navigation path work together correctly
        
        await simulateTabSelection(.tasks)
        XCTAssertEqual(appState.selectedNavigationTab, .tasks)
        XCTAssertTrue(appState.navigationPath.isEmpty)
        
        // Add navigation path items
        appState.navigationPath.append("task-list")
        appState.navigationPath.append("task-detail")
        XCTAssertEqual(appState.navigationPath.count, 2)
        XCTAssertEqual(appState.selectedNavigationTab, .tasks, "Tab selection should persist with navigation path")
        
        // Switch tabs - should reset navigation path
        await simulateTabSelection(.messages)
        XCTAssertEqual(appState.selectedNavigationTab, .messages)
        XCTAssertTrue(appState.navigationPath.isEmpty, "Navigation path should be reset when switching tabs")
        
        // Add path again and use resetNavigation
        appState.navigationPath.append("shopping-list")
        XCTAssertFalse(appState.navigationPath.isEmpty)
        
        appState.resetNavigation()
        XCTAssertTrue(appState.navigationPath.isEmpty, "resetNavigation should clear navigation path")
        XCTAssertEqual(appState.selectedNavigationTab, .messages, "resetNavigation should not change selected tab")
    }
    
    // MARK: - Navigation Visibility Logic Tests
    
    func testNavigationVisibilityAcrossDifferentAppStates() async {
        // Test shouldShowBottomNavigation across different app states
        
        // Authenticated with family in dashboard - should show
        XCTAssertTrue(appState.isAuthenticated)
        XCTAssertNotNil(appState.currentFamily)
        XCTAssertEqual(appState.currentFlow, .familyDashboard)
        XCTAssertTrue(appState.shouldShowBottomNavigation, "Should show navigation in family dashboard")
        
        // Change to onboarding flow - should hide
        appState.currentFlow = .onboarding
        XCTAssertFalse(appState.shouldShowBottomNavigation, "Should hide navigation during onboarding")
        
        // Change to family selection - should hide
        appState.currentFlow = .familySelection
        XCTAssertFalse(appState.shouldShowBottomNavigation, "Should hide navigation during family selection")
        
        // Change to create family - should hide
        appState.currentFlow = .createFamily
        XCTAssertFalse(appState.shouldShowBottomNavigation, "Should hide navigation during family creation")
        
        // Change to join family - should hide
        appState.currentFlow = .joinFamily
        XCTAssertFalse(appState.shouldShowBottomNavigation, "Should hide navigation during family joining")
        
        // Change to role selection - should hide
        appState.currentFlow = .roleSelection
        XCTAssertFalse(appState.shouldShowBottomNavigation, "Should hide navigation during role selection")
        
        // Back to family dashboard - should show
        appState.currentFlow = .familyDashboard
        XCTAssertTrue(appState.shouldShowBottomNavigation, "Should show navigation when back to family dashboard")
    }
    
    func testNavigationVisibilityWithAuthenticationChanges() async {
        // Test visibility changes with authentication state
        
        // Start authenticated with family - should show
        XCTAssertTrue(appState.shouldShowBottomNavigation)
        
        // Sign out - should hide
        appState.isAuthenticated = false
        appState.currentUser = nil
        appState.currentFamily = nil
        appState.currentMembership = nil
        appState.currentFlow = .onboarding
        XCTAssertFalse(appState.shouldShowBottomNavigation, "Should hide navigation when not authenticated")
        
        // Sign in but no family - should hide
        appState.isAuthenticated = true
        appState.currentUser = UserProfile(displayName: "Test User", appleUserIdHash: "test_hash")
        appState.currentFamily = nil
        appState.currentFlow = .familySelection
        XCTAssertFalse(appState.shouldShowBottomNavigation, "Should hide navigation without family")
        
        // Add family - should show
        let mockData = MockDataGenerator.mockFamilyWithMembers()
        appState.currentFamily = mockData.family
        appState.currentMembership = mockData.memberships[0]
        appState.currentFlow = .familyDashboard
        XCTAssertTrue(appState.shouldShowBottomNavigation, "Should show navigation with family")
    }
    
    func testNavigationVisibilityWithFamilyChanges() async {
        // Test visibility changes with family membership changes
        
        // Start with family - should show
        XCTAssertTrue(appState.shouldShowBottomNavigation)
        
        // Leave family - should hide
        appState.leaveFamily()
        XCTAssertNil(appState.currentFamily)
        XCTAssertNil(appState.currentMembership)
        XCTAssertEqual(appState.currentFlow, .familySelection)
        XCTAssertFalse(appState.shouldShowBottomNavigation, "Should hide navigation after leaving family")
        
        // Join new family - should show
        let newMockData = MockDataGenerator.mockFamilyWithMembers()
        appState.setFamily(newMockData.family, membership: newMockData.memberships[0])
        XCTAssertEqual(appState.currentFlow, .familyDashboard)
        XCTAssertTrue(appState.shouldShowBottomNavigation, "Should show navigation after joining family")
    }
    
    // MARK: - NavigationStack Coordination Tests
    
    func testNavigationStackCoordinationWithTabSelection() async {
        // Test that tab selection properly coordinates with NavigationStack
        
        // Start with empty navigation path
        XCTAssertTrue(appState.navigationPath.isEmpty)
        XCTAssertEqual(appState.selectedNavigationTab, .dashboard)
        
        // Add navigation path items
        appState.navigationPath.append("detail1")
        appState.navigationPath.append("detail2")
        XCTAssertEqual(appState.navigationPath.count, 2)
        
        // Switch tabs - should reset navigation path
        await simulateTabSelection(.tasks)
        XCTAssertTrue(appState.navigationPath.isEmpty, "Tab selection should reset NavigationStack path")
        XCTAssertEqual(appState.selectedNavigationTab, .tasks)
        
        // Add path again and switch to another tab
        appState.navigationPath.append("task-detail")
        XCTAssertEqual(appState.navigationPath.count, 1)
        
        await simulateTabSelection(.schoolRun)
        XCTAssertTrue(appState.navigationPath.isEmpty, "Tab selection should reset NavigationStack path")
        XCTAssertEqual(appState.selectedNavigationTab, .schoolRun)
    }
    
    func testNavigationStackCoordinationWithFlowChanges() async {
        // Test NavigationStack coordination with app flow changes
        
        // Start in family dashboard with navigation path
        appState.navigationPath.append("dashboard-detail")
        XCTAssertEqual(appState.navigationPath.count, 1)
        XCTAssertEqual(appState.currentFlow, .familyDashboard)
        
        // Change flow to family selection - should reset path
        appState.currentFlow = .familySelection
        // Navigation path might be preserved during flow changes, but tab selection should reset it
        
        await simulateTabSelection(.dashboard)
        XCTAssertTrue(appState.navigationPath.isEmpty, "Tab selection should reset path regardless of flow")
        XCTAssertEqual(appState.currentFlow, .familyDashboard, "Home tab should set family dashboard flow")
    }
    
    func testNavigationStackCoordinationWithResetNavigation() async {
        // Test explicit navigation reset coordination
        
        // Set up navigation state
        await simulateTabSelection(.messages)
        appState.navigationPath.append("shopping-list")
        appState.navigationPath.append("item-detail")
        XCTAssertEqual(appState.navigationPath.count, 2)
        XCTAssertEqual(appState.selectedNavigationTab, .messages)
        
        // Reset navigation
        appState.resetNavigation()
        XCTAssertTrue(appState.navigationPath.isEmpty, "resetNavigation should clear NavigationStack path")
        XCTAssertEqual(appState.selectedNavigationTab, .messages, "resetNavigation should preserve selected tab")
        
        // Verify navigation still works after reset
        await simulateTabSelection(.tasks)
        XCTAssertEqual(appState.selectedNavigationTab, .tasks)
        XCTAssertTrue(appState.navigationPath.isEmpty)
    }
    
    // MARK: - Complex Integration Scenarios
    
    func testCompleteUserNavigationJourney() async {
        // Test a complete user navigation journey
        
        // 1. Start at home
        XCTAssertEqual(appState.selectedNavigationTab, .dashboard)
        XCTAssertTrue(appState.shouldShowBottomNavigation)
        
        // 2. Navigate to tasks, drill down into details
        await simulateTabSelection(.tasks)
        appState.navigationPath.append("task-list")
        appState.navigationPath.append("task-detail")
        XCTAssertEqual(appState.selectedNavigationTab, .tasks)
        XCTAssertEqual(appState.navigationPath.count, 2)
        
        // 3. Switch to school run (should reset path)
        await simulateTabSelection(.schoolRun)
        XCTAssertEqual(appState.selectedNavigationTab, .schoolRun)
        XCTAssertTrue(appState.navigationPath.isEmpty)
        
        // 4. Navigate to shopping
        await simulateTabSelection(.messages)
        XCTAssertEqual(appState.selectedNavigationTab, .messages)
        
        // 5. Go back to home
        await simulateTabSelection(.dashboard)
        XCTAssertEqual(appState.selectedNavigationTab, .dashboard)
        XCTAssertEqual(appState.currentFlow, .familyDashboard)
        
        // 6. Verify final state
        XCTAssertTrue(appState.shouldShowBottomNavigation)
        XCTAssertTrue(appState.navigationPath.isEmpty)
        XCTAssertTrue(appState.isAuthenticated)
        XCTAssertNotNil(appState.currentFamily)
    }
    
    func testNavigationWithErrorRecovery() async {
        // Test navigation behavior during error states
        
        // Start normal navigation
        await simulateTabSelection(.tasks)
        XCTAssertEqual(appState.selectedNavigationTab, .tasks)
        
        // Simulate error
        appState.showError("Network error")
        XCTAssertNotNil(appState.errorMessage)
        XCTAssertEqual(appState.selectedNavigationTab, .tasks, "Tab selection should persist during error")
        
        // Navigation should still work during error
        await simulateTabSelection(.messages)
        XCTAssertEqual(appState.selectedNavigationTab, .messages)
        XCTAssertNotNil(appState.errorMessage, "Error should persist during navigation")
        
        // Clear error
        appState.clearError()
        XCTAssertNil(appState.errorMessage)
        XCTAssertEqual(appState.selectedNavigationTab, .messages, "Tab selection should persist after error cleared")
        
        // Navigation should continue to work normally
        await simulateTabSelection(.dashboard)
        XCTAssertEqual(appState.selectedNavigationTab, .dashboard)
    }
    
    func testNavigationWithLoadingStates() async {
        // Test navigation behavior during loading states
        
        await simulateTabSelection(.schoolRun)
        XCTAssertEqual(appState.selectedNavigationTab, .schoolRun)
        
        // Start loading
        appState.isLoading = true
        XCTAssertTrue(appState.isLoading)
        XCTAssertEqual(appState.selectedNavigationTab, .schoolRun, "Tab selection should persist during loading")
        
        // Navigation should still work during loading
        await simulateTabSelection(.tasks)
        XCTAssertEqual(appState.selectedNavigationTab, .tasks)
        XCTAssertTrue(appState.isLoading, "Loading state should persist during navigation")
        
        // Stop loading
        appState.isLoading = false
        XCTAssertFalse(appState.isLoading)
        XCTAssertEqual(appState.selectedNavigationTab, .tasks, "Tab selection should persist after loading")
    }
    
    // MARK: - Edge Cases and Error Conditions
    
    func testNavigationWithInvalidStates() async {
        // Test navigation behavior with invalid app states
        
        // Remove family but keep authenticated
        appState.currentFamily = nil
        appState.currentMembership = nil
        XCTAssertFalse(appState.shouldShowBottomNavigation, "Should not show navigation without family")
        
        // Tab selection should still work (for when navigation becomes visible again)
        await simulateTabSelection(.messages)
        XCTAssertEqual(appState.selectedNavigationTab, .messages)
        
        // Restore family
        let mockData = MockDataGenerator.mockFamilyWithMembers()
        appState.currentFamily = mockData.family
        appState.currentMembership = mockData.memberships[0]
        appState.currentFlow = .familyDashboard
        XCTAssertTrue(appState.shouldShowBottomNavigation, "Should show navigation when family restored")
        XCTAssertEqual(appState.selectedNavigationTab, .messages, "Tab selection should be preserved")
    }
    
    func testNavigationIdempotency() async {
        // Test that repeated navigation operations are safe
        
        // Select same tab multiple times
        await simulateTabSelection(.tasks)
        await simulateTabSelection(.tasks)
        await simulateTabSelection(.tasks)
        XCTAssertEqual(appState.selectedNavigationTab, .tasks)
        XCTAssertTrue(appState.navigationPath.isEmpty)
        
        // Reset navigation multiple times
        appState.resetNavigation()
        appState.resetNavigation()
        appState.resetNavigation()
        XCTAssertTrue(appState.navigationPath.isEmpty)
        XCTAssertEqual(appState.selectedNavigationTab, .tasks)
        
        // Mixed operations
        await simulateTabSelection(.dashboard)
        appState.resetNavigation()
        await simulateTabSelection(.dashboard)
        XCTAssertEqual(appState.selectedNavigationTab, .dashboard)
        XCTAssertEqual(appState.currentFlow, .familyDashboard)
    }
    
    // MARK: - Performance and Stress Tests
    
    func testNavigationPerformanceWithRapidSwitching() async {
        // Test performance with rapid tab switching
        let startTime = Date()
        
        for i in 0..<100 {
            let tab = NavigationTab.allCases[i % NavigationTab.allCases.count]
            appState.handleTabSelection(tab)
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        XCTAssertLessThan(duration, 1.0, "Rapid navigation switching should complete within 1 second")
        XCTAssertTrue(appState.navigationPath.isEmpty, "Navigation path should be empty after rapid switching")
        XCTAssertTrue(NavigationTab.allCases.contains(appState.selectedNavigationTab), "Should end with valid tab selected")
    }
    
    func testNavigationMemoryStability() async {
        // Test that navigation doesn't cause memory issues
        
        for _ in 0..<50 {
            // Create navigation path
            for j in 0..<10 {
                appState.navigationPath.append("detail-\(j)")
            }
            
            // Switch tabs (should reset path)
            for tab in NavigationTab.allCases {
                await simulateTabSelection(tab)
            }
            
            // Verify clean state
            XCTAssertTrue(appState.navigationPath.isEmpty)
        }
        
        // Final verification
        XCTAssertTrue(appState.navigationPath.isEmpty)
        XCTAssertTrue(NavigationTab.allCases.contains(appState.selectedNavigationTab))
    }
    
    // MARK: - Integration with Mock Services
    
    func testNavigationWithMockServiceIntegration() async {
        // Test navigation integration with mock services
        
        XCTAssertNotNil(appState.mockServices, "Mock services should be available")
        
        // Test navigation with different user scenarios
        appState.configureDemoScenario(.familyAdmin)
        XCTAssertTrue(appState.shouldShowBottomNavigation, "Family admin should see navigation")
        
        await simulateTabSelection(.tasks)
        XCTAssertEqual(appState.selectedNavigationTab, .tasks)
        
        appState.configureDemoScenario(.childUser)
        XCTAssertTrue(appState.shouldShowBottomNavigation, "Child user should see navigation")
        XCTAssertEqual(appState.selectedNavigationTab, .tasks, "Tab selection should persist across scenario changes")
        
        appState.configureDemoScenario(.visitorUser)
        XCTAssertTrue(appState.shouldShowBottomNavigation, "Visitor user should see navigation")
        XCTAssertEqual(appState.selectedNavigationTab, .tasks, "Tab selection should persist across scenario changes")
    }
    
    func testNavigationWithDemoJourneyIntegration() async {
        // Test navigation with demo journey manager
        
        guard let demoManager = appState.getDemoManager() else {
            XCTFail("Demo manager should be available")
            return
        }
        
        // Start demo journey
        appState.startGuidedDemo(.newUserOnboarding)
        
        // Navigation should still work during demo
        await simulateTabSelection(.schoolRun)
        XCTAssertEqual(appState.selectedNavigationTab, .schoolRun)
        
        // Reset to initial state
        appState.resetToInitialState()
        XCTAssertEqual(appState.selectedNavigationTab, .dashboard, "Should reset to home tab")
        XCTAssertEqual(appState.currentFlow, .onboarding, "Should reset to onboarding flow")
        XCTAssertFalse(appState.shouldShowBottomNavigation, "Should not show navigation after reset")
    }
}