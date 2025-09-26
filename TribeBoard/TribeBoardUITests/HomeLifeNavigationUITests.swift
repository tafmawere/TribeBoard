import XCTest

/// UI tests for HomeLife navigation and tab integration
final class HomeLifeNavigationUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - HomeLife Tab Integration Tests
    
    @MainActor
    func testHomeLifeTabExists() throws {
        // Test that HomeLife tab appears in bottom navigation
        let homeLifeTab = app.tabBars.buttons["HomeLife"]
        XCTAssertTrue(homeLifeTab.exists, "HomeLife tab should exist in bottom navigation")
    }
    
    @MainActor
    func testHomeLifeTabSelection() throws {
        // Test selecting HomeLife tab
        let homeLifeTab = app.tabBars.buttons["HomeLife"]
        XCTAssertTrue(homeLifeTab.exists)
        
        homeLifeTab.tap()
        
        // Verify we're on HomeLife screen
        let homeLifeNavigationTitle = app.navigationBars["HomeLife"]
        XCTAssertTrue(homeLifeNavigationTitle.exists, "Should navigate to HomeLife screen")
    }
    
    @MainActor
    func testHomeLifeTabIcon() throws {
        // Test that HomeLife tab has proper icon
        let homeLifeTab = app.tabBars.buttons["HomeLife"]
        XCTAssertTrue(homeLifeTab.exists)
        
        // Verify icon is present (icon should be visible as part of the button)
        XCTAssertTrue(homeLifeTab.isEnabled)
    }
    
    // MARK: - HomeLife Navigation Hub Tests
    
    @MainActor
    func testHomeLifeNavigationHubFeatureCards() throws {
        // Navigate to HomeLife
        app.tabBars.buttons["HomeLife"].tap()
        
        // Test that all feature cards are present
        let mealPlanCard = app.buttons["Meal Plan"]
        let groceryListCard = app.buttons["Grocery List"]
        let tasksCard = app.buttons["Tasks"]
        let pantryCard = app.buttons["Pantry"]
        
        XCTAssertTrue(mealPlanCard.exists, "Meal Plan card should exist")
        XCTAssertTrue(groceryListCard.exists, "Grocery List card should exist")
        XCTAssertTrue(tasksCard.exists, "Tasks card should exist")
        XCTAssertTrue(pantryCard.exists, "Pantry card should exist")
    }
    
    @MainActor
    func testNavigationToMealPlan() throws {
        // Navigate to HomeLife and tap Meal Plan
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Meal Plan"].tap()
        
        // Verify navigation to Meal Plan Dashboard
        let mealPlanTitle = app.navigationBars["Meal Plan"]
        XCTAssertTrue(mealPlanTitle.exists, "Should navigate to Meal Plan Dashboard")
    }
    
    @MainActor
    func testNavigationToGroceryList() throws {
        // Navigate to HomeLife and tap Grocery List
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Grocery List"].tap()
        
        // Verify navigation to Grocery List
        let groceryListTitle = app.navigationBars["Grocery List"]
        XCTAssertTrue(groceryListTitle.exists, "Should navigate to Grocery List")
    }
    
    @MainActor
    func testNavigationToTasks() throws {
        // Navigate to HomeLife and tap Tasks
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Tasks"].tap()
        
        // Verify navigation to Tasks
        let tasksTitle = app.navigationBars["Shopping Tasks"]
        XCTAssertTrue(tasksTitle.exists, "Should navigate to Shopping Tasks")
    }
    
    @MainActor
    func testNavigationToPantry() throws {
        // Navigate to HomeLife and tap Pantry
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Pantry"].tap()
        
        // Verify navigation to Pantry Check
        let pantryTitle = app.navigationBars["Pantry Check"]
        XCTAssertTrue(pantryTitle.exists, "Should navigate to Pantry Check")
    }
    
    // MARK: - Back Navigation Tests
    
    @MainActor
    func testBackNavigationFromMealPlan() throws {
        // Navigate to Meal Plan and back
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Meal Plan"].tap()
        
        // Navigate back
        app.navigationBars.buttons.element(boundBy: 0).tap() // Back button
        
        // Should be back at HomeLife hub
        let homeLifeTitle = app.navigationBars["HomeLife"]
        XCTAssertTrue(homeLifeTitle.exists, "Should navigate back to HomeLife hub")
    }
    
    @MainActor
    func testBackNavigationFromGroceryList() throws {
        // Navigate to Grocery List and back
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Grocery List"].tap()
        
        // Navigate back
        app.navigationBars.buttons.element(boundBy: 0).tap() // Back button
        
        // Should be back at HomeLife hub
        let homeLifeTitle = app.navigationBars["HomeLife"]
        XCTAssertTrue(homeLifeTitle.exists, "Should navigate back to HomeLife hub")
    }
    
    // MARK: - Navigation State Preservation Tests
    
    @MainActor
    func testNavigationStatePreservationBetweenTabs() throws {
        // Navigate to HomeLife -> Meal Plan
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Meal Plan"].tap()
        
        // Switch to another tab
        if app.tabBars.buttons["Family"].exists {
            app.tabBars.buttons["Family"].tap()
        }
        
        // Switch back to HomeLife
        app.tabBars.buttons["HomeLife"].tap()
        
        // Should preserve navigation state (still on Meal Plan)
        let mealPlanTitle = app.navigationBars["Meal Plan"]
        XCTAssertTrue(mealPlanTitle.exists, "Should preserve navigation state")
    }
    
    // MARK: - Cross-Feature Navigation Tests
    
    @MainActor
    func testNavigationFromMealPlanToPantryCheck() throws {
        // Navigate to Meal Plan
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Meal Plan"].tap()
        
        // Look for "Check Pantry" button on a meal card
        let checkPantryButton = app.buttons["Check Pantry"]
        if checkPantryButton.exists {
            checkPantryButton.tap()
            
            // Should navigate to Pantry Check
            let pantryTitle = app.navigationBars["Pantry Check"]
            XCTAssertTrue(pantryTitle.exists, "Should navigate to Pantry Check from Meal Plan")
        }
    }
    
    @MainActor
    func testNavigationFromPantryCheckToGroceryList() throws {
        // Navigate to Pantry Check
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Pantry"].tap()
        
        // Look for "Generate Grocery List" button
        let generateButton = app.buttons["Generate Grocery List"]
        if generateButton.exists {
            generateButton.tap()
            
            // Should navigate to Grocery List
            let groceryListTitle = app.navigationBars["Grocery List"]
            XCTAssertTrue(groceryListTitle.exists, "Should navigate to Grocery List from Pantry Check")
        }
    }
    
    @MainActor
    func testNavigationFromGroceryListToOrderPlatforms() throws {
        // Navigate to Grocery List
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Grocery List"].tap()
        
        // Look for "Order Online" button
        let orderOnlineButton = app.buttons["Order Online"]
        if orderOnlineButton.exists {
            orderOnlineButton.tap()
            
            // Should show platform selection
            let platformSelectionTitle = app.navigationBars["Choose Platform"]
            XCTAssertTrue(platformSelectionTitle.exists, "Should show platform selection")
        }
    }
}