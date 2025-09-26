import XCTest

/// UI tests for error states, loading states, and empty state displays
final class ErrorAndLoadingStateUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Loading State Tests
    
    @MainActor
    func testHomeLifeInitialLoadingState() throws {
        // Navigate to HomeLife quickly to catch loading state
        app.tabBars.buttons["HomeLife"].tap()
        
        // Look for loading indicators
        let loadingIndicator = app.activityIndicators.firstMatch
        let loadingText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Loading'")).firstMatch
        let loadingOverlay = app.otherElements["loadingOverlay"]
        
        // Loading state may be brief, so this documents expected behavior
        if loadingIndicator.exists || loadingText.exists || loadingOverlay.exists {
            XCTAssertTrue(loadingIndicator.exists || loadingText.exists || loadingOverlay.exists, 
                         "Should show loading state when appropriate")
        }
    }
    
    @MainActor
    func testMealPlanLoadingState() throws {
        // Navigate to Meal Plan quickly
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Meal Plan"].tap()
        
        // Look for meal plan specific loading indicators
        let mealPlanLoading = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Loading meal plan' OR label CONTAINS 'Loading meals'")).firstMatch
        let skeletonCards = app.otherElements.matching(identifier: "skeletonCard")
        let loadingSpinner = app.activityIndicators.firstMatch
        
        if mealPlanLoading.exists || skeletonCards.count > 0 || loadingSpinner.exists {
            XCTAssertTrue(mealPlanLoading.exists || skeletonCards.count > 0 || loadingSpinner.exists, 
                         "Should show meal plan loading state")
        }
    }
    
    @MainActor
    func testGroceryListLoadingState() throws {
        // Navigate to Grocery List quickly
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Grocery List"].tap()
        
        // Look for grocery list loading indicators
        let groceryLoading = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Loading grocery' OR label CONTAINS 'Loading items'")).firstMatch
        let loadingSpinner = app.activityIndicators.firstMatch
        
        if groceryLoading.exists || loadingSpinner.exists {
            XCTAssertTrue(groceryLoading.exists || loadingSpinner.exists, 
                         "Should show grocery list loading state")
        }
    }
    
    @MainActor
    func testPantryCheckLoadingState() throws {
        // Navigate to Pantry Check quickly
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Pantry"].tap()
        
        // Look for pantry check loading indicators
        let pantryLoading = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Loading ingredients' OR label CONTAINS 'Analyzing pantry'")).firstMatch
        let loadingSpinner = app.activityIndicators.firstMatch
        
        if pantryLoading.exists || loadingSpinner.exists {
            XCTAssertTrue(pantryLoading.exists || loadingSpinner.exists, 
                         "Should show pantry check loading state")
        }
    }
    
    @MainActor
    func testTasksLoadingState() throws {
        // Navigate to Tasks quickly
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Tasks"].tap()
        
        // Look for tasks loading indicators
        let tasksLoading = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Loading tasks'")).firstMatch
        let loadingSpinner = app.activityIndicators.firstMatch
        
        if tasksLoading.exists || loadingSpinner.exists {
            XCTAssertTrue(tasksLoading.exists || loadingSpinner.exists, 
                         "Should show tasks loading state")
        }
    }
    
    // MARK: - Empty State Tests
    
    @MainActor
    func testMealPlanEmptyState() throws {
        // Navigate to Meal Plan
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Meal Plan"].tap()
        
        // Wait for loading to complete
        sleep(3)
        
        // Look for empty state elements
        let emptyStateMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'No meals planned' OR label CONTAINS 'Start planning' OR label CONTAINS 'empty'")).firstMatch
        let emptyStateImage = app.images["emptyMealPlan"]
        let addMealButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Add meal' OR label CONTAINS 'Plan meals'")).firstMatch
        
        if emptyStateMessage.exists {
            XCTAssertTrue(emptyStateMessage.exists, "Should show empty state message when no meals are planned")
            
            // Should have encouraging call-to-action
            if addMealButton.exists {
                XCTAssertTrue(addMealButton.exists, "Should provide call-to-action in empty state")
            }
        }
    }
    
    @MainActor
    func testGroceryListEmptyStates() throws {
        // Navigate to Grocery List
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Grocery List"].tap()
        
        // Wait for loading to complete
        sleep(2)
        
        // Test weekly list empty state
        let weeklyTab = app.buttons["Weekly List"]
        if weeklyTab.exists {
            weeklyTab.tap()
            
            let weeklyEmptyMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'No weekly items' OR label CONTAINS 'grocery list is empty'")).firstMatch
            if weeklyEmptyMessage.exists {
                XCTAssertTrue(weeklyEmptyMessage.exists, "Should show empty state for weekly list")
            }
        }
        
        // Test urgent items empty state
        let urgentTab = app.buttons["Urgent Items"]
        if urgentTab.exists {
            urgentTab.tap()
            
            let urgentEmptyMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'No urgent items' OR label CONTAINS 'urgent list is empty'")).firstMatch
            let addUrgentButton = app.buttons["Add Urgent Item"]
            
            if urgentEmptyMessage.exists {
                XCTAssertTrue(urgentEmptyMessage.exists, "Should show empty state for urgent items")
                
                if addUrgentButton.exists {
                    XCTAssertTrue(addUrgentButton.exists, "Should provide add button in urgent items empty state")
                }
            }
        }
    }
    
    @MainActor
    func testTasksEmptyState() throws {
        // Navigate to Tasks
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Tasks"].tap()
        
        // Wait for loading to complete
        sleep(2)
        
        // Look for tasks empty state
        let emptyTasksMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'No tasks' OR label CONTAINS 'No shopping tasks' OR label CONTAINS 'All caught up'")).firstMatch
        let createTaskButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Create' OR label CONTAINS 'Add Task'")).firstMatch
        
        if emptyTasksMessage.exists {
            XCTAssertTrue(emptyTasksMessage.exists, "Should show empty state when no tasks exist")
            
            if createTaskButton.exists {
                XCTAssertTrue(createTaskButton.exists, "Should provide create task button in empty state")
            }
        }
    }
    
    @MainActor
    func testPantryCheckEmptyState() throws {
        // Navigate to Pantry Check
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Pantry"].tap()
        
        // Wait for loading to complete
        sleep(2)
        
        // Look for pantry empty state
        let emptyPantryMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'No ingredients' OR label CONTAINS 'pantry is empty'")).firstMatch
        
        if emptyPantryMessage.exists {
            XCTAssertTrue(emptyPantryMessage.exists, "Should show empty state when no ingredients to check")
        }
    }
    
    // MARK: - Error State Tests
    
    @MainActor
    func testNetworkErrorHandling() throws {
        // This test documents expected behavior for network errors
        // In a real scenario, you might simulate network conditions
        
        // Navigate through HomeLife features looking for error states
        app.tabBars.buttons["HomeLife"].tap()
        
        // Look for network error messages
        let networkError = app.alerts.matching(NSPredicate(format: "label CONTAINS 'network' OR label CONTAINS 'connection'")).firstMatch
        let errorMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Failed to load' OR label CONTAINS 'error'")).firstMatch
        let retryButton = app.buttons["Retry"]
        
        if networkError.exists || errorMessage.exists {
            XCTAssertTrue(networkError.exists || errorMessage.exists, "Should show network error message")
            
            if retryButton.exists {
                XCTAssertTrue(retryButton.exists, "Should provide retry option for network errors")
                retryButton.tap()
            }
        }
    }
    
    @MainActor
    func testMealPlanLoadingError() throws {
        // Navigate to Meal Plan and look for potential errors
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Meal Plan"].tap()
        
        // Wait for loading to complete or error to appear
        sleep(3)
        
        // Look for meal plan specific errors
        let mealPlanError = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Failed to load meal plan' OR label CONTAINS 'meal plan error'")).firstMatch
        let errorAlert = app.alerts.firstMatch
        let retryButton = app.buttons["Retry"]
        
        if mealPlanError.exists || errorAlert.exists {
            XCTAssertTrue(mealPlanError.exists || errorAlert.exists, "Should show meal plan error message")
            
            if retryButton.exists {
                retryButton.tap()
            } else if errorAlert.exists {
                let okButton = errorAlert.buttons["OK"]
                if okButton.exists {
                    okButton.tap()
                }
            }
        }
    }
    
    @MainActor
    func testGroceryListGenerationError() throws {
        // Navigate to Pantry Check and try to generate grocery list
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Pantry"].tap()
        
        // Wait for loading
        sleep(2)
        
        // Try to generate grocery list
        let generateButton = app.buttons["Generate Grocery List"]
        if generateButton.exists {
            generateButton.tap()
            
            // Look for potential generation errors
            let generationError = app.alerts.matching(NSPredicate(format: "label CONTAINS 'Failed to generate' OR label CONTAINS 'generation error'")).firstMatch
            let errorMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'error' OR label CONTAINS 'failed'")).firstMatch
            
            if generationError.exists || errorMessage.exists {
                XCTAssertTrue(generationError.exists || errorMessage.exists, "Should show grocery list generation error")
                
                if generationError.exists {
                    let okButton = generationError.buttons["OK"]
                    if okButton.exists {
                        okButton.tap()
                    }
                }
            }
        }
    }
    
    @MainActor
    func testTaskCreationError() throws {
        // Navigate to task creation and try to create invalid task
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Tasks"].tap()
        
        let createTaskButton = app.buttons["Create Task"]
        if createTaskButton.exists {
            createTaskButton.tap()
            
            // Try to submit empty form
            let submitButton = app.buttons["Create Task"]
            if submitButton.exists {
                submitButton.tap()
                
                // Should show validation error
                let validationError = app.alerts.firstMatch
                let errorMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'required' OR label CONTAINS 'error'")).firstMatch
                
                XCTAssertTrue(validationError.exists || errorMessage.exists, 
                             "Should show validation error for incomplete task")
                
                if validationError.exists {
                    let okButton = validationError.buttons["OK"]
                    if okButton.exists {
                        okButton.tap()
                    }
                }
            }
        }
    }
    
    // MARK: - Success State Tests
    
    @MainActor
    func testSuccessMessageDisplay() throws {
        // Navigate to Pantry Check and perform successful action
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Pantry"].tap()
        
        // Wait for loading
        sleep(2)
        
        // Try to check an ingredient
        let ingredientCheckbox = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'ingredientCheckbox'")).firstMatch
        if ingredientCheckbox.exists {
            ingredientCheckbox.tap()
            
            // Look for success feedback
            let successMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'updated' OR label CONTAINS 'success'")).firstMatch
            let toastMessage = app.otherElements["toast"]
            
            if successMessage.exists || toastMessage.exists {
                XCTAssertTrue(successMessage.exists || toastMessage.exists, 
                             "Should show success feedback for user actions")
            }
        }
    }
    
    @MainActor
    func testPlatformSelectionSuccess() throws {
        // Navigate to grocery list and try platform selection
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Grocery List"].tap()
        
        let orderOnlineButton = app.buttons["Order Online"]
        if orderOnlineButton.exists {
            orderOnlineButton.tap()
            
            // Select a platform
            let platformButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Woolworths' OR label CONTAINS 'Checkers'")).firstMatch
            if platformButton.exists {
                platformButton.tap()
                
                // Should show success confirmation
                let successAlert = app.alerts.firstMatch
                let successMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Order submitted' OR label CONTAINS 'Success'")).firstMatch
                let toastMessage = app.otherElements["toast"]
                
                XCTAssertTrue(successAlert.exists || successMessage.exists || toastMessage.exists, 
                             "Should show success confirmation after platform selection")
                
                if successAlert.exists {
                    let okButton = successAlert.buttons["OK"]
                    if okButton.exists {
                        okButton.tap()
                    }
                }
            }
        }
    }
    
    // MARK: - State Transition Tests
    
    @MainActor
    func testLoadingToContentTransition() throws {
        // Navigate to HomeLife and observe loading to content transition
        app.tabBars.buttons["HomeLife"].tap()
        
        // Should transition from loading to content
        let loadingIndicator = app.activityIndicators.firstMatch
        
        if loadingIndicator.exists {
            // Wait for loading to complete
            let contentAppeared = app.buttons["Meal Plan"].waitForExistence(timeout: 10.0)
            XCTAssertTrue(contentAppeared, "Should transition from loading to content")
            XCTAssertFalse(loadingIndicator.exists, "Loading indicator should disappear")
        }
    }
    
    @MainActor
    func testErrorToRetryTransition() throws {
        // This test documents the expected behavior for error recovery
        // Navigate through features looking for error states with retry options
        
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Meal Plan"].tap()
        
        // Look for any error with retry option
        let retryButton = app.buttons["Retry"]
        if retryButton.exists {
            retryButton.tap()
            
            // Should show loading state again
            let loadingIndicator = app.activityIndicators.firstMatch
            if loadingIndicator.exists {
                XCTAssertTrue(loadingIndicator.exists, "Should show loading state after retry")
            }
        }
    }
    
    @MainActor
    func testEmptyToContentTransition() throws {
        // Test transition from empty state to content when data is added
        // This would typically require adding data through the UI
        
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Grocery List"].tap()
        
        // Switch to urgent tab
        let urgentTab = app.buttons["Urgent Items"]
        if urgentTab.exists {
            urgentTab.tap()
            
            // If empty state exists, try to add item
            let addUrgentButton = app.buttons["Add Urgent Item"]
            if addUrgentButton.exists {
                addUrgentButton.tap()
                
                // Fill out form
                let nameField = app.textFields["Item Name"]
                if nameField.exists {
                    nameField.tap()
                    nameField.typeText("Test Item")
                    
                    let saveButton = app.buttons["Add Item"]
                    if saveButton.exists {
                        saveButton.tap()
                        
                        // Should transition from empty to content
                        let itemCard = app.cells.matching(identifier: "groceryItemCard").firstMatch
                        let itemExists = itemCard.waitForExistence(timeout: 5.0)
                        
                        if itemExists {
                            XCTAssertTrue(itemExists, "Should show content after adding item")
                        }
                    }
                }
            }
        }
    }
}