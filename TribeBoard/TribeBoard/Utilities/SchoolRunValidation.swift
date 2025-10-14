import Foundation
import SwiftUI

/// Comprehensive validation utilities for School Run forms and data
struct SchoolRunValidation {
    
    // MARK: - Validation Rules
    
    /// Minimum run title length
    static let minTitleLength = 3
    
    /// Maximum run title length
    static let maxTitleLength = 50
    
    /// Maximum stop name length
    static let maxStopNameLength = 30
    
    /// Maximum stop note length
    static let maxStopNoteLength = 100
    
    /// Minimum time between stops (in seconds)
    static let minStopInterval: TimeInterval = 300 // 5 minutes
    
    /// Maximum number of stops per run
    static let maxStopsPerRun = 10
    
    /// Maximum future date for scheduling (1 year)
    static let maxFutureDays = 365
    
    // MARK: - Run Validation
    
    /// Validate a complete run and throw error if invalid
    static func validateRun(_ run: SchoolRun) throws {
        let result = validateRun(title: run.title, date: run.date, stops: run.route)
        if !result.isValid {
            throw result.errors.first ?? SchoolRunError.invalidRunData("Validation failed")
        }
    }
    
    /// Validate complete run data
    static func validateRun(title: String, date: Date, stops: [RunStop]) -> SchoolRunValidationResult {
        var errors: [SchoolRunError] = []
        var warnings: [String] = []
        
        // Validate title
        if let titleError = validateTitle(title) {
            errors.append(titleError)
        }
        
        // Validate date
        if let dateError = validateDate(date) {
            errors.append(dateError)
        }
        
        // Validate stops
        let stopErrors = validateStops(stops, runDate: date)
        errors.append(contentsOf: stopErrors)
        
        // Generate warnings
        warnings.append(contentsOf: generateWarnings(title: title, date: date, stops: stops))
        
        return SchoolRunValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }
    
    /// Validate run title
    static func validateTitle(_ title: String) -> SchoolRunError? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedTitle.isEmpty {
            return .invalidRunTitle("Title is required")
        }
        
        if trimmedTitle.count < minTitleLength {
            return .invalidRunTitle("Title must be at least \(minTitleLength) characters")
        }
        
        if trimmedTitle.count > maxTitleLength {
            return .invalidRunTitle("Title must be less than \(maxTitleLength) characters")
        }
        
        // Check for invalid characters
        let allowedCharacters = CharacterSet.alphanumerics
            .union(.whitespaces)
            .union(.punctuationCharacters)
        
        if trimmedTitle.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
            return .invalidRunTitle("Title contains invalid characters")
        }
        
        // Check for excessive whitespace
        if trimmedTitle.contains("  ") {
            return .invalidRunTitle("Title cannot contain multiple consecutive spaces")
        }
        
        return nil
    }
    
    /// Validate run date
    static func validateDate(_ date: Date) -> SchoolRunError? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let selectedDay = calendar.startOfDay(for: date)
        
        if selectedDay < today {
            return .invalidRunDate("Date cannot be in the past")
        }
        
        let maxDate = calendar.date(byAdding: .day, value: maxFutureDays, to: today) ?? today
        if selectedDay > maxDate {
            return .invalidRunDate("Date cannot be more than \(maxFutureDays) days in the future")
        }
        
        // Check if date is a reasonable day (not too far in the future for practical use)
        let oneMonthFromNow = calendar.date(byAdding: .month, value: 1, to: today) ?? today
        if selectedDay > oneMonthFromNow {
            // This is a warning, not an error
        }
        
        return nil
    }
    
    /// Validate stops collection
    static func validateStops(_ stops: [RunStop], runDate: Date) -> [SchoolRunError] {
        var errors: [SchoolRunError] = []
        
        // Check minimum stops
        if stops.isEmpty {
            errors.append(.insufficientStops)
            return errors
        }
        
        // Check maximum stops
        if stops.count > maxStopsPerRun {
            errors.append(.invalidStopData("Maximum \(maxStopsPerRun) stops allowed"))
        }
        
        // Validate individual stops
        for (index, stop) in stops.enumerated() {
            if let stopError = validateStop(stop, index: index, runDate: runDate) {
                errors.append(stopError)
            }
        }
        
        // Check for duplicate names
        let stopNames = stops.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        let uniqueNames = Set(stopNames)
        if stopNames.count != uniqueNames.count {
            errors.append(.duplicateStopNames)
        }
        
        // Validate stop timing
        errors.append(contentsOf: validateStopTiming(stops, runDate: runDate))
        
        return errors
    }
    
    /// Validate individual stop
    static func validateStop(_ stop: RunStop, index: Int, runDate: Date) -> SchoolRunError? {
        let trimmedName = stop.name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate name
        if trimmedName.isEmpty {
            return .invalidStopData("Stop \(index + 1) name is required")
        }
        
        if trimmedName.count > maxStopNameLength {
            return .invalidStopData("Stop \(index + 1) name must be less than \(maxStopNameLength) characters")
        }
        
        // Validate note length
        if stop.note.count > maxStopNoteLength {
            return .invalidStopData("Stop \(index + 1) note must be less than \(maxStopNoteLength) characters")
        }
        
        // Validate time is on the same day as run date
        let calendar = Calendar.current
        let runDay = calendar.startOfDay(for: runDate)
        let stopDay = calendar.startOfDay(for: stop.time)
        
        if runDay != stopDay {
            return .invalidStopTiming("Stop \(index + 1) must be on the same day as the run")
        }
        
        // Check for reasonable time (not too early or too late)
        let hour = calendar.component(.hour, from: stop.time)
        if hour < 5 || hour > 23 {
            return .invalidStopTiming("Stop \(index + 1) time should be between 5:00 AM and 11:00 PM")
        }
        
        return nil
    }
    
    /// Validate stop timing relationships
    static func validateStopTiming(_ stops: [RunStop], runDate: Date) -> [SchoolRunError] {
        var errors: [SchoolRunError] = []
        
        guard stops.count > 1 else { return errors }
        
        let sortedStops = stops.sorted { $0.time < $1.time }
        
        // Check minimum intervals between stops
        for i in 1..<sortedStops.count {
            let timeDifference = sortedStops[i].time.timeIntervalSince(sortedStops[i-1].time)
            if timeDifference < minStopInterval {
                let minutes = Int(minStopInterval / 60)
                errors.append(.stopTimeConflict("Stops must be at least \(minutes) minutes apart"))
                break
            }
        }
        
        // Check for reasonable total duration
        if let firstStop = sortedStops.first, let lastStop = sortedStops.last {
            let totalDuration = lastStop.time.timeIntervalSince(firstStop.time)
            let maxDuration: TimeInterval = 8 * 3600 // 8 hours
            
            if totalDuration > maxDuration {
                errors.append(.invalidStopTiming("Total run duration cannot exceed 8 hours"))
            }
        }
        
        return errors
    }
    
    // MARK: - Warning Generation
    
    /// Generate warnings for potential issues
    static func generateWarnings(title: String, date: Date, stops: [RunStop]) -> [String] {
        var warnings: [String] = []
        
        // Date warnings
        let calendar = Calendar.current
        let oneWeekFromNow = calendar.date(byAdding: .weekOfYear, value: 1, to: Date()) ?? Date()
        if date > oneWeekFromNow {
            warnings.append("Run is scheduled more than a week in advance")
        }
        
        // Weekend warning
        let weekday = calendar.component(.weekday, from: date)
        if weekday == 1 || weekday == 7 { // Sunday or Saturday
            warnings.append("Run is scheduled for a weekend")
        }
        
        // Stop warnings
        if stops.count == 1 {
            warnings.append("Run has only one stop")
        }
        
        // Time warnings
        let sortedStops = stops.sorted { $0.time < $1.time }
        if let firstStop = sortedStops.first {
            let hour = calendar.component(.hour, from: firstStop.time)
            if hour < 7 {
                warnings.append("Run starts very early (before 7:00 AM)")
            }
            if hour > 20 {
                warnings.append("Run starts very late (after 8:00 PM)")
            }
        }
        
        // Mixed stop types warning
        let hasPickup = stops.contains { $0.type == .pickup }
        let hasDropoff = stops.contains { $0.type == .dropoff }
        if hasPickup && hasDropoff {
            warnings.append("Run contains both pickup and drop-off stops")
        }
        
        return warnings
    }
    
    // MARK: - Real-time Validation
    
    /// Validate title in real-time (for live feedback)
    static func validateTitleRealTime(_ title: String) -> TitleValidationState {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedTitle.isEmpty {
            return .empty
        }
        
        if trimmedTitle.count < minTitleLength {
            return .tooShort(current: trimmedTitle.count, required: minTitleLength)
        }
        
        if trimmedTitle.count > maxTitleLength {
            return .tooLong(current: trimmedTitle.count, maximum: maxTitleLength)
        }
        
        return .valid
    }
    
    /// Validate stop name in real-time
    static func validateStopNameRealTime(_ name: String) -> StopNameValidationState {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            return .empty
        }
        
        if trimmedName.count > maxStopNameLength {
            return .tooLong(current: trimmedName.count, maximum: maxStopNameLength)
        }
        
        return .valid
    }
    
    // MARK: - Validation Helpers
    
    /// Check if two stops have conflicting times
    static func hasTimeConflict(_ stop1: RunStop, _ stop2: RunStop) -> Bool {
        let timeDifference = abs(stop1.time.timeIntervalSince(stop2.time))
        return timeDifference < minStopInterval
    }
    
    /// Get suggested time for next stop
    static func suggestNextStopTime(after stops: [RunStop], baseDate: Date) -> Date {
        guard !stops.isEmpty else {
            // If no stops, suggest 15 minutes from base date
            return Calendar.current.date(byAdding: .minute, value: 15, to: baseDate) ?? baseDate
        }
        
        let latestStop = stops.max { $0.time < $1.time }!
        let suggestedTime = Calendar.current.date(byAdding: .minute, value: 15, to: latestStop.time) ?? latestStop.time
        
        return suggestedTime
    }
    
    /// Validate stop order makes sense geographically (placeholder for future enhancement)
    static func validateStopOrder(_ stops: [RunStop]) -> [String] {
        var suggestions: [String] = []
        
        // This is a placeholder for future geographic validation
        // Could integrate with mapping services to suggest optimal order
        
        if stops.count > 3 {
            suggestions.append("Consider optimizing stop order for efficiency")
        }
        
        return suggestions
    }
}

// MARK: - Validation Result Types

/// Result of school run validation operation
struct SchoolRunValidationResult {
    let isValid: Bool
    let errors: [SchoolRunError]
    let warnings: [String]
    
    /// Get user-friendly error messages
    var errorMessages: [String] {
        return errors.map { $0.userFriendlyMessage }
    }
    
    /// Get the first error message for display
    var firstErrorMessage: String? {
        return errors.first?.userFriendlyMessage
    }
    
    /// Check if there are any critical errors
    var hasCriticalErrors: Bool {
        return errors.contains { $0.severity == .critical }
    }
    
    /// Get errors by category
    func errors(for category: ErrorCategory) -> [SchoolRunError] {
        return errors.filter { $0.category == category }
    }
}

/// Real-time title validation states
enum TitleValidationState {
    case empty
    case tooShort(current: Int, required: Int)
    case tooLong(current: Int, maximum: Int)
    case valid
    
    var isValid: Bool {
        if case .valid = self {
            return true
        }
        return false
    }
    
    var message: String? {
        switch self {
        case .empty:
            return nil
        case .tooShort(let current, let required):
            return "At least \(required) characters (\(current)/\(required))"
        case .tooLong(let current, let maximum):
            return "Too long (\(current)/\(maximum))"
        case .valid:
            return nil
        }
    }
}

/// Real-time stop name validation states
enum StopNameValidationState {
    case empty
    case tooLong(current: Int, maximum: Int)
    case valid
    
    var isValid: Bool {
        switch self {
        case .empty:
            return false
        case .tooLong:
            return false
        case .valid:
            return true
        }
    }
    
    var message: String? {
        switch self {
        case .empty:
            return "Stop name is required"
        case .tooLong(let current, let maximum):
            return "Too long (\(current)/\(maximum))"
        case .valid:
            return nil
        }
    }
}

// MARK: - SwiftUI Integration

/// View modifier for real-time validation feedback
struct ValidationFeedback: ViewModifier {
    let validationState: TitleValidationState
    
    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            content
            
            if let message = validationState.message {
                Text(message)
                    .font(.caption)
                    .foregroundColor(validationState.isValid ? .secondary : .red)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: validationState.message)
    }
}

extension View {
    /// Add validation feedback to a view
    func validationFeedback(_ state: TitleValidationState) -> some View {
        modifier(ValidationFeedback(validationState: state))
    }
}