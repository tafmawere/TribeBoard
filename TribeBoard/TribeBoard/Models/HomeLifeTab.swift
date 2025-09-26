import Foundation

/// Enum representing the different tabs within the HomeLife navigation
enum HomeLifeTab: String, CaseIterable, Identifiable {
    case mealPlan = "mealPlan"
    case groceryList = "groceryList"
    case tasks = "tasks"
    case pantry = "pantry"
    
    var id: String { rawValue }
    
    /// Display name for the HomeLife tab
    var displayName: String {
        switch self {
        case .mealPlan:
            return "Meal Plan"
        case .groceryList:
            return "Grocery List"
        case .tasks:
            return "Tasks"
        case .pantry:
            return "Pantry"
        }
    }
    
    /// Icon for the HomeLife tab
    var icon: String {
        switch self {
        case .mealPlan:
            return "🍽️"
        case .groceryList:
            return "🛒"
        case .tasks:
            return "✅"
        case .pantry:
            return "📋"
        }
    }
    
    /// Description for the HomeLife tab
    var description: String {
        switch self {
        case .mealPlan:
            return "Plan your family meals"
        case .groceryList:
            return "Manage shopping lists"
        case .tasks:
            return "Assign shopping tasks"
        case .pantry:
            return "Check what you have"
        }
    }
}