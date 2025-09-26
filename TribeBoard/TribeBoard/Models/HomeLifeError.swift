import Foundation

/// Enum representing errors specific to HomeLife functionality
enum HomeLifeError: LocalizedError {
    case mealPlanLoadFailed
    case groceryListGenerationFailed
    case taskCreationFailed
    case pantryCheckFailed
    case navigationError
    case dataValidationError(String)
    
    var errorDescription: String? {
        switch self {
        case .mealPlanLoadFailed:
            return "Unable to load meal plan. Please try again."
        case .groceryListGenerationFailed:
            return "Failed to generate grocery list. Please check your selections."
        case .taskCreationFailed:
            return "Unable to create task. Please verify all fields."
        case .pantryCheckFailed:
            return "Failed to save pantry check. Please try again."
        case .navigationError:
            return "Navigation error occurred. Please try again."
        case .dataValidationError(let message):
            return "Data validation error: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .mealPlanLoadFailed:
            return "Check your internet connection and try refreshing the meal plan."
        case .groceryListGenerationFailed:
            return "Ensure you have selected ingredients from the pantry check."
        case .taskCreationFailed:
            return "Make sure all required fields are filled out correctly."
        case .pantryCheckFailed:
            return "Try saving your pantry check again."
        case .navigationError:
            return "Return to the HomeLife dashboard and try navigating again."
        case .dataValidationError:
            return "Please check your input and try again."
        }
    }
}