import XCTest
@testable import TribeBoard

/// Comprehensive accessibility tests for authentication flows
/// Tests VoiceOver compatibility, Dynamic Type support, and accessibility compliance
/// for all authentication-related user interfaces
final class AuthenticationAccessibilityTests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchForAccessibilityTesting()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Sign-In Screen Accessibility Tests
    
    func testSignInScreenVoiceOverNavigation() throws {
        // Navigate to sign-in screen
        let signInButton = app.buttons["Sign In"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5))
        signInButton.tap()
        
        // Validate sign-in screen accessibility elements
        let signInTitle = app.staticTexts["Welcome to TribeBoard"]
        let appleSignInButton = app.buttons["Sign in with Apple"]
        let privacyPolicyLink = app.buttons["Privacy Policy"]
        let termsOfServiceLink = app.buttons["Terms of Service"]
        
        // Test VoiceOver navigation order
        let navigationElements = [signInTitle, appleSignInButton, privacyPolicyLink, termsOfServiceLink]
        AccessibilityTestHelpers.validateVoiceOverNavigationOrder(navigationElements)
        
        // Validate individual element accessibility
        AccessibilityTestHelpers.validateVoiceOverElement(
            signInTitle,
            expectedLabel: "Welcome to TribeBoard",
            expectedTraits: .staticText
        )
        
        AccessibilityTestHelpers.validateVoiceOverElement(
            appleSignInButton,
            expectedLabel: "Sign in with Apple",
            expectedTraits: .button
        )
        
        AccessibilityTestHelpers.validateVoiceOverElement(
            privacyPolicyLink,
            expectedLabel: "Privacy Policy",
            expectedTraits: .link
        )
        
        AccessibilityTestHelpers.validateVoiceOverElement(
            termsOfServiceLink,
            expectedLabel: "Terms of Service",
            expectedTraits: .link
        )
    }
    
    func testSignInScreenTouchTargets() throws {
        // Navigate to sign-in screen
        let signInButton = app.buttons["Sign In"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5))
        signInButton.tap()
        
        // Validate touch target sizes for interactive elements
        let appleSignInButton = app.buttons["Sign in with Apple"]
        let privacyPolicyLink = app.buttons["Privacy Policy"]
        let termsOfServiceLink = app.buttons["Terms of Service"]
        
        AccessibilityTestHelpers.validateTouchTargetSize(appleSignInButton)
        AccessibilityTestHelpers.validateTouchTargetSize(privacyPolicyLink)
        AccessibilityTestHelpers.validateTouchTargetSize(termsOfServiceLink)
        
        // Validate spacing between interactive elements
        let interactiveElements = [appleSignInButton, privacyPolicyLink, termsOfServiceLink]
        AccessibilityTestHelpers.validateTouchTargetSpacing(interactiveElements)
    }
    
    func testSignInScreenDynamicTypeSupport() throws {
        // Navigate to sign-in screen
        let signInButton = app.buttons["Sign In"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5))
        signInButton.tap()
        
        // Test Dynamic Type support for text elements
        let signInTitle = app.staticTexts["Welcome to TribeBoard"]
        let appleSignInButton = app.buttons["Sign in with Apple"]
        
        AccessibilityTestHelpers.validateDynamicTypeSupport(app: app, textElement: signInTitle)
        AccessibilityTestHelpers.validateDynamicTypeSupport(app: app, textElement: appleSignInButton)
        
        // Validate text readability at different sizes
        AccessibilityTestHelpers.validateTextReadability(signInTitle)
        AccessibilityTestHelpers.validateTextReadability(appleSignInButton)
    }
    
    func testSignInScreenColorContrast() throws {
        // Navigate to sign-in screen
        let signInButton = app.buttons["Sign In"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5))
        signInButton.tap()
        
        // Validate color contrast for key elements
        let signInTitle = app.staticTexts["Welcome to TribeBoard"]
        let appleSignInButton = app.buttons["Sign in with Apple"]
        let privacyPolicyLink = app.buttons["Privacy Policy"]
        
        AccessibilityTestHelpers.validateColorContrast(signInTitle)
        AccessibilityTestHelpers.validateColorContrast(appleSignInButton)
        AccessibilityTestHelpers.validateColorContrast(privacyPolicyLink)
        
        // Test high contrast mode compatibility
        AccessibilityTestHelpers.validateHighContrastMode(app: app, element: appleSignInButton)
    }
    
    // MARK: - Authentication Loading States Accessibility Tests
    
    func testAuthenticationLoadingStateAccessibility() throws {
        // Navigate to sign-in screen and trigger loading state
        let signInButton = app.buttons["Sign In"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5))
        signInButton.tap()
        
        let appleSignInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(appleSignInButton.waitForExistence(timeout: 5))
        appleSignInButton.tap()
        
        // Validate loading indicator accessibility
        let loadingIndicator = app.activityIndicators["Signing in..."]
        if loadingIndicator.waitForExistence(timeout: 3) {
            AccessibilityTestHelpers.validateVoiceOverElement(
                loadingIndicator,
                expectedLabel: "Signing in...",
                expectedTraits: .updatesFrequently
            )
            
            // Validate that loading state is announced to screen readers
            XCTAssertTrue(loadingIndicator.isAccessibilityElement)
            XCTAssertFalse(loadingIndicator.label.isEmpty)
        }
        
        // Validate loading overlay accessibility
        let loadingOverlay = app.otherElements["Loading Overlay"]
        if loadingOverlay.exists {
            AccessibilityTestHelpers.validateVoiceOverElement(
                loadingOverlay,
                expectedLabel: "Loading",
                expectedTraits: .updatesFrequently
            )
        }
    }
    
    func testAuthenticationProgressAccessibility() throws {
        // Navigate to sign-in screen
        let signInButton = app.buttons["Sign In"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5))
        signInButton.tap()
        
        let appleSignInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(appleSignInButton.waitForExistence(timeout: 5))
        appleSignInButton.tap()
        
        // Validate progress indicators have proper accessibility
        let progressView = app.progressIndicators.firstMatch
        if progressView.waitForExistence(timeout: 3) {
            XCTAssertTrue(progressView.isAccessibilityElement)
            XCTAssertTrue(progressView.accessibilityTraits.contains(.updatesFrequently))
            
            // Validate progress announcements
            AccessibilityTestHelpers.validateVoiceOverElement(
                progressView,
                expectedLabel: "Authentication in progress",
                expectedTraits: .updatesFrequently
            )
        }
    }
    
    // MARK: - Authentication Error Accessibility Tests
    
    func testAuthenticationErrorAccessibility() throws {
        // Simulate authentication error by using mock environment
        app.launchArguments.append("--mock-auth-error")
        app.terminate()
        app.launch()
        
        // Navigate to sign-in and trigger error
        let signInButton = app.buttons["Sign In"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5))
        signInButton.tap()
        
        let appleSignInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(appleSignInButton.waitForExistence(timeout: 5))
        appleSignInButton.tap()
        
        // Validate error alert accessibility
        let errorAlert = app.alerts["Authentication Error"]
        if errorAlert.waitForExistence(timeout: 5) {
            let errorTitle = errorAlert.staticTexts["Authentication Failed"]
            let errorMessage = errorAlert.staticTexts.element(boundBy: 1)
            let retryButton = errorAlert.buttons["Retry"]
            let cancelButton = errorAlert.buttons["Cancel"]
            
            // Validate error alert VoiceOver support
            AccessibilityTestHelpers.validateVoiceOverElement(
                errorTitle,
                expectedLabel: "Authentication Failed",
                expectedTraits: .staticText
            )
            
            AccessibilityTestHelpers.validateVoiceOverElement(
                retryButton,
                expectedLabel: "Retry",
                expectedTraits: .button
            )
            
            AccessibilityTestHelpers.validateVoiceOverElement(
                cancelButton,
                expectedLabel: "Cancel",
                expectedTraits: .button
            )
            
            // Validate error message readability
            AccessibilityTestHelpers.validateTextReadability(errorMessage)
            
            // Validate touch targets for error actions
            AccessibilityTestHelpers.validateTouchTargetSize(retryButton)
            AccessibilityTestHelpers.validateTouchTargetSize(cancelButton)
        }
    }
    
    func testNetworkErrorAccessibility() throws {
        // Simulate network error
        app.launchArguments.append("--mock-network-error")
        app.terminate()
        app.launch()
        
        // Navigate to sign-in and trigger network error
        let signInButton = app.buttons["Sign In"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5))
        signInButton.tap()
        
        let appleSignInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(appleSignInButton.waitForExistence(timeout: 5))
        appleSignInButton.tap()
        
        // Validate network error display accessibility
        let networkErrorView = app.otherElements["Network Error View"]
        if networkErrorView.waitForExistence(timeout: 5) {
            let errorIcon = networkErrorView.images["Network Error Icon"]
            let errorTitle = networkErrorView.staticTexts["No Internet Connection"]
            let errorMessage = networkErrorView.staticTexts["Please check your connection and try again"]
            let retryButton = networkErrorView.buttons["Try Again"]
            
            // Validate network error accessibility
            if errorIcon.exists {
                AccessibilityTestHelpers.validateVoiceOverElement(
                    errorIcon,
                    expectedLabel: "Network error",
                    expectedTraits: .image
                )
            }
            
            AccessibilityTestHelpers.validateVoiceOverElement(
                errorTitle,
                expectedLabel: "No Internet Connection",
                expectedTraits: .staticText
            )
            
            AccessibilityTestHelpers.validateTextReadability(errorMessage)
            AccessibilityTestHelpers.validateTouchTargetSize(retryButton)
        }
    }
    
    // MARK: - Authentication Success State Accessibility Tests
    
    func testAuthenticationSuccessAccessibility() throws {
        // Simulate successful authentication
        app.launchArguments.append("--mock-auth-success")
        app.terminate()
        app.launch()
        
        // Navigate through successful authentication
        let signInButton = app.buttons["Sign In"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5))
        signInButton.tap()
        
        let appleSignInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(appleSignInButton.waitForExistence(timeout: 5))
        appleSignInButton.tap()
        
        // Validate success feedback accessibility
        let successView = app.otherElements["Authentication Success"]
        if successView.waitForExistence(timeout: 5) {
            let successIcon = successView.images["Success Icon"]
            let successMessage = successView.staticTexts["Welcome to TribeBoard!"]
            
            if successIcon.exists {
                AccessibilityTestHelpers.validateVoiceOverElement(
                    successIcon,
                    expectedLabel: "Success",
                    expectedTraits: .image
                )
            }
            
            AccessibilityTestHelpers.validateVoiceOverElement(
                successMessage,
                expectedLabel: "Welcome to TribeBoard!",
                expectedTraits: .staticText
            )
            
            AccessibilityTestHelpers.validateTextReadability(successMessage)
        }
        
        // Validate transition to main app accessibility
        let mainTabBar = app.tabBars.firstMatch
        if mainTabBar.waitForExistence(timeout: 5) {
            let tabButtons = mainTabBar.buttons
            XCTAssertGreaterThan(tabButtons.count, 0, "Main navigation should be accessible after authentication")
            
            // Validate each tab button accessibility
            for i in 0..<tabButtons.count {
                let tabButton = tabButtons.element(boundBy: i)
                XCTAssertTrue(tabButton.isAccessibilityElement)
                AccessibilityTestHelpers.validateTouchTargetSize(tabButton)
            }
        }
    }
    
    // MARK: - Comprehensive Authentication Flow Accessibility Tests
    
    func testCompleteAuthenticationFlowAccessibility() throws {
        // Test complete authentication flow accessibility
        AccessibilityTestHelpers.validateScreenAccessibility(
            app: app,
            screenIdentifier: "Initial Screen",
            keyElements: [app.buttons["Sign In"]]
        )
        
        // Navigate to sign-in screen
        let signInButton = app.buttons["Sign In"]
        signInButton.tap()
        
        // Validate sign-in screen accessibility
        let signInScreenElements = [
            app.staticTexts["Welcome to TribeBoard"],
            app.buttons["Sign in with Apple"],
            app.buttons["Privacy Policy"],
            app.buttons["Terms of Service"]
        ]
        
        AccessibilityTestHelpers.validateScreenAccessibility(
            app: app,
            screenIdentifier: "Sign In Screen",
            keyElements: signInScreenElements
        )
        
        // Test comprehensive accessibility compliance for each element
        for element in signInScreenElements {
            if element.exists {
                AccessibilityTestHelpers.validateAccessibilityCompliance(
                    element,
                    shouldSupportDynamicType: true
                )
            }
        }
    }
    
    func testAuthenticationAccessibilityWithVoiceOverEnabled() throws {
        // This test would ideally run with VoiceOver actually enabled
        // For now, we simulate VoiceOver behavior
        app.launchArguments.append("--voiceover-simulation-enabled")
        app.terminate()
        app.launch()
        
        // Navigate to sign-in screen
        let signInButton = app.buttons["Sign In"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5))
        
        // Test VoiceOver focus behavior
        AccessibilityTestHelpers.validateVoiceOverFocus(signInButton)
        signInButton.tap()
        
        // Test VoiceOver navigation on sign-in screen
        let appleSignInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(appleSignInButton.waitForExistence(timeout: 5))
        
        AccessibilityTestHelpers.validateVoiceOverFocus(appleSignInButton)
        
        // Validate that all interactive elements can receive VoiceOver focus
        let interactiveElements = [
            app.buttons["Sign in with Apple"],
            app.buttons["Privacy Policy"],
            app.buttons["Terms of Service"]
        ]
        
        for element in interactiveElements {
            if element.exists {
                AccessibilityTestHelpers.validateVoiceOverFocus(element)
            }
        }
    }
}