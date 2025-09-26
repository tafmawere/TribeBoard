import Foundation

/// Core data model representing a monthly meal plan for a family
struct MealPlan: Identifiable, Codable {
    let id = UUID()
    let month: Date
    let meals: [PlannedMeal]
    
    /// Computed property that returns meals for a specific date
    func meals(for date: Date) -> [PlannedMeal] {
        let calendar = Calendar.current
        return meals.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }
    
    /// Computed property that returns all unique ingredients across all meals
    var allIngredients: [Ingredient] {
        var uniqueIngredients: [Ingredient] = []
        let allMealIngredients = meals.flatMap(\.ingredients)
        
        for ingredient in allMealIngredients {
            if !uniqueIngredients.contains(where: { $0.name == ingredient.name }) {
                uniqueIngredients.append(ingredient)
            }
        }
        
        return uniqueIngredients
    }
    
    /// Returns ingredients needed for a specific week
    func ingredients(for weekStartDate: Date) -> [Ingredient] {
        let calendar = Calendar.current
        let weekRange = calendar.dateInterval(of: .weekOfYear, for: weekStartDate)
        
        guard let weekStart = weekRange?.start, let weekEnd = weekRange?.end else {
            return []
        }
        
        let weekMeals = meals.filter { meal in
            meal.date >= weekStart && meal.date < weekEnd
        }
        
        return weekMeals.flatMap(\.ingredients)
    }
}

/// Data model representing a planned meal for a specific date
struct PlannedMeal: Identifiable, Codable {
    let id = UUID()
    let name: String
    let date: Date
    let ingredients: [Ingredient]
    let servings: Int
    let mealType: MealType
    let estimatedPrepTime: Int // in minutes
    
    /// Computed property that formats the meal date for display
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    /// Computed property that formats the day of week
    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
}

/// Enum representing different types of meals
enum MealType: String, CaseIterable, Codable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snack"
    
    var emoji: String {
        switch self {
        case .breakfast: return "🌅"
        case .lunch: return "☀️"
        case .dinner: return "🌙"
        case .snack: return "🍎"
        }
    }
}

/// Data model representing an ingredient with pantry tracking
struct Ingredient: Identifiable, Codable {
    let id = UUID()
    let name: String
    let quantity: String
    let unit: String
    let emoji: String
    var isAvailableInPantry: Bool = false
    let category: IngredientCategory
    
    /// Computed property that combines quantity and unit for display
    var displayQuantity: String {
        if unit.isEmpty {
            return quantity
        }
        return "\(quantity) \(unit)"
    }
    
    /// Computed property that formats ingredient for display with emoji
    var displayName: String {
        "\(emoji) \(name)"
    }
}

/// Enum representing ingredient categories for organization
enum IngredientCategory: String, CaseIterable, Codable {
    case produce = "Produce"
    case meat = "Meat & Poultry"
    case dairy = "Dairy"
    case pantry = "Pantry Staples"
    case frozen = "Frozen"
    case bakery = "Bakery"
    case spices = "Spices & Seasonings"
    
    var emoji: String {
        switch self {
        case .produce: return "🥬"
        case .meat: return "🥩"
        case .dairy: return "🥛"
        case .pantry: return "🏺"
        case .frozen: return "🧊"
        case .bakery: return "🍞"
        case .spices: return "🧂"
        }
    }
}