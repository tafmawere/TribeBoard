import Foundation
import SwiftUI

/// Utility for validating that all static content is properly configured for demonstration
struct StaticContentValidator {
    
    // MARK: - Validation Results
    
    struct ValidationResult {
        let isValid: Bool
        let issues: [String]
        let summary: String
    }
    
    // MARK: - Main Validation
    
    /// Validates all static content components
    static func validateStaticContent() -> ValidationResult {
        var issues: [String] = []
        
        // Validate mock data
        issues.append(contentsOf: validateMockData())
        
        // Validate UserDefaults storage
        issues.append(contentsOf: validateUserDefaultsStorage())
        
        // Validate static data generation
        issues.append(contentsOf: validateStaticDataGeneration())
        
        // Validate map placeholders
        issues.append(contentsOf: validateMapPlaceholders())
        
        let isValid = issues.isEmpty
        let summary = isValid ? 
            "✅ All static content is properly configured" : 
            "⚠️ Found \(issues.count) issues with static content"
        
        return ValidationResult(isValid: isValid, issues: issues, summary: summary)
    }
    
    // MARK: - Individual Validators
    
    private static func validateMockData() -> [String] {
        var issues: [String] = []
        
        // Check children data
        if MockSchoolRunDataProvider.children.isEmpty {
            issues.append("No mock children data available")
        }
        
        // Check sample runs
        if MockSchoolRunDataProvider.sampleRuns.isEmpty {
            issues.append("No sample runs available")
        }
        
        // Validate run data structure
        for run in MockSchoolRunDataProvider.sampleRuns {
            if run.stops.isEmpty {
                issues.append("Run '\(run.name)' has no stops")
            }
            
            if run.name.isEmpty {
                issues.append("Found run with empty name")
            }
        }
        
        return issues
    }
    
    private static func validateUserDefaultsStorage() -> [String] {
        var issues: [String] = []
        
        // Test encoding/decoding of runs
        let testRun = MockSchoolRunDataProvider.sampleRuns.first
        if let run = testRun {
            do {
                let encoded = try JSONEncoder().encode([run])
                let decoded = try JSONDecoder().decode([ScheduledSchoolRun].self, from: encoded)
                
                if decoded.isEmpty || decoded[0].name != run.name {
                    issues.append("UserDefaults encoding/decoding test failed")
                }
            } catch {
                issues.append("UserDefaults JSON encoding/decoding error: \(error.localizedDescription)")
            }
        }
        
        return issues
    }
    
    private static func validateStaticDataGeneration() -> [String] {
        var issues: [String] = []
        
        // Test static data generator
        let generatedRuns = StaticDataGenerator.generateSampleRuns(count: 3)
        
        if generatedRuns.isEmpty {
            issues.append("StaticDataGenerator produced no runs")
        }
        
        if generatedRuns.count != 3 {
            issues.append("StaticDataGenerator produced \(generatedRuns.count) runs instead of 3")
        }
        
        // Validate generated run structure
        for run in generatedRuns {
            if run.stops.isEmpty {
                issues.append("Generated run '\(run.name)' has no stops")
            }
            
            if run.estimatedDuration <= 0 {
                issues.append("Generated run '\(run.name)' has invalid duration")
            }
        }
        
        return issues
    }
    
    private static func validateMapPlaceholders() -> [String] {
        var issues: [String] = []
        
        // Since we're using programmatic generation, validate that the view can be created
        let testStop = RunStop(name: "Test", type: .home, task: "Test", estimatedMinutes: 5)
        
        // Test that map placeholder views can be instantiated
        let _ = SchoolRunMapPlaceholder(currentStop: testStop, showCurrentLocation: true, mapStyle: .overview)
        let _ = SchoolRunMapPlaceholder(currentStop: testStop, showCurrentLocation: true, mapStyle: .execution)
        let _ = MapPlaceholderThumbnail(for: .home)
        
        // If we get here without crashing, the views are properly configured
        
        return issues
    }
    
    // MARK: - Performance Validation
    
    /// Validates that static content performs well
    static func validatePerformance() -> ValidationResult {
        var issues: [String] = []
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Test data loading performance
        let _ = MockSchoolRunDataProvider.sampleRuns
        let _ = MockSchoolRunDataProvider.children
        let _ = StaticDataGenerator.generateSampleRuns(count: 10)
        
        let loadTime = CFAbsoluteTimeGetCurrent() - startTime
        
        if loadTime > 0.1 { // 100ms threshold
            issues.append("Static data loading took \(String(format: "%.3f", loadTime))s (should be < 0.1s)")
        }
        
        let isValid = issues.isEmpty
        let summary = isValid ? 
            "✅ Static content performance is acceptable (\(String(format: "%.3f", loadTime))s)" : 
            "⚠️ Performance issues detected"
        
        return ValidationResult(isValid: isValid, issues: issues, summary: summary)
    }
    
    // MARK: - Demo Data Validation
    
    /// Validates that demo data is realistic and comprehensive
    static func validateDemoDataQuality() -> ValidationResult {
        var issues: [String] = []
        
        let demoDataset = StaticDataGenerator.createDemoDataset()
        
        // Check variety
        let stopTypes = Set(demoDataset.flatMap { $0.stops.map { $0.type } })
        if stopTypes.count < 4 {
            issues.append("Demo data lacks variety in stop types (only \(stopTypes.count) types)")
        }
        
        // Check realistic durations
        let durations = demoDataset.flatMap { $0.stops.map { $0.estimatedMinutes } }
        let averageDuration = durations.reduce(0, +) / durations.count
        
        if averageDuration < 3 || averageDuration > 30 {
            issues.append("Unrealistic average stop duration: \(averageDuration) minutes")
        }
        
        // Check child assignments
        let assignedChildren = demoDataset.flatMap { $0.stops.compactMap { $0.assignedChild } }
        if assignedChildren.isEmpty {
            issues.append("No children assigned to any stops in demo data")
        }
        
        let isValid = issues.isEmpty
        let summary = isValid ? 
            "✅ Demo data quality is good (\(demoDataset.count) runs, \(stopTypes.count) stop types)" : 
            "⚠️ Demo data quality issues detected"
        
        return ValidationResult(isValid: isValid, issues: issues, summary: summary)
    }
    
    // MARK: - Complete Validation
    
    /// Runs all validations and returns a comprehensive report
    static func runCompleteValidation() -> (overall: ValidationResult, details: [String: ValidationResult]) {
        let contentValidation = validateStaticContent()
        let performanceValidation = validatePerformance()
        let qualityValidation = validateDemoDataQuality()
        
        let allIssues = contentValidation.issues + performanceValidation.issues + qualityValidation.issues
        let overallValid = allIssues.isEmpty
        
        let overallResult = ValidationResult(
            isValid: overallValid,
            issues: allIssues,
            summary: overallValid ? 
                "✅ All static content validations passed" : 
                "⚠️ Found \(allIssues.count) total issues across all validations"
        )
        
        let details: [String: ValidationResult] = [
            "Content": contentValidation,
            "Performance": performanceValidation,
            "Quality": qualityValidation
        ]
        
        return (overall: overallResult, details: details)
    }
}

// MARK: - Debug Helper

#if DEBUG
extension StaticContentValidator {
    /// Prints a detailed validation report to the console
    static func printValidationReport() {
        let (overall, details) = runCompleteValidation()
        
        print("\n" + String(repeating: "=", count: 50))
        print("STATIC CONTENT VALIDATION REPORT")
        print(String(repeating: "=", count: 50))
        
        print("\nOVERALL: \(overall.summary)")
        
        for (category, result) in details {
            print("\n\(category.uppercased()):")
            print("  \(result.summary)")
            
            if !result.issues.isEmpty {
                print("  Issues:")
                for issue in result.issues {
                    print("    • \(issue)")
                }
            }
        }
        
        print("\n" + String(repeating: "=", count: 50) + "\n")
    }
}
#endif