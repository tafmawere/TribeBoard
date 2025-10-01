import XCTest

/// UI tests for error state display and error recovery functionality
class ErrorStateUITests: UITestBase {
    
    // MARK: - Test Setup
    
    override func setUp() {
        super.setUp()
        
        // Configure app for error state testing
        app.launchEnvironment["ENABLE_ERROR_SCENARIOS"] = "1"
        app.launchEnvironment["MOCK_ERROR_STATES"] = "1"
    }
    
    // MARK: - Error Message Display Tests
    
    func testNetworkErrorDisplayConsistency() {
        // Navigate to a screen that can show network errors
        performMockSignIn()
        navigateToTab("Family")
        
        // Trigger network error scenario
        app.buttons["Demo Controls"].tap()
        app.buttons["Trigger Network Error"].tap()
        
        // Verify error message display
        let errorView = app.otherElements["NetworkErrorView"]
        XCTAssertTrue(errorView.waitForExistence(timeout: defaultTimeout))
        
        // Check error message consistency
        let errorTitle = app.staticTexts["Connection Lost"]
        let errorMessage = app.staticTexts["Unable to connect to TribeBoard servers. Please check your internet connection and try again."]
        
        XCTAssertTrue(errorTitle.exists)
        XCTAssertTrue(errorMessage.exists)
        
        // Verify error icon is displayed
        let errorIcon = app.images["network-error-icon"]
        XCTAssertTrue(errorIcon.exists)
        
        takeScreenshot(name: "Network Error Display")
    }
    
    func testAuthenticationErrorDisplayClarity() {
        // Start from sign-in screen
        let signInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: defaultTimeout))
        
        // Configure mock to return authentication error
        app.buttons["Demo Controls"].tap()
        app.buttons["Set Auth Error"].tap()
        app.buttons["Authorization Failed"].tap()
        app.buttons["Done"].tap()
        
        // Attempt sign-in to trigger error
        signInButton.tap()
        
        // Verify authentication error alert
        let errorAlert = app.alerts["Authentication Error"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: defaultTimeout))
        
        // Check error message clarity
        let errorMessage = errorAlert.staticTexts["Authentication failed. Please try again or contact support if the problem persists."]
        XCTAssertTrue(errorMessage.exists)
        
        // Verify alert buttons
        let tryAgainButton = errorAlert.buttons["Try Again"]
        let cancelButton = errorAlert.buttons["Cancel"]
        
        XCTAssertTrue(tryAgainButton.exists)
        XCTAssertTrue(cancelButton.exists)
        
        takeScreenshot(name: "Authentication Error Alert")
        
        // Dismiss alert
        cancelButton.tap()
    }
    
    func testFamilyManagementErrorDisplay() {
        performMockSignIn()
        navigateToTab("Family")
        
        // Trigger family management error
        app.buttons["Create New Family"].tap()
        
        // Configure error scenario
        app.buttons["Demo Controls"].tap()
        app.buttons["Set Family Error"].tap()
        app.buttons["Family Full"].tap()
        app.buttons["Done"].tap()
        
        // Fill form and submit to trigger error
        let familyNameField = app.textFields["Family Name"]
        clearAndTypeText("Test Family", into: familyNameField)
        
        app.buttons["Create Family"].tap()
        
        // Verify family error display
        let errorView = app.otherElements["FamilyFullErrorView"]
        XCTAssertTrue(errorView.waitForExistence(timeout: defaultTimeout))
        
        let errorTitle = app.staticTexts["Family is Full"]
        let errorMessage = app.staticTexts["This family has reached its maximum number of members. Contact the family admin to make space or upgrade the plan."]
        
        XCTAssertTrue(errorTitle.exists)
        XCTAssertTrue(errorMessage.exists)
        
        takeScreenshot(name: "Family Management Error")
    }
    
    func testPermissionErrorDisplay() {
        performMockSignIn()
        navigateToTab("Family")
        
        // Configure permission error scenario
        app.buttons["Demo Controls"].tap()
        app.buttons["Set Permission Error"].tap()
        app.buttons["Access Denied"].tap()
        app.buttons["Done"].tap()
        
        // Try to perform admin action
        app.buttons["Family Settings"].tap()
        app.buttons["Manage Members"].tap()
        
        // Verify permission error display
        let errorView = app.otherElements["PermissionDeniedErrorView"]
        XCTAssertTrue(errorView.waitForExistence(timeout: defaultTimeout))
        
        let errorTitle = app.staticTexts["Access Denied"]
        let errorMessage = app.staticTexts["You don't have permission to perform this action. Only family admins can manage members and settings."]
        
        XCTAssertTrue(errorTitle.exists)
        XCTAssertTrue(errorMessage.exists)
        
        takeScreenshot(name: "Permission Error Display")
    }
    
    // MARK: - Error Recovery Option Tests
    
    func testNetworkErrorRecoveryOptions() {
        performMockSignIn()
        navigateToTab("Tasks")
        
        // Trigger network error
        app.buttons["Demo Controls"].tap()
        app.buttons["Trigger Network Error"].tap()
        
        let errorView = app.otherElements["NetworkErrorView"]
        XCTAssertTrue(errorView.waitForExistence(timeout: defaultTimeout))
        
        // Verify retry button exists and is functional
        let retryButton = app.buttons["Try Again"]
        XCTAssertTrue(retryButton.exists)
        XCTAssertTrue(retryButton.isEnabled)
        
        // Test retry functionality
        retryButton.tap()
        
        // Verify loading state appears
        let loadingIndicator = app.activityIndicators.firstMatch
        XCTAssertTrue(loadingIndicator.waitForExistence(timeout: shortTimeout))
        
        // Wait for retry to complete
        waitForLoadingToComplete()
        
        // Verify error is dismissed after successful retry
        XCTAssertTrue(errorView.waitForNonExistence(timeout: defaultTimeout))
        
        takeScreenshot(name: "Network Error Recovery")
    }
    
    func testOfflineErrorContinueOption() {
        performMockSignIn()
        navigateToTab("Family")
        
        // Trigger offline error
        app.buttons["Demo Controls"].tap()
        app.buttons["Trigger Offline Error"].tap()
        
        let errorView = app.otherElements["OfflineErrorView"]
        XCTAssertTrue(errorView.waitForExistence(timeout: defaultTimeout))
        
        // Verify continue offline option
        let continueButton = app.buttons["Continue Offline"]
        XCTAssertTrue(continueButton.exists)
        XCTAssertTrue(continueButton.isEnabled)
        
        // Test continue offline functionality
        continueButton.tap()
        
        // Verify offline mode indicator appears
        let offlineIndicator = app.staticTexts["Offline Mode"]
        XCTAssertTrue(offlineIndicator.waitForExistence(timeout: defaultTimeout))
        
        // Verify limited functionality message
        let limitedFunctionalityMessage = app.staticTexts["Limited functionality available"]
        XCTAssertTrue(limitedFunctionalityMessage.exists)
        
        takeScreenshot(name: "Offline Error Continue")
    }
    
    func testAuthenticationErrorRetryFlow() {
        // Start from sign-in screen
        let signInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: defaultTimeout))
        
        // Configure authentication error
        app.buttons["Demo Controls"].tap()
        app.buttons["Set Auth Error"].tap()
        app.buttons["Network Unavailable"].tap()
        app.buttons["Done"].tap()
        
        // Attempt sign-in
        signInButton.tap()
        
        // Handle error alert
        let errorAlert = app.alerts["Authentication Error"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: defaultTimeout))
        
        let tryAgainButton = errorAlert.buttons["Try Again"]
        XCTAssertTrue(tryAgainButton.exists)
        
        // Clear error condition for retry
        tryAgainButton.tap()
        
        // Configure successful authentication for retry
        app.buttons["Demo Controls"].tap()
        app.buttons["Clear Auth Error"].tap()
        app.buttons["Done"].tap()
        
        // Verify retry works
        XCTAssertTrue(signInButton.waitForExistence(timeout: defaultTimeout))
        signInButton.tap()
        
        // Verify successful authentication
        let dashboardIndicator = app.staticTexts["Family Dashboard"]
        XCTAssertTrue(dashboardIndicator.waitForExistence(timeout: longTimeout))
        
        takeScreenshot(name: "Authentication Error Retry Success")
    }
    
    func testFamilyErrorContactAdminOption() {
        performMockSignIn()
        navigateToTab("Family")
        
        // Trigger family full error
        app.buttons["Join Family"].tap()
        
        app.buttons["Demo Controls"].tap()
        app.buttons["Set Family Error"].tap()
        app.buttons["Family Full"].tap()
        app.buttons["Done"].tap()
        
        let familyCodeField = app.textFields["Family Code"]
        clearAndTypeText("ABC123", into: familyCodeField)
        
        app.buttons["Join Family"].tap()
        
        let errorView = app.otherElements["FamilyFullErrorView"]
        XCTAssertTrue(errorView.waitForExistence(timeout: defaultTimeout))
        
        // Verify contact admin option
        let contactAdminButton = app.buttons["Contact Admin"]
        XCTAssertTrue(contactAdminButton.exists)
        XCTAssertTrue(contactAdminButton.isEnabled)
        
        // Test contact admin functionality
        contactAdminButton.tap()
        
        // Verify contact options appear
        let contactSheet = app.sheets["Contact Options"]
        XCTAssertTrue(contactSheet.waitForExistence(timeout: defaultTimeout))
        
        let sendMessageButton = contactSheet.buttons["Send Message"]
        let sendEmailButton = contactSheet.buttons["Send Email"]
        
        XCTAssertTrue(sendMessageButton.exists)
        XCTAssertTrue(sendEmailButton.exists)
        
        takeScreenshot(name: "Family Error Contact Admin")
        
        // Dismiss sheet
        contactSheet.buttons["Cancel"].tap()
    }
    
    // MARK: - Error State Accessibility Tests
    
    func testErrorStateAccessibilityLabels() {
        performMockSignIn()
        navigateToTab("Tasks")
        
        // Trigger network error
        app.buttons["Demo Controls"].tap()
        app.buttons["Trigger Network Error"].tap()
        
        let errorView = app.otherElements["NetworkErrorView"]
        XCTAssertTrue(errorView.waitForExistence(timeout: defaultTimeout))
        
        // Verify accessibility labels
        let errorIcon = app.images["network-error-icon"]
        verifyAccessibilityLabel(errorIcon, expectedLabel: "Network connection error")
        
        let errorTitle = app.staticTexts["Connection Lost"]
        verifyAccessibilityLabel(errorTitle, expectedLabel: "Connection Lost")
        
        let errorMessage = app.staticTexts["Unable to connect to TribeBoard servers. Please check your internet connection and try again."]
        XCTAssertTrue(errorMessage.exists)
        XCTAssertFalse(errorMessage.label.isEmpty)
        
        let retryButton = app.buttons["Try Again"]
        verifyAccessibilityLabel(retryButton, expectedLabel: "Try Again")
        verifyAccessibilityTraits(retryButton, expectedTraits: .button)
    }
    
    func testErrorAlertAccessibilitySupport() {
        // Start from sign-in screen
        let signInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: defaultTimeout))
        
        // Configure authentication error
        app.buttons["Demo Controls"].tap()
        app.buttons["Set Auth Error"].tap()
        app.buttons["Authorization Failed"].tap()
        app.buttons["Done"].tap()
        
        // Trigger error
        signInButton.tap()
        
        let errorAlert = app.alerts["Authentication Error"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: defaultTimeout))
        
        // Verify alert accessibility
        XCTAssertFalse(errorAlert.label.isEmpty)
        
        // Verify button accessibility
        let tryAgainButton = errorAlert.buttons["Try Again"]
        let cancelButton = errorAlert.buttons["Cancel"]
        
        verifyAccessibilityTraits(tryAgainButton, expectedTraits: .button)
        verifyAccessibilityTraits(cancelButton, expectedTraits: .button)
        
        XCTAssertTrue(tryAgainButton.isHittable)
        XCTAssertTrue(cancelButton.isHittable)
        
        // Test keyboard navigation if VoiceOver is enabled
        if isVoiceOverEnabled() {
            // Verify focus can move between alert elements
            XCTAssertTrue(tryAgainButton.hasFocus || cancelButton.hasFocus)
        }
        
        cancelButton.tap()
    }
    
    func testErrorStateScreenReaderSupport() {
        performMockSignIn()
        navigateToTab("Family")
        
        // Trigger permission error
        app.buttons["Demo Controls"].tap()
        app.buttons["Set Permission Error"].tap()
        app.buttons["Access Denied"].tap()
        app.buttons["Done"].tap()
        
        app.buttons["Family Settings"].tap()
        
        let errorView = app.otherElements["PermissionDeniedErrorView"]
        XCTAssertTrue(errorView.waitForExistence(timeout: defaultTimeout))
        
        // Verify screen reader can access all error elements
        let errorElements = [
            app.images["permission-error-icon"],
            app.staticTexts["Access Denied"],
            app.staticTexts["You don't have permission to perform this action. Only family admins can manage members and settings."],
            app.buttons["Contact Admin"]
        ]
        
        for element in errorElements {
            XCTAssertTrue(element.exists)
            assertElementIsAccessible(element)
        }
        
        // Verify proper reading order for screen readers
        let contactAdminButton = app.buttons["Contact Admin"]
        XCTAssertTrue(contactAdminButton.exists)
        
        // Verify semantic structure
        XCTAssertTrue(errorView.exists)
        XCTAssertFalse(errorView.label.isEmpty)
    }
    
    func testErrorStateDynamicTypeSupport() {
        // Configure larger text size
        app.launchEnvironment["DYNAMIC_TYPE_SIZE"] = "accessibilityExtraExtraExtraLarge"
        
        performMockSignIn()
        navigateToTab("Tasks")
        
        // Trigger network error
        app.buttons["Demo Controls"].tap()
        app.buttons["Trigger Network Error"].tap()
        
        let errorView = app.otherElements["NetworkErrorView"]
        XCTAssertTrue(errorView.waitForExistence(timeout: defaultTimeout))
        
        // Verify error text scales properly
        let errorTitle = app.staticTexts["Connection Lost"]
        let errorMessage = app.staticTexts["Unable to connect to TribeBoard servers. Please check your internet connection and try again."]
        
        XCTAssertTrue(errorTitle.exists)
        XCTAssertTrue(errorMessage.exists)
        
        // Verify buttons remain accessible with larger text
        let retryButton = app.buttons["Try Again"]
        XCTAssertTrue(retryButton.exists)
        XCTAssertTrue(retryButton.isHittable)
        
        // Verify layout doesn't break with larger text
        XCTAssertTrue(errorView.frame.height > 0)
        XCTAssertTrue(errorView.frame.width > 0)
        
        takeScreenshot(name: "Error State Dynamic Type Support")
    }
    
    // MARK: - Error State Context Tests
    
    func testErrorStateInDifferentContexts() {
        performMockSignIn()
        
        // Test error in family context
        navigateToTab("Family")
        app.buttons["Demo Controls"].tap()
        app.buttons["Trigger Network Error"].tap()
        
        let familyErrorView = app.otherElements["NetworkErrorView"]
        XCTAssertTrue(familyErrorView.waitForExistence(timeout: defaultTimeout))
        
        // Verify context-appropriate error message
        let contextMessage = app.staticTexts["Unable to load family information"]
        XCTAssertTrue(contextMessage.exists)
        
        // Dismiss error
        app.buttons["Try Again"].tap()
        waitForLoadingToComplete()
        
        // Test error in tasks context
        navigateToTab("Tasks")
        app.buttons["Demo Controls"].tap()
        app.buttons["Trigger Network Error"].tap()
        
        let tasksErrorView = app.otherElements["NetworkErrorView"]
        XCTAssertTrue(tasksErrorView.waitForExistence(timeout: defaultTimeout))
        
        // Verify context-appropriate error message
        let tasksContextMessage = app.staticTexts["Unable to load tasks"]
        XCTAssertTrue(tasksContextMessage.exists)
        
        takeScreenshot(name: "Error State Different Contexts")
    }
    
    func testMultipleErrorStatesHandling() {
        performMockSignIn()
        navigateToTab("Family")
        
        // Trigger multiple error conditions
        app.buttons["Demo Controls"].tap()
        app.buttons["Trigger Multiple Errors"].tap()
        
        // Verify primary error is displayed
        let primaryErrorView = app.otherElements["NetworkErrorView"]
        XCTAssertTrue(primaryErrorView.waitForExistence(timeout: defaultTimeout))
        
        // Verify secondary errors are queued or handled appropriately
        let errorQueue = app.staticTexts["Additional errors: 2"]
        XCTAssertTrue(errorQueue.exists)
        
        // Resolve primary error
        app.buttons["Try Again"].tap()
        waitForLoadingToComplete()
        
        // Verify next error in queue is displayed
        let secondaryErrorView = app.otherElements["AuthenticationErrorView"]
        XCTAssertTrue(secondaryErrorView.waitForExistence(timeout: defaultTimeout))
        
        takeScreenshot(name: "Multiple Error States Handling")
    }
}