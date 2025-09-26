import XCTest
@testable import TribeBoard

/// Unit tests for AppState HomeLife integration
@MainActor
final class AppStateHomeLifeTests: XCTestCase {
    
    var appState: AppState!
    
    override func setUp() {
        super.setUp()
        appState = AppState()
    }
    
    override func tearDown() {
        appState = nil
        super.tearDown()
    }
    
    // MARK: - Navigation Tests
    
    func testHomeLifeNavigationInitialState() {
        // Test initial HomeLife navigation state
        XCTAssertTrue(appState.homeLifeNavigationPath.isEmpty)
        XCTAssertEqual(appState.selectedHomeLifeTab, .mealPlan)
    }
    
    func testNavigateToHomeLifeTab() {
        // Test navigation to different HomeLife tabs
        appState.navigateToHomeLifeTab(.groceryList)
        XCTAssertEqual(appState.selectedHomeLifeTab, .groceryList)
        
        appState.navigateToHomeLifeTab(.tasks)
        XCTAssertEqual(appState.selectedHomeLifeTab, .tasks)
        
        appState.navigateToHomeLifeTab(.pantry)
        XCTAssertEqual(appState.selectedHomeLifeTab, .pantry)
    }
    
    func testResetHomeLifeNavigation() {
        // Setup navigation state
        appState.selectedHomeLifeTab = .groceryList
        appState.homeLifeNavigationPath.append("test")
        
        // Reset navigation
        appState.resetHomeLifeNavigation()
        
        // Verify reset
        XCTAssertTrue(appState.homeLifeNavigationPath.isEmpty)
        XCTAssertEqual(appState.selectedHomeLifeTab, .mealPlan)
    }
    
    // MARK: - Data Management Tests
    
    func testLoadHomeLifeMealPlan() async {
        // Test meal plan loading
        XCTAssertNil(appState.currentMealPlan)
        XCTAssertFalse(appState.homeLifeIsLoading)
        
        await appState.loadHomeLifeMealPlan()
        
        XCTAssertNotNil(appState.currentMealPlan)
        XCTAssertFalse(appState.homeLifeIsLoading)
        XCTAssertNotNil(appState.homeLifeSuccessMessage)
    }
    
    func testGenerateGroceryList() async {
        // Setup test ingredients
        let ingredients = [
            Ingredient(
                name: "Carrots",
                quantity: "2",
                unit: "cups",
                emoji: "🥕",
                isAvailableInPantry: false,
                category: .produce
            ),
            Ingredient(
                name: "Milk",
                quantity: "1",
                unit: "liter",
                emoji: "🥛",
                isAvailableInPantry: true,
                category: .dairy
            )
        ]
        
        // Test grocery list generation
        XCTAssertTrue(appState.groceryList.isEmpty)
        
        await appState.generateGroceryList(from: ingredients)
        
        // Should only add unchecked ingredients
        XCTAssertEqual(appState.groceryList.count, 1)
        XCTAssertEqual(appState.groceryList.first?.ingredient.name, "Carrots")
        XCTAssertNotNil(appState.homeLifeSuccessMessage)
    }
    
    func testAddUrgentGroceryItem() {
        // Setup test grocery item
        let ingredient = Ingredient(
            name: "Bread",
            quantity: "1",
            unit: "loaf",
            emoji: "🍞",
            category: .bakery
        )
        
        let groceryItem = GroceryItem(
            ingredient: ingredient,
            linkedMeal: nil,
            addedBy: "Test User",
            addedDate: Date(),
            isUrgent: true,
            notes: nil
        )
        
        // Test adding urgent item
        XCTAssertTrue(appState.groceryList.isEmpty)
        
        appState.addUrgentGroceryItem(groceryItem)
        
        XCTAssertEqual(appState.groceryList.count, 1)
        XCTAssertTrue(appState.groceryList.first?.isUrgent == true)
        XCTAssertNotNil(appState.homeLifeSuccessMessage)
    }
    
    func testRemoveGroceryItem() {
        // Setup test grocery item
        let ingredient = Ingredient(
            name: "Bread",
            quantity: "1",
            unit: "loaf",
            emoji: "🍞",
            category: .bakery
        )
        
        let groceryItem = GroceryItem(
            ingredient: ingredient,
            linkedMeal: nil,
            addedBy: "Test User",
            addedDate: Date(),
            isUrgent: false,
            notes: nil
        )
        
        // Add and then remove item
        appState.addUrgentGroceryItem(groceryItem)
        XCTAssertEqual(appState.groceryList.count, 1)
        
        appState.removeGroceryItem(groceryItem)
        XCTAssertTrue(appState.groceryList.isEmpty)
        XCTAssertNotNil(appState.homeLifeSuccessMessage)
    }
    
    func testCreateShoppingTask() async {
        // Setup test data
        let ingredient = Ingredient(
            name: "Milk",
            quantity: "1",
            unit: "liter",
            emoji: "🥛",
            category: .dairy
        )
        
        let groceryItem = GroceryItem(
            ingredient: ingredient,
            linkedMeal: "Breakfast",
            addedBy: "Test User",
            addedDate: Date(),
            isUrgent: false,
            notes: nil
        )
        
        appState.addUrgentGroceryItem(groceryItem)
        
        // Test task creation
        XCTAssertTrue(appState.shoppingTasks.isEmpty)
        XCTAssertEqual(appState.groceryList.count, 1)
        
        await appState.createShoppingTask(
            items: [groceryItem],
            assignedTo: "Test User",
            taskType: .shopRun,
            dueDate: Date().addingTimeInterval(3600), // 1 hour from now
            notes: "Test task",
            location: nil
        )
        
        // Verify task creation and item removal from grocery list
        XCTAssertEqual(appState.shoppingTasks.count, 1)
        XCTAssertTrue(appState.groceryList.isEmpty) // Items should be removed
        XCTAssertNotNil(appState.homeLifeSuccessMessage)
        
        let task = appState.shoppingTasks.first!
        XCTAssertEqual(task.assignedTo, "Test User")
        XCTAssertEqual(task.taskType, .shopRun)
        XCTAssertEqual(task.status, .pending)
        XCTAssertEqual(task.items.count, 1)
    }
    
    func testUpdateShoppingTaskStatus() {
        // Setup test task
        let ingredient = Ingredient(
            name: "Bread",
            quantity: "1",
            unit: "loaf",
            emoji: "🍞",
            category: .bakery
        )
        
        let groceryItem = GroceryItem(
            ingredient: ingredient,
            linkedMeal: nil,
            addedBy: "Test User",
            addedDate: Date(),
            isUrgent: false,
            notes: nil
        )
        
        let task = ShoppingTask(
            items: [groceryItem],
            assignedTo: "Test User",
            taskType: .shopRun,
            dueDate: Date(),
            notes: nil,
            location: nil,
            status: .pending,
            createdBy: "Test User"
        )
        
        appState.shoppingTasks.append(task)
        
        // Test status update
        XCTAssertEqual(appState.shoppingTasks.first?.status, .pending)
        
        appState.updateShoppingTaskStatus(task, status: .completed)
        
        XCTAssertEqual(appState.shoppingTasks.first?.status, .completed)
        XCTAssertNotNil(appState.homeLifeSuccessMessage)
    }
    
    func testLoadShoppingTasks() async {
        // Test loading shopping tasks
        XCTAssertTrue(appState.shoppingTasks.isEmpty)
        
        await appState.loadShoppingTasks()
        
        XCTAssertFalse(appState.shoppingTasks.isEmpty)
        XCTAssertFalse(appState.homeLifeIsLoading)
    }
    
    // MARK: - Error Handling Tests
    
    func testShowHomeLifeError() {
        // Test error handling
        XCTAssertNil(appState.homeLifeErrorMessage)
        
        appState.showHomeLifeError(.mealPlanLoadFailed)
        
        XCTAssertNotNil(appState.homeLifeErrorMessage)
        XCTAssertTrue(appState.homeLifeErrorMessage!.contains("meal plan"))
    }
    
    func testClearHomeLifeMessages() {
        // Setup messages
        appState.homeLifeErrorMessage = "Test error"
        appState.homeLifeSuccessMessage = "Test success"
        
        // Clear messages
        appState.clearHomeLifeMessages()
        
        XCTAssertNil(appState.homeLifeErrorMessage)
        XCTAssertNil(appState.homeLifeSuccessMessage)
    }
    
    // MARK: - State Management Tests
    
    func testResetHomeLifeData() {
        // Setup state with data
        appState.currentMealPlan = MealPlanDataProvider.mockMealPlan()
        appState.groceryList = MealPlanDataProvider.mockGroceryItems()
        appState.shoppingTasks = MealPlanDataProvider.mockShoppingTasks()
        appState.homeLifeIsLoading = true
        appState.homeLifeErrorMessage = "Test error"
        appState.selectedHomeLifeTab = .groceryList
        
        // Reset data
        appState.resetHomeLifeData()
        
        // Verify reset
        XCTAssertNil(appState.currentMealPlan)
        XCTAssertTrue(appState.groceryList.isEmpty)
        XCTAssertTrue(appState.shoppingTasks.isEmpty)
        XCTAssertFalse(appState.homeLifeIsLoading)
        XCTAssertNil(appState.homeLifeErrorMessage)
        XCTAssertEqual(appState.selectedHomeLifeTab, .mealPlan)
    }
    
    func testGetHomeLifeSummary() {
        // Setup test data
        appState.currentMealPlan = MealPlanDataProvider.mockMealPlan()
        appState.groceryList = MealPlanDataProvider.mockGroceryItems()
        appState.shoppingTasks = MealPlanDataProvider.mockShoppingTasks()
        
        // Get summary
        let summary = appState.getHomeLifeSummary()
        
        // Verify summary data
        XCTAssertGreaterThan(summary.mealPlanCount, 0)
        XCTAssertGreaterThan(summary.groceryItemCount, 0)
        XCTAssertGreaterThanOrEqual(summary.pendingTaskCount, 0)
        XCTAssertNotNil(summary.statusMessage)
    }
    
    func testValidateHomeLifeData() {
        // Test with valid data
        appState.currentMealPlan = MealPlanDataProvider.mockMealPlan()
        appState.groceryList = MealPlanDataProvider.mockGroceryItems()
        appState.shoppingTasks = MealPlanDataProvider.mockShoppingTasks()
        
        XCTAssertTrue(appState.validateHomeLifeData())
        
        // Test with invalid data (empty grocery item name)
        let invalidIngredient = Ingredient(
            name: "",
            quantity: "1",
            unit: "cup",
            emoji: "🥕",
            category: .produce
        )
        
        let invalidGroceryItem = GroceryItem(
            ingredient: invalidIngredient,
            linkedMeal: nil,
            addedBy: "Test",
            addedDate: Date(),
            isUrgent: false,
            notes: nil
        )
        
        appState.groceryList = [invalidGroceryItem]
        
        XCTAssertFalse(appState.validateHomeLifeData())
        XCTAssertNotNil(appState.homeLifeErrorMessage)
    }
    
    // MARK: - Integration Tests
    
    func testResetToInitialStateIncludesHomeLife() {
        // Setup HomeLife data
        appState.currentMealPlan = MealPlanDataProvider.mockMealPlan()
        appState.groceryList = MealPlanDataProvider.mockGroceryItems()
        appState.selectedHomeLifeTab = .tasks
        
        // Reset to initial state
        appState.resetToInitialState()
        
        // Verify HomeLife data is reset
        XCTAssertNil(appState.currentMealPlan)
        XCTAssertTrue(appState.groceryList.isEmpty)
        XCTAssertEqual(appState.selectedHomeLifeTab, .mealPlan)
    }
    
    func testHomeLifeTabSelectionCoordination() {
        // Test that HomeLife tab selection works with main navigation
        appState.selectTab(.homeLife)
        
        XCTAssertEqual(appState.selectedNavigationTab, .homeLife)
        
        // Test HomeLife sub-navigation
        appState.navigateToHomeLifeTab(.groceryList)
        
        XCTAssertEqual(appState.selectedHomeLifeTab, .groceryList)
        XCTAssertEqual(appState.selectedNavigationTab, .homeLife) // Should remain on HomeLife
    }
}