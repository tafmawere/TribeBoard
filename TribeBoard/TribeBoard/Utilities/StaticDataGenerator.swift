import Foundation

/// Utility for generating static demonstration data for the School Run Scheduler
struct StaticDataGenerator {
    
    // MARK: - Static Data Generation
    
    /// Generates additional sample runs for demonstration purposes
    static func generateSampleRuns(count: Int = 5) -> [ScheduledSchoolRun] {
        var runs: [ScheduledSchoolRun] = []
        let baseDate = Date()
        
        let runTemplates: [(String, [RunStop.StopType])] = [
            ("Monday Morning Drop-off", [.home, .school, .ot, .home]),
            ("Tuesday Music Lessons", [.home, .music, .school, .home]),
            ("Wednesday Soccer Practice", [.home, .custom, .home]),
            ("Thursday Pickup Run", [.home, .school, .music, .ot, .home]),
            ("Friday Fun Day", [.home, .custom, .custom, .home]),
            ("Saturday Activities", [.home, .custom, .music, .home]),
            ("Sunday Family Time", [.home, .custom, .home])
        ]
        
        for i in 0..<min(count, runTemplates.count) {
            let template = runTemplates[i]
            let runDate = Calendar.current.date(byAdding: .day, value: i - 2, to: baseDate) ?? baseDate
            let runTime = Calendar.current.date(bySettingHour: 15 + (i % 3), minute: 30, second: 0, of: baseDate) ?? baseDate
            
            let stops = template.1.enumerated().map { index, stopType in
                createStopForType(stopType, index: index, totalStops: template.1.count)
            }
            
            let run = ScheduledSchoolRun(
                name: template.0,
                scheduledDate: runDate,
                scheduledTime: runTime,
                stops: stops,
                isCompleted: i < 2 // Mark first two as completed
            )
            
            runs.append(run)
        }
        
        return runs
    }
    
    /// Creates a realistic stop for a given type
    private static func createStopForType(_ type: RunStop.StopType, index: Int, totalStops: Int) -> RunStop {
        let locationNames: [RunStop.StopType: [String]] = [
            .home: ["Home"],
            .school: ["Riverside Elementary", "Oakwood Middle School", "Sunset High School", "Pine Valley Academy"],
            .ot: ["Children's OT Clinic", "Pediatric Wellness Center", "Therapy Plus", "Kids First Rehabilitation"],
            .music: ["Harmony Music School", "Melody Academy", "Sound Studio", "Creative Arts Center"],
            .custom: ["Soccer Complex", "Community Center", "Library", "Park", "Grocery Store", "Friend's House"]
        ]
        
        let tasks: [RunStop.StopType: [String]] = [
            .home: ["Gather items", "Get ready", "Load car", "Final check"],
            .school: ["Pick up", "Drop off", "Check in", "Wait for dismissal"],
            .ot: ["Drop off for therapy", "Pick up from session", "Check in with therapist"],
            .music: ["Drop off for lesson", "Pick up from practice", "Bring instrument"],
            .custom: ["Complete activity", "Quick stop", "Meet friend", "Run errand"]
        ]
        
        let durations: [RunStop.StopType: [Int]] = [
            .home: [3, 5, 7],
            .school: [8, 10, 12, 15],
            .ot: [10, 15, 20],
            .music: [8, 10, 12],
            .custom: [5, 8, 10, 12, 15]
        ]
        
        let locationName = locationNames[type]?.randomElement() ?? type.rawValue
        let task = tasks[type]?.randomElement() ?? "Complete stop"
        let duration = durations[type]?.randomElement() ?? 10
        
        // Assign children to some stops
        let assignedChild: ChildProfile? = {
            if type == .home || Int.random(in: 0...2) == 0 {
                return nil
            }
            return MockSchoolRunDataProvider.children.randomElement()
        }()
        
        return RunStop(
            name: locationName,
            type: type,
            assignedChild: assignedChild,
            task: task,
            estimatedMinutes: duration
        )
    }
    
    // MARK: - Static Location Data
    
    /// Generates realistic addresses for demonstration
    static func generateAddress(for stopType: RunStop.StopType) -> String {
        let streetNumbers = Array(100...9999)
        let streetNames = [
            "Main Street", "Oak Avenue", "Pine Lane", "Maple Drive", "Cedar Way",
            "Elm Street", "Birch Road", "Willow Court", "Aspen Boulevard", "Cherry Lane"
        ]
        
        let number = streetNumbers.randomElement() ?? 123
        let street = streetNames.randomElement() ?? "Main Street"
        
        return "\(number) \(street)"
    }
    
    /// Generates estimated arrival times
    static func generateEstimatedArrival(baseTime: Date, stopIndex: Int, estimatedMinutes: Int) -> String {
        let arrivalTime = baseTime.addingTimeInterval(TimeInterval(stopIndex * estimatedMinutes * 60))
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: arrivalTime)
    }
    
    // MARK: - Static Route Visualization Data
    
    /// Generates route visualization data for demonstration
    static func generateRouteData(for stops: [RunStop]) -> RouteVisualization {
        let totalMinutes = stops.reduce(0) { $0 + $1.estimatedMinutes }
        let totalDistance = Double.random(in: 5.0...25.0).rounded(toPlaces: 1)
        
        let waypoints = stops.enumerated().map { index, stop in
            // Generate mock coordinates around a central point
            let baseLat = 37.7749
            let baseLng = -122.4194
            let latOffset = Double.random(in: -0.05...0.05)
            let lngOffset = Double.random(in: -0.05...0.05)
            
            return Waypoint(
                name: stop.name,
                coordinate: (lat: baseLat + latOffset, lng: baseLng + lngOffset)
            )
        }
        
        return RouteVisualization(
            totalDistance: "\(totalDistance) miles",
            estimatedTime: "\(totalMinutes) minutes",
            waypoints: waypoints
        )
    }
    
    // MARK: - Static Navigation Updates
    
    /// Generates mock navigation updates for demonstration
    static func generateNavigationUpdate(for stop: RunStop, progress: Double) -> NavigationUpdate {
        let remainingDistance = (1.0 - progress) * Double.random(in: 0.5...5.0)
        let remainingMinutes = Int(remainingDistance * 3) // Rough estimate
        
        let trafficConditions = ["Light traffic", "Moderate traffic", "Heavy traffic", "Clear roads"].randomElement() ?? "Normal traffic"
        
        return NavigationUpdate(
            currentLocation: "En route to \(stop.name)",
            estimatedArrival: Date().addingTimeInterval(TimeInterval(remainingMinutes * 60)),
            distanceRemaining: "\(remainingDistance.rounded(toPlaces: 1)) miles",
            trafficConditions: trafficConditions
        )
    }
    
    // MARK: - Demo Data Presets
    
    /// Creates a comprehensive demo dataset
    static func createDemoDataset() -> [ScheduledSchoolRun] {
        var allRuns: [ScheduledSchoolRun] = []
        
        // Add the original sample runs
        allRuns.append(contentsOf: MockSchoolRunDataProvider.sampleRuns)
        
        // Add generated sample runs
        allRuns.append(contentsOf: generateSampleRuns(count: 3))
        
        return allRuns
    }
    
    /// Resets all data to fresh demo state
    static func resetToFreshDemoData() {
        // This would be called by the SchoolRunManager to reset to demo data
        UserDefaults.standard.removeObject(forKey: "school_runs")
        UserDefaults.standard.removeObject(forKey: "run_execution_states")
        UserDefaults.standard.removeObject(forKey: "current_stop_indices")
    }
}

