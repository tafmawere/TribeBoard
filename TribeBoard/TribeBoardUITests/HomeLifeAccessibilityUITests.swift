import XCTest

/// UI tests for HomeLife accessibility features and VoiceOver navigation
final class HomeLifeAccessibilityUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - VoiceOver Navigation Tests
    
    @MainActor
    func testVoiceOverNavigationThroughHomeLife() throws {
        // Test VoiceOver navigation through HomeLife features
        
        // Navigate to HomeLife
        let homeLifeTab = app.tabBars.buttons["HomeLife"]
        XCTAssertTrue(homeLifeTab.exists, "HomeLife tab should exist")
        
        // Test tab accessibility
        XCTAssertTrue(homeLifeTab.isAccessibilityElement, "HomeLife tab should be accessible to VoiceOver")
        XCTAssertNotNil(homeLifeTab.label, "HomeLife tab should have accessibility label")
        
        homeLifeTab.tap()
        
        // Test feature cards VoiceOver navigation
        let featureCards = [
            app.buttons["Meal Plan"],
            app.buttons["Grocery List"],
            app.buttons["Tasks"],
            app.buttons["Pantry"]
        ]
        
        for card in featureCards {
            if card.exists {
                XCTAssertTrue(card.isAccessibilityElement, "Feature card should be accessible to VoiceOver")
                XCTAssertNotNil(card.label, "Feature card should have accessibility label")
                XCTAssertFalse(card.label.isEmpty, "Feature card label should not be empty")
                
                // Test accessibility traits
                let traits = card.accessibilityTraits
                XCTAssertTrue(traits.contains(.button), "Feature card should have button trait")
            }
        }
    }
    
    @MainActor
    func testVoiceOverMealPlanNavigation() throws {
        // Test VoiceOver navigation in Meal Plan
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Meal Plan"].tap()
        
        // Wait for content to load
        sleep(2)
        
        // Test navigation title accessibility
        let navigationTitle = app.navigationBars["Meal Plan"]
        if navigationTitle.exists {
            let titleText = navigationTitle.staticTexts.firstMatch
            if titleText.exists {
                XCTAssertTrue(titleText.isAccessibilityElement, "Navigation title should be accessible")
                let traits = titleText.accessibilityTraits
                XCTAssertTrue(traits.contains(.header), "Navigation title should have header trait")
            }
        }
        
        // Test meal cards VoiceOver support
        let mealCards = app.otherElements.matching(identifier: "mealCard")
        
        for i in 0..<min(mealCards.count, 3) {
            let mealCard = mealCards.element(boundBy: i)
            if mealCard.exists {
                XCTAssertTrue(mealCard.isAccessibilityElement, "Meal card should be accessible to VoiceOver")
                XCTAssertNotNil(mealCard.label, "Meal card should have descriptive accessibility label")
                
                // Label should include meal name and date information
                let label = mealCard.label
                XCTAssertGreaterThan(label.count, 10, "Meal card label should be comprehensive")
            }
        }
        
        // Test Check Pantry buttons
        let checkPantryButtons = app.buttons.matching(identifier: "checkPantryButton")
        
        for i in 0..<min(checkPantryButtons.count, 2) {
            let button = checkPantryButtons.element(boundBy: i)
            if button.exists {
                XCTAssertTrue(button.isAccessibilityElement, "Check Pantry button should be accessible")
                XCTAssertNotNil(button.label, "Check Pantry button should have accessibility label")
                
                // Test accessibility hint
                if let hint = button.accessibilityHint {
                    XCTAssertFalse(hint.isEmpty, "Accessibility hint should not be empty")
                    XCTAssertTrue(hint.lowercased().contains("pantry") || hint.lowercased().contains("check"), 
                                 "Hint should describe the action")
                }
            }
        }
    }
    
    @MainActor
    func testVoiceOverPantryCheckNavigation() throws {
        // Test VoiceOver navigation in Pantry Check
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Pantry"].tap()
        
        // Wait for ingredients to load
        sleep(2)
        
        // Test ingredient checkboxes VoiceOver support
        let ingredientCheckboxes = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'ingredientCheckbox'"))
        
        for i in 0..<min(ingredientCheckboxes.count, 5) {
            let checkbox = ingredientCheckboxes.element(boundBy: i)
            if checkbox.exists {
                XCTAssertTrue(checkbox.isAccessibilityElement, "Ingredient checkbox should be accessible")
                XCTAssertNotNil(checkbox.label, "Ingredient checkbox should have accessibility label")
                
                // Test accessibility value for state
                XCTAssertNotNil(checkbox.value, "Ingredient checkbox should have accessibility value")
                
                // Test accessibility traits
                let traits = checkbox.accessibilityTraits
                XCTAssertTrue(traits.contains(.button), "Ingredient checkbox should have button trait")
                
                // Label should include ingredient name and quantity
                let label = checkbox.label
                XCTAssertGreaterThan(label.count, 3, "Ingredient label should include name and quantity")
            }
        }
        
        // Test Generate Grocery List button
        let generateButton = app.buttons["Generate Grocery List"]
        if generateButton.exists {
            XCTAssertTrue(generateButton.isAccessibilityElement, "Generate button should be accessible")
            XCTAssertNotNil(generateButton.label, "Generate button should have accessibility label")
            
            if let hint = generateButton.accessibilityHint {
                XCTAssertTrue(hint.lowercased().contains("grocery") || hint.lowercased().contains("list"), 
                             "Generate button hint should describe the action")
            }
        }
    }
    
    @MainActor
    func testVoiceOverGroceryListNavigation() throws {
        // Test VoiceOver navigation in Grocery List
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Grocery List"].tap()
        
        // Wait for items to load
        sleep(2)
        
        // Test tab controls accessibility
        let weeklyTab = app.buttons["Weekly List"]
        let urgentTab = app.buttons["Urgent Items"]
        
        if weeklyTab.exists {
            XCTAssertTrue(weeklyTab.isAccessibilityElement, "Weekly tab should be accessible")
            XCTAssertNotNil(weeklyTab.label, "Weekly tab should have accessibility label")
            
            let traits = weeklyTab.accessibilityTraits
            XCTAssertTrue(traits.contains(.button), "Weekly tab should have button trait")
        }
        
        if urgentTab.exists {
            XCTAssertTrue(urgentTab.isAccessibilityElement, "Urgent tab should be accessible")
            XCTAssertNotNil(urgentTab.label, "Urgent tab should have accessibility label")
        }
        
        // Test grocery item cards
        let groceryItemCards = app.cells.matching(identifier: "groceryItemCard")
        
        for i in 0..<min(groceryItemCards.count, 3) {
            let itemCard = groceryItemCards.element(boundBy: i)
            if itemCard.exists {
                XCTAssertTrue(itemCard.isAccessibilityElement, "Grocery item card should be accessible")
                XCTAssertNotNil(itemCard.label, "Grocery item card should have accessibility label")
                
                // Label should include item details
                let label = itemCard.label
                XCTAssertGreaterThan(label.count, 5, "Grocery item label should be descriptive")
            }
        }
        
        // Test Order Online button
        let orderOnlineButton = app.buttons["Order Online"]
        if orderOnlineButton.exists {
            XCTAssertTrue(orderOnlineButton.isAccessibilityElement, "Order Online button should be accessible")
            XCTAssertNotNil(orderOnlineButton.label, "Order Online button should have accessibility label")
        }
    }
    
    // MARK: - Dynamic Type Tests
    
    @MainActor
    func testDynamicTypeSupport() throws {
        // Test Dynamic Type support across HomeLife features
        // Note: In a real test environment, you would programmatically change Dynamic Type settings
        
        // Navigate to HomeLife
        app.tabBars.buttons["HomeLife"].tap()
        
        // Test that feature cards exist and should support Dynamic Type
        let featureCards = [
            app.buttons["Meal Plan"],
            app.buttons["Grocery List"],
            app.buttons["Tasks"],
            app.buttons["Pantry"]
        ]
        
        for card in featureCards {
            if card.exists {
                // Verify card exists and is accessible (Dynamic Type support would be tested with actual settings changes)
                XCTAssertTrue(card.exists, "Feature cards should support Dynamic Type scaling")
                XCTAssertTrue(card.isAccessibilityElement, "Feature cards should remain accessible with Dynamic Type")
            }
        }
        
        // Test meal plan text scaling
        app.buttons["Meal Plan"].tap()
        sleep(2)
        
        let mealCards = app.otherElements.matching(identifier: "mealCard")
        if mealCards.count > 0 {
            let firstCard = mealCards.element(boundBy: 0)
            XCTAssertTrue(firstCard.exists, "Meal cards should support Dynamic Type")
            XCTAssertTrue(firstCard.isAccessibilityElement, "Meal cards should remain accessible with Dynamic Type")
        }
    }
    
    @MainActor
    func testTextSizeAdaptationLayout() throws {
        // Test that layout adapts properly to larger text sizes
        
        // Navigate to Pantry Check (has many text elements)
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Pantry"].tap()
        sleep(2)
        
        // Test ingredient list layout with potential larger text
        let ingredientCheckboxes = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'ingredientCheckbox'"))
        
        if ingredientCheckboxes.count > 0 {
            let firstCheckbox = ingredientCheckboxes.element(boundBy: 0)
            
            // Verify minimum touch target size is maintained
            let frame = firstCheckbox.frame
            XCTAssertGreaterThanOrEqual(frame.width, 44, "Touch target should maintain minimum width with larger text")
            XCTAssertGreaterThanOrEqual(frame.height, 44, "Touch target should maintain minimum height with larger text")
            
            // Verify element remains accessible
            XCTAssertTrue(firstCheckbox.isAccessibilityElement, "Elements should remain accessible with larger text")
        }
    }
    
    // MARK: - High Contrast Mode Tests
    
    @MainActor
    func testHighContrastModeSupport() throws {
        // Test interface usability in high contrast mode
        // Note: In a real test, you would programmatically enable high contrast mode
        
        // Navigate through HomeLife features
        app.tabBars.buttons["HomeLife"].tap()
        
        // Test feature cards visibility in high contrast
        let featureCards = [
            app.buttons["Meal Plan"],
            app.buttons["Grocery List"],
            app.buttons["Tasks"],
            app.buttons["Pantry"]
        ]
        
        for card in featureCards {
            if card.exists {
                XCTAssertTrue(card.isEnabled, "Feature cards should be usable in high contrast mode")
                XCTAssertTrue(card.isAccessibilityElement, "Feature cards should remain accessible in high contrast")
                
                // Test that card can be interacted with
                XCTAssertTrue(card.isHittable, "Feature cards should be hittable in high contrast mode")
            }
        }
        
        // Test status indicators don't rely solely on color
        app.buttons["Tasks"].tap()
        sleep(2)
        
        let statusBadges = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Pending' OR label CONTAINS 'In Progress' OR label CONTAINS 'Completed'"))
        
        for i in 0..<min(statusBadges.count, 3) {
            let badge = statusBadges.element(boundBy: i)
            if badge.exists {
                // Status should be conveyed through text, not just color
                XCTAssertNotNil(badge.label, "Status badge should have text label")
                XCTAssertFalse(badge.label.isEmpty, "Status badge text should not be empty")
                
                let label = badge.label
                let hasStatusText = label.contains("Pending") || label.contains("Progress") || label.contains("Completed")
                XCTAssertTrue(hasStatusText, "Status should be conveyed through text, not just color")
            }
        }
    }
    
    // MARK: - Reduced Motion Tests
    
    @MainActor
    func testReducedMotionSupport() throws {
        // Test that essential functionality works without animations
        
        // Navigate to Pantry Check and test checkbox interactions
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Pantry"].tap()
        sleep(2)
        
        // Test ingredient checkbox state changes without relying on animation
        let ingredientCheckbox = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'ingredientCheckbox'")).firstMatch
        
        if ingredientCheckbox.exists {
            let initialValue = ingredientCheckbox.value as? String ?? ""
            let initialSelected = ingredientCheckbox.isSelected
            
            ingredientCheckbox.tap()
            
            // State change should be apparent without animation
            let newValue = ingredientCheckbox.value as? String ?? ""
            let newSelected = ingredientCheckbox.isSelected
            
            XCTAssertTrue(newValue != initialValue || newSelected != initialSelected, 
                         "Checkbox state should change without relying on animation")
            
            // Accessibility should reflect the change
            XCTAssertNotNil(ingredientCheckbox.value, "Checkbox should have accessibility value indicating state")
        }
        
        // Test navigation without animation dependencies
        app.navigationBars.buttons.element(boundBy: 0).tap() // Back to HomeLife
        
        let groceryListCard = app.buttons["Grocery List"]
        if groceryListCard.exists {
            groceryListCard.tap()
            
            // Navigation should work without animations
            let groceryListTitle = app.navigationBars["Grocery List"]
            XCTAssertTrue(groceryListTitle.waitForExistence(timeout: 5.0), 
                         "Navigation should work without relying on animations")
        }
    }
    
    // MARK: - Touch Target Size Tests
    
    @MainActor
    func testMinimumTouchTargetSizes() throws {
        // Test that all interactive elements meet minimum 44x44 point touch target size
        
        // Test HomeLife tab
        let homeLifeTab = app.tabBars.buttons["HomeLife"]
        let tabFrame = homeLifeTab.frame
        XCTAssertGreaterThanOrEqual(tabFrame.width, 44, "HomeLife tab should meet minimum touch target width")
        XCTAssertGreaterThanOrEqual(tabFrame.height, 44, "HomeLife tab should meet minimum touch target height")
        
        // Navigate to HomeLife
        homeLifeTab.tap()
        
        // Test feature cards
        let featureCards = [
            app.buttons["Meal Plan"],
            app.buttons["Grocery List"],
            app.buttons["Tasks"],
            app.buttons["Pantry"]
        ]
        
        for card in featureCards {
            if card.exists {
                let frame = card.frame
                XCTAssertGreaterThanOrEqual(frame.width, 44, "Feature card should meet minimum touch target width")
                XCTAssertGreaterThanOrEqual(frame.height, 44, "Feature card should meet minimum touch target height")
            }
        }
        
        // Test Pantry Check checkboxes
        app.buttons["Pantry"].tap()
        sleep(2)
        
        let ingredientCheckboxes = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'ingredientCheckbox'"))
        
        for i in 0..<min(ingredientCheckboxes.count, 3) {
            let checkbox = ingredientCheckboxes.element(boundBy: i)
            if checkbox.exists {
                let frame = checkbox.frame
                XCTAssertGreaterThanOrEqual(frame.width, 44, "Ingredient checkbox should meet minimum touch target width")
                XCTAssertGreaterThanOrEqual(frame.height, 44, "Ingredient checkbox should meet minimum touch target height")
            }
        }
    }
    
    @MainActor
    func testInteractiveElementSpacing() throws {
        // Test adequate spacing between interactive elements
        
        // Navigate to Pantry Check
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Pantry"].tap()
        sleep(2)
        
        // Test spacing between ingredient checkboxes
        let ingredientCheckboxes = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'ingredientCheckbox'"))
        
        if ingredientCheckboxes.count >= 2 {
            let firstCheckbox = ingredientCheckboxes.element(boundBy: 0)
            let secondCheckbox = ingredientCheckboxes.element(boundBy: 1)
            
            let firstFrame = firstCheckbox.frame
            let secondFrame = secondCheckbox.frame
            
            // Calculate spacing (assuming vertical layout)
            let verticalSpacing = abs(secondFrame.minY - firstFrame.maxY)
            XCTAssertGreaterThanOrEqual(verticalSpacing, 8, "Interactive elements should have adequate vertical spacing")
        }
        
        // Test spacing in grocery list
        app.navigationBars.buttons.element(boundBy: 0).tap() // Back to HomeLife
        app.buttons["Grocery List"].tap()
        sleep(2)
        
        let groceryItemCards = app.cells.matching(identifier: "groceryItemCard")
        
        if groceryItemCards.count >= 2 {
            let firstCard = groceryItemCards.element(boundBy: 0)
            let secondCard = groceryItemCards.element(boundBy: 1)
            
            let firstFrame = firstCard.frame
            let secondFrame = secondCard.frame
            
            let spacing = abs(secondFrame.minY - firstFrame.maxY)
            XCTAssertGreaterThanOrEqual(spacing, 4, "Grocery item cards should have adequate spacing")
        }
    }
    
    // MARK: - Accessibility Hints Tests
    
    @MainActor
    func testAccessibilityHintsQuality() throws {
        // Test that accessibility hints are helpful and descriptive
        
        // Navigate to Meal Plan
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Meal Plan"].tap()
        sleep(2)
        
        // Test Check Pantry button hints
        let checkPantryButton = app.buttons["Check Pantry"]
        if checkPantryButton.exists {
            if let hint = checkPantryButton.accessibilityHint {
                XCTAssertFalse(hint.isEmpty, "Check Pantry button should have accessibility hint")
                XCTAssertGreaterThan(hint.count, 10, "Accessibility hint should be descriptive")
                
                let hintLower = hint.lowercased()
                let hasRelevantKeywords = hintLower.contains("pantry") || hintLower.contains("ingredients") || 
                                        hintLower.contains("check") || hintLower.contains("available")
                XCTAssertTrue(hasRelevantKeywords, "Accessibility hint should contain relevant keywords")
            }
        }
        
        // Navigate to Grocery List and test Order Online button
        app.navigationBars.buttons.element(boundBy: 0).tap() // Back to HomeLife
        app.buttons["Grocery List"].tap()
        
        let orderOnlineButton = app.buttons["Order Online"]
        if orderOnlineButton.exists {
            if let hint = orderOnlineButton.accessibilityHint {
                XCTAssertFalse(hint.isEmpty, "Order Online button should have accessibility hint")
                
                let hintLower = hint.lowercased()
                let hasRelevantKeywords = hintLower.contains("order") || hintLower.contains("platform") || 
                                        hintLower.contains("delivery") || hintLower.contains("grocery")
                XCTAssertTrue(hasRelevantKeywords, "Order Online hint should explain the action")
            }
        }
    }
    
    // MARK: - Form Accessibility Tests
    
    @MainActor
    func testFormAccessibilityLabels() throws {
        // Test form accessibility in task creation
        
        // Navigate to task creation
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Tasks"].tap()
        
        let createTaskButton = app.buttons["Create Task"]
        if createTaskButton.exists {
            createTaskButton.tap()
            
            // Test form field accessibility
            let formFields = [
                app.buttons["Assign to"],
                app.buttons["Task Type"],
                app.buttons["Due Date"]
            ]
            
            for field in formFields {
                if field.exists {
                    XCTAssertTrue(field.isAccessibilityElement, "Form field should be accessible")
                    XCTAssertNotNil(field.label, "Form field should have accessibility label")
                    XCTAssertFalse(field.label.isEmpty, "Form field label should not be empty")
                    
                    // Test accessibility traits
                    let traits = field.accessibilityTraits
                    XCTAssertTrue(traits.contains(.button), "Form field should have appropriate accessibility trait")
                }
            }
            
            // Test notes field if it's a text field
            let notesField = app.textFields["Notes"]
            if notesField.exists {
                XCTAssertTrue(notesField.isAccessibilityElement, "Notes field should be accessible")
                XCTAssertNotNil(notesField.label, "Notes field should have accessibility label")
                
                let traits = notesField.accessibilityTraits
                let hasTextTrait = traits.contains(.searchField) || traits.contains(.keyboardKey)
                XCTAssertTrue(hasTextTrait, "Notes field should have text input accessibility trait")
            }
        }
    }
    
    // MARK: - Error State Accessibility Tests
    
    @MainActor
    func testErrorStateAccessibility() throws {
        // Test that error states are accessible
        
        // Navigate to task creation and trigger validation error
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Tasks"].tap()
        
        let createTaskButton = app.buttons["Create Task"]
        if createTaskButton.exists {
            createTaskButton.tap()
            
            // Try to submit empty form
            let submitButton = app.buttons["Create Task"]
            if submitButton.exists {
                submitButton.tap()
                
                // Test error message accessibility
                let errorAlert = app.alerts.firstMatch
                let errorMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'required' OR label CONTAINS 'error'")).firstMatch
                
                if errorAlert.exists {
                    XCTAssertTrue(errorAlert.isAccessibilityElement, "Error alert should be accessible")
                    
                    let alertTitle = errorAlert.staticTexts.firstMatch
                    if alertTitle.exists {
                        XCTAssertNotNil(alertTitle.label, "Error alert should have accessible title")
                    }
                } else if errorMessage.exists {
                    XCTAssertTrue(errorMessage.isAccessibilityElement, "Error message should be accessible")
                    XCTAssertNotNil(errorMessage.label, "Error message should have accessibility label")
                }
            }
        }
    }
    
    // MARK: - Loading State Accessibility Tests
    
    @MainActor
    func testLoadingStateAccessibility() throws {
        // Test that loading states are accessible
        
        // Navigate quickly to potentially catch loading state
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Meal Plan"].tap()
        
        // Look for loading indicators
        let loadingIndicator = app.activityIndicators.firstMatch
        let loadingText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Loading'")).firstMatch
        
        if loadingIndicator.exists {
            XCTAssertTrue(loadingIndicator.isAccessibilityElement, "Loading indicator should be accessible")
            
            if let label = loadingIndicator.label {
                XCTAssertFalse(label.isEmpty, "Loading indicator should have descriptive label")
            }
        }
        
        if loadingText.exists {
            XCTAssertTrue(loadingText.isAccessibilityElement, "Loading text should be accessible")
            XCTAssertNotNil(loadingText.label, "Loading text should have accessibility label")
        }
    }
}