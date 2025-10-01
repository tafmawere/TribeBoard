import XCTest

/// UI tests for the complete sign-in experience
final class SignInFlowUITests: UITestBase {
    
    // MARK: - Test Setup
    
    override func setUp() {
        super.setUp()
        
        // Ensure we start from signed-out state
        app.launchEnvironment["MOCK_AUTH_STATE"] = "signed_out"
        app.launchEnvironment["MOCK_AUTH_SUCCESS"] = "true"
    }
    
    // MARK: - Sign-In Screen Display Tests
    
    func testSignInScreenDisplaysCorrectly() {
        // Given: App launches in signed-out state
        // When: Sign-in screen is displayed
        // Then: All required elements should be visible
        
        // Verify welcome section
        XCTAssertTrue(app.images["TribeBoard Logo"].waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(app.staticTexts["Welcome to TribeBoard"].exists)
        XCTAssertTrue(app.staticTexts["Keep your family organized and connected"].exists)
        
        // Verify sign-in section
        XCTAssertTrue(app.buttons["Sign in with Apple"].exists)
        XCTAssertTrue(app.staticTexts["Your privacy is protected"].exists)
        XCTAssertTrue(app.staticTexts["We only access your name and email address. You can choose to hide your email using Apple's private relay."].exists)
        
        takeScreenshot(name: "SignIn_Screen_Initial_Display")
    }
    
    func testAppleIDButtonDisplaysCorrectly() {
        // Given: Sign-in screen is displayed
        // When: Checking Apple ID button
        // Then: Button should have correct appearance and accessibility
        
        let signInButton = app.buttons["Sign in with Apple"]
        
        XCTAssertTrue(signInButton.waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(signInButton.isEnabled)
        XCTAssertTrue(signInButton.isHittable)
        
        // Verify accessibility
        XCTAssertEqual(signInButton.label, "Sign in with Apple")
        XCTAssertFalse(signInButton.label.isEmpty)
        
        takeScreenshot(name: "SignIn_Apple_Button_Display")
    }
    
    func testSignInButtonAccessibility() {
        // Given: Sign-in screen is displayed
        // When: Checking button accessibility
        // Then: Button should meet accessibility requirements
        
        let signInButton = app.buttons["Sign in with Apple"]
        
        XCTAssertTrue(signInButton.waitForExistence(timeout: defaultTimeout))
        
        // Verify accessibility label and hint
        XCTAssertEqual(signInButton.label, "Sign in with Apple")
        
        // Verify button is accessible
        assertElementIsAccessible(signInButton)
        
        // Verify button traits
        verifyAccessibilityTraits(signInButton, expectedTraits: .button)
    }
    
    // MARK: - Apple ID Button Interaction Tests
    
    func testAppleIDButtonTapTriggersAuthentication() {
        // Given: Sign-in screen is displayed
        let signInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: defaultTimeout))
        
        // When: User taps the Apple ID button
        signInButton.tap()
        
        // Then: Loading state should be displayed
        let loadingIndicator = app.staticTexts["Signing in..."]
        XCTAssertTrue(loadingIndicator.waitForExistence(timeout: shortTimeout))
        
        takeScreenshot(name: "SignIn_Loading_State")
    }
    
    func testAppleIDButtonDisabledDuringLoading() {
        // Given: Sign-in screen is displayed
        let signInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: defaultTimeout))
        
        // When: Authentication is in progress
        signInButton.tap()
        
        // Then: Button should be disabled during loading
        let loadingIndicator = app.staticTexts["Signing in..."]
        if loadingIndicator.waitForExistence(timeout: shortTimeout) {
            // Button should be disabled while loading
            XCTAssertFalse(signInButton.isEnabled)
            takeScreenshot(name: "SignIn_Button_Disabled_During_Loading")
        }
    }
    
    // MARK: - Loading State Tests
    
    func testLoadingStateDisplaysCorrectly() {
        // Given: Sign-in screen is displayed
        let signInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: defaultTimeout))
        
        // When: User initiates sign-in
        signInButton.tap()
        
        // Then: Loading state should display correctly
        let loadingText = app.staticTexts["Signing in..."]
        XCTAssertTrue(loadingText.waitForExistence(timeout: shortTimeout))
        
        // Verify loading indicator is present
        let progressIndicator = app.progressIndicators.firstMatch
        XCTAssertTrue(progressIndicator.exists)
        
        takeScreenshot(name: "SignIn_Loading_State_Complete")
    }
    
    func testLoadingStateAccessibility() {
        // Given: Sign-in screen is displayed
        let signInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: defaultTimeout))
        
        // When: Loading state is displayed
        signInButton.tap()
        
        let loadingText = app.staticTexts["Signing in..."]
        if loadingText.waitForExistence(timeout: shortTimeout) {
            // Then: Loading state should be accessible
            assertElementIsAccessible(loadingText)
            
            // Verify progress indicator accessibility
            let progressIndicator = app.progressIndicators.firstMatch
            if progressIndicator.exists {
                XCTAssertFalse(progressIndicator.label.isEmpty)
            }
        }
    }
    
    func testAuthenticationProgressIndication() {
        // Given: Sign-in screen is displayed
        let signInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: defaultTimeout))
        
        // When: Authentication is initiated
        signInButton.tap()
        
        // Then: Progress should be clearly indicated
        let loadingText = app.staticTexts["Signing in..."]
        XCTAssertTrue(loadingText.waitForExistence(timeout: shortTimeout))
        
        // Verify visual progress indicators
        let progressIndicator = app.progressIndicators.firstMatch
        XCTAssertTrue(progressIndicator.exists)
        
        // Verify button state changes
        XCTAssertFalse(signInButton.isEnabled)
        
        takeScreenshot(name: "SignIn_Progress_Indication")
    }
    
    // MARK: - Successful Authentication Navigation Tests
    
    func testSuccessfulAuthenticationNavigation() {
        // Given: Sign-in screen is displayed with successful auth configured
        app.launchEnvironment["MOCK_AUTH_SUCCESS"] = "true"
        app.launchEnvironment["MOCK_AUTH_DELAY"] = "1"
        
        let signInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: defaultTimeout))
        
        // When: User successfully signs in
        signInButton.tap()
        
        // Wait for loading to complete
        waitForLoadingToComplete(timeout: longTimeout)
        
        // Then: Should navigate to main app (family dashboard or onboarding)
        let expectation = XCTestExpectation(description: "Navigation after successful auth")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Check for either family dashboard or onboarding
            let familyDashboard = self.app.staticTexts["Family Dashboard"]
            let onboardingScreen = self.app.staticTexts["Welcome to TribeBoard"]
            let roleSelection = self.app.staticTexts["Choose Your Role"]
            
            if familyDashboard.exists || onboardingScreen.exists || roleSelection.exists {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: longTimeout)
        takeScreenshot(name: "SignIn_Successful_Navigation")
    }
    
    func testAuthenticationStateTransition() {
        // Given: Sign-in screen is displayed
        let signInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: defaultTimeout))
        
        // When: Authentication completes successfully
        signInButton.tap()
        
        // Then: Should transition away from sign-in screen
        let signInScreen = app.otherElements["SignInView"]
        
        // Wait for transition (loading should complete and screen should change)
        let transitionExpectation = XCTestExpectation(description: "Screen transition")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            // Sign-in screen should no longer be the primary view
            if !signInScreen.exists || !self.app.buttons["Sign in with Apple"].exists {
                transitionExpectation.fulfill()
            }
        }
        
        wait(for: [transitionExpectation], timeout: longTimeout)
    }
    
    func testPostAuthenticationScreenDisplay() {
        // Given: Successful authentication is configured
        app.launchEnvironment["MOCK_AUTH_SUCCESS"] = "true"
        app.launchEnvironment["MOCK_USER_HAS_FAMILY"] = "false"
        
        let signInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: defaultTimeout))
        
        // When: User completes sign-in
        signInButton.tap()
        waitForLoadingToComplete(timeout: longTimeout)
        
        // Then: Should display appropriate next screen
        let expectation = XCTestExpectation(description: "Post-auth screen display")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Should show onboarding or role selection for new users
            let roleSelection = self.app.staticTexts["Choose Your Role"]
            let onboarding = self.app.staticTexts["Let's get started"]
            let familyCreation = self.app.staticTexts["Create Your Family"]
            
            if roleSelection.exists || onboarding.exists || familyCreation.exists {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: longTimeout)
        takeScreenshot(name: "SignIn_Post_Auth_Screen")
    }
    
    // MARK: - Integration Tests
    
    func testCompleteSignInUserJourney() {
        // Given: App starts in signed-out state
        XCTAssertTrue(app.buttons["Sign in with Apple"].waitForExistence(timeout: defaultTimeout))
        
        // When: User goes through complete sign-in flow
        let signInButton = app.buttons["Sign in with Apple"]
        
        // Step 1: Tap sign-in button
        signInButton.tap()
        
        // Step 2: Verify loading state
        let loadingText = app.staticTexts["Signing in..."]
        XCTAssertTrue(loadingText.waitForExistence(timeout: shortTimeout))
        
        // Step 3: Wait for authentication to complete
        waitForLoadingToComplete(timeout: longTimeout)
        
        // Step 4: Verify navigation to next screen
        let expectation = XCTestExpectation(description: "Complete sign-in journey")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // Should be on a different screen now
            let stillOnSignIn = self.app.buttons["Sign in with Apple"].exists
            if !stillOnSignIn {
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: longTimeout)
        takeScreenshot(name: "SignIn_Complete_Journey")
    }
    
    func testSignInFlowWithNetworkConditions() {
        // Given: Network conditions are simulated
        app.launchEnvironment["MOCK_NETWORK_DELAY"] = "2"
        
        let signInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: defaultTimeout))
        
        // When: User attempts sign-in with network delay
        signInButton.tap()
        
        // Then: Should handle network conditions gracefully
        let loadingText = app.staticTexts["Signing in..."]
        XCTAssertTrue(loadingText.waitForExistence(timeout: shortTimeout))
        
        // Should maintain loading state during network delay
        XCTAssertTrue(loadingText.exists)
        XCTAssertFalse(signInButton.isEnabled)
        
        // Wait for completion
        waitForLoadingToComplete(timeout: longTimeout)
        
        takeScreenshot(name: "SignIn_Network_Conditions")
    }
    
    // MARK: - Edge Case Tests
    
    func testSignInScreenAfterAppRelaunch() {
        // Given: App is relaunched in signed-out state
        app.terminate()
        app.launchEnvironment["MOCK_AUTH_STATE"] = "signed_out"
        app.launch()
        
        // When: Sign-in screen is displayed after relaunch
        // Then: Should display correctly
        XCTAssertTrue(app.buttons["Sign in with Apple"].waitForExistence(timeout: defaultTimeout))
        XCTAssertTrue(app.staticTexts["Welcome to TribeBoard"].exists)
        
        takeScreenshot(name: "SignIn_After_Relaunch")
    }
    
    func testSignInButtonMultipleTaps() {
        // Given: Sign-in screen is displayed
        let signInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: defaultTimeout))
        
        // When: User taps button multiple times quickly
        signInButton.tap()
        
        // Button should be disabled after first tap
        if app.staticTexts["Signing in..."].waitForExistence(timeout: shortTimeout) {
            // Additional taps should not cause issues
            signInButton.tap()
            signInButton.tap()
            
            // Should still be in loading state
            XCTAssertTrue(app.staticTexts["Signing in..."].exists)
            XCTAssertFalse(signInButton.isEnabled)
        }
        
        takeScreenshot(name: "SignIn_Multiple_Taps")
    }
}