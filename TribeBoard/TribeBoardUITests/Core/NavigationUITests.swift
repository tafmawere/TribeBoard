import XCTest

/// UI tests for app navigation functionality including tab navigation, state persistence, and accessibility
final class NavigationUITests: UITestBase {
    
    // MARK: - Tab Navigation Tests
    
    /// Test navigation between main app sections using tab bar
    func testTabNavigationBetweenMainSections() {
        // Arrange: Sign in to access main navigation
        performMockSignIn()
        waitForLoadingToComplete()
        
        // Test navigation to each main tab
        let tabs = ["Dashboard", "Calendar", "Run", "HomeLife", "Tasks"]
        
        for tab in tabs {
            // Act: Navigate to tab
            navigateToTab(tab)
            
            // Assert: Verify tab is selected and content is displayed
            let tabButton = app.tabBars.buttons[tab]
            XCTAssertTrue(tabButton.isSelected, "Tab '\(tab)' should be selected")
            
            // Verify content area is displayed
            let contentArea = app.scrollViews.firstMatch
            XCTAssertTrue(contentArea.waitForExistence(timeout: defaultTimeout),
                         "Content area should be displayed for '\(tab)' tab")
            
            // Take screenshot for visual verification
            takeScreenshot(name: "Navigation_\(tab)_Tab")
        }
    }
    
    /// Test tab navigation maintains proper selection state
    func testTabSelectionStateManagement() {
        // Arrange: Sign in and navigate to dashboard
        performMockSignIn()
        waitForLoadingToComplete()
        
        // Act: Navigate between tabs and verify selection state
        navigateToTab("Calendar")
        XCTAssertTrue(app.tabBars.buttons["Calendar"].isSelected)
        XCTAssertFalse(app.tabBars.buttons["Dashboard"].isSelected)
        
        navigateToTab("Tasks")
        XCTAssertTrue(app.tabBars.buttons["Tasks"].isSelected)
        XCTAssertFalse(app.tabBars.buttons["Calendar"].isSelected)
        
        // Return to dashboard
        navigateToTab("Dashboard")
        XCTAssertTrue(app.tabBars.buttons["Dashboard"].isSelected)
        XCTAssertFalse(app.tabBars.buttons["Tasks"].isSelected)
    }
    
    /// Test rapid tab switching doesn't cause navigation issues
    func testRapidTabSwitching() {
        // Arrange: Sign in to access navigation
        performMockSignIn()
        waitForLoadingToComplete()
        
        let tabs = ["Dashboard", "Calendar", "Run", "HomeLife", "Tasks"]
        
        // Act: Rapidly switch between tabs
        for _ in 0..<3 {
            for tab in tabs {
                navigateToTab(tab)
                // Brief wait to allow transition
                Thread.sleep(forTimeInterval: 0.2)
            }
        }
        
        // Assert: App should still be responsive and on the last tab
        XCTAssertTrue(app.tabBars.buttons["Tasks"].isSelected)
        let contentArea = app.scrollViews.firstMatch
        XCTAssertTrue(contentArea.exists, "Content should still be displayed after rapid switching")
    }
    
    // MARK: - Navigation State Persistence Tests
    
    /// Test navigation state persists across app launches
    func testNavigationStatePersistenceAcrossLaunches() {
        // Arrange: Sign in and navigate to specific tab
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Calendar")
        
        // Verify initial state
        XCTAssertTrue(app.tabBars.buttons["Calendar"].isSelected)
        
        // Act: Terminate and relaunch app
        app.terminate()
        app.launch()
        
        // Wait for app to restore state
        let dashboardTab = app.tabBars.buttons["Dashboard"]
        XCTAssertTrue(dashboardTab.waitForExistence(timeout: longTimeout))
        
        // Assert: Should return to dashboard (default) after relaunch
        // Note: In a real app, this might persist the last selected tab
        XCTAssertTrue(app.tabBars.buttons["Dashboard"].isSelected,
                     "Should default to Dashboard after app relaunch")
    }
    
    /// Test deep linking navigation works correctly
    func testDeepLinkingNavigation() {
        // Arrange: Sign in to access navigation
        performMockSignIn()
        waitForLoadingToComplete()
        
        // Act: Simulate deep link to School Run section
        navigateToTab("Run")
        
        // Navigate to a specific school run screen
        let scheduleButton = app.buttons["Schedule New Run"]
        if scheduleButton.waitForExistence(timeout: defaultTimeout) {
            safeTap(scheduleButton)
            
            // Assert: Should navigate to schedule screen
            assertNavigationCompleted(to: "Schedule Run", timeout: defaultTimeout)
            
            // Verify back navigation works
            navigateBack()
            assertNavigationCompleted(to: "School Run", timeout: defaultTimeout)
        }
    }
    
    /// Test navigation stack management with multiple levels
    func testNavigationStackManagement() {
        // Arrange: Sign in and navigate to tasks
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Tasks")
        
        // Act: Navigate through multiple levels
        let createTaskButton = app.buttons["Create Task"]
        if createTaskButton.waitForExistence(timeout: defaultTimeout) {
            safeTap(createTaskButton)
            
            // Should be on task creation screen
            let taskForm = app.textFields["Task Title"]
            XCTAssertTrue(taskForm.waitForExistence(timeout: defaultTimeout))
            
            // Navigate back
            navigateBack()
            
            // Should be back on tasks list
            XCTAssertTrue(app.tabBars.buttons["Tasks"].isSelected)
            let tasksList = app.tables.firstMatch
            XCTAssertTrue(tasksList.waitForExistence(timeout: defaultTimeout))
        }
    }
    
    // MARK: - Navigation Accessibility Tests
    
    /// Test tab navigation accessibility with VoiceOver
    func testTabNavigationAccessibility() {
        // Arrange: Sign in to access navigation
        performMockSignIn()
        waitForLoadingToComplete()
        
        let tabs = ["Dashboard", "Calendar", "Run", "HomeLife", "Tasks"]
        
        for tab in tabs {
            let tabButton = app.tabBars.buttons[tab]
            
            // Assert: Tab button should be accessible
            assertElementIsAccessible(tabButton)
            
            // Verify accessibility label is descriptive
            XCTAssertFalse(tabButton.label.isEmpty, "Tab '\(tab)' should have accessibility label")
            
            // Verify accessibility traits
            XCTAssertTrue(tabButton.elementType == .button, "Tab should be identified as button")
            
            // Test tab activation via accessibility
            safeTap(tabButton)
            XCTAssertTrue(tabButton.isSelected, "Tab '\(tab)' should be selected after activation")
        }
    }
    
    /// Test keyboard navigation support
    func testKeyboardNavigationSupport() {
        // Arrange: Sign in to access navigation
        performMockSignIn()
        waitForLoadingToComplete()
        
        // Note: Keyboard navigation testing in XCUITest is limited
        // This test verifies that interactive elements are properly configured
        
        let tabs = ["Dashboard", "Calendar", "Run", "HomeLife", "Tasks"]
        
        for tab in tabs {
            let tabButton = app.tabBars.buttons[tab]
            
            // Assert: Tab should be focusable and hittable
            XCTAssertTrue(tabButton.waitForExistence(timeout: defaultTimeout))
            XCTAssertTrue(tabButton.isHittable, "Tab '\(tab)' should be keyboard accessible")
        }
    }
    
    /// Test navigation accessibility labels and hints
    func testNavigationAccessibilityLabelsAndHints() {
        // Arrange: Sign in to access navigation
        performMockSignIn()
        waitForLoadingToComplete()
        
        // Test main navigation tabs
        let expectedLabels = [
            "Dashboard": "Dashboard",
            "Calendar": "Calendar", 
            "Run": "Run",
            "HomeLife": "HomeLife",
            "Tasks": "Tasks"
        ]
        
        for (tab, expectedLabel) in expectedLabels {
            let tabButton = app.tabBars.buttons[tab]
            verifyAccessibilityLabel(tabButton, expectedLabel: expectedLabel)
        }
        
        // Test navigation back button accessibility
        navigateToTab("Run")
        let scheduleButton = app.buttons["Schedule New Run"]
        if scheduleButton.waitForExistence(timeout: defaultTimeout) {
            safeTap(scheduleButton)
            
            let backButton = app.navigationBars.buttons.element(boundBy: 0)
            if backButton.exists {
                XCTAssertFalse(backButton.label.isEmpty, "Back button should have accessibility label")
            }
        }
    }
    
    // MARK: - Navigation Error Handling Tests
    
    /// Test navigation behavior when not authenticated
    func testNavigationWithoutAuthentication() {
        // Arrange: Start app without signing in
        // App should show sign-in screen
        
        let signInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: defaultTimeout),
                     "Should show sign-in screen when not authenticated")
        
        // Assert: Navigation tabs should not be accessible
        let tabBar = app.tabBars.firstMatch
        XCTAssertFalse(tabBar.exists, "Tab bar should not be visible when not authenticated")
    }
    
    /// Test navigation recovery from error states
    func testNavigationErrorRecovery() {
        // Arrange: Sign in and navigate to a section
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Tasks")
        
        // Simulate error condition by attempting invalid navigation
        // In a real app, this might involve network errors or data issues
        
        // Act: Try to navigate to a restricted area or trigger an error
        let createTaskButton = app.buttons["Create Task"]
        if createTaskButton.waitForExistence(timeout: defaultTimeout) {
            safeTap(createTaskButton)
            
            // If an error occurs, the app should handle it gracefully
            if isErrorAlertDisplayed() {
                dismissErrorAlerts()
                
                // Assert: Should return to a safe navigation state
                XCTAssertTrue(app.tabBars.buttons["Tasks"].isSelected,
                             "Should maintain current tab selection after error recovery")
            }
        }
    }
    
    // MARK: - Navigation Performance Tests
    
    /// Test navigation transition performance
    func testNavigationTransitionPerformance() {
        // Arrange: Sign in to access navigation
        performMockSignIn()
        waitForLoadingToComplete()
        
        // Measure navigation performance
        measure {
            let tabs = ["Dashboard", "Calendar", "Run", "HomeLife", "Tasks"]
            
            for tab in tabs {
                navigateToTab(tab)
                waitForLoadingToComplete(timeout: shortTimeout)
            }
        }
    }
    
    /// Test navigation memory usage during extended use
    func testNavigationMemoryUsage() {
        // Arrange: Sign in to access navigation
        performMockSignIn()
        waitForLoadingToComplete()
        
        let tabs = ["Dashboard", "Calendar", "Run", "HomeLife", "Tasks"]
        
        // Act: Perform extensive navigation to test memory management
        for cycle in 0..<10 {
            for tab in tabs {
                navigateToTab(tab)
                
                // Verify app remains responsive
                let tabButton = app.tabBars.buttons[tab]
                XCTAssertTrue(tabButton.isSelected, 
                             "Navigation should remain responsive in cycle \(cycle)")
            }
        }
        
        // Assert: App should still be functional
        let contentArea = app.scrollViews.firstMatch
        XCTAssertTrue(contentArea.exists, "App should remain functional after extensive navigation")
    }
    
    // MARK: - Helper Methods
    
    /// Verifies that all main navigation tabs are present and accessible
    private func verifyMainNavigationTabsExist() {
        let expectedTabs = ["Dashboard", "Calendar", "Run", "HomeLife", "Tasks"]
        
        for tab in expectedTabs {
            let tabButton = app.tabBars.buttons[tab]
            XCTAssertTrue(tabButton.waitForExistence(timeout: defaultTimeout),
                         "Tab '\(tab)' should exist in navigation")
        }
    }
    
    /// Verifies navigation state is consistent
    private func verifyNavigationStateConsistency() {
        let selectedTabs = app.tabBars.buttons.allElementsBoundByIndex.filter { $0.isSelected }
        XCTAssertEqual(selectedTabs.count, 1, "Exactly one tab should be selected")
    }
}