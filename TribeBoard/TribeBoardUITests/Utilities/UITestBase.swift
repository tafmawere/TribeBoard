import XCTest

/// Base class for all UI tests providing common setup, teardown, and utility methods
class UITestBase: XCTestCase {
    
    // MARK: - Properties
    
    /// The main app instance for UI testing
    var app: XCUIApplication!
    
    /// Default timeout for UI operations
    let defaultTimeout: TimeInterval = 10.0
    
    /// Short timeout for quick operations
    let shortTimeout: TimeInterval = 3.0
    
    /// Long timeout for complex operations
    let longTimeout: TimeInterval = 30.0
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        
        // Stop immediately when a failure occurs
        continueAfterFailure = false
        
        setupApp()
        launchApp()
    }
    
    override func tearDown() {
        app?.terminate()
        app = nil
        super.tearDown()
    }
    
    // MARK: - App Setup
    
    private func setupApp() {
        app = XCUIApplication()
        
        // Configure app for testing
        app.launchArguments = [
            "-UITesting",
            "-DisableAnimations",
            "-UseMockServices"
        ]
        
        app.launchEnvironment = [
            "UI_TESTING": "1",
            "MOCK_AUTH_SERVICE": "1",
            "MOCK_DATA_SERVICE": "1",
            "DISABLE_NETWORK_CALLS": "1"
        ]
    }
    
    private func launchApp() {
        app.launch()
        
        // Wait for app to be ready
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: defaultTimeout))
    }
    
    // MARK: - Navigation Helpers
    
    /// Navigates to a specific tab in the main navigation
    func navigateToTab(_ tab: String) {
        let tabButton = app.tabBars.buttons[tab]
        XCTAssertTrue(tabButton.waitForExistence(timeout: defaultTimeout))
        tabButton.tap()
    }
    
    /// Navigates back using the navigation back button
    func navigateBack() {
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        if backButton.exists {
            backButton.tap()
        }
    }
    
    /// Dismisses any presented modal or sheet
    func dismissModal() {
        // Try common dismiss methods
        if app.buttons["Done"].exists {
            app.buttons["Done"].tap()
        } else if app.buttons["Cancel"].exists {
            app.buttons["Cancel"].tap()
        } else if app.buttons["Close"].exists {
            app.buttons["Close"].tap()
        }
    }
    
    // MARK: - Element Interaction Helpers
    
    /// Safely taps an element after waiting for it to exist
    func safeTap(_ element: XCUIElement, timeout: TimeInterval = 0) {
        let waitTime = timeout > 0 ? timeout : defaultTimeout
        XCTAssertTrue(element.waitForExistence(timeout: waitTime))
        XCTAssertTrue(element.isHittable)
        element.tap()
    }
    
    /// Safely types text into a text field
    func safeTypeText(_ text: String, into element: XCUIElement, timeout: TimeInterval = 0) {
        let waitTime = timeout > 0 ? timeout : defaultTimeout
        XCTAssertTrue(element.waitForExistence(timeout: waitTime))
        element.tap()
        element.typeText(text)
    }
    
    /// Clears text from a text field and types new text
    func clearAndTypeText(_ text: String, into element: XCUIElement, timeout: TimeInterval = 0) {
        let waitTime = timeout > 0 ? timeout : defaultTimeout
        XCTAssertTrue(element.waitForExistence(timeout: waitTime))
        element.tap()
        
        // Clear existing text
        if let currentText = element.value as? String, !currentText.isEmpty {
            element.doubleTap()
            element.typeText(XCUIKeyboardKey.delete.rawValue)
        }
        
        element.typeText(text)
    }
    
    /// Waits for an element to appear
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 0) -> Bool {
        let waitTime = timeout > 0 ? timeout : defaultTimeout
        return element.waitForExistence(timeout: waitTime)
    }
    
    /// Waits for an element to disappear
    func waitForElementToDisappear(_ element: XCUIElement, timeout: TimeInterval = 0) -> Bool {
        let waitTime = timeout > 0 ? timeout : defaultTimeout
        return element.waitForNonExistence(timeout: waitTime)
    }
    
    // MARK: - Authentication Helpers
    
    /// Performs mock sign-in flow
    func performMockSignIn() {
        let signInButton = app.buttons["Sign in with Apple"]
        safeTap(signInButton)
        
        // Wait for authentication to complete
        let dashboardIndicator = app.staticTexts["Family Dashboard"]
        XCTAssertTrue(dashboardIndicator.waitForExistence(timeout: longTimeout))
    }
    
    /// Performs sign-out flow
    func performSignOut() {
        navigateToTab("Settings")
        
        let signOutButton = app.buttons["Sign Out"]
        if signOutButton.waitForExistence(timeout: defaultTimeout) {
            safeTap(signOutButton)
            
            // Handle confirmation if present
            let confirmButton = app.alerts.buttons["Sign Out"]
            if confirmButton.waitForExistence(timeout: shortTimeout) {
                safeTap(confirmButton)
            }
        }
    }
    
    // MARK: - Loading State Helpers
    
    /// Waits for loading indicators to disappear
    func waitForLoadingToComplete(timeout: TimeInterval = 0) {
        let waitTime = timeout > 0 ? timeout : defaultTimeout
        
        let loadingIndicators = [
            app.activityIndicators.firstMatch,
            app.staticTexts["Loading..."],
            app.progressIndicators.firstMatch
        ]
        
        for indicator in loadingIndicators {
            if indicator.exists {
                XCTAssertTrue(indicator.waitForNonExistence(timeout: waitTime))
            }
        }
    }
    
    // MARK: - Error Handling Helpers
    
    /// Dismisses any error alerts
    func dismissErrorAlerts() {
        let alert = app.alerts.firstMatch
        if alert.exists {
            let okButton = alert.buttons["OK"]
            let dismissButton = alert.buttons["Dismiss"]
            
            if okButton.exists {
                okButton.tap()
            } else if dismissButton.exists {
                dismissButton.tap()
            }
        }
    }
    
    /// Checks if an error alert is displayed
    func isErrorAlertDisplayed() -> Bool {
        return app.alerts.firstMatch.exists
    }
    
    // MARK: - Accessibility Helpers
    
    /// Verifies that an element has proper accessibility labels
    func verifyAccessibilityLabel(_ element: XCUIElement, expectedLabel: String) {
        XCTAssertTrue(element.waitForExistence(timeout: defaultTimeout))
        XCTAssertEqual(element.label, expectedLabel)
    }
    
    /// Verifies that an element has accessibility traits
    func verifyAccessibilityTraits(_ element: XCUIElement, expectedTraits: XCUIElement.ElementType) {
        XCTAssertTrue(element.waitForExistence(timeout: defaultTimeout))
        XCTAssertEqual(element.elementType, expectedTraits)
    }
    
    /// Checks if VoiceOver is enabled (for accessibility testing)
    func isVoiceOverEnabled() -> Bool {
        return UIAccessibility.isVoiceOverRunning
    }
    
    // MARK: - Screenshot Helpers
    
    /// Takes a screenshot with a descriptive name
    func takeScreenshot(name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    
    /// Takes a screenshot on test failure
    func takeFailureScreenshot() {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Test Failure - \(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    
    // MARK: - Form Helpers
    
    /// Fills out a form with provided data
    func fillForm(_ formData: [String: String]) {
        for (fieldIdentifier, value) in formData {
            let textField = app.textFields[fieldIdentifier]
            if textField.exists {
                clearAndTypeText(value, into: textField)
            }
        }
    }
    
    /// Submits a form by tapping the submit button
    func submitForm(buttonIdentifier: String = "Submit") {
        let submitButton = app.buttons[buttonIdentifier]
        safeTap(submitButton)
    }
    
    // MARK: - Scroll Helpers
    
    /// Scrolls to make an element visible
    func scrollToElement(_ element: XCUIElement, in scrollView: XCUIElement? = nil) {
        let container = scrollView ?? app.scrollViews.firstMatch
        
        while !element.isHittable && container.exists {
            container.swipeUp()
        }
        
        XCTAssertTrue(element.isHittable, "Element should be visible after scrolling")
    }
}

// MARK: - Custom Assertions

extension UITestBase {
    
    /// Asserts that a screen is displayed by checking for key elements
    func assertScreenIsDisplayed(_ screenIdentifier: String, timeout: TimeInterval = 0) {
        let waitTime = timeout > 0 ? timeout : defaultTimeout
        let screenElement = app.otherElements[screenIdentifier]
        XCTAssertTrue(screenElement.waitForExistence(timeout: waitTime), 
                     "Screen '\(screenIdentifier)' should be displayed")
    }
    
    /// Asserts that navigation completed successfully
    func assertNavigationCompleted(to destination: String, timeout: TimeInterval = 0) {
        let waitTime = timeout > 0 ? timeout : defaultTimeout
        let navigationTitle = app.navigationBars[destination]
        XCTAssertTrue(navigationTitle.waitForExistence(timeout: waitTime),
                     "Should navigate to '\(destination)'")
    }
    
    /// Asserts that an element is accessible
    func assertElementIsAccessible(_ element: XCUIElement) {
        XCTAssertTrue(element.exists, "Element should exist")
        XCTAssertFalse(element.label.isEmpty, "Element should have accessibility label")
        XCTAssertTrue(element.isHittable, "Element should be hittable")
    }
}