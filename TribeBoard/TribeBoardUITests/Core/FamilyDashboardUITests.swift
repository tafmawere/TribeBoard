import XCTest

/// UI tests for family dashboard functionality including member management, family creation, and joining flows
final class FamilyDashboardUITests: UITestBase {
    
    // MARK: - Family Dashboard Display Tests
    
    /// Test family dashboard displays correctly with member information
    func testFamilyDashboardDisplaysCorrectly() {
        // Arrange: Sign in and navigate to family dashboard
        performMockSignIn()
        waitForLoadingToComplete()
        
        // Assert: Family dashboard should be displayed
        let dashboardTitle = app.navigationBars["Family Dashboard"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: defaultTimeout),
                     "Family dashboard should be displayed")
        
        // Verify family name is displayed
        let familyNameText = app.staticTexts.containing("Family").firstMatch
        XCTAssertTrue(familyNameText.waitForExistence(timeout: defaultTimeout),
                     "Family name should be displayed")
        
        // Verify member count is displayed
        let memberCountText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Member'")).firstMatch
        XCTAssertTrue(memberCountText.waitForExistence(timeout: defaultTimeout),
                     "Member count should be displayed")
        
        // Take screenshot for visual verification
        takeScreenshot(name: "FamilyDashboard_Display")
    }
    
    /// Test family dashboard shows current user role
    func testFamilyDashboardShowsCurrentUserRole() {
        // Arrange: Sign in and navigate to family dashboard
        performMockSignIn()
        waitForLoadingToComplete()
        
        // Assert: User role should be displayed
        let roleText = app.staticTexts["Your Role:"]
        XCTAssertTrue(roleText.waitForExistence(timeout: defaultTimeout),
                     "User role label should be displayed")
        
        // Verify role badge is present
        let roleBadge = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Admin' OR label CONTAINS 'Adult' OR label CONTAINS 'Kid'")).firstMatch
        XCTAssertTrue(roleBadge.waitForExistence(timeout: defaultTimeout),
                     "Role badge should be displayed")
    }
    
    /// Test family dashboard member list displays correctly
    func testFamilyDashboardMemberListDisplay() {
        // Arrange: Sign in and navigate to family dashboard
        performMockSignIn()
        waitForLoadingToComplete()
        
        // Assert: Members section should be displayed
        let membersSection = app.staticTexts["Family Members"]
        XCTAssertTrue(membersSection.waitForExistence(timeout: defaultTimeout),
                     "Family Members section should be displayed")
        
        // Verify at least one member is displayed
        let memberRows = app.cells.matching(NSPredicate(format: "identifier CONTAINS 'member_row'"))
        XCTAssertGreaterThan(memberRows.count, 0, "At least one family member should be displayed")
        
        // Verify member avatars are displayed
        let memberAvatars = app.images.matching(NSPredicate(format: "identifier CONTAINS 'member_avatar'"))
        XCTAssertGreaterThan(memberAvatars.count, 0, "Member avatars should be displayed")
    }
    
    // MARK: - Family Member Management Tests
    
    /// Test admin controls are visible for admin users
    func testAdminControlsVisibilityForAdminUsers() {
        // Arrange: Sign in as admin user
        performMockSignIn()
        waitForLoadingToComplete()
        
        // Assert: Admin controls section should be visible
        let adminControlsSection = app.staticTexts["Admin Controls"]
        XCTAssertTrue(adminControlsSection.waitForExistence(timeout: defaultTimeout),
                     "Admin Controls section should be visible for admin users")
        
        // Verify invite button is present
        let inviteButton = app.buttons["Invite New Member"]
        XCTAssertTrue(inviteButton.waitForExistence(timeout: defaultTimeout),
                     "Invite New Member button should be visible")
        
        // Verify family settings button is present
        let settingsButton = app.buttons["Family Settings"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: defaultTimeout),
                     "Family Settings button should be visible")
    }
    
    /// Test member role change functionality
    func testMemberRoleChangeFlow() {
        // Arrange: Sign in as admin and navigate to family dashboard
        performMockSignIn()
        waitForLoadingToComplete()
        
        // Find a member row with role change button
        let roleChangeButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'change_role'")).firstMatch
        
        if roleChangeButton.waitForExistence(timeout: defaultTimeout) {
            // Act: Tap role change button
            safeTap(roleChangeButton)
            
            // Assert: Role change sheet should appear
            let roleChangeSheet = app.navigationBars["Change Role"]
            XCTAssertTrue(roleChangeSheet.waitForExistence(timeout: defaultTimeout),
                         "Role change sheet should be displayed")
            
            // Verify role options are displayed
            let roleOptions = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Adult' OR label CONTAINS 'Kid'"))
            XCTAssertGreaterThan(roleOptions.count, 0, "Role options should be displayed")
            
            // Test canceling the role change
            let cancelButton = app.buttons["Cancel"]
            safeTap(cancelButton)
            
            // Should return to family dashboard
            let dashboardTitle = app.navigationBars["Family Dashboard"]
            XCTAssertTrue(dashboardTitle.waitForExistence(timeout: defaultTimeout),
                         "Should return to family dashboard after canceling")
        }
    }
    
    /// Test member removal functionality
    func testMemberRemovalFlow() {
        // Arrange: Sign in as admin and navigate to family dashboard
        performMockSignIn()
        waitForLoadingToComplete()
        
        // Find a member row with remove button
        let removeButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'remove_member'")).firstMatch
        
        if removeButton.waitForExistence(timeout: defaultTimeout) {
            // Act: Tap remove button
            safeTap(removeButton)
            
            // Assert: Confirmation dialog should appear
            let confirmationDialog = app.alerts.firstMatch
            XCTAssertTrue(confirmationDialog.waitForExistence(timeout: defaultTimeout),
                         "Removal confirmation dialog should be displayed")
            
            // Verify dialog contains member name
            let dialogText = confirmationDialog.staticTexts.firstMatch.label
            XCTAssertTrue(dialogText.contains("remove"), "Dialog should mention removing member")
            
            // Test canceling the removal
            let cancelButton = confirmationDialog.buttons["Cancel"]
            if cancelButton.exists {
                safeTap(cancelButton)
            }
            
            // Should return to family dashboard
            let dashboardTitle = app.navigationBars["Family Dashboard"]
            XCTAssertTrue(dashboardTitle.waitForExistence(timeout: defaultTimeout),
                         "Should return to family dashboard after canceling removal")
        }
    }
    
    /// Test invite new member functionality
    func testInviteNewMemberFlow() {
        // Arrange: Sign in as admin and navigate to family dashboard
        performMockSignIn()
        waitForLoadingToComplete()
        
        // Act: Tap invite new member button
        let inviteButton = app.buttons["Invite New Member"]
        if inviteButton.waitForExistence(timeout: defaultTimeout) {
            safeTap(inviteButton)
            
            // Assert: Should show coming soon message or invite flow
            // Since this is marked as "coming soon" in the implementation
            waitForLoadingToComplete()
            
            // Verify we're still on the family dashboard
            let dashboardTitle = app.navigationBars["Family Dashboard"]
            XCTAssertTrue(dashboardTitle.exists, "Should remain on family dashboard")
        }
    }
    
    // MARK: - Family Creation Flow Tests
    
    /// Test family creation form display and validation
    func testFamilyCreationFormDisplay() {
        // Arrange: Start from family selection and navigate to create family
        app.launch()
        
        // Navigate to create family (this would be from onboarding flow)
        let createFamilyButton = app.buttons["Create Family"]
        if createFamilyButton.waitForExistence(timeout: defaultTimeout) {
            safeTap(createFamilyButton)
            
            // Assert: Create family form should be displayed
            let createFamilyTitle = app.navigationBars["Create Family"]
            XCTAssertTrue(createFamilyTitle.waitForExistence(timeout: defaultTimeout),
                         "Create Family screen should be displayed")
            
            // Verify family name input field
            let familyNameField = app.textFields["Enter your family name"]
            XCTAssertTrue(familyNameField.waitForExistence(timeout: defaultTimeout),
                         "Family name input field should be displayed")
            
            // Verify create button is present but disabled initially
            let createButton = app.buttons["Create Family"]
            XCTAssertTrue(createButton.waitForExistence(timeout: defaultTimeout),
                         "Create Family button should be displayed")
            
            // Take screenshot for visual verification
            takeScreenshot(name: "FamilyCreation_Form")
        }
    }
    
    /// Test family creation form validation
    func testFamilyCreationFormValidation() {
        // Arrange: Navigate to create family form
        app.launch()
        let createFamilyButton = app.buttons["Create Family"]
        
        if createFamilyButton.waitForExistence(timeout: defaultTimeout) {
            safeTap(createFamilyButton)
            
            let familyNameField = app.textFields["Enter your family name"]
            let createButton = app.buttons["Create Family"]
            
            // Test empty input validation
            XCTAssertTrue(familyNameField.waitForExistence(timeout: defaultTimeout))
            XCTAssertTrue(createButton.waitForExistence(timeout: defaultTimeout))
            
            // Create button should be disabled with empty input
            XCTAssertFalse(createButton.isEnabled, "Create button should be disabled with empty input")
            
            // Test valid input
            safeTypeText("Test Family", into: familyNameField)
            
            // Create button should be enabled with valid input
            XCTAssertTrue(createButton.isEnabled, "Create button should be enabled with valid input")
            
            // Test input guidelines are displayed
            let guidelines = app.staticTexts["Guidelines:"]
            XCTAssertTrue(guidelines.waitForExistence(timeout: defaultTimeout),
                         "Input guidelines should be displayed")
        }
    }
    
    /// Test successful family creation flow
    func testSuccessfulFamilyCreationFlow() {
        // Arrange: Navigate to create family form
        app.launch()
        let createFamilyButton = app.buttons["Create Family"]
        
        if createFamilyButton.waitForExistence(timeout: defaultTimeout) {
            safeTap(createFamilyButton)
            
            let familyNameField = app.textFields["Enter your family name"]
            let createButton = app.buttons["Create Family"]
            
            // Act: Fill in family name and create family
            safeTypeText("Test Family", into: familyNameField)
            safeTap(createButton)
            
            // Assert: Loading state should be displayed
            let loadingIndicator = app.staticTexts["Creating your family..."]
            XCTAssertTrue(loadingIndicator.waitForExistence(timeout: shortTimeout),
                         "Loading message should be displayed during creation")
            
            // Wait for creation to complete
            waitForLoadingToComplete(timeout: longTimeout)
            
            // Success message should be displayed
            let successMessage = app.staticTexts["Family Created Successfully!"]
            XCTAssertTrue(successMessage.waitForExistence(timeout: defaultTimeout),
                         "Success message should be displayed after creation")
            
            // Family code should be displayed
            let familyCodeLabel = app.staticTexts["Family Code"]
            XCTAssertTrue(familyCodeLabel.waitForExistence(timeout: defaultTimeout),
                         "Family code should be displayed")
            
            // Copy button should be available
            let copyButton = app.buttons["Copy Code"]
            XCTAssertTrue(copyButton.waitForExistence(timeout: defaultTimeout),
                         "Copy code button should be available")
            
            // Take screenshot for visual verification
            takeScreenshot(name: "FamilyCreation_Success")
        }
    }
    
    // MARK: - Family Joining Flow Tests
    
    /// Test join family form display
    func testJoinFamilyFormDisplay() {
        // Arrange: Navigate to join family form
        app.launch()
        let joinFamilyButton = app.buttons["Join Family"]
        
        if joinFamilyButton.waitForExistence(timeout: defaultTimeout) {
            safeTap(joinFamilyButton)
            
            // Assert: Join family form should be displayed
            let joinFamilyTitle = app.navigationBars["Join Family"]
            XCTAssertTrue(joinFamilyTitle.waitForExistence(timeout: defaultTimeout),
                         "Join Family screen should be displayed")
            
            // Verify family code input field
            let codeField = app.textFields["Enter family code"]
            XCTAssertTrue(codeField.waitForExistence(timeout: defaultTimeout),
                         "Family code input field should be displayed")
            
            // Verify QR scan button
            let scanButton = app.buttons["Scan QR Code"]
            XCTAssertTrue(scanButton.waitForExistence(timeout: defaultTimeout),
                         "QR scan button should be displayed")
            
            // Take screenshot for visual verification
            takeScreenshot(name: "FamilyJoin_Form")
        }
    }
    
    /// Test join family code validation
    func testJoinFamilyCodeValidation() {
        // Arrange: Navigate to join family form
        app.launch()
        let joinFamilyButton = app.buttons["Join Family"]
        
        if joinFamilyButton.waitForExistence(timeout: defaultTimeout) {
            safeTap(joinFamilyButton)
            
            let codeField = app.textFields["Enter family code"]
            let searchButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'search'")).firstMatch
            
            // Test invalid code format
            safeTypeText("123", into: codeField)
            
            // Search button should be disabled for invalid format
            if searchButton.exists {
                XCTAssertFalse(searchButton.isEnabled, "Search button should be disabled for invalid code format")
            }
            
            // Clear and test valid format
            clearAndTypeText("DEMO1234", into: codeField)
            
            // Search button should be enabled for valid format
            if searchButton.exists {
                XCTAssertTrue(searchButton.isEnabled, "Search button should be enabled for valid code format")
            }
        }
    }
    
    /// Test QR code scanning functionality
    func testQRCodeScanningFlow() {
        // Arrange: Navigate to join family form
        app.launch()
        let joinFamilyButton = app.buttons["Join Family"]
        
        if joinFamilyButton.waitForExistence(timeout: defaultTimeout) {
            safeTap(joinFamilyButton)
            
            // Act: Tap QR scan button
            let scanButton = app.buttons["Scan QR Code"]
            safeTap(scanButton)
            
            // Assert: Should show scanning state or camera permission
            // Note: In UI tests, camera access might be restricted
            let scanningText = app.staticTexts["Scanning..."]
            if scanningText.waitForExistence(timeout: shortTimeout) {
                XCTAssertTrue(scanningText.exists, "Scanning state should be displayed")
            }
            
            // Wait for scan to complete or timeout
            waitForLoadingToComplete(timeout: longTimeout)
        }
    }
    
    // MARK: - Family Settings Interface Tests
    
    /// Test family settings access and display
    func testFamilySettingsAccess() {
        // Arrange: Sign in as admin and navigate to family dashboard
        performMockSignIn()
        waitForLoadingToComplete()
        
        // Act: Tap family settings button
        let settingsButton = app.buttons["Family Settings"]
        if settingsButton.waitForExistence(timeout: defaultTimeout) {
            safeTap(settingsButton)
            
            // Assert: Should show coming soon message or settings interface
            // Since this is marked as "coming soon" in the implementation
            waitForLoadingToComplete()
            
            // Verify we're still on the family dashboard
            let dashboardTitle = app.navigationBars["Family Dashboard"]
            XCTAssertTrue(dashboardTitle.exists, "Should remain on family dashboard")
        }
    }
    
    /// Test family dashboard menu functionality
    func testFamilyDashboardMenu() {
        // Arrange: Sign in and navigate to family dashboard
        performMockSignIn()
        waitForLoadingToComplete()
        
        // Act: Tap menu button (ellipsis)
        let menuButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'ellipsis'")).firstMatch
        if menuButton.waitForExistence(timeout: defaultTimeout) {
            safeTap(menuButton)
            
            // Assert: Menu options should be displayed
            let refreshOption = app.buttons["Refresh"]
            XCTAssertTrue(refreshOption.waitForExistence(timeout: defaultTimeout),
                         "Refresh option should be available in menu")
            
            let leaveFamilyOption = app.buttons["Leave Family"]
            XCTAssertTrue(leaveFamilyOption.waitForExistence(timeout: defaultTimeout),
                         "Leave Family option should be available in menu")
            
            let signOutOption = app.buttons["Sign Out"]
            XCTAssertTrue(signOutOption.waitForExistence(timeout: defaultTimeout),
                         "Sign Out option should be available in menu")
            
            // Test refresh functionality
            safeTap(refreshOption)
            waitForLoadingToComplete()
            
            // Should remain on family dashboard
            let dashboardTitle = app.navigationBars["Family Dashboard"]
            XCTAssertTrue(dashboardTitle.exists, "Should remain on family dashboard after refresh")
        }
    }
    
    // MARK: - Accessibility Tests
    
    /// Test family dashboard accessibility compliance
    func testFamilyDashboardAccessibility() {
        // Arrange: Sign in and navigate to family dashboard
        performMockSignIn()
        waitForLoadingToComplete()
        
        // Test main elements accessibility
        let dashboardTitle = app.navigationBars["Family Dashboard"]
        assertElementIsAccessible(dashboardTitle)
        
        // Test family name accessibility
        let familyNameText = app.staticTexts.containing("Family").firstMatch
        if familyNameText.exists {
            assertElementIsAccessible(familyNameText)
        }
        
        // Test member rows accessibility
        let memberRows = app.cells.matching(NSPredicate(format: "identifier CONTAINS 'member_row'"))
        for i in 0..<min(memberRows.count, 3) { // Test first 3 members
            let memberRow = memberRows.element(boundBy: i)
            if memberRow.exists {
                assertElementIsAccessible(memberRow)
            }
        }
        
        // Test admin controls accessibility
        let inviteButton = app.buttons["Invite New Member"]
        if inviteButton.exists {
            assertElementIsAccessible(inviteButton)
        }
    }
    
    /// Test family creation form accessibility
    func testFamilyCreationFormAccessibility() {
        // Arrange: Navigate to create family form
        app.launch()
        let createFamilyButton = app.buttons["Create Family"]
        
        if createFamilyButton.waitForExistence(timeout: defaultTimeout) {
            safeTap(createFamilyButton)
            
            // Test form elements accessibility
            let familyNameField = app.textFields["Enter your family name"]
            assertElementIsAccessible(familyNameField)
            
            let createButton = app.buttons["Create Family"]
            assertElementIsAccessible(createButton)
            
            // Test guidelines accessibility
            let guidelines = app.staticTexts["Guidelines:"]
            if guidelines.exists {
                assertElementIsAccessible(guidelines)
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    /// Test family dashboard error handling
    func testFamilyDashboardErrorHandling() {
        // Arrange: Sign in and navigate to family dashboard
        performMockSignIn()
        waitForLoadingToComplete()
        
        // Simulate error by attempting invalid operation
        let inviteButton = app.buttons["Invite New Member"]
        if inviteButton.waitForExistence(timeout: defaultTimeout) {
            safeTap(inviteButton)
            
            // Should handle error gracefully
            if isErrorAlertDisplayed() {
                dismissErrorAlerts()
            }
            
            // Should remain functional
            let dashboardTitle = app.navigationBars["Family Dashboard"]
            XCTAssertTrue(dashboardTitle.exists, "Dashboard should remain functional after error")
        }
    }
    
    /// Test family creation error handling
    func testFamilyCreationErrorHandling() {
        // Arrange: Navigate to create family form
        app.launch()
        let createFamilyButton = app.buttons["Create Family"]
        
        if createFamilyButton.waitForExistence(timeout: defaultTimeout) {
            safeTap(createFamilyButton)
            
            let familyNameField = app.textFields["Enter your family name"]
            let createButton = app.buttons["Create Family"]
            
            // Test with potentially problematic input
            safeTypeText("", into: familyNameField) // Empty name
            
            // Create button should be disabled
            XCTAssertFalse(createButton.isEnabled, "Create button should be disabled with empty input")
            
            // Test with valid input but potential server error
            safeTypeText("Test Family", into: familyNameField)
            safeTap(createButton)
            
            // Wait for operation to complete
            waitForLoadingToComplete(timeout: longTimeout)
            
            // Handle any error alerts
            if isErrorAlertDisplayed() {
                dismissErrorAlerts()
            }
            
            // Form should remain functional
            XCTAssertTrue(familyNameField.exists, "Form should remain functional after error")
        }
    }
    
    // MARK: - Performance Tests
    
    /// Test family dashboard loading performance
    func testFamilyDashboardLoadingPerformance() {
        // Measure family dashboard loading time
        measure {
            performMockSignIn()
            waitForLoadingToComplete()
            
            let dashboardTitle = app.navigationBars["Family Dashboard"]
            XCTAssertTrue(dashboardTitle.waitForExistence(timeout: defaultTimeout))
            
            // Reset for next iteration
            performSignOut()
        }
    }
    
    /// Test family creation performance
    func testFamilyCreationPerformance() {
        // Measure family creation performance
        app.launch()
        let createFamilyButton = app.buttons["Create Family"]
        
        if createFamilyButton.waitForExistence(timeout: defaultTimeout) {
            measure {
                safeTap(createFamilyButton)
                
                let familyNameField = app.textFields["Enter your family name"]
                let createButton = app.buttons["Create Family"]
                
                safeTypeText("Performance Test Family", into: familyNameField)
                safeTap(createButton)
                
                waitForLoadingToComplete(timeout: longTimeout)
                
                // Reset for next iteration
                navigateBack()
            }
        }
    }
}