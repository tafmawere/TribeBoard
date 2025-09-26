import Foundation

/// Data model representing a shopping task assigned to a family member
struct ShoppingTask: Identifiable, Codable {
    let id = UUID()
    let items: [GroceryItem]
    let assignedTo: String
    let taskType: TaskType
    let dueDate: Date
    let notes: String?
    let location: TaskLocation?
    var status: TaskStatus
    let createdAt: Date = Date()
    let createdBy: String
    
    /// Computed property that formats the due date for display
    var formattedDueDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: dueDate)
    }
    
    /// Computed property that returns a short due date format
    var shortDueDate: String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(dueDate) {
            formatter.timeStyle = .short
            return "Today \(formatter.string(from: dueDate))"
        } else if calendar.isDateInTomorrow(dueDate) {
            formatter.timeStyle = .short
            return "Tomorrow \(formatter.string(from: dueDate))"
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: dueDate)
        }
    }
    
    /// Computed property that returns the total number of items
    var itemCount: Int {
        items.count
    }
    
    /// Computed property that returns a summary of items
    var itemSummary: String {
        let itemNames = items.prefix(3).map { $0.ingredient.name }
        if items.count > 3 {
            return itemNames.joined(separator: ", ") + " +\(items.count - 3) more"
        }
        return itemNames.joined(separator: ", ")
    }
    
    /// Computed property that checks if the task is overdue
    var isOverdue: Bool {
        status != .completed && dueDate < Date()
    }
    
    /// Computed property that returns priority based on due date and urgency
    var priority: TaskPriority {
        if isOverdue {
            return .critical
        } else if Calendar.current.isDateInToday(dueDate) {
            return .high
        } else if Calendar.current.isDateInTomorrow(dueDate) {
            return .medium
        } else {
            return .low
        }
    }
}

/// Enum representing different types of shopping tasks
enum TaskType: String, CaseIterable, Codable {
    case shopRun = "Shop Run"
    case schoolRunPlusShop = "School Run + Shop Stop"
    
    var emoji: String {
        switch self {
        case .shopRun: return "🛒"
        case .schoolRunPlusShop: return "🚗🛒"
        }
    }
    
    var description: String {
        switch self {
        case .shopRun: return "Dedicated shopping trip"
        case .schoolRunPlusShop: return "Shopping combined with school pickup/dropoff"
        }
    }
}

/// Enum representing task completion status
enum TaskStatus: String, CaseIterable, Codable {
    case pending = "Pending"
    case inProgress = "In Progress"
    case completed = "Completed"
    case cancelled = "Cancelled"
    
    var color: String {
        switch self {
        case .pending: return "orange"
        case .inProgress: return "blue"
        case .completed: return "green"
        case .cancelled: return "gray"
        }
    }
    
    var emoji: String {
        switch self {
        case .pending: return "⏳"
        case .inProgress: return "🔄"
        case .completed: return "✅"
        case .cancelled: return "❌"
        }
    }
}

/// Enum representing task priority levels
enum TaskPriority: String, CaseIterable, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
    
    var color: String {
        switch self {
        case .low: return "gray"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
    
    var sortOrder: Int {
        switch self {
        case .critical: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }
}

/// Data model representing a location for shopping tasks
struct TaskLocation: Identifiable, Codable {
    let id = UUID()
    let name: String
    let address: String
    let latitude: Double?
    let longitude: Double?
    let type: LocationType
    
    /// Computed property that returns a formatted address
    var formattedAddress: String {
        return address.isEmpty ? name : "\(name), \(address)"
    }
}

/// Enum representing different types of task locations
enum LocationType: String, CaseIterable, Codable {
    case supermarket = "Supermarket"
    case school = "School"
    case pharmacy = "Pharmacy"
    case other = "Other"
    
    var emoji: String {
        switch self {
        case .supermarket: return "🏪"
        case .school: return "🏫"
        case .pharmacy: return "💊"
        case .other: return "📍"
        }
    }
}