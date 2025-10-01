import XCTest

/// UI tests for authentication error state displays and error handling
final class AuthErrorUITests: UITestBase {
    
    // MARK: - Test Setup
    
    override func setUp() {
        super.setUp()
        
        // Ensure we start from signed-out state
        app.launchEnvironment["MOCK_AUTH_STATE"] = "signed_out"
    }
    
    // MARK: - Authentication Error Alert Display Tests
    
    func testAuthorizationFailedErrorDisplay() {
        // Given: App is configured to simulate authorization failure
        app.launchEnvironment["MOCK_AUTH_ERROR"] = "authorizationFailed"
        app.launch()
        
        let signInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: defaultTimeout))
        
        // When: User attempts sign-in and authorization fails
        signInButton.tap()
        
        // Then: Error alert should be displayed with correct message
        let alert = app.alerts["Authentication Error"]
        XCTAssertTrue(alert.waitForExistence(timeout: defaultTimeout))
        
        // Verify error message content
        let errorMessage = alert.staticTexts.element(matching: .staticText, identifier: "We couldn't sign you in with Apple ID. This might be due to a temporary issue with Apple's servers. Please try again.")
        XCTAssertTrue(errorMessage.exists)
        
        // Verify alert buttons
        XCTAssertTrue(alert.buttons["OK"].exists)
        XCTAssertTrue(alert.buttons["Retry"].exists)
        
        takeScreenshot(name: "AuthError_Authorization_Failed")
    }
    
    func testUserCancelledErrorDisplay() {
        // Given: App is configured to simulate user cancellation
        app.launchEnvironment["MOCK_AUTH_ERROR"] = "userCancelled"
        app.launch()
        
        let signInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: defaultTimeout))
        
        // When: User cancels sign-in
        signInButton.tap()
        
        // Then: Error alert should be displayed with appropriate message
        let alert = app.alerts["Authentication Error"]
        XCTAssertTrue(alert.waitForExistence(timeout: defaultTimeout))
        
        // Verify user-cancelled specific message
        let errorMessage = alert.staticTexts.element(matching: .staticText, identifier: "Sign in was cancelled. You can try again when you're ready.")
        XCTAssertTrue(errorMessage.exists)
        
        // Verify only OK button is shown (no retry for user cancellation)
        XCTAssertTrue(alert.buttons["OK"].exists)
        XCTAssertFalse(alert.buttons["Retry"].exists)
        
        takeScreenshot(name: "AuthError_User_Cancelled")
    }
    
    func testNetworkUnavailableErrorDisplay() {
        // Given: App is configured to simulate network unavailable
        app.launchEnvironment["MOCK_AUTH_ERROR"] = "networkUnavailable"
        app.launchEnvironment["MOCK_NETWORK_CONNECTED"] = "false"
        app.launch()
        
        let signInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: defaultTimeout))
        
        // When: User attempts sign-in with no network
        signInButton.tap()
        
        // Then: Network error alert should be displayed
        let alert = app.alerts["Authentication Error"]
        XCTAssertTrue(alert.waitForExistence(timeout: defaultTimeout))
        
        // Verify network-specific error message
        let errorMessage = alert.staticTexts.element(matching: .staticText, identifier: "No internet connection detected. Please connect to Wi-Fi or cellular data and try again.")
        XCTAssertTrue(errorMessage.exists)
        
        // Verify smart retry button for network errors
        XCTAssertTrue(alert.buttons["OK"].exists)
        XCTAssertTrue(alert.buttons["Retry when connected"].exists)
        
        takeScreenshot(name: "AuthError_Network_Unavailable")
    }
    
    func testInvalidCredentialsErrorDisplay() {
        // Given: App is configured to simulate invalid credentials
        app.launchEnvironment["MOCK_AUTH_ERROR"] = "invalidCredentials"
        app.launch()
        
        let signInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: defaultTimeout))
        
        // When: User attempts sign-in with invalid credentials
        signInButton.tap()
        
        // Then: Invalid credentials error should be displayed
        let alert = app.alerts["Authentication Error"]
        XCTAssertTrue(alert.waitForExistence(timeout: defaultTimeout))
        
        // Verify invalid credentials message
        let errorMessage = alert.staticTexts.element(matching: .staticText, identifier: "There was an issue with the credentials from Apple. Please try signing in again.")
        XCTAssertTrue(errorMessage.exists)
        
        // Verify retry option is available
        XCTAssertTrue(alert.buttons["OK"].exists)
        XCTAssertTrue(alert.buttons["Retry"].exists)
        
        takeScreenshot(name: "AuthError_Invalid_Credentials")
    }
    
    func testKeychainErrorDisplay() {
        // Given: App is configured to simulate keychain error
        app.launchEnvironment["MOCK_AUTH_ERROR"] = "keychainError"
        app.launch()
        
        let signInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: defaultTimeout))
        
        // When: User attempts sign-in and keychain error occurs
        signInButton.tap()
        
        // Then: Keychain error should be displayed
        let alert = app.alerts["Authentication Error"]
        XCTAssertTrue(alert.waitForExistence(timeout: defaultTimeout))
        
        // Verify keychain error message pattern
        let keychainErrorExists = alert.staticTexts.containing("There was a problem securely storing your sign-in information").firstMatch.exists
        XCTAssertTrue(keychainErrorExists)
        
        // Verify retry option is available
        XCTAssertTrue(alert.buttons["OK"].exists)
        XCTAssertTrue(alert.buttons["Retry"].exists)
        
        takeScreenshot(name: "AuthError_Keychain_Error")
    }
    
    func testDataServiceErrorDisplay() {
        // Given: App is configured to simulate data service error
        app.launchEnvironment["MOCK_AUTH_ERROR"] = "dataServiceError"
        app.launch()
        
        let signInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: defaultTimeout))
        
        // When: User attempts sign-in and data service error occurs
        signInButton.tap()
        
        // Then: Data service error should be displayed
        let alert = app.alerts["Authentication Error"]
        XCTAssertTrue(alert.waitForExistence(timeout: defaultTimeout))
        
        // Verify data service error message pattern
        let dataErrorExists = alert.staticTexts.containing("There was a problem setting up your account").firstMatch.exists
        XCTAssertTrue(dataErrorExists)
        
        // Verify retry option is available
        XCTAssertTrue(alert.buttons["OK"].exists)
        XCTAssertTrue(alert.buttons["Retry"].exists)
        
        takeScreenshot(name: "AuthError_Data_Service_Error")
    }
    
    func testUnknownErrorDisplay() {
        // Given: App is configured to simulate unknown error
        app.launchEnvironment["MOCK_AUTH_ERROR"] = "unknownError"
        app.launch()
        
        let signInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: defaultTimeout))
        
        // When: User attempts sign-in and unknown error occurs
        signInButton.tap()
        
        // Then: Unknown error should be displayed
        let alert = app.alerts["Authentication Error"]
        XCTAssertTrue(alert.waitForExistence(timeout: defaultTimeout))
        
        // Verify unknown error message pattern
        let unknownErrorExists = alert.staticTexts.containing("An unexpected error occurred").firstMatch.exists
        XCTAssertTrue(unknownErrorExists)
        
        // Verify retry option is available
        XCTAssertTrue(alert.buttons["OK"].exists)
        XCTAssertTrue(alert.buttons["Retry"].exists)
        
        takeScreenshot(name: "AuthError_Unknown_Error")
    }
    
    // MARK: - Error Recovery Option Tests
    
    func testErrorAlertOKButtonDismissesAlert() {
        // Given: Error alert is displayed
        app.launchEnvironment["MOCK_AUTH_ERROR"] = "authorizationFailed"
        app.launch()
        
        let signInButton = app.buttons["Sign in with Apple"]
        signInButton.tap()
        
        let alert = app.alerts["Authentication Error"]
        XCTAssertTrue(alert.waitForExistence(timeout: defaultTimeout))
        
        // When: User taps OK button
        alert.buttons["OK"].tap()
        
        // Then: Alert should be dismissed
        XCTAssertTrue(alert.waitForNonExistence(timeout: shortTimeout))
        
        // And sign-in screen should still be visible
        XCTAssertTrue(app.buttons["Sign in with Apple"].exists)
        
        takeScreenshot(name: "AuthError_OK_Dismisses_Alert")
    }
    
    func testErrorAlertRetryButtonTriggersRetry() {
        // Given: Error alert with retry option is displayed
        app.launchEnvironment["MOCK_AUTH_ERROR"] = "authorizationFailed"
        app.launchEnvironment["MOCK_AUTH_RETRY_SUCCESS"] = "true"
        app.launch()
        
        let signInButton = app.buttons["Sign in with Apple"]
        signInButton.tap()
        
        let alert = app.alerts["Authentication Error"]
        XCTAssertTrue(alert.waitForExistence(timeout: defaultTimeout))
        
        // When: User taps Retry button
        alert.buttons["Retry"].tap()
        
        // Then: Alert should be dismissed and retry should be attempted
        XCTAssertTrue(alert.waitForNonExistence(timeout: shortTimeout))
        
        // Loading state should appear again
        let loadingText = app.staticTexts["Signing in..."]
        XCTAssertTrue(loadingText.waitForExistence(timeout: shortTimeout))
        
        takeScreenshot(name: "AuthError_Retry_Triggers_Retry")
    }
    
    func testNetworkErrorSmartRetryButton() {
        // Given: Network error alert is displayed
        app.launchEnvironment["MOCK_AUTH_ERROR"] = "networkUnavailable"
        app.launchEnvironment["MOCK_NETWORK_CONNECTED"] = "false"
        app.launch()
        
        let signInButton = app.buttons["Sign in with Apple"]
        signInButton.tap()
        
        let alert = app.alerts["Authentication Error"]
        XCTAssertTrue(alert.waitForExistence(timeout: defaultTimeout))
        
        // When: User taps "Retry when connected" button
        let smartRetryButton = alert.buttons["Retry when connected"]
        XCTAssertTrue(smartRetryButton.exists)
        smartRetryButton.tap()
        
        // Then: Alert should be dismissed
        XCTAssertTrue(alert.waitForNonExistence(timeout: shortTimeout))
        
        // Should return to sign-in screen
        XCTAssertTrue(app.buttons["Sign in with Apple"].exists)
        
        takeScreenshot(name: "AuthError_Smart_Retry_Network")
    }
    
    // MARK: - Error Recovery Functionality Tests
    
    func testRetryAfterAuthorizationFailure() {
        // Given: Authorization failure followed by successful retry
        app.launchEnvironment["MOCK_AUTH_ERROR"] = "authorizationFailed"
        app.launchEnvironment["MOCK_AUTH_RETRY_SUCCESS"] = "true"
        app.launch()
        
        let signInButton = app.buttons["Sign in with Apple"]
        signInButton.tap()
        
        let alert = app.alerts["Authentication Error"]
        XCTAssertTrue(alert.waitForExistence(timeout: defaultTimeout))
        
        // When: User retries after error
        alert.buttons["Retry"].tap()
        
        // Then: Should successfully complete authentication
        waitForLoadingToComplete(timeout: longTimeout)
        
        // Should navigate away from sign-in screen
        let expectation = XCTestExpectation(description: "Successful retry navigation")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if !self.app.buttons["Sign in with Apple"].exists {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: longTimeout)
        takeScreenshot(name: "AuthError_Successful_Retry")
    }
    
    func testRetryAfterNetworkError() {
        // Given: Network error followed by network recovery
        app.launchEnvironment["MOCK_AUTH_ERROR"] = "networkUnavailable"
        app.launchEnvironment["MOCK_NETWORK_RECOVERY"] = "true"
        app.launch()
        
        let signInButton = app.buttons["Sign in with Apple"]
        signInButton.tap()
        
        let alert = app.alerts["Authentication Error"]
        XCTAssertTrue(alert.waitForExistence(timeout: defaultTimeout))
        
        // When: User retries after network error
        alert.buttons["Retry when connected"].tap()
        
        // Then: Should handle network recovery gracefully
        XCTAssertTrue(alert.waitForNonExistence(timeout: shortTimeout))
        
        // Should return to sign-in screen ready for retry
        XCTAssertTrue(app.buttons["Sign in with Apple"].exists)
        XCTAssertTrue(app.buttons["Sign in with Apple"].isEnabled)
        
        takeScreenshot(name: "AuthError_Network_Recovery")
    }
    
    // MARK: - Network Error Handling Tests
    
    func testNetworkErrorWithConnectionAvailable() {
        // Given: Network error but connection is available
        app.launchEnvironment["MOCK_AUTH_ERROR"] = "networkUnavailable"
        app.launchEnvironment["MOCK_NETWORK_CONNECTED"] = "true"
        app.launch()
        
        let signInButton = app.buttons["Sign in with Apple"]
        signInButton.tap()
        
        let alert = app.alerts["Authentication Error"]
        XCTAssertTrue(alert.waitForExistence(timeout: defaultTimeout))
        
        // Then: Should show connection-available network error message
        let connectionAvailableMessage = alert.staticTexts.containing("There seems to be a network issue preventing sign-in").firstMatch
        XCTAssertTrue(connectionAvailableMessage.exists)
        
        takeScreenshot(name: "AuthError_Network_With_Connection")
    }
    
    func testNetworkErrorWithoutConnection() {
        // Given: Network error with no connection
        app.launchEnvironment["MOCK_AUTH_ERROR"] = "networkUnavailable"
        app.launchEnvironment["MOCK_NETWORK_CONNECTED"] = "false"
        app.launch()
        
        let signInButton = app.buttons["Sign in with Apple"]
        signInButton.tap()
        
        let alert = app.alerts["Authentication Error"]
        XCTAssertTrue(alert.waitForExistence(timeout: defaultTimeout))
        
        // Then: Should show no-connection network error message
        let noConnectionMessage = alert.staticTexts.containing("No internet connection detected").firstMatch
        XCTAssertTrue(noConnectionMessage.exists)
        
        takeScreenshot(name: "AuthError_Network_No_Connection")
    }
    
    func testNetworkErrorUserGuidance() {
        // Given: Network error is displayed
        app.launchEnvironment["MOCK_AUTH_ERROR"] = "networkUnavailable"
        app.launch()
        
        let signInButton = app.buttons["Sign in with Apple"]
        signInButton.tap()
        
        let alert = app.alerts["Authentication Error"]
        XCTAssertTrue(alert.waitForExistence(timeout: defaultTimeout))
        
        // Then: Should provide clear user guidance
        let guidanceMessage = alert.staticTexts.containing("Please connect to Wi-Fi or cellular data").firstMatch
        XCTAssertTrue(guidanceMessage.exists)
        
        // Should offer smart retry option
        XCTAssertTrue(alert.buttons["Retry when connected"].exists)
        
        takeScreenshot(name: "AuthError_Network_User_Guidance")
    }
    
    // MARK: - Error Alert Accessibility Tests
    
    func testErrorAlertAccessibility() {
        // Given: Error alert is displayed
        app.launchEnvironment["MOCK_AUTH_ERROR"] = "authorizationFailed"
        app.launch()
        
        let signInButton = app.buttons["Sign in with Apple"]
        signInButton.tap()
        
        let alert = app.alerts["Authentication Error"]
        XCTAssertTrue(alert.waitForExistence(timeout: defaultTimeout))
        
        // Then: Alert should be accessible
        assertElementIsAccessible(alert)
        
        // Alert title should be accessible
        let alertTitle = alert.staticTexts["Authentication Error"]
        assertElementIsAccessible(alertTitle)
        
        // Buttons should be accessible
        assertElementIsAccessible(alert.buttons["OK"])
        assertElementIsAccessible(alert.buttons["Retry"])
        
        // Error message should be accessible
        let errorMessage = alert.staticTexts.firstMatch
        XCTAssertFalse(errorMessage.label.isEmpty)
        
        takeScreenshot(name: "AuthError_Accessibility")
    }
    
    func testErrorAlertVoiceOverSupport() {
        // Given: Error alert is displayed
        app.launchEnvironment["MOCK_AUTH_ERROR"] = "networkUnavailable"
        app.launch()
        
        let signInButton = app.buttons["Sign in with Apple"]
        signInButton.tap()
        
        let alert = app.alerts["Authentication Error"]
        XCTAssertTrue(alert.waitForExistence(timeout: defaultTimeout))
        
        // Then: All elements should have proper accessibility labels
        XCTAssertFalse(alert.label.isEmpty)
        
        // Buttons should have clear labels
        let okButton = alert.buttons["OK"]
        let retryButton = alert.buttons["Retry when connected"]
        
        XCTAssertEqual(okButton.label, "OK")
        XCTAssertEqual(retryButton.label, "Retry when connected")
        
        // Error message should be readable
        let errorMessage = alert.staticTexts.firstMatch
        XCTAssertFalse(errorMessage.label.isEmpty)
        XCTAssertTrue(errorMessage.label.count > 10) // Should have meaningful content
        
        takeScreenshot(name: "AuthError_VoiceOver_Support")
    }
    
    // MARK: - Multiple Error Scenarios Tests
    
    func testSequentialErrorHandling() {
        // Given: Multiple errors can occur in sequence
        app.launchEnvironment["MOCK_AUTH_ERROR"] = "authorizationFailed"
        app.launchEnvironment["MOCK_AUTH_SEQUENTIAL_ERRORS"] = "true"
        app.launch()
        
        let signInButton = app.buttons["Sign in with Apple"]
        
        // First error
        signInButton.tap()
        let firstAlert = app.alerts["Authentication Error"]
        XCTAssertTrue(firstAlert.waitForExistence(timeout: defaultTimeout))
        firstAlert.buttons["Retry"].tap()
        
        // Second error should be handled properly
        let secondAlert = app.alerts["Authentication Error"]
        if secondAlert.waitForExistence(timeout: defaultTimeout) {
            XCTAssertTrue(secondAlert.buttons["OK"].exists)
            secondAlert.buttons["OK"].tap()
        }
        
        // Should return to sign-in screen
        XCTAssertTrue(app.buttons["Sign in with Apple"].exists)
        
        takeScreenshot(name: "AuthError_Sequential_Handling")
    }
    
    func testErrorHandlingAfterAppBackground() {
        // Given: App goes to background during error state
        app.launchEnvironment["MOCK_AUTH_ERROR"] = "authorizationFailed"
        app.launch()
        
        let signInButton = app.buttons["Sign in with Apple"]
        signInButton.tap()
        
        let alert = app.alerts["Authentication Error"]
        XCTAssertTrue(alert.waitForExistence(timeout: defaultTimeout))
        
        // When: App is backgrounded and foregrounded
        XCUIDevice.shared.press(.home)
        app.activate()
        
        // Then: Error alert should still be properly displayed
        XCTAssertTrue(alert.exists)
        XCTAssertTrue(alert.buttons["OK"].exists)
        
        // Should be able to dismiss normally
        alert.buttons["OK"].tap()
        XCTAssertTrue(alert.waitForNonExistence(timeout: shortTimeout))
        
        takeScreenshot(name: "AuthError_After_Background")
    }
    
    // MARK: - Error Message Clarity Tests
    
    func testErrorMessageClarity() {
        let errorTypes = [
            "authorizationFailed",
            "userCancelled", 
            "networkUnavailable",
            "invalidCredentials",
            "keychainError",
            "dataServiceError",
            "unknownError"
        ]
        
        for errorType in errorTypes {
            // Given: Specific error type
            app.terminate()
            app.launchEnvironment["MOCK_AUTH_ERROR"] = errorType
            app.launch()
            
            let signInButton = app.buttons["Sign in with Apple"]
            signInButton.tap()
            
            let alert = app.alerts["Authentication Error"]
            if alert.waitForExistence(timeout: defaultTimeout) {
                // Then: Error message should be clear and actionable
                let errorMessage = alert.staticTexts.firstMatch
                XCTAssertFalse(errorMessage.label.isEmpty)
                XCTAssertTrue(errorMessage.label.count > 20) // Should have meaningful content
                
                // Dismiss alert for next iteration
                alert.buttons["OK"].tap()
                
                takeScreenshot(name: "AuthError_Clarity_\(errorType)")
            }
        }
    }
}