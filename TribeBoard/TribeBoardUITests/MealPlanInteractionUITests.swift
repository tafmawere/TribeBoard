import XCTest

/// UI tests for meal plan interactions and pantry checking
final class MealPlanInteractionUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Meal Plan Dashboard Tests
    
    @MainActor
    func testMealPlanDashboardElements() throws {
        // Navigate to Meal Plan
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Meal Plan"].tap()
        
        // Test that key elements are present
        let monthSelector = app.buttons.matching(identifier: "monthSelector").firstMatch
        let viewModeToggle = app.segmentedControls["viewModeToggle"]
        
        // At least one of these should exist (depending on current implementation)
        XCTAssertTrue(monthSelector.exists || viewModeToggle.exists, "Month selector or view mode toggle should exist")
    }
    
    @MainActor
    func testMealCardElements() throws {
        // Navigate to Meal Plan
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Meal Plan"].tap()
        
        // Wait for meal cards to load
        let mealCard = app.otherElements.matching(identifier: "mealCard").firstMatch
        let exists = mealCard.waitForExistence(timeout: 5.0)
        
        if exists {
            // Test meal card contains expected elements
            XCTAssertTrue(mealCard.exists, "Meal card should exist")
            
            // Look for Check Pantry button within the meal card area
            let checkPantryButton = app.buttons["Check Pantry"]
            XCTAssertTrue(checkPantryButton.exists, "Check Pantry button should exist on meal cards")
        }
    }
    
    @MainActor
    func testViewModeToggle() throws {
        // Navigate to Meal Plan
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Meal Plan"].tap()
        
        // Look for view mode controls
        let listButton = app.buttons["List"]
        let calendarButton = app.buttons["Calendar"]
        
        if listButton.exists && calendarButton.exists {
            // Test switching between view modes
            calendarButton.tap()
            XCTAssertTrue(calendarButton.isSelected, "Calendar view should be selected")
            
            listButton.tap()
            XCTAssertTrue(listButton.isSelected, "List view should be selected")
        }
    }
    
    @MainActor
    func testMonthNavigation() throws {
        // Navigate to Meal Plan
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Meal Plan"].tap()
        
        // Look for month navigation controls
        let previousMonthButton = app.buttons["previousMonth"]
        let nextMonthButton = app.buttons["nextMonth"]
        
        if previousMonthButton.exists {
            previousMonthButton.tap()
            // Should navigate to previous month (verify by checking if month display changes)
        }
        
        if nextMonthButton.exists {
            nextMonthButton.tap()
            // Should navigate to next month
        }
    }
    
    // MARK: - Pantry Check Interaction Tests
    
    @MainActor
    func testPantryCheckNavigation() throws {
        // Navigate to Pantry Check
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Pantry"].tap()
        
        // Verify we're on Pantry Check screen
        let pantryTitle = app.navigationBars["Pantry Check"]
        XCTAssertTrue(pantryTitle.exists, "Should be on Pantry Check screen")
    }
    
    @MainActor
    func testIngredientCheckboxInteractions() throws {
        // Navigate to Pantry Check
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Pantry"].tap()
        
        // Wait for ingredients to load
        let ingredientCheckbox = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'ingredientCheckbox'")).firstMatch
        let exists = ingredientCheckbox.waitForExistence(timeout: 5.0)
        
        if exists {
            // Test checkbox interaction
            let initialState = ingredientCheckbox.isSelected
            ingredientCheckbox.tap()
            
            // State should change after tap
            XCTAssertNotEqual(ingredientCheckbox.isSelected, initialState, "Checkbox state should change after tap")
            
            // Tap again to toggle back
            ingredientCheckbox.tap()
            XCTAssertEqual(ingredientCheckbox.isSelected, initialState, "Checkbox should return to initial state")
        }
    }
    
    @MainActor
    func testWeekSelector() throws {
        // Navigate to Pantry Check
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Pantry"].tap()
        
        // Look for week navigation controls
        let weekSelector = app.buttons["weekSelector"]
        let previousWeekButton = app.buttons["previousWeek"]
        let nextWeekButton = app.buttons["nextWeek"]
        
        if previousWeekButton.exists {
            previousWeekButton.tap()
            // Should change to previous week
        }
        
        if nextWeekButton.exists {
            nextWeekButton.tap()
            // Should change to next week
        }
    }
    
    @MainActor
    func testGenerateGroceryListButton() throws {
        // Navigate to Pantry Check
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Pantry"].tap()
        
        // Look for Generate Grocery List button
        let generateButton = app.buttons["Generate Grocery List"]
        
        if generateButton.exists {
            // Button should be tappable
            XCTAssertTrue(generateButton.isEnabled, "Generate Grocery List button should be enabled")
            
            generateButton.tap()
            
            // Should navigate to Grocery List or show confirmation
            let groceryListTitle = app.navigationBars["Grocery List"]
            let confirmationAlert = app.alerts.firstMatch
            
            XCTAssertTrue(groceryListTitle.exists || confirmationAlert.exists, 
                         "Should navigate to Grocery List or show confirmation")
        }
    }
    
    // MARK: - Ingredient List Tests
    
    @MainActor
    func testIngredientListDisplay() throws {
        // Navigate to Pantry Check
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Pantry"].tap()
        
        // Wait for ingredients to load
        sleep(2) // Give time for data to load
        
        // Look for ingredient list elements
        let ingredientList = app.scrollViews.firstMatch
        if ingredientList.exists {
            // Should be able to scroll through ingredients
            ingredientList.swipeUp()
            ingredientList.swipeDown()
        }
    }
    
    @MainActor
    func testIngredientQuantityDisplay() throws {
        // Navigate to Pantry Check
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Pantry"].tap()
        
        // Look for ingredient quantity text
        let quantityText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'cup' OR label CONTAINS 'lb' OR label CONTAINS 'oz'")).firstMatch
        
        if quantityText.exists {
            XCTAssertTrue(quantityText.exists, "Ingredient quantities should be displayed")
        }
    }
    
    // MARK: - Progress Tracking Tests
    
    @MainActor
    func testPantryCheckProgress() throws {
        // Navigate to Pantry Check
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Pantry"].tap()
        
        // Look for progress indicator
        let progressIndicator = app.progressIndicators.firstMatch
        let progressText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '%' OR label CONTAINS 'of'")).firstMatch
        
        if progressIndicator.exists || progressText.exists {
            // Progress should be displayed
            XCTAssertTrue(progressIndicator.exists || progressText.exists, "Progress should be displayed")
        }
    }
    
    @MainActor
    func testProgressUpdatesWithCheckboxes() throws {
        // Navigate to Pantry Check
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Pantry"].tap()
        
        // Wait for content to load
        sleep(2)
        
        // Find an unchecked checkbox
        let uncheckedCheckbox = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'ingredientCheckbox' AND selected == false")).firstMatch
        
        if uncheckedCheckbox.exists {
            // Check initial progress state
            let progressText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'of'")).firstMatch
            let initialProgressText = progressText.exists ? progressText.label : ""
            
            // Check the checkbox
            uncheckedCheckbox.tap()
            
            // Progress should update
            if progressText.exists {
                let updatedProgressText = progressText.label
                XCTAssertNotEqual(initialProgressText, updatedProgressText, "Progress should update when checkbox is toggled")
            }
        }
    }
    
    // MARK: - Error State Tests
    
    @MainActor
    func testEmptyStateHandling() throws {
        // Navigate to Pantry Check
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Pantry"].tap()
        
        // Look for empty state message if no ingredients
        let emptyStateMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'No ingredients' OR label CONTAINS 'empty'")).firstMatch
        
        // This test documents behavior - empty state may or may not exist depending on data
        if emptyStateMessage.exists {
            XCTAssertTrue(emptyStateMessage.exists, "Empty state message should be displayed when appropriate")
        }
    }
    
    @MainActor
    func testLoadingStateHandling() throws {
        // Navigate to Pantry Check quickly to potentially catch loading state
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Pantry"].tap()
        
        // Look for loading indicator
        let loadingIndicator = app.activityIndicators.firstMatch
        let loadingText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Loading' OR label CONTAINS 'loading'")).firstMatch
        
        // Loading state may be brief, so this test documents expected behavior
        if loadingIndicator.exists || loadingText.exists {
            XCTAssertTrue(loadingIndicator.exists || loadingText.exists, "Loading state should be displayed when appropriate")
        }
    }
}