import XCTest

/// UI tests for sign-out functionality and logout flows
final class SignOutFlowUITests: UITestBase {
    
    // MARK: - Test Setup
    
    override func setUp() {
        super.setUp()
        
        // Start with authenticated state
        app.launchEnvironment["MOCK_AUTH_STATE"] = "authenticated"
        app.launchEnvironment["MOCK_USER_HAS_FAMILY"] = "true"
    }
    
    // MARK: - Sign-Out Button Accessibility Tests
    
    func testSignOutButtonAccessibility() {
        // Given: User is authenticated and on settings screen
        navigateToSettings()
        
        // When: Checking sign-out button accessibility
        let signOutButton = app.buttons["Sign Out"]
        XCTAssertTrue(signOutButton.waitForExistence(timeout: defaultTimeout))
        
        // Then: Button should be accessible
        assertElementIsAccessible(signOutButton)
        
        // Verify accessibility label
        XCTAssertEqual(signOutButton.label, "Sign Out")
        
        // Verify button traits
        verifyAccessibilityTraits(signOutButton, expectedTraits: .button)
        
        // Verify button is properly positioned and hittable
        XCTAssertTrue(signOutButton.isHittable)
        
        takeScreenshot(name: "SignOut_Button_Accessibility")
    }
    
    func testSignOutButtonVisualAppearance() {
        // Given: User is on settings screen
        navigateToSettings()
        
        // When: Checking sign-out button appearance
        let signOutButton = app.buttons["Sign Out"]
        XCTAssertTrue(signOutButton.waitForExistence(timeout: defaultTimeout))
        
        // Then: Button should be visible and properly styled
        XCTAssertTrue(signOutButton.exists)
        XCTAssertTrue(signOutButton.isEnabled)
        
        // Verify it's in the Account section
        let accountSection = app.staticTexts["Account"]
        XCTAssertTrue(accountSection.exists)
        
        // Verify destructive styling context (red color indication)
        let signOutSubtitle = app.staticTexts["Sign out of your account"]
        XCTAssertTrue(signOutSubtitle.exists)
        
        takeScreenshot(name: "SignOut_Button_Visual_Appearance")
    }
    
    func testSignOutButtonInteraction() {
        // Given: User is on settings screen
        navigateToSettings()
        
        let signOutButton = app.buttons["Sign Out"]
        XCTAssertTrue(signOutButton.waitForExistence(timeout: defaultTimeout))
        
        // When: User taps the sign-out button
        signOutButton.tap()
        
        // Then: Sign-out confirmation dialog should appear
        let confirmationAlert = app.alerts["Sign Out"]
        XCTAssertTrue(confirmationAlert.waitForExistence(timeout: defaultTimeout))
        
        takeScreenshot(name: "SignOut_Button_Interaction")
    }
    
    // MARK: - Sign-Out Confirmation Dialog Tests
    
    func testSignOutConfirmationDialogDisplay() {
        // Given: User taps sign-out button
        navigateToSettings()
        app.buttons["Sign Out"].tap()
        
        // When: Confirmation dialog appears
        let confirmationAlert = app.alerts["Sign Out"]
        XCTAssertTrue(confirmationAlert.waitForExistence(timeout: defaultTimeout))
        
        // Then: Dialog should display correct content
        XCTAssertTrue(confirmationAlert.staticTexts["Sign Out"].exists)
        
        // Verify confirmation message
        let confirmationMessage = confirmationAlert.staticTexts["Are you sure you want to sign out? You'll need to sign in again to access your account."]
        XCTAssertTrue(confirmationMessage.exists)
        
        // Verify dialog buttons
        XCTAssertTrue(confirmationAlert.buttons["Cancel"].exists)
        XCTAssertTrue(confirmationAlert.buttons["Sign Out"].exists)
        
        takeScreenshot(name: "SignOut_Confirmation_Dialog")
    }
    
    func testSignOutConfirmationDialogAccessibility() {
        // Given: Sign-out confirmation dialog is displayed
        navigateToSettings()
        app.buttons["Sign Out"].tap()
        
        let confirmationAlert = app.alerts["Sign Out"]
        XCTAssertTrue(confirmationAlert.waitForExistence(timeout: defaultTimeout))
        
        // When: Checking dialog accessibility
        // Then: All elements should be accessible
        assertElementIsAccessible(confirmationAlert)
        
        // Verify button accessibility
        let cancelButton = confirmationAlert.buttons["Cancel"]
        let signOutButton = confirmationAlert.buttons["Sign Out"]
        
        assertElementIsAccessible(cancelButton)
        assertElementIsAccessible(signOutButton)
        
        // Verify proper button labels
        XCTAssertEqual(cancelButton.label, "Cancel")
        XCTAssertEqual(signOutButton.label, "Sign Out")
        
        takeScreenshot(name: "SignOut_Confirmation_Accessibility")
    }
    
    func testSignOutConfirmationCancelButton() {
        // Given: Sign-out confirmation dialog is displayed
        navigateToSettings()
        app.buttons["Sign Out"].tap()
        
        let confirmationAlert = app.alerts["Sign Out"]
        XCTAssertTrue(confirmationAlert.waitForExistence(timeout: defaultTimeout))
        
        // When: User taps Cancel button
        confirmationAlert.buttons["Cancel"].tap()
        
        // Then: Dialog should be dismissed and user remains signed in
        XCTAssertTrue(confirmationAlert.waitForNonExistence(timeout: shortTimeout))
        
        // Should still be on settings screen
        XCTAssertTrue(app.navigationBars["Settings"].exists)
        XCTAssertTrue(app.buttons["Sign Out"].exists)
        
        takeScreenshot(name: "SignOut_Confirmation_Cancel")
    }
    
    func testSignOutConfirmationUserChoices() {
        // Given: Sign-out confirmation dialog is displayed
        navigateToSettings()
        app.buttons["Sign Out"].tap()
        
        let confirmationAlert = app.alerts["Sign Out"]
        XCTAssertTrue(confirmationAlert.waitForExistence(timeout: defaultTimeout))
        
        // When: Verifying user has clear choices
        // Then: Both options should be clearly presented
        let cancelButton = confirmationAlert.buttons["Cancel"]
        let signOutButton = confirmationAlert.buttons["Sign Out"]
        
        XCTAssertTrue(cancelButton.exists)
        XCTAssertTrue(signOutButton.exists)
        
        // Verify buttons are distinguishable
        XCTAssertNotEqual(cancelButton.label, signOutButton.label)
        
        // Both buttons should be hittable
        XCTAssertTrue(cancelButton.isHittable)
        XCTAssertTrue(signOutButton.isHittable)
        
        // Cancel to avoid actual sign-out
        cancelButton.tap()
        
        takeScreenshot(name: "SignOut_User_Choices")
    }
    
    // MARK: - Authentication State Cleanup Tests
    
    func testSuccessfulSignOutStateCleanup() {
        // Given: User is authenticated and confirms sign-out
        app.launchEnvironment["MOCK_SIGNOUT_SUCCESS"] = "true"
        navigateToSettings()
        
        app.buttons["Sign Out"].tap()
        
        let confirmationAlert = app.alerts["Sign Out"]
        XCTAssertTrue(confirmationAlert.waitForExistence(timeout: defaultTimeout))
        
        // When: User confirms sign-out
        confirmationAlert.buttons["Sign Out"].tap()
        
        // Then: Should navigate to sign-in screen
        let signInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: longTimeout))
        
        // Verify sign-in screen elements are present
        XCTAssertTrue(app.staticTexts["Welcome to TribeBoard"].exists)
        
        // Verify settings screen is no longer accessible
        XCTAssertFalse(app.navigationBars["Settings"].exists)
        
        takeScreenshot(name: "SignOut_Successful_State_Cleanup")
    }
    
    func testSignOutNavigationTransition() {
        // Given: User is authenticated
        app.launchEnvironment["MOCK_SIGNOUT_SUCCESS"] = "true"
        navigateToSettings()
        
        // When: User completes sign-out flow
        app.buttons["Sign Out"].tap()
        app.alerts["Sign Out"].buttons["Sign Out"].tap()
        
        // Then: Should transition smoothly to sign-in screen
        let expectation = XCTestExpectation(description: "Navigation to sign-in")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if self.app.buttons["Sign in with Apple"].exists {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: longTimeout)
        
        // Verify complete transition
        XCTAssertFalse(app.navigationBars["Settings"].exists)
        XCTAssertTrue(app.buttons["Sign in with Apple"].exists)
        
        takeScreenshot(name: "SignOut_Navigation_Transition")
    }
    
    func testSignOutAuthenticationDataCleanup() {
        // Given: User is authenticated with stored data
        app.launchEnvironment["MOCK_SIGNOUT_SUCCESS"] = "true"
        app.launchEnvironment["MOCK_VERIFY_DATA_CLEANUP"] = "true"
        
        navigateToSettings()
        
        // When: User signs out
        app.buttons["Sign Out"].tap()
        app.alerts["Sign Out"].buttons["Sign Out"].tap()
        
        // Then: Authentication data should be cleaned up
        let signInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: longTimeout))
        
        // Verify no cached authentication state
        XCTAssertTrue(signInButton.isEnabled)
        XCTAssertTrue(app.staticTexts["Welcome to TribeBoard"].exists)
        
        takeScreenshot(name: "SignOut_Data_Cleanup")
    }
    
    // MARK: - Sign-Out Error Handling Tests
    
    func testSignOutErrorHandling() {
        // Given: Sign-out is configured to fail
        app.launchEnvironment["MOCK_SIGNOUT_ERROR"] = "keychainError"
        navigateToSettings()
        
        // When: User attempts to sign out
        app.buttons["Sign Out"].tap()
        app.alerts["Sign Out"].buttons["Sign Out"].tap()
        
        // Then: Error alert should be displayed
        let errorAlert = app.alerts["Authentication Error"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: defaultTimeout))
        
        // Verify error message
        let keychainErrorExists = errorAlert.staticTexts.containing("There was a problem securely storing").firstMatch.exists
        XCTAssertTrue(keychainErrorExists)
        
        // Verify retry option is available
        XCTAssertTrue(errorAlert.buttons["OK"].exists)
        XCTAssertTrue(errorAlert.buttons["Retry"].exists)
        
        takeScreenshot(name: "SignOut_Error_Handling")
    }
    
    func testSignOutErrorRecovery() {
        // Given: Sign-out error with retry capability
        app.launchEnvironment["MOCK_SIGNOUT_ERROR"] = "keychainError"
        app.launchEnvironment["MOCK_SIGNOUT_RETRY_SUCCESS"] = "true"
        
        navigateToSettings()
        
        // When: User encounters error and retries
        app.buttons["Sign Out"].tap()
        app.alerts["Sign Out"].buttons["Sign Out"].tap()
        
        let errorAlert = app.alerts["Authentication Error"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: defaultTimeout))
        
        errorAlert.buttons["Retry"].tap()
        
        // Then: Retry should succeed
        let signInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: longTimeout))
        
        takeScreenshot(name: "SignOut_Error_Recovery")
    }
    
    func testSignOutErrorDismissal() {
        // Given: Sign-out error is displayed
        app.launchEnvironment["MOCK_SIGNOUT_ERROR"] = "unknownError"
        navigateToSettings()
        
        app.buttons["Sign Out"].tap()
        app.alerts["Sign Out"].buttons["Sign Out"].tap()
        
        let errorAlert = app.alerts["Authentication Error"]
        XCTAssertTrue(errorAlert.waitForExistence(timeout: defaultTimeout))
        
        // When: User dismisses error
        errorAlert.buttons["OK"].tap()
        
        // Then: Should return to settings screen
        XCTAssertTrue(errorAlert.waitForNonExistence(timeout: shortTimeout))
        XCTAssertTrue(app.navigationBars["Settings"].exists)
        XCTAssertTrue(app.buttons["Sign Out"].exists)
        
        takeScreenshot(name: "SignOut_Error_Dismissal")
    }
    
    // MARK: - Sign-Out Flow Integration Tests
    
    func testCompleteSignOutFlow() {
        // Given: User is authenticated and on settings screen
        app.launchEnvironment["MOCK_SIGNOUT_SUCCESS"] = "true"
        navigateToSettings()
        
        // When: User goes through complete sign-out flow
        
        // Step 1: Tap sign-out button
        let signOutButton = app.buttons["Sign Out"]
        XCTAssertTrue(signOutButton.waitForExistence(timeout: defaultTimeout))
        signOutButton.tap()
        
        // Step 2: Confirm sign-out
        let confirmationAlert = app.alerts["Sign Out"]
        XCTAssertTrue(confirmationAlert.waitForExistence(timeout: defaultTimeout))
        confirmationAlert.buttons["Sign Out"].tap()
        
        // Step 3: Verify navigation to sign-in
        let signInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: longTimeout))
        
        // Step 4: Verify complete state transition
        XCTAssertTrue(app.staticTexts["Welcome to TribeBoard"].exists)
        XCTAssertFalse(app.navigationBars["Settings"].exists)
        
        takeScreenshot(name: "SignOut_Complete_Flow")
    }
    
    func testSignOutFromDifferentScreens() {
        // Test sign-out accessibility from various entry points
        let entryPoints = [
            ("Settings", "Settings"),
            ("Profile", "Profile") // If profile has sign-out option
        ]
        
        for (screenName, navigationTitle) in entryPoints {
            // Given: User navigates to different screen
            app.terminate()
            app.launchEnvironment["MOCK_AUTH_STATE"] = "authenticated"
            app.launchEnvironment["MOCK_SIGNOUT_SUCCESS"] = "true"
            app.launch()
            
            if screenName == "Settings" {
                navigateToSettings()
            }
            // Add other navigation cases as needed
            
            // When: Sign-out is available and accessible
            let signOutButton = app.buttons["Sign Out"]
            if signOutButton.waitForExistence(timeout: defaultTimeout) {
                // Then: Sign-out should work consistently
                signOutButton.tap()
                
                let confirmationAlert = app.alerts["Sign Out"]
                if confirmationAlert.waitForExistence(timeout: defaultTimeout) {
                    confirmationAlert.buttons["Cancel"].tap() // Cancel to avoid actual sign-out
                }
                
                takeScreenshot(name: "SignOut_From_\(screenName)")
            }
        }
    }
    
    func testSignOutWithUnsavedChanges() {
        // Given: User has unsaved changes in settings
        app.launchEnvironment["MOCK_UNSAVED_CHANGES"] = "true"
        navigateToSettings()
        
        // When: User attempts to sign out
        app.buttons["Sign Out"].tap()
        
        let confirmationAlert = app.alerts["Sign Out"]
        XCTAssertTrue(confirmationAlert.waitForExistence(timeout: defaultTimeout))
        
        // Then: Should still allow sign-out (unsaved changes warning handled separately)
        XCTAssertTrue(confirmationAlert.buttons["Sign Out"].exists)
        XCTAssertTrue(confirmationAlert.buttons["Cancel"].exists)
        
        // Cancel to avoid actual sign-out
        confirmationAlert.buttons["Cancel"].tap()
        
        takeScreenshot(name: "SignOut_Unsaved_Changes")
    }
    
    // MARK: - Edge Cases and Reliability Tests
    
    func testSignOutDuringNetworkIssues() {
        // Given: Network issues during sign-out
        app.launchEnvironment["MOCK_NETWORK_CONNECTED"] = "false"
        app.launchEnvironment["MOCK_SIGNOUT_NETWORK_ERROR"] = "true"
        
        navigateToSettings()
        
        // When: User attempts sign-out with network issues
        app.buttons["Sign Out"].tap()
        app.alerts["Sign Out"].buttons["Sign Out"].tap()
        
        // Then: Should handle network issues gracefully
        let errorAlert = app.alerts["Authentication Error"]
        if errorAlert.waitForExistence(timeout: defaultTimeout) {
            XCTAssertTrue(errorAlert.buttons["OK"].exists)
            errorAlert.buttons["OK"].tap()
        }
        
        // Should remain on settings screen if sign-out fails
        XCTAssertTrue(app.navigationBars["Settings"].exists)
        
        takeScreenshot(name: "SignOut_Network_Issues")
    }
    
    func testSignOutButtonStateConsistency() {
        // Given: User is authenticated
        navigateToSettings()
        
        // When: Checking sign-out button state
        let signOutButton = app.buttons["Sign Out"]
        XCTAssertTrue(signOutButton.waitForExistence(timeout: defaultTimeout))
        
        // Then: Button should be consistently enabled and accessible
        XCTAssertTrue(signOutButton.isEnabled)
        XCTAssertTrue(signOutButton.isHittable)
        
        // Verify button remains consistent after screen transitions
        navigateBack()
        navigateToSettings()
        
        XCTAssertTrue(signOutButton.exists)
        XCTAssertTrue(signOutButton.isEnabled)
        
        takeScreenshot(name: "SignOut_Button_State_Consistency")
    }
    
    func testSignOutAfterAppBackground() {
        // Given: User backgrounds and foregrounds app
        navigateToSettings()
        
        XCUIDevice.shared.press(.home)
        app.activate()
        
        // When: User attempts sign-out after backgrounding
        let signOutButton = app.buttons["Sign Out"]
        XCTAssertTrue(signOutButton.waitForExistence(timeout: defaultTimeout))
        
        signOutButton.tap()
        
        // Then: Sign-out flow should work normally
        let confirmationAlert = app.alerts["Sign Out"]
        XCTAssertTrue(confirmationAlert.waitForExistence(timeout: defaultTimeout))
        
        // Cancel to avoid actual sign-out
        confirmationAlert.buttons["Cancel"].tap()
        
        takeScreenshot(name: "SignOut_After_Background")
    }
    
    // MARK: - Helper Methods
    
    private func navigateToSettings() {
        // Navigate to settings screen
        navigateToTab("Settings")
        
        // Wait for settings screen to load
        let settingsTitle = app.navigationBars["Settings"]
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: defaultTimeout))
        
        // Scroll to account section if needed
        let signOutButton = app.buttons["Sign Out"]
        if !signOutButton.isHittable {
            scrollToElement(signOutButton)
        }
    }
}