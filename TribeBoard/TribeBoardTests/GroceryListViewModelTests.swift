import XCTest
@testable import TribeBoard

/// Unit tests for GroceryListViewModel
@MainActor
final class GroceryListViewModelTests: XCTestCase {
    
    var viewModel: GroceryListViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = GroceryListViewModel()
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        XCTAssertTrue(viewModel.groceryItems.isEmpty)
        XCTAssertEqual(viewModel.selectedTab, .weekly)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.successMessage)
        XCTAssertEqual(viewModel.newUrgentItem.name, "")
        XCTAssertFalse(viewModel.showAddUrgentItemSheet)
        XCTAssertNil(viewModel.selectedPlatform)
        XCTAssertFalse(viewModel.showPlatformSelection)
        XCTAssertTrue(viewModel.availablePlatforms.isEmpty)
    }
    
    // MARK: - Computed Properties Tests
    
    func testWeeklyGroceryItems() {
        let weeklyItem = createMockGroceryItem(name: "Weekly Item", isUrgent: false)
        let urgentItem = createMockGroceryItem(name: "Urgent Item", isUrgent: true)
        
        viewModel.groceryItems = [urgentItem, weeklyItem]
        
        let weeklyItems = viewModel.weeklyGroceryItems
        XCTAssertEqual(weeklyItems.count, 1)
        XCTAssertEqual(weeklyItems.first?.ingredient.name, "Weekly Item")
        XCTAssertFalse(weeklyItems.first?.isUrgent ?? true)
    }
    
    func testUrgentGroceryItems() {
        let weeklyItem = createMockGroceryItem(name: "Weekly Item", isUrgent: false)
        let urgentItem1 = createMockGroceryItem(name: "Urgent Item 1", isUrgent: true)
        let urgentItem2 = createMockGroceryItem(name: "Urgent Item 2", isUrgent: true, addedDate: Date().addingTimeInterval(-3600))
        
        viewModel.groceryItems = [weeklyItem, urgentItem1, urgentItem2]
        
        let urgentItems = viewModel.urgentGroceryItems
        XCTAssertEqual(urgentItems.count, 2)
        XCTAssertTrue(urgentItems.allSatisfy { $0.isUrgent })
        
        // Should be sorted by added date (newest first)
        XCTAssertGreaterThanOrEqual(urgentItems[0].addedDate, urgentItems[1].addedDate)
    }
    
    func testItemsForSelectedTab() {
        let weeklyItem = createMockGroceryItem(name: "Weekly Item", isUrgent: false)
        let urgentItem = createMockGroceryItem(name: "Urgent Item", isUrgent: true)
        
        viewModel.groceryItems = [weeklyItem, urgentItem]
        
        // Test weekly tab
        viewModel.selectedTab = .weekly
        let weeklyTabItems = viewModel.itemsForSelectedTab
        XCTAssertEqual(weeklyTabItems.count, 1)
        XCTAssertFalse(weeklyTabItems.first?.isUrgent ?? true)
        
        // Test urgent tab
        viewModel.selectedTab = .urgent
        let urgentTabItems = viewModel.itemsForSelectedTab
        XCTAssertEqual(urgentTabItems.count, 1)
        XCTAssertTrue(urgentTabItems.first?.isUrgent ?? false)
    }
    
    func testItemCounts() {
        let weeklyItem1 = createMockGroceryItem(name: "Weekly 1", isUrgent: false)
        let weeklyItem2 = createMockGroceryItem(name: "Weekly 2", isUrgent: false)
        let urgentItem = createMockGroceryItem(name: "Urgent", isUrgent: true)
        
        viewModel.groceryItems = [weeklyItem1, weeklyItem2, urgentItem]
        
        XCTAssertEqual(viewModel.totalItemCount, 3)
        XCTAssertEqual(viewModel.weeklyItemCount, 2)
        XCTAssertEqual(viewModel.urgentItemCount, 1)
    }
    
    func testHasItemsToOrder() {
        // Test with no items
        XCTAssertFalse(viewModel.hasItemsToOrder)
        
        // Test with items
        viewModel.groceryItems = [createMockGroceryItem()]
        XCTAssertTrue(viewModel.hasItemsToOrder)
    }
    
    func testEstimatedCost() {
        let weeklyItem = createMockGroceryItem(isUrgent: false)
        let urgentItem = createMockGroceryItem(isUrgent: true)
        
        viewModel.groceryItems = [weeklyItem, urgentItem]
        
        let cost = viewModel.estimatedTotalCost
        XCTAssertGreaterThan(cost, 0)
        
        let formattedCost = viewModel.formattedEstimatedCost
        XCTAssertTrue(formattedCost.hasPrefix("R"))
        XCTAssertTrue(formattedCost.contains(String(format: "%.0f", cost)))
    }
    
    // MARK: - Data Loading Tests
    
    func testLoadGroceryItems() async {
        XCTAssertTrue(viewModel.groceryItems.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        
        await viewModel.loadGroceryItems()
        
        XCTAssertFalse(viewModel.groceryItems.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.successMessage)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testLoadGroceryItemsSetsLoadingState() async {
        let loadingExpectation = expectation(description: "Loading should complete")
        
        Task {
            await viewModel.loadGroceryItems()
            loadingExpectation.fulfill()
        }
        
        // Give a moment for loading state to be set
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        await fulfillment(of: [loadingExpectation], timeout: 2.0)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    // MARK: - Grocery List Generation Tests
    
    func testGenerateGroceryListFromIngredients() async {
        let availableIngredient = Ingredient(
            name: "Available Item",
            quantity: "1",
            unit: "cup",
            emoji: "✅",
            isAvailableInPantry: true,
            category: .pantry
        )
        
        let missingIngredient = Ingredient(
            name: "Missing Item",
            quantity: "2",
            unit: "cups",
            emoji: "❌",
            isAvailableInPantry: false,
            category: .produce
        )
        
        let ingredients = [availableIngredient, missingIngredient]
        let linkedMeals = ["Missing Item": "Dinner Recipe"]
        
        XCTAssertTrue(viewModel.groceryItems.isEmpty)
        
        await viewModel.generateGroceryList(from: ingredients, linkedMeals: linkedMeals)
        
        // Should only add missing ingredients
        XCTAssertEqual(viewModel.groceryItems.count, 1)
        XCTAssertEqual(viewModel.groceryItems.first?.ingredient.name, "Missing Item")
        XCTAssertEqual(viewModel.groceryItems.first?.linkedMeal, "Dinner Recipe")
        XCTAssertEqual(viewModel.groceryItems.first?.addedBy, "System")
        XCTAssertFalse(viewModel.groceryItems.first?.isUrgent ?? true)
        XCTAssertEqual(viewModel.selectedTab, .weekly) // Should switch to weekly tab
        XCTAssertNotNil(viewModel.successMessage)
    }
    
    func testGenerateGroceryListRemovesExistingSystemItems() async {
        // Add existing system-generated item
        let existingSystemItem = createMockGroceryItem(addedBy: "System", isUrgent: false)
        let existingUserItem = createMockGroceryItem(addedBy: "User", isUrgent: true)
        
        viewModel.groceryItems = [existingSystemItem, existingUserItem]
        
        let missingIngredient = Ingredient(
            name: "New Missing Item",
            quantity: "1",
            unit: "cup",
            emoji: "🆕",
            isAvailableInPantry: false,
            category: .produce
        )
        
        await viewModel.generateGroceryList(from: [missingIngredient])
        
        // Should remove existing system items but keep user items
        XCTAssertEqual(viewModel.groceryItems.count, 2) // User item + new item
        XCTAssertTrue(viewModel.groceryItems.contains { $0.addedBy == "User" && $0.isUrgent })
        XCTAssertTrue(viewModel.groceryItems.contains { $0.ingredient.name == "New Missing Item" })
        XCTAssertFalse(viewModel.groceryItems.contains { $0.id == existingSystemItem.id })
    }
    
    // MARK: - Urgent Item Management Tests
    
    func testAddUrgentItemWithValidData() {
        viewModel.newUrgentItem.name = "Urgent Bread"
        viewModel.newUrgentItem.quantity = "2"
        viewModel.newUrgentItem.unit = "loaves"
        viewModel.newUrgentItem.notes = "For dinner party"
        
        XCTAssertTrue(viewModel.groceryItems.isEmpty)
        
        viewModel.addUrgentItem()
        
        XCTAssertEqual(viewModel.groceryItems.count, 1)
        let addedItem = viewModel.groceryItems.first!
        XCTAssertEqual(addedItem.ingredient.name, "Urgent Bread")
        XCTAssertEqual(addedItem.ingredient.quantity, "2")
        XCTAssertEqual(addedItem.ingredient.unit, "loaves")
        XCTAssertTrue(addedItem.isUrgent)
        XCTAssertEqual(addedItem.notes, "For dinner party")
        XCTAssertEqual(viewModel.selectedTab, .urgent) // Should switch to urgent tab
        XCTAssertNotNil(viewModel.successMessage)
        XCTAssertFalse(viewModel.showAddUrgentItemSheet)
        
        // Form should be reset
        XCTAssertTrue(viewModel.newUrgentItem.name.isEmpty)
    }
    
    func testAddUrgentItemWithEmptyName() {
        viewModel.newUrgentItem.name = ""
        
        viewModel.addUrgentItem()
        
        XCTAssertTrue(viewModel.groceryItems.isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage!.contains("required"))
    }
    
    func testAddUrgentItemWithWhitespaceOnlyName() {
        viewModel.newUrgentItem.name = "   \n\t   "
        
        viewModel.addUrgentItem()
        
        XCTAssertTrue(viewModel.groceryItems.isEmpty)
        XCTAssertNotNil(viewModel.errorMessage)
    }
    
    func testNewUrgentItemValidation() {
        // Test invalid item
        viewModel.newUrgentItem.name = ""
        XCTAssertFalse(viewModel.newUrgentItem.isValid)
        
        // Test valid item
        viewModel.newUrgentItem.name = "Valid Item"
        XCTAssertTrue(viewModel.newUrgentItem.isValid)
        
        // Test whitespace-only name
        viewModel.newUrgentItem.name = "   "
        XCTAssertFalse(viewModel.newUrgentItem.isValid)
    }
    
    // MARK: - Item Management Tests
    
    func testRemoveItem() {
        let item1 = createMockGroceryItem(name: "Item 1")
        let item2 = createMockGroceryItem(name: "Item 2")
        
        viewModel.groceryItems = [item1, item2]
        
        viewModel.removeItem(item1)
        
        XCTAssertEqual(viewModel.groceryItems.count, 1)
        XCTAssertEqual(viewModel.groceryItems.first?.ingredient.name, "Item 2")
        XCTAssertNotNil(viewModel.successMessage)
    }
    
    func testToggleItemCompletion() {
        let item = createMockGroceryItem(name: "Test Item")
        viewModel.groceryItems = [item]
        
        XCTAssertFalse(viewModel.groceryItems.first?.isCompleted ?? true)
        
        viewModel.toggleItemCompletion(item)
        
        XCTAssertTrue(viewModel.groceryItems.first?.isCompleted ?? false)
        
        // Toggle back
        viewModel.toggleItemCompletion(viewModel.groceryItems.first!)
        XCTAssertFalse(viewModel.groceryItems.first?.isCompleted ?? true)
    }
    
    func testToggleItemCompletionWithNonExistentItem() {
        let existingItem = createMockGroceryItem(name: "Existing")
        let nonExistentItem = createMockGroceryItem(name: "Non-existent")
        
        viewModel.groceryItems = [existingItem]
        
        // Should not crash or change anything
        viewModel.toggleItemCompletion(nonExistentItem)
        XCTAssertEqual(viewModel.groceryItems.count, 1)
        XCTAssertFalse(viewModel.groceryItems.first?.isCompleted ?? true)
    }
    
    // MARK: - Tab Management Tests
    
    func testSwitchTab() {
        XCTAssertEqual(viewModel.selectedTab, .weekly)
        
        viewModel.switchTab(to: .urgent)
        XCTAssertEqual(viewModel.selectedTab, .urgent)
        
        viewModel.switchTab(to: .weekly)
        XCTAssertEqual(viewModel.selectedTab, .weekly)
    }
    
    // MARK: - Platform Management Tests
    
    func testLoadGroceryPlatforms() {
        XCTAssertTrue(viewModel.availablePlatforms.isEmpty)
        
        viewModel.loadGroceryPlatforms()
        
        XCTAssertFalse(viewModel.availablePlatforms.isEmpty)
    }
    
    func testSelectPlatform() {
        viewModel.loadGroceryPlatforms()
        let platform = viewModel.availablePlatforms.first!
        
        viewModel.selectPlatform(platform)
        
        XCTAssertEqual(viewModel.selectedPlatform?.id, platform.id)
        XCTAssertFalse(viewModel.showPlatformSelection)
        XCTAssertNotNil(viewModel.successMessage)
        XCTAssertTrue(viewModel.successMessage!.contains(platform.name))
    }
    
    func testShowPlatformSelectionSheet() {
        XCTAssertFalse(viewModel.showPlatformSelection)
        XCTAssertTrue(viewModel.availablePlatforms.isEmpty)
        
        viewModel.showPlatformSelectionSheet()
        
        XCTAssertTrue(viewModel.showPlatformSelection)
        XCTAssertFalse(viewModel.availablePlatforms.isEmpty)
    }
    
    func testShowAddUrgentItemForm() {
        // Setup some data in the form
        viewModel.newUrgentItem.name = "Test"
        viewModel.newUrgentItem.notes = "Test notes"
        
        viewModel.showAddUrgentItemForm()
        
        XCTAssertTrue(viewModel.showAddUrgentItemSheet)
        // Form should be reset
        XCTAssertTrue(viewModel.newUrgentItem.name.isEmpty)
        XCTAssertTrue(viewModel.newUrgentItem.notes.isEmpty)
    }
    
    // MARK: - Filtering and Grouping Tests
    
    func testFilterItemsByCategory() {
        let produceItem = createMockGroceryItem(name: "Carrot", category: .produce)
        let dairyItem = createMockGroceryItem(name: "Milk", category: .dairy)
        let pantryItem = createMockGroceryItem(name: "Rice", category: .pantry)
        
        viewModel.groceryItems = [produceItem, dairyItem, pantryItem]
        
        let produceItems = viewModel.filterItems(by: .produce)
        XCTAssertEqual(produceItems.count, 1)
        XCTAssertEqual(produceItems.first?.ingredient.name, "Carrot")
        
        let dairyItems = viewModel.filterItems(by: .dairy)
        XCTAssertEqual(dairyItems.count, 1)
        XCTAssertEqual(dairyItems.first?.ingredient.name, "Milk")
    }
    
    func testItemsGroupedByCategory() {
        let produceItem1 = createMockGroceryItem(name: "Carrot", category: .produce)
        let produceItem2 = createMockGroceryItem(name: "Lettuce", category: .produce)
        let dairyItem = createMockGroceryItem(name: "Milk", category: .dairy)
        
        viewModel.groceryItems = [produceItem1, produceItem2, dairyItem]
        
        let groupedItems = viewModel.itemsGroupedByCategory()
        
        XCTAssertEqual(groupedItems[.produce]?.count, 2)
        XCTAssertEqual(groupedItems[.dairy]?.count, 1)
        XCTAssertNil(groupedItems[.pantry])
    }
    
    // MARK: - Completed Items Management Tests
    
    func testClearCompletedItems() {
        let completedItem1 = createMockGroceryItem(name: "Completed 1", isCompleted: true)
        let completedItem2 = createMockGroceryItem(name: "Completed 2", isCompleted: true)
        let pendingItem = createMockGroceryItem(name: "Pending", isCompleted: false)
        
        viewModel.groceryItems = [completedItem1, completedItem2, pendingItem]
        
        viewModel.clearCompletedItems()
        
        XCTAssertEqual(viewModel.groceryItems.count, 1)
        XCTAssertEqual(viewModel.groceryItems.first?.ingredient.name, "Pending")
        XCTAssertNotNil(viewModel.successMessage)
        XCTAssertTrue(viewModel.successMessage!.contains("2"))
    }
    
    func testClearCompletedItemsWithNoCompletedItems() {
        let pendingItem = createMockGroceryItem(name: "Pending", isCompleted: false)
        viewModel.groceryItems = [pendingItem]
        
        viewModel.clearCompletedItems()
        
        XCTAssertEqual(viewModel.groceryItems.count, 1)
        XCTAssertNil(viewModel.successMessage) // No success message if nothing was cleared
    }
    
    // MARK: - Message Management Tests
    
    func testClearErrorMessage() {
        viewModel.errorMessage = "Test error"
        viewModel.clearErrorMessage()
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testClearSuccessMessage() {
        viewModel.successMessage = "Test success"
        viewModel.clearSuccessMessage()
        XCTAssertNil(viewModel.successMessage)
    }
    
    // MARK: - Integration Tests
    
    func testCompleteWorkflow() async {
        // 1. Load initial grocery items
        await viewModel.loadGroceryItems()
        XCTAssertFalse(viewModel.groceryItems.isEmpty)
        
        // 2. Add urgent item
        viewModel.newUrgentItem.name = "Urgent Milk"
        viewModel.addUrgentItem()
        XCTAssertTrue(viewModel.groceryItems.contains { $0.isUrgent && $0.ingredient.name == "Urgent Milk" })
        
        // 3. Switch tabs and verify filtering
        viewModel.switchTab(to: .urgent)
        let urgentItems = viewModel.itemsForSelectedTab
        XCTAssertTrue(urgentItems.allSatisfy { $0.isUrgent })
        
        // 4. Generate grocery list from pantry check
        let missingIngredient = Ingredient(
            name: "Generated Item",
            quantity: "1",
            unit: "cup",
            emoji: "🆕",
            isAvailableInPantry: false,
            category: .produce
        )
        
        await viewModel.generateGroceryList(from: [missingIngredient])
        XCTAssertTrue(viewModel.groceryItems.contains { $0.ingredient.name == "Generated Item" })
        
        // 5. Select platform for ordering
        viewModel.loadGroceryPlatforms()
        if let platform = viewModel.availablePlatforms.first {
            viewModel.selectPlatform(platform)
            XCTAssertEqual(viewModel.selectedPlatform?.id, platform.id)
        }
    }
    
    // MARK: - Edge Cases Tests
    
    func testConcurrentOperations() async {
        // Test concurrent loading operations
        async let load1 = viewModel.loadGroceryItems()
        async let load2 = viewModel.loadGroceryItems()
        
        await load1
        await load2
        
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.groceryItems.isEmpty)
    }
    
    func testEmptyStateHandling() {
        // Test behavior with empty grocery list
        XCTAssertTrue(viewModel.groceryItems.isEmpty)
        XCTAssertFalse(viewModel.hasItemsToOrder)
        XCTAssertEqual(viewModel.estimatedTotalCost, 0.0)
        XCTAssertTrue(viewModel.itemsForSelectedTab.isEmpty)
        
        // Operations should handle empty state gracefully
        viewModel.clearCompletedItems() // Should not crash
        XCTAssertNil(viewModel.successMessage)
    }
    
    // MARK: - Helper Methods
    
    private func createMockGroceryItem(
        name: String = "Test Item",
        category: IngredientCategory = .pantry,
        addedBy: String = "Test User",
        isUrgent: Bool = false,
        isCompleted: Bool = false,
        addedDate: Date = Date()
    ) -> GroceryItem {
        let ingredient = Ingredient(
            name: name,
            quantity: "1",
            unit: "piece",
            emoji: "🛒",
            category: category
        )
        
        return GroceryItem(
            ingredient: ingredient,
            linkedMeal: nil,
            addedBy: addedBy,
            addedDate: addedDate,
            isUrgent: isUrgent,
            isCompleted: isCompleted,
            notes: nil
        )
    }
}