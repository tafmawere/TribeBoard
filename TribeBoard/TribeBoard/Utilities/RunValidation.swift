import Foundation

/// Utility class for validating school run data and configurations
struct RunValidation {
    
    /// Validates a school run and returns any validation errors found
    /// - Parameter run: The SchoolRun to validate
    /// - Returns: Array of ValidationError cases found during validation
    static func validateRun(_ run: ScheduledSchoolRun) -> [ValidationError] {
        var errors: [ValidationError] = []
        
        // Validate run name
        if run.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyRunName)
        }
        
        // Validate stops exist
        if run.stops.isEmpty {
            errors.append(.noStops)
        }
        
        // Validate individual stops
        for (index, stop) in run.stops.enumerated() {
            // Check stop name
            if stop.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(.emptyStopName(stopIndex: index + 1))
            }
            
            // Check estimated duration
            if stop.estimatedMinutes <= 0 {
                errors.append(.invalidStopDuration(stopIndex: index + 1))
            }
            
            // Check if duration is unreasonably long (over 2 hours)
            if stop.estimatedMinutes > 120 {
                errors.append(.excessiveStopDuration(stopIndex: index + 1))
            }
            
            // Check task description
            if stop.task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(.emptyStopTask(stopIndex: index + 1))
            }
        }
        
        // Validate total run duration isn't excessive (over 4 hours)
        let totalMinutes = run.stops.reduce(0) { $0 + $1.estimatedMinutes }
        if totalMinutes > 240 {
            errors.append(.excessiveTotalDuration)
        }
        
        // Check for duplicate stop names (potential user error)
        let stopNames = run.stops.map { $0.name.lowercased() }
        let uniqueNames = Set(stopNames)
        if stopNames.count != uniqueNames.count {
            errors.append(.duplicateStopNames)
        }
        
        return errors
    }
    
    /// Validates form data before creating a SchoolRun object
    /// - Parameters:
    ///   - name: Run name string
    ///   - stops: Array of RunStop objects
    /// - Returns: Array of ValidationError cases found during validation
    static func validateFormData(name: String, stops: [RunStop]) -> [ValidationError] {
        var errors: [ValidationError] = []
        
        // Validate run name
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyRunName)
        }
        
        // Validate stops exist
        if stops.isEmpty {
            errors.append(.noStops)
        }
        
        // Validate individual stops
        for (index, stop) in stops.enumerated() {
            if stop.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(.emptyStopName(stopIndex: index + 1))
            }
            
            if stop.estimatedMinutes <= 0 {
                errors.append(.invalidStopDuration(stopIndex: index + 1))
            }
            
            if stop.estimatedMinutes > 120 {
                errors.append(.excessiveStopDuration(stopIndex: index + 1))
            }
            
            if stop.task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(.emptyStopTask(stopIndex: index + 1))
            }
        }
        
        return errors
    }
}