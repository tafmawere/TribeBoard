import SwiftUI
import Foundation

/// ViewModel for managing meal plan state and pantry check functionality
@MainActor
class MealPlanViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Current meal plan for the family
    @Published var currentMealPlan: MealPlan?
    
    /// Loading state for async operations
    @Published var isLoading = false
    
    /// Error message for display
    @Published var errorMessage: String?
    
    /// Success message for operations
    @Published var successMessage: String?
    
    /// Selected date for filtering meals
    @Published var selectedDate = Date()
    
    /// Selected week start date for pantry check
    @Published var selectedWeekStartDate = Date()
    
    /// Ingredients for the selected week with pantry status
    @Published var weekIngredients: [Ingredient] = []
    
    /// View mode for meal display (calendar or list)
    @Published var viewMode: MealViewMode = .list
    
    /// Selected month for meal plan display
    @Published var selectedMonth = Date()
    
    // MARK: - Computed Properties
    
    /// Meals for the currently selected date
    var mealsForSelectedDate: [PlannedMeal] {
        guard let mealPlan = currentMealPlan else { return [] }
        return mealPlan.meals(for: selectedDate)
    }
    
    /// Meals for the currently selected month
    var mealsForSelectedMonth: [PlannedMeal] {
        guard let mealPlan = currentMealPlan else { return [] }
        let calendar = Calendar.current
        
        return mealPlan.meals.filter { meal in
            calendar.isDate(meal.date, equalTo: selectedMonth, toGranularity: .month)
        }.sorted { $0.date < $1.date }
    }
    
    /// Ingredients that are not available in pantry
    var missingIngredients: [Ingredient] {
        weekIngredients.filter { !$0.isAvailableInPantry }
    }
    
    /// Count of checked ingredients
    var checkedIngredientsCount: Int {
        weekIngredients.filter { $0.isAvailableInPantry }.count
    }
    
    /// Total ingredients count
    var totalIngredientsCount: Int {
        weekIngredients.count
    }
    
    /// Progress percentage for pantry check
    var pantryCheckProgress: Double {
        guard totalIngredientsCount > 0 else { return 0.0 }
        return Double(checkedIngredientsCount) / Double(totalIngredientsCount)
    }
    
    /// Whether pantry check is complete
    var isPantryCheckComplete: Bool {
        totalIngredientsCount > 0 && checkedIngredientsCount == totalIngredientsCount
    }
    
    // MARK: - Initialization
    
    init() {
        setupInitialState()
    }
    
    // MARK: - Public Methods
    
    /// Load meal plan data
    func loadMealPlan() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Simulate network delay for realistic loading experience
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Load mock meal plan data
            let mealPlan = MealPlanDataProvider.mockMealPlan()
            
            await MainActor.run {
                self.currentMealPlan = mealPlan
                self.successMessage = "Meal plan loaded successfully"
                
                // Auto-clear success message after 3 seconds
                Task {
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                    await MainActor.run {
                        self.successMessage = nil
                    }
                }
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load meal plan: \(error.localizedDescription)"
            }
        }
        
        isLoading = false
    }
    
    /// Load ingredients for pantry check for the selected week
    func loadIngredientsForWeek() {
        guard let mealPlan = currentMealPlan else {
            errorMessage = "No meal plan available"
            return
        }
        
        let ingredients = mealPlan.ingredients(for: selectedWeekStartDate)
        
        // Group ingredients by name and combine quantities
        var groupedIngredients: [String: Ingredient] = [:]
        
        for ingredient in ingredients {
            if let existing = groupedIngredients[ingredient.name] {
                // Combine quantities if units match, otherwise keep separate
                if existing.unit == ingredient.unit {
                    let existingQty = Double(existing.quantity) ?? 0
                    let newQty = Double(ingredient.quantity) ?? 0
                    let combinedQty = existingQty + newQty
                    
                    var combined = existing
                    combined = Ingredient(
                        name: combined.name,
                        quantity: String(format: "%.1f", combinedQty),
                        unit: combined.unit,
                        emoji: combined.emoji,
                        isAvailableInPantry: combined.isAvailableInPantry,
                        category: combined.category
                    )
                    groupedIngredients[ingredient.name] = combined
                } else {
                    // Different units, create a new entry with modified name
                    let modifiedName = "\(ingredient.name) (\(ingredient.unit))"
                    groupedIngredients[modifiedName] = ingredient
                }
            } else {
                groupedIngredients[ingredient.name] = ingredient
            }
        }
        
        weekIngredients = Array(groupedIngredients.values).sorted { $0.name < $1.name }
    }
    
    /// Toggle pantry availability for an ingredient
    func toggleIngredientAvailability(_ ingredient: Ingredient) {
        if let index = weekIngredients.firstIndex(where: { $0.id == ingredient.id }) {
            var updatedIngredient = weekIngredients[index]
            updatedIngredient = Ingredient(
                name: updatedIngredient.name,
                quantity: updatedIngredient.quantity,
                unit: updatedIngredient.unit,
                emoji: updatedIngredient.emoji,
                isAvailableInPantry: !updatedIngredient.isAvailableInPantry,
                category: updatedIngredient.category
            )
            weekIngredients[index] = updatedIngredient
        }
    }
    
    /// Filter meals by date range
    func filterMeals(from startDate: Date, to endDate: Date) -> [PlannedMeal] {
        guard let mealPlan = currentMealPlan else { return [] }
        
        return mealPlan.meals.filter { meal in
            meal.date >= startDate && meal.date <= endDate
        }.sorted { $0.date < $1.date }
    }
    
    /// Get meals for a specific date
    func meals(for date: Date) -> [PlannedMeal] {
        guard let mealPlan = currentMealPlan else { return [] }
        return mealPlan.meals(for: date)
    }
    
    /// Change selected month
    func changeMonth(to date: Date) {
        selectedMonth = date
    }
    
    /// Change view mode
    func changeViewMode(to mode: MealViewMode) {
        viewMode = mode
    }
    
    /// Change selected week for pantry check
    func changeWeek(to weekStartDate: Date) {
        selectedWeekStartDate = weekStartDate
        loadIngredientsForWeek()
    }
    
    /// Get formatted week range string
    func getWeekRangeString(for date: Date) -> String {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return "Invalid week"
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let startString = formatter.string(from: weekInterval.start)
        let endString = formatter.string(from: weekInterval.end.addingTimeInterval(-1)) // Subtract 1 second to get last day of week
        
        return "\(startString) - \(endString)"
    }
    
    /// Clear error message
    func clearErrorMessage() {
        errorMessage = nil
    }
    
    /// Clear success message
    func clearSuccessMessage() {
        successMessage = nil
    }
    
    /// Reset pantry check (mark all ingredients as not available)
    func resetPantryCheck() {
        weekIngredients = weekIngredients.map { ingredient in
            var reset = ingredient
            reset = Ingredient(
                name: reset.name,
                quantity: reset.quantity,
                unit: reset.unit,
                emoji: reset.emoji,
                isAvailableInPantry: false,
                category: reset.category
            )
            return reset
        }
    }
    
    // MARK: - Private Methods
    
    private func setupInitialState() {
        let calendar = Calendar.current
        
        // Set selected week to start of current week
        selectedWeekStartDate = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        
        // Load initial data
        Task {
            await loadMealPlan()
            loadIngredientsForWeek()
        }
    }
}

// MARK: - Supporting Enums

/// Enum for meal view display modes
enum MealViewMode: String, CaseIterable {
    case calendar = "Calendar"
    case list = "List"
    
    var icon: String {
        switch self {
        case .calendar: return "calendar"
        case .list: return "list.bullet"
        }
    }
}