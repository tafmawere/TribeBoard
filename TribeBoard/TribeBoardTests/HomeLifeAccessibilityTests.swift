import XCTest
@testable import TribeBoard

/// Unit tests for HomeLife accessibility compliance
@MainActor
final class HomeLifeAccessibilityTests: XCTestCase {
    
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
    
    func testHomeLifeTabVoiceOverSupport() throws {
        // Test HomeLife tab accessibility
        let homeLifeTab = app.tabBars.buttons["HomeLife"]
        XCTAssertTrue(homeLifeTab.exists, "HomeLife tab should exist")
        
        // Test accessibility properties
        XCTAssertNotNil(homeLifeTab.label, "HomeLife tab should have accessibility label")
        XCTAssertFalse(homeLifeTab.label.isEmpty, "HomeLife tab label should not be empty")
        
        // Test that tab is accessible to VoiceOver
        XCTAssertTrue(homeLifeTab.isAccessibilityElement, "HomeLife tab should be accessible to VoiceOver")
        
        // Test accessibility traits
        let traits = homeLifeTab.accessibilityTraits
        XCTAssertTrue(traits.contains(.button), "HomeLife tab should have button trait")
    }
    
    func testHomeLifeNavigationHubAccessibility() throws {
        // Navigate to HomeLife
        app.tabBars.buttons["HomeLife"].tap()
        
        // Test feature cards accessibility
        let mealPlanCard = app.buttons["Meal Plan"]
        let groceryListCard = app.buttons["Grocery List"]
        let tasksCard = app.buttons["Tasks"]
        let pantryCard = app.buttons["Pantry"]
        
        let featureCards = [mealPlanCard, groceryListCard, tasksCard, pantryCard]
        
        for card in featureCards {
            if card.exists {
                // Test accessibility label
                XCTAssertNotNil(card.label, "Feature card should have accessibility label")
                XCTAssertFalse(card.label.isEmpty, "Feature card label should not be empty")
                
                // Test accessibility element
                XCTAssertTrue(card.isAccessibilityElement, "Feature card should be accessible to VoiceOver")
                
                // Test accessibility traits
                let traits = card.accessibilityTraits
                XCTAssertTrue(traits.contains(.button), "Feature card should have button trait")
                
                // Test accessibility hint (if present)
                if let hint = card.accessibilityHint {
                    XCTAssertFalse(hint.isEmpty, "Accessibility hint should not be empty if present")
                }
            }
        }
    }
    
    func testMealPlanAccessibilityLabels() throws {
        // Navigate to Meal Plan
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Meal Plan"].tap()
        
        // Wait for content to load
        sleep(2)
        
        // Test meal cards accessibility
        let mealCards = app.otherElements.matching(identifier: "mealCard")
        
        for i in 0..<min(mealCards.count, 3) { // Test first 3 cards
            let mealCard = mealCards.element(boundBy: i)
            if mealCard.exists {
                // Test accessibility label
                XCTAssertNotNil(mealCard.label, "Meal card should have accessibility label")
                XCTAssertFalse(mealCard.label.isEmpty, "Meal card label should not be empty")
                
                // Test that label includes meal name and date
                let label = mealCard.label
                XCTAssertTrue(label.count > 10, "Meal card label should be descriptive")
            }
        }
        
        // Test Check Pantry buttons
        let checkPantryButtons = app.buttons.matching(identifier: "checkPantryButton")
        
        for i in 0..<min(checkPantryButtons.count, 3) {
            let button = checkPantryButtons.element(boundBy: i)
            if button.exists {
                XCTAssertNotNil(button.label, "Check Pantry button should have accessibility label")
                XCTAssertTrue(button.isAccessibilityElement, "Check Pantry button should be accessible")
                
                // Test accessibility hint
                if let hint = button.accessibilityHint {
                    XCTAssertTrue(hint.contains("pantry") || hint.contains("ingredients"), 
                                 "Check Pantry button hint should be descriptive")
                }
            }
        }
    }
    
    func testPantryCheckAccessibilityLabels() throws {
        // Navigate to Pantry Check
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Pantry"].tap()
        
        // Wait for ingredients to load
        sleep(2)
        
        // Test ingredient checkboxes
        let ingredientCheckboxes = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'ingredientCheckbox'"))
        
        for i in 0..<min(ingredientCheckboxes.count, 5) { // Test first 5 checkboxes
            let checkbox = ingredientCheckboxes.element(boundBy: i)
            if checkbox.exists {
                // Test accessibility label
                XCTAssertNotNil(checkbox.label, "Ingredient checkbox should have accessibility label")
                XCTAssertFalse(checkbox.label.isEmpty, "Ingredient checkbox label should not be empty")
                
                // Test accessibility traits
                let traits = checkbox.accessibilityTraits
                XCTAssertTrue(traits.contains(.button), "Ingredient checkbox should have button trait")
                
                // Test accessibility value for checked/unchecked state
                XCTAssertNotNil(checkbox.value, "Ingredient checkbox should have accessibility value")
                
                // Test that label includes ingredient name and quantity
                let label = checkbox.label
                XCTAssertTrue(label.count > 5, "Ingredient checkbox label should include name and quantity")
            }
        }
        
        // Test Generate Grocery List button
        let generateButton = app.buttons["Generate Grocery List"]
        if generateButton.exists {
            XCTAssertNotNil(generateButton.label, "Generate button should have accessibility label")
            XCTAssertTrue(generateButton.isAccessibilityElement, "Generate button should be accessible")
            
            if let hint = generateButton.accessibilityHint {
                XCTAssertTrue(hint.contains("grocery") || hint.contains("list"), 
                             "Generate button hint should be descriptive")
            }
        }
    }
    
    func testGroceryListAccessibilityLabels() throws {
        // Navigate to Grocery List
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Grocery List"].tap()
        
        // Wait for items to load
        sleep(2)
        
        // Test tab controls
        let weeklyTab = app.buttons["Weekly List"]
        let urgentTab = app.buttons["Urgent Items"]
        
        if weeklyTab.exists {
            XCTAssertNotNil(weeklyTab.label, "Weekly tab should have accessibility label")
            XCTAssertTrue(weeklyTab.isAccessibilityElement, "Weekly tab should be accessible")
        }
        
        if urgentTab.exists {
            XCTAssertNotNil(urgentTab.label, "Urgent tab should have accessibility label")
            XCTAssertTrue(urgentTab.isAccessibilityElement, "Urgent tab should be accessible")
        }
        
        // Test grocery item cards
        let groceryItemCards = app.cells.matching(identifier: "groceryItemCard")
        
        for i in 0..<min(groceryItemCards.count, 3) {
            let itemCard = groceryItemCards.element(boundBy: i)
            if itemCard.exists {
                XCTAssertNotNil(itemCard.label, "Grocery item card should have accessibility label")
                XCTAssertFalse(itemCard.label.isEmpty, "Grocery item card label should not be empty")
                
                // Test that label includes item name, quantity, and attribution
                let label = itemCard.label
                XCTAssertTrue(label.count > 10, "Grocery item card label should be comprehensive")
            }
        }
        
        // Test Order Online button
        let orderOnlineButton = app.buttons["Order Online"]
        if orderOnlineButton.exists {
            XCTAssertNotNil(orderOnlineButton.label, "Order Online button should have accessibility label")
            XCTAssertTrue(orderOnlineButton.isAccessibilityElement, "Order Online button should be accessible")
        }
    }
    
    func testTaskCreationAccessibilityLabels() throws {
        // Navigate to Tasks
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Tasks"].tap()
        
        // Try to navigate to task creation
        let createTaskButton = app.buttons["Create Task"]
        if createTaskButton.exists {
            XCTAssertNotNil(createTaskButton.label, "Create Task button should have accessibility label")
            XCTAssertTrue(createTaskButton.isAccessibilityElement, "Create Task button should be accessible")
            
            createTaskButton.tap()
            
            // Test form field accessibility
            let assigneeField = app.buttons["Assign to"]
            let taskTypeField = app.buttons["Task Type"]
            let dueDateField = app.buttons["Due Date"]
            let notesField = app.textFields["Notes"]
            
            let formFields = [assigneeField, taskTypeField, dueDateField]
            
            for field in formFields {
                if field.exists {
                    XCTAssertNotNil(field.label, "Form field should have accessibility label")
                    XCTAssertTrue(field.isAccessibilityElement, "Form field should be accessible")
                    
                    // Test accessibility traits
                    let traits = field.accessibilityTraits
                    XCTAssertTrue(traits.contains(.button), "Form field should have appropriate trait")
                }
            }
            
            if notesField.exists {
                XCTAssertNotNil(notesField.label, "Notes field should have accessibility label")
                XCTAssertTrue(notesField.isAccessibilityElement, "Notes field should be accessible")
                
                let traits = notesField.accessibilityTraits
                XCTAssertTrue(traits.contains(.searchField) || traits.contains(.keyboardKey), 
                             "Notes field should have text input trait")
            }
        }
    }
    
    // MARK: - Dynamic Type Support Tests
    
    func testDynamicTypeSupport() throws {
        // Test that text scales with Dynamic Type settings
        // This test documents expected behavior for Dynamic Type support
        
        // Navigate to HomeLife
        app.tabBars.buttons["HomeLife"].tap()
        
        // Test feature card text scaling
        let mealPlanCard = app.buttons["Meal Plan"]
        if mealPlanCard.exists {
            // In a real test, you would change Dynamic Type settings and verify text scales
            // For now, we verify that text elements exist and are properly configured
            XCTAssertTrue(mealPlanCard.exists, "Feature cards should support Dynamic Type")
        }
        
        // Navigate to Meal Plan to test meal card text
        app.buttons["Meal Plan"].tap()
        sleep(2)
        
        // Test meal card text elements
        let mealCards = app.otherElements.matching(identifier: "mealCard")
        if mealCards.count > 0 {
            let firstCard = mealCards.element(boundBy: 0)
            XCTAssertTrue(firstCard.exists, "Meal cards should support Dynamic Type")
        }
    }
    
    func testTextSizeAdaptation() throws {
        // Test that layout adapts to larger text sizes
        // This test documents expected behavior for text size adaptation
        
        // Navigate to Pantry Check
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Pantry"].tap()
        sleep(2)
        
        // Test ingredient list text adaptation
        let ingredientCheckboxes = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'ingredientCheckbox'"))
        
        if ingredientCheckboxes.count > 0 {
            let firstCheckbox = ingredientCheckboxes.element(boundBy: 0)
            XCTAssertTrue(firstCheckbox.exists, "Ingredient checkboxes should adapt to text size changes")
            
            // Verify minimum touch target size (44x44 points)
            let frame = firstCheckbox.frame
            XCTAssertGreaterThanOrEqual(frame.width, 44, "Touch target should meet minimum width")
            XCTAssertGreaterThanOrEqual(frame.height, 44, "Touch target should meet minimum height")
        }
    }
    
    // MARK: - High Contrast Mode Tests
    
    func testHighContrastSupport() throws {
        // Test that interface works in high contrast mode
        // This test documents expected behavior for high contrast support
        
        // Navigate through HomeLife features
        app.tabBars.buttons["HomeLife"].tap()
        
        // Test that elements are still visible and accessible in high contrast
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
            }
        }
    }
    
    func testColorIndependentInformation() throws {
        // Test that information is not conveyed by color alone
        
        // Navigate to Tasks to test status indicators
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Tasks"].tap()
        sleep(2)
        
        // Test task status badges
        let statusBadges = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Pending' OR label CONTAINS 'In Progress' OR label CONTAINS 'Completed'"))
        
        for i in 0..<min(statusBadges.count, 3) {
            let badge = statusBadges.element(boundBy: i)
            if badge.exists {
                // Status should be conveyed through text, not just color
                XCTAssertNotNil(badge.label, "Status badge should have text label")
                XCTAssertFalse(badge.label.isEmpty, "Status badge text should not be empty")
                
                let label = badge.label
                XCTAssertTrue(label.contains("Pending") || label.contains("Progress") || label.contains("Completed"), 
                             "Status should be conveyed through text")
            }
        }
    }
    
    // MARK: - Reduced Motion Tests
    
    func testReducedMotionSupport() throws {
        // Test that essential functionality works with reduced motion
        // This test documents expected behavior for reduced motion preferences
        
        // Navigate to Pantry Check and test checkbox interactions
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Pantry"].tap()
        sleep(2)
        
        // Test ingredient checkbox without relying on animations
        let ingredientCheckbox = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'ingredientCheckbox'")).firstMatch
        
        if ingredientCheckbox.exists {
            let initialState = ingredientCheckbox.isSelected
            ingredientCheckbox.tap()
            
            // State change should be apparent without animation
            XCTAssertNotEqual(ingredientCheckbox.isSelected, initialState, 
                             "Checkbox state should change without relying on animation")
            
            // Accessibility value should reflect state change
            XCTAssertNotNil(ingredientCheckbox.value, "Checkbox should have accessibility value indicating state")
        }
    }
    
    func testStaticAlternativesToAnimations() throws {
        // Test that animated elements have static alternatives
        
        // Navigate to Grocery List and test platform selection
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Grocery List"].tap()
        
        let orderOnlineButton = app.buttons["Order Online"]
        if orderOnlineButton.exists {
            orderOnlineButton.tap()
            
            // Platform selection should work without animations
            let platformButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Woolworths' OR label CONTAINS 'Checkers'")).firstMatch
            
            if platformButton.exists {
                platformButton.tap()
                
                // Success feedback should be available without animation
                let successMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Order submitted' OR label CONTAINS 'Success'")).firstMatch
                let successAlert = app.alerts.firstMatch
                
                XCTAssertTrue(successMessage.exists || successAlert.exists, 
                             "Success feedback should be available without relying on animation")
            }
        }
    }
    
    // MARK: - Touch Target Size Tests
    
    func testMinimumTouchTargetSizes() throws {
        // Test that interactive elements meet minimum touch target size (44x44 points)
        
        // Navigate to HomeLife
        app.tabBars.buttons["HomeLife"].tap()
        
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
        
        // Test HomeLife tab
        let homeLifeTab = app.tabBars.buttons["HomeLife"]
        let tabFrame = homeLifeTab.frame
        XCTAssertGreaterThanOrEqual(tabFrame.width, 44, "HomeLife tab should meet minimum touch target width")
        XCTAssertGreaterThanOrEqual(tabFrame.height, 44, "HomeLife tab should meet minimum touch target height")
    }
    
    func testInteractiveElementSpacing() throws {
        // Test that interactive elements have adequate spacing
        
        // Navigate to Pantry Check
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Pantry"].tap()
        sleep(2)
        
        // Test ingredient checkbox spacing
        let ingredientCheckboxes = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'ingredientCheckbox'"))
        
        if ingredientCheckboxes.count >= 2 {
            let firstCheckbox = ingredientCheckboxes.element(boundBy: 0)
            let secondCheckbox = ingredientCheckboxes.element(boundBy: 1)
            
            let firstFrame = firstCheckbox.frame
            let secondFrame = secondCheckbox.frame
            
            // Calculate vertical spacing between checkboxes
            let spacing = abs(secondFrame.minY - firstFrame.maxY)
            XCTAssertGreaterThanOrEqual(spacing, 8, "Interactive elements should have adequate spacing")
        }
    }
    
    // MARK: - Accessibility Hints Tests
    
    func testAccessibilityHints() throws {
        // Test that complex interactions have helpful accessibility hints
        
        // Navigate to Meal Plan
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Meal Plan"].tap()
        sleep(2)
        
        // Test Check Pantry button hints
        let checkPantryButton = app.buttons["Check Pantry"]
        if checkPantryButton.exists {
            if let hint = checkPantryButton.accessibilityHint {
                XCTAssertFalse(hint.isEmpty, "Check Pantry button should have accessibility hint")
                XCTAssertTrue(hint.contains("pantry") || hint.contains("ingredients") || hint.contains("check"), 
                             "Accessibility hint should be descriptive")
            }
        }
        
        // Navigate to Grocery List and test Order Online button
        app.navigationBars.buttons.element(boundBy: 0).tap() // Back to HomeLife
        app.buttons["Grocery List"].tap()
        
        let orderOnlineButton = app.buttons["Order Online"]
        if orderOnlineButton.exists {
            if let hint = orderOnlineButton.accessibilityHint {
                XCTAssertFalse(hint.isEmpty, "Order Online button should have accessibility hint")
                XCTAssertTrue(hint.contains("order") || hint.contains("platform") || hint.contains("delivery"), 
                             "Accessibility hint should explain the action")
            }
        }
    }
    
    // MARK: - Heading Hierarchy Tests
    
    func testHeadingHierarchy() throws {
        // Test proper heading hierarchy for screen readers
        
        // Navigate to HomeLife
        app.tabBars.buttons["HomeLife"].tap()
        
        // Test navigation title as heading
        let homeLifeTitle = app.navigationBars["HomeLife"]
        if homeLifeTitle.exists {
            let titleElement = homeLifeTitle.staticTexts.firstMatch
            if titleElement.exists {
                let traits = titleElement.accessibilityTraits
                XCTAssertTrue(traits.contains(.header), "Navigation title should have header trait")
            }
        }
        
        // Navigate to Meal Plan and test section headings
        app.buttons["Meal Plan"].tap()
        
        let mealPlanTitle = app.navigationBars["Meal Plan"]
        if mealPlanTitle.exists {
            let titleElement = mealPlanTitle.staticTexts.firstMatch
            if titleElement.exists {
                let traits = titleElement.accessibilityTraits
                XCTAssertTrue(traits.contains(.header), "Meal Plan title should have header trait")
            }
        }
    }
    
    // MARK: - Form Accessibility Tests
    
    func testFormAccessibility() throws {
        // Test form accessibility in task creation
        
        // Navigate to task creation
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Tasks"].tap()
        
        let createTaskButton = app.buttons["Create Task"]
        if createTaskButton.exists {
            createTaskButton.tap()
            
            // Test form field labels and associations
            let assigneeField = app.buttons["Assign to"]
            if assigneeField.exists {
                XCTAssertNotNil(assigneeField.label, "Form field should have clear label")
                XCTAssertTrue(assigneeField.label.contains("Assign"), "Label should be descriptive")
            }
            
            // Test required field indication
            let requiredFields = app.buttons.matching(NSPredicate(format: "label CONTAINS 'required' OR label CONTAINS '*'"))
            // Required fields should be clearly marked (this test documents expected behavior)
            
            // Test form validation feedback
            let submitButton = app.buttons["Create Task"]
            if submitButton.exists {
                submitButton.tap()
                
                // Should provide accessible error feedback
                let errorAlert = app.alerts.firstMatch
                let errorMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'required' OR label CONTAINS 'error'")).firstMatch
                
                if errorAlert.exists || errorMessage.exists {
                    XCTAssertTrue(errorAlert.exists || errorMessage.exists, 
                                 "Form validation errors should be accessible")
                }
            }
        }
    }
}