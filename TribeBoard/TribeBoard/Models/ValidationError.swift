import Foundation

/// Enumeration of validation errors that can occur during school run creation and management
enum ValidationError: LocalizedError, Equatable {
    case emptyRunName
    case noStops
    case emptyStopName(stopIndex: Int)
    case invalidStopDuration(stopIndex: Int)
    case excessiveStopDuration(stopIndex: Int)
    case emptyStopTask(stopIndex: Int)
    case excessiveTotalDuration
    case duplicateStopNames
    
    /// Localized error description for user display
    var errorDescription: String? {
        switch self {
        case .emptyRunName:
            return "Please enter a name for your run"
        case .noStops:
            return "Please add at least one stop to your run"
        case .emptyStopName(let stopIndex):
            return "Stop \(stopIndex): Please enter a location name"
        case .invalidStopDuration(let stopIndex):
            return "Stop \(stopIndex): Please enter a valid duration (1-120 minutes)"
        case .excessiveStopDuration(let stopIndex):
            return "Stop \(stopIndex): Duration cannot exceed 2 hours (120 minutes)"
        case .emptyStopTask(let stopIndex):
            return "Stop \(stopIndex): Please describe what needs to be done at this stop"
        case .excessiveTotalDuration:
            return "Total run duration cannot exceed 4 hours. Please reduce stop durations."
        case .duplicateStopNames:
            return "Multiple stops have the same name. Please use unique names for each stop."
        }
    }
    
    /// Recovery suggestion for the user
    var recoverySuggestion: String? {
        switch self {
        case .emptyRunName:
            return "Try something like 'Monday School Run' or 'After School Activities'"
        case .noStops:
            return "Add stops by tapping the '+ Add Stop' button"
        case .emptyStopName:
            return "Choose from preset locations or enter a custom location name"
        case .invalidStopDuration:
            return "Enter the estimated time you'll spend at this stop"
        case .excessiveStopDuration:
            return "Consider breaking long activities into multiple shorter stops"
        case .emptyStopTask:
            return "Describe what you need to do, like 'Pick up Emma' or 'Drop off supplies'"
        case .excessiveTotalDuration:
            return "Consider splitting this into multiple shorter runs"
        case .duplicateStopNames:
            return "Add numbers or descriptions to make each stop unique"
        }
    }
    
    /// Category of error for grouping and prioritization
    var category: ValidationErrorCategory {
        switch self {
        case .emptyRunName:
            return .runDetails
        case .noStops, .duplicateStopNames, .excessiveTotalDuration:
            return .runStructure
        case .emptyStopName, .invalidStopDuration, .excessiveStopDuration, .emptyStopTask:
            return .stopDetails
        }
    }
}

/// Categories for grouping validation errors
enum ValidationErrorCategory {
    case runDetails
    case runStructure
    case stopDetails
    
    var displayName: String {
        switch self {
        case .runDetails:
            return "Run Information"
        case .runStructure:
            return "Run Structure"
        case .stopDetails:
            return "Stop Details"
        }
    }
}