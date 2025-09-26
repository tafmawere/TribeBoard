import XCTest
@testable import TribeBoard

/// Unit tests for MealPlanViewModel
@MainActor
final class MealPlanViewModelTests: XCTestCase {
    
    var viewModel: MealPlanViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = MealPlanViewModel()
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialState() {
        XCTAssertNil(viewModel.currentMealPlan)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.successMessage)
        XCTAssertNotNil(viewModel.selectedDate)
        XCTAssertNotNil(viewModel.selectedWeekStartDate)
        XCTAssertTrue(viewModel.weekIngredients.isEmpty)
        XCTAssertEqual(viewModel.viewMode, .list)
        XCTAssertNotNil(viewModel.selectedMonth)
    }
    
    // MARK: - Meal Plan Loading Tests
    
    func testLoadMealPlan() async {
        XCTAssertNil(viewModel.currentMealPlan)
        XCTAssertFalse(viewModel.isLoading)
        
        await viewModel.loadMealPlan()
        
        XCTAssertNotNil(viewModel.currentMealPlan)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNotNil(viewModel.successMessage)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testLoadMealPlanSetsLoadingState() async {
        let loadingExpectation = expectation(description: "Loading state should be set")
        
        Task {
            // Check loading state is set immediately
            await viewModel.loadMealPlan()
            loadingExpectation.fulfill()
        }
        
        // Give a moment for the loading state to be set
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        await fulfillment(of: [loadingExpectation], timeout: 2.0)
        XCTAssertFalse(viewModel.isLoading) // Should be false after completion
    }
    
    // MARK: - Computed Properties Tests
    
    func testMealsForSelectedDateWithNoMealPlan() {
        XCTAssertTrue(viewModel.mealsForSelectedDate.isEmpty)
    }
    
    func testMealsForSelectedDateWithMealPlan() async {
        await viewModel.loadMealPlan()
        
        // Set selected date to a date that should have meals
        if let mealPlan = viewModel.currentMealPlan,
           let firstMeal = mealPlan.meals.first {
            viewModel.selectedDate = firstMeal.date
            let meals = viewModel.mealsForSelectedDate
            XCTAssertFalse(meals.isEmpty)
        }
    }
    
    func testMealsForSelectedMonth() async {
        await viewModel.loadMealPlan()
        
        if let mealPlan = viewModel.currentMealPlan,
           let firstMeal = mealPlan.meals.first {
            viewModel.selectedMonth = firstMeal.date
            let meals = viewModel.mealsForSelectedMonth
            XCTAssertFalse(meals.isEmpty)
            
            // Verify meals are sorted by date
            for i in 0..<(meals.count - 1) {
                XCTAssertLessThanOrEqual(meals[i].date, meals[i + 1].date)
            }
        }
    }
    
    func testMissingIngredients() {
        // Setup test ingredients with mixed availability
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
        
        viewModel.weekIngredients = [availableIngredient, missingIngredient]
        
        let missing = viewModel.missingIngredients
        XCTAssertEqual(missing.count, 1)
        XCTAssertEqual(missing.first?.name, "Missing Item")
    }
    
    func testPantryCheckProgress() {
        // Test with no ingredients
        XCTAssertEqual(viewModel.pantryCheckProgress, 0.0)
        
        // Test with mixed ingredients
        let ingredient1 = createMockIngredient(name: "Item 1", isAvailable: true)
        let ingredient2 = createMockIngredient(name: "Item 2", isAvailable: false)
        let ingredient3 = createMockIngredient(name: "Item 3", isAvailable: true)
        
        viewModel.weekIngredients = [ingredient1, ingredient2, ingredient3]
        
        XCTAssertEqual(viewModel.pantryCheckProgress, 2.0/3.0, accuracy: 0.01)
        XCTAssertEqual(viewModel.checkedIngredientsCount, 2)
        XCTAssertEqual(viewModel.totalIngredientsCount, 3)
    }
    
    func testIsPantryCheckComplete() {
        // Test with no ingredients
        XCTAssertFalse(viewModel.isPantryCheckComplete)
        
        // Test with all ingredients checked
        let ingredient1 = createMockIngredient(name: "Item 1", isAvailable: true)
        let ingredient2 = createMockIngredient(name: "Item 2", isAvailable: true)
        
        viewModel.weekIngredients = [ingredient1, ingredient2]
        XCTAssertTrue(viewModel.isPantryCheckComplete)
        
        // Test with some ingredients unchecked
        let ingredient3 = createMockIngredient(name: "Item 3", isAvailable: false)
        viewModel.weekIngredients.append(ingredient3)
        XCTAssertFalse(viewModel.isPantryCheckComplete)
    }
    
    // MARK: - Ingredient Management Tests
    
    func testLoadIngredientsForWeekWithNoMealPlan() {
        viewModel.loadIngredientsForWeek()
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage!.contains("No meal plan available"))
    }
    
    func testLoadIngredientsForWeekWithMealPlan() async {
        await viewModel.loadMealPlan()
        viewModel.loadIngredientsForWeek()
        
        // Should have loaded ingredients without error
        XCTAssertNil(viewModel.errorMessage)
        // Ingredients should be sorted by name
        let ingredientNames = viewModel.weekIngredients.map { $0.name }
        let sortedNames = ingredientNames.sorted()
        XCTAssertEqual(ingredientNames, sortedNames)
    }
    
    func testToggleIngredientAvailability() {
        let ingredient = createMockIngredient(name: "Test Item", isAvailable: false)
        viewModel.weekIngredients = [ingredient]
        
        XCTAssertFalse(viewModel.weekIngredients.first!.isAvailableInPantry)
        
        viewModel.toggleIngredientAvailability(ingredient)
        
        XCTAssertTrue(viewModel.weekIngredients.first!.isAvailableInPantry)
        
        // Toggle back
        viewModel.toggleIngredientAvailability(viewModel.weekIngredients.first!)
        XCTAssertFalse(viewModel.weekIngredients.first!.isAvailableInPantry)
    }
    
    func testToggleIngredientAvailabilityWithNonExistentIngredient() {
        let existingIngredient = createMockIngredient(name: "Existing", isAvailable: false)
        let nonExistentIngredient = createMockIngredient(name: "Non-existent", isAvailable: false)
        
        viewModel.weekIngredients = [existingIngredient]
        
        // Should not crash or change anything
        viewModel.toggleIngredientAvailability(nonExistentIngredient)
        XCTAssertEqual(viewModel.weekIngredients.count, 1)
        XCTAssertFalse(viewModel.weekIngredients.first!.isAvailableInPantry)
    }
    
    // MARK: - Filtering and Date Management Tests
    
    func testFilterMealsWithDateRange() async {
        await viewModel.loadMealPlan()
        
        let calendar = Calendar.current
        let today = Date()
        let startDate = calendar.startOfDay(for: today)
        let endDate = calendar.date(byAdding: .day, value: 7, to: startDate)!
        
        let filteredMeals = viewModel.filterMeals(from: startDate, to: endDate)
        
        // All filtered meals should be within the date range
        for meal in filteredMeals {
            XCTAssertGreaterThanOrEqual(meal.date, startDate)
            XCTAssertLessThanOrEqual(meal.date, endDate)
        }
        
        // Should be sorted by date
        for i in 0..<(filteredMeals.count - 1) {
            XCTAssertLessThanOrEqual(filteredMeals[i].date, filteredMeals[i + 1].date)
        }
    }
    
    func testMealsForSpecificDate() async {
        await viewModel.loadMealPlan()
        
        if let mealPlan = viewModel.currentMealPlan,
           let firstMeal = mealPlan.meals.first {
            let meals = viewModel.meals(for: firstMeal.date)
            XCTAssertFalse(meals.isEmpty)
            
            // All meals should be for the specified date
            let calendar = Calendar.current
            for meal in meals {
                XCTAssertTrue(calendar.isDate(meal.date, inSameDayAs: firstMeal.date))
            }
        }
    }
    
    func testChangeMonth() {
        let newMonth = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        viewModel.changeMonth(to: newMonth)
        
        XCTAssertEqual(viewModel.selectedMonth, newMonth)
    }
    
    func testChangeViewMode() {
        XCTAssertEqual(viewModel.viewMode, .list)
        
        viewModel.changeViewMode(to: .calendar)
        XCTAssertEqual(viewModel.viewMode, .calendar)
        
        viewModel.changeViewMode(to: .list)
        XCTAssertEqual(viewModel.viewMode, .list)
    }
    
    func testChangeWeek() async {
        await viewModel.loadMealPlan()
        
        let calendar = Calendar.current
        let newWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: Date())!
        
        viewModel.changeWeek(to: newWeekStart)
        
        XCTAssertEqual(viewModel.selectedWeekStartDate, newWeekStart)
    }
    
    // MARK: - Week Range Formatting Tests
    
    func testGetWeekRangeString() {
        let calendar = Calendar.current
        let testDate = Date()
        
        let weekRange = viewModel.getWeekRangeString(for: testDate)
        
        XCTAssertFalse(weekRange.isEmpty)
        XCTAssertTrue(weekRange.contains("-"))
        XCTAssertFalse(weekRange.contains("Invalid"))
    }
    
    func testGetWeekRangeStringWithInvalidDate() {
        // Test with a date that might cause issues
        let distantFuture = Date.distantFuture
        let weekRange = viewModel.getWeekRangeString(for: distantFuture)
        
        // Should handle gracefully
        XCTAssertFalse(weekRange.isEmpty)
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
    
    // MARK: - Pantry Check Reset Tests
    
    func testResetPantryCheck() {
        let ingredient1 = createMockIngredient(name: "Item 1", isAvailable: true)
        let ingredient2 = createMockIngredient(name: "Item 2", isAvailable: false)
        let ingredient3 = createMockIngredient(name: "Item 3", isAvailable: true)
        
        viewModel.weekIngredients = [ingredient1, ingredient2, ingredient3]
        
        XCTAssertEqual(viewModel.checkedIngredientsCount, 2)
        
        viewModel.resetPantryCheck()
        
        XCTAssertEqual(viewModel.checkedIngredientsCount, 0)
        XCTAssertTrue(viewModel.weekIngredients.allSatisfy { !$0.isAvailableInPantry })
    }
    
    // MARK: - Integration Tests
    
    func testCompleteWorkflow() async {
        // Test complete workflow from loading to pantry check
        
        // 1. Load meal plan
        await viewModel.loadMealPlan()
        XCTAssertNotNil(viewModel.currentMealPlan)
        
        // 2. Load ingredients for week
        viewModel.loadIngredientsForWeek()
        XCTAssertNil(viewModel.errorMessage)
        
        // 3. Toggle some ingredients
        if !viewModel.weekIngredients.isEmpty {
            let firstIngredient = viewModel.weekIngredients[0]
            let initialAvailability = firstIngredient.isAvailableInPantry
            
            viewModel.toggleIngredientAvailability(firstIngredient)
            XCTAssertNotEqual(viewModel.weekIngredients[0].isAvailableInPantry, initialAvailability)
        }
        
        // 4. Check progress calculation
        let progress = viewModel.pantryCheckProgress
        XCTAssertGreaterThanOrEqual(progress, 0.0)
        XCTAssertLessThanOrEqual(progress, 1.0)
        
        // 5. Reset pantry check
        viewModel.resetPantryCheck()
        XCTAssertEqual(viewModel.pantryCheckProgress, 0.0)
    }
    
    // MARK: - Edge Cases Tests
    
    func testEmptyMealPlanHandling() {
        // Create empty meal plan
        let emptyMealPlan = MealPlan(month: Date(), meals: [])
        viewModel.currentMealPlan = emptyMealPlan
        
        XCTAssertTrue(viewModel.mealsForSelectedDate.isEmpty)
        XCTAssertTrue(viewModel.mealsForSelectedMonth.isEmpty)
        
        viewModel.loadIngredientsForWeek()
        XCTAssertTrue(viewModel.weekIngredients.isEmpty)
    }
    
    func testConcurrentOperations() async {
        // Test that concurrent operations don't cause issues
        async let load1 = viewModel.loadMealPlan()
        async let load2 = viewModel.loadMealPlan()
        
        await load1
        await load2
        
        XCTAssertNotNil(viewModel.currentMealPlan)
        XCTAssertFalse(viewModel.isLoading)
    }
    
    // MARK: - Helper Methods
    
    private func createMockIngredient(name: String, isAvailable: Bool = false) -> Ingredient {
        return Ingredient(
            name: name,
            quantity: "1",
            unit: "cup",
            emoji: "🥕",
            isAvailableInPantry: isAvailable,
            category: .produce
        )
    }
}