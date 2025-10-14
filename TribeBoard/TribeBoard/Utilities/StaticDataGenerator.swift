import Foundation

/// Utility for generating static school run data for testing and demonstration
/// Note: Temporarily simplified to avoid compilation issues during development
struct StaticDataGenerator {
    
    /// Generates additional sample runs for demonstration purposes
    static func generateSampleRuns(count: Int = 5) -> [SchoolRun] {
        var runs: [SchoolRun] = []
        let baseDate = Date()
        
        let runTemplates = [
            "Morning School Run",
            "Afternoon Pickup",
            "Soccer Practice Drop-off",
            "Music Lesson Transport",
            "Weekend Activity Run"
        ]
        
        for i in 0..<min(count, runTemplates.count) {
            let title = runTemplates[i]
            let runDate = Calendar.current.date(byAdding: .day, value: i - 2, to: baseDate) ?? baseDate
            let runTime = Calendar.current.date(bySettingHour: 15 + (i % 3), minute: 30, second: 0, of: runDate) ?? runDate
            
            let stops = [
                RunStop(name: "Home", time: runTime, note: "Starting point", type: .pickup, task: "Starting point", estimatedMinutes: 5),
                RunStop(name: "School", time: runTime.addingTimeInterval(1800), note: "Destination", type: .dropoff, task: "Destination", estimatedMinutes: 10)
            ]
            
            let run = SchoolRun(
                title: title,
                date: runDate,
                route: stops,
                status: i < 2 ? .completed : .scheduled
            )
            
            runs.append(run)
        }
        
        return runs
    }
    
    // MARK: - Demo Data Presets
    
    /// Creates a comprehensive demo dataset
    static func createDemoDataset() -> [SchoolRun] {
        var allRuns: [SchoolRun] = []
        
        // Add the original sample runs
        allRuns.append(contentsOf: MockSchoolRunDataProvider.sampleRuns)
        
        // Add generated sample runs
        allRuns.append(contentsOf: generateSampleRuns(count: 3))
        
        return allRuns
    }
}