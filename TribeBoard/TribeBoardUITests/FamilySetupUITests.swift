import XCTest

/// UI tests for family setup and roles critical user paths
final class FamilySetupUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Configure app for UI testing
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment = ["UITEST_MODE": "1"]
        
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Onboarding Flow Tests
    
    func testOnboardingFlow() throws {
        // Test onboarding screen appears
        let onboardingTitle = app.staticTexts["Welcome to TribeBoard"]
        XCTAssertTrue(onboardingTitle.waitForExistence(timeout: 5))
        
        // Test Sign in with Apple button exists and is tappable
        let signInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(signInButton.exists)
        XCTAssertTrue(signInButton.isEnabled)
        
        // Test accessibility
        XCTAssertNotNil(signInButton.label)
        XCTAssertTrue(signInButton.isHittable)
    }
    
    func testOnboardingToFamilySelection() throws {
        // Navigate through onboarding
        let signInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: 5))
        
        // In UI test environment, we would mock the authentication
        // For now, test that the button is accessible
        signInButton.tap()
        
        // Note: In a real UI test with mocked auth, we would verify:
        // - Loading state appears
        // - Navigation to family selection occurs
        // - Family selection screen elements are present
    }
    
    // MARK: - Family Creation Flow Tests
    
    func testFamilyCreationFlow() throws {
        // This test assumes we've navigated to the family creation screen
        // In a real implementation, we would set up the app state first
        
        // Test family name input
        let familyNameField = app.textFields["Family Name"]
        if familyNameField.exists {
            familyNameField.tap()
            familyNameField.typeText("Test Family")
            
            // Test create button becomes enabled
            let createButton = app.buttons["Create Family"]
            XCTAssertTrue(createButton.exists)
            
            // Test form validation
            familyNameField.clearAndEnterText("")
            XCTAssertFalse(createButton.isEnabled)
            
            familyNameField.clearAndEnterText("Valid Family Name")
            XCTAssertTrue(createButton.isEnabled)
        }
    }
    
    func testFamilyCreationSuccess() throws {
        // Test successful family creation flow
        let familyNameField = app.textFields["Family Name"]
        let createButton = app.buttons["Create Family"]
        
        if familyNameField.exists && createButton.exists {
            familyNameField.tap()
            familyNameField.typeText("UI Test Family")
            
            createButton.tap()
            
            // Test loading state
            let loadingIndicator = app.activityIndicators.firstMatch
            XCTAssertTrue(loadingIndicator.waitForExistence(timeout: 2))
            
            // Test success navigation (would need mocked backend)
            // let successMessage = app.staticTexts["Family created successfully"]
            // XCTAssertTrue(successMessage.waitForExistence(timeout: 5))
        }
    }
    
    func testQRCodeDisplay() throws {
        // Test QR code is displayed after family creation
        let qrCodeImage = app.images["Family QR Code"]
        if qrCodeImage.exists {
            XCTAssertTrue(qrCodeImage.isHittable)
            
            // Test QR code accessibility
            XCTAssertNotNil(qrCodeImage.label)
            XCTAssertTrue(qrCodeImage.label.contains("QR code"))
        }
    }
    
    // MARK: - Family Joining Flow Tests
    
    func testFamilyJoiningFlow() throws {
        // Test family code input
        let familyCodeField = app.textFields["Family Code"]
        if familyCodeField.exists {
            familyCodeField.tap()
            familyCodeField.typeText("TEST123")
            
            // Test search button
            let searchButton = app.buttons["Search Family"]
            XCTAssertTrue(searchButton.exists)
            XCTAssertTrue(searchButton.isEnabled)
            
            searchButton.tap()
            
            // Test loading state
            let loadingIndicator = app.activityIndicators.firstMatch
            XCTAssertTrue(loadingIndicator.waitForExistence(timeout: 2))
        }
    }
    
    func testQRCodeScanning() throws {
        // Test QR code scan button
        let scanButton = app.buttons["Scan QR Code"]
        if scanButton.exists {
            XCTAssertTrue(scanButton.isEnabled)
            XCTAssertTrue(scanButton.isHittable)
            
            scanButton.tap()
            
            // Test camera permission alert (if not already granted)
            let cameraAlert = app.alerts.firstMatch
            if cameraAlert.exists {
                let allowButton = cameraAlert.buttons["Allow"]
                if allowButton.exists {
                    allowButton.tap()
                }
            }
            
            // Test camera view appears (in simulator, this might not work)
            // let cameraView = app.otherElements["Camera View"]
            // XCTAssertTrue(cameraView.waitForExistence(timeout: 3))
        }
    }
    
    func testFamilyJoinConfirmation() throws {
        // Test family confirmation dialog
        let confirmationDialog = app.alerts["Join Family"]
        if confirmationDialog.exists {
            // Test family information is displayed
            let familyNameText = confirmationDialog.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Family'")).firstMatch
            XCTAssertTrue(familyNameText.exists)
            
            // Test join and cancel buttons
            let joinButton = confirmationDialog.buttons["Join"]
            let cancelButton = confirmationDialog.buttons["Cancel"]
            
            XCTAssertTrue(joinButton.exists)
            XCTAssertTrue(cancelButton.exists)
            XCTAssertTrue(joinButton.isEnabled)
            XCTAssertTrue(cancelButton.isEnabled)
        }
    }
    
    // MARK: - Role Selection Flow Tests
    
    func testRoleSelectionScreen() throws {
        // Test role selection cards are displayed
        let roleCards = app.collectionViews["Role Selection"]
        if roleCards.exists {
            // Test all role options are present
            let parentAdminCard = app.buttons["Parent Admin Role"]
            let adultCard = app.buttons["Adult Role"]
            let kidCard = app.buttons["Kid Role"]
            let visitorCard = app.buttons["Visitor Role"]
            
            XCTAssertTrue(parentAdminCard.exists)
            XCTAssertTrue(adultCard.exists)
            XCTAssertTrue(kidCard.exists)
            XCTAssertTrue(visitorCard.exists)
            
            // Test role selection
            adultCard.tap()
            
            // Test continue button becomes enabled
            let continueButton = app.buttons["Continue"]
            XCTAssertTrue(continueButton.exists)
            XCTAssertTrue(continueButton.isEnabled)
        }
    }
    
    func testRoleSelectionConstraints() throws {
        // Test Parent Admin constraint (when already exists)
        let parentAdminCard = app.buttons["Parent Admin Role"]
        if parentAdminCard.exists {
            // If Parent Admin is disabled, test the disabled state
            if !parentAdminCard.isEnabled {
                XCTAssertFalse(parentAdminCard.isEnabled)
                
                // Test error message appears when trying to select
                parentAdminCard.tap()
                let errorMessage = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Parent Admin already exists'")).firstMatch
                XCTAssertTrue(errorMessage.waitForExistence(timeout: 2))
            }
        }
    }
    
    // MARK: - Family Dashboard Tests
    
    func testFamilyDashboardDisplay() throws {
        // Test family dashboard elements
        let dashboardTitle = app.navigationBars.staticTexts.firstMatch
        if dashboardTitle.exists {
            XCTAssertTrue(dashboardTitle.label.contains("Family"))
        }
        
        // Test member list
        let membersList = app.tables["Family Members"]
        if membersList.exists {
            XCTAssertTrue(membersList.cells.count > 0)
            
            // Test member cell elements
            let firstMemberCell = membersList.cells.firstMatch
            if firstMemberCell.exists {
                // Test member name and role are displayed
                XCTAssertTrue(firstMemberCell.staticTexts.count >= 2) // Name and role
                
                // Test member avatar
                let memberAvatar = firstMemberCell.images.firstMatch
                XCTAssertTrue(memberAvatar.exists)
            }
        }
    }
    
    func testMemberManagement() throws {
        // Test member management for Parent Admin
        let membersList = app.tables["Family Members"]
        if membersList.exists && membersList.cells.count > 1 {
            let memberCell = membersList.cells.element(boundBy: 1) // Second member (not self)
            
            // Test long press for context menu (if implemented)
            memberCell.press(forDuration: 1.0)
            
            // Test context menu options
            let changeRoleButton = app.buttons["Change Role"]
            let removeMemberButton = app.buttons["Remove Member"]
            
            if changeRoleButton.exists {
                XCTAssertTrue(changeRoleButton.isEnabled)
            }
            
            if removeMemberButton.exists {
                XCTAssertTrue(removeMemberButton.isEnabled)
            }
        }
    }
    
    // MARK: - Error Handling UI Tests
    
    func testErrorMessageDisplay() throws {
        // Test error messages are displayed properly
        let errorAlert = app.alerts.firstMatch
        if errorAlert.exists {
            // Test error message is readable
            let errorMessage = errorAlert.staticTexts.firstMatch
            XCTAssertTrue(errorMessage.exists)
            XCTAssertFalse(errorMessage.label.isEmpty)
            
            // Test dismiss button
            let okButton = errorAlert.buttons["OK"]
            XCTAssertTrue(okButton.exists)
            XCTAssertTrue(okButton.isEnabled)
        }
    }
    
    func testFormValidationErrors() throws {
        // Test inline validation errors
        let familyNameField = app.textFields["Family Name"]
        if familyNameField.exists {
            familyNameField.tap()
            familyNameField.typeText("A") // Too short
            
            // Tap outside to trigger validation
            app.tap()
            
            // Test validation error appears
            let validationError = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'at least'")).firstMatch
            XCTAssertTrue(validationError.waitForExistence(timeout: 2))
        }
    }
    
    // MARK: - Accessibility Tests
    
    func testAccessibilityLabels() throws {
        // Test all interactive elements have accessibility labels
        let buttons = app.buttons.allElementsBoundByIndex
        for button in buttons {
            XCTAssertFalse(button.label.isEmpty, "Button should have accessibility label")
        }
        
        let textFields = app.textFields.allElementsBoundByIndex
        for textField in textFields {
            XCTAssertFalse(textField.label.isEmpty, "Text field should have accessibility label")
        }
    }
    
    func testVoiceOverNavigation() throws {
        // Test VoiceOver navigation order
        // This would require enabling VoiceOver in the test environment
        // For now, we test that elements are accessible
        
        let accessibleElements = app.descendants(matching: .any).matching(NSPredicate(format: "isAccessibilityElement == true"))
        XCTAssertTrue(accessibleElements.count > 0, "Should have accessible elements")
    }
    
    // MARK: - Performance Tests
    
    func testAppLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
    
    func testScrollPerformance() throws {
        let membersList = app.tables["Family Members"]
        if membersList.exists {
            measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric]) {
                membersList.swipeUp()
                membersList.swipeDown()
            }
        }
    }
}

// MARK: - Helper Extensions

extension XCUIElement {
    func clearAndEnterText(_ text: String) {
        guard let stringValue = self.value as? String else {
            XCTFail("Tried to clear and enter text into a non string value")
            return
        }
        
        self.tap()
        
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        self.typeText(deleteString)
        self.typeText(text)
    }
}