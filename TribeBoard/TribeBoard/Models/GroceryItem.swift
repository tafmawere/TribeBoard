import Foundation

/// Data model representing an item in the grocery list
struct GroceryItem: Identifiable, Codable {
    let id = UUID()
    let ingredient: Ingredient
    let linkedMeal: String?
    let addedBy: String
    let addedDate: Date
    let isUrgent: Bool
    var isCompleted: Bool = false
    let notes: String?
    
    /// Computed property that formats the added date for display
    var formattedAddedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: addedDate)
    }
    
    /// Computed property that returns display text for meal attribution
    var mealAttribution: String {
        if let linkedMeal = linkedMeal {
            return "For: \(linkedMeal)"
        }
        return "Added manually"
    }
    
    /// Computed property that returns the source of the item
    var source: GroceryItemSource {
        if linkedMeal != nil {
            return .mealPlan
        }
        return isUrgent ? .urgent : .manual
    }
    
    /// Computed property for display priority
    var priority: GroceryItemPriority {
        if isUrgent {
            return .high
        } else if linkedMeal != nil {
            return .medium
        } else {
            return .low
        }
    }
}

/// Enum representing the source of a grocery item
enum GroceryItemSource: String, CaseIterable, Codable {
    case mealPlan = "Meal Plan"
    case urgent = "Urgent Addition"
    case manual = "Manual Addition"
    
    var color: String {
        switch self {
        case .mealPlan: return "blue"
        case .urgent: return "red"
        case .manual: return "gray"
        }
    }
}

/// Enum representing grocery item priority levels
enum GroceryItemPriority: String, CaseIterable, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    var color: String {
        switch self {
        case .low: return "gray"
        case .medium: return "orange"
        case .high: return "red"
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }
}