import Foundation

/// Utility class for validating school run data and configurations
struct RunValidation {
    
    /// Validates a school run and returns any validation errors found
    /// - Parameter run: The SchoolRun to validate
    /// - Returns: Array of ValidationError cases found during validation
    static func validateRun(_ run: SchoolRun) -> [ValidationError] {
        var errors: [ValidationError] = []
        
        // Validate run title
        if run.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(.emptyRunName)
        }
        
        // Validate stops exist
        if run.route.isEmpty {
            errors.append(.noStops)
        }
        
        // Validate individual stops
        for (index, stop) in run.route.enumerated() {
            // Check stop name
            if stop.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(.emptyStopName(stopIndex: index + 1))
            }
            
            // Note: Duration and task validation removed as RunStop structure has changed
            // The new RunStop uses time and note properties instead of estimatedMinutes and task
        }
        
        // Validate total run duration using estimatedDuration property
        if run.estimatedDuration > 14400 { // 4 hours in seconds
            errors.append(.excessiveTotalDuration)
        }
        
        // Check for duplicate stop names (potential user error)
        let stopNames = run.route.map { $0.name.lowercased() }
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
            
            // Note: Duration validation removed as RunStop no longer has estimatedMinutes
            // Note: Task validation removed as RunStop no longer has task property
            // The new RunStop structure uses time and note properties instead
        }
        
        return errors
    }
}