import Foundation

/// Supporting data structures for static route visualization
struct RouteVisualization {
    let totalDistance: String
    let estimatedTime: String
    let waypoints: [Waypoint]
}

struct Waypoint {
    let name: String
    let coordinate: (lat: Double, lng: Double)
}

struct LocationInfo {
    let name: String
    let address: String
    let estimatedArrival: String
}

/// Provides static mock data for school run functionality including children, runs, and map placeholders
class MockSchoolRunDataProvider {
    
    // MARK: - Mock Children Profiles
    
    /// Static collection of sample children for demonstration purposes
    static let children: [ChildProfile] = [
        ChildProfile(name: "Emma", avatar: "person.circle.fill", age: 8),
        ChildProfile(name: "Liam", avatar: "person.circle.fill", age: 10),
        ChildProfile(name: "Sophia", avatar: "person.circle.fill", age: 6),
        ChildProfile(name: "Noah", avatar: "person.circle.fill", age: 12),
        ChildProfile(name: "Olivia", avatar: "person.circle.fill", age: 7)
    ]
    
    // MARK: - Mock School Runs
    
    /// Static collection of sample school runs for demonstration purposes
    static let sampleRuns: [ScheduledSchoolRun] = [
        // Thursday School Run
        ScheduledSchoolRun(
            name: "Thursday School Run",
            scheduledDate: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date(),
            scheduledTime: Calendar.current.date(bySettingHour: 15, minute: 30, second: 0, of: Date()) ?? Date(),
            stops: [
                RunStop(
                    name: "Home",
                    type: .home,
                    assignedChild: nil,
                    task: "Pick snacks & guitar",
                    estimatedMinutes: 5
                ),
                RunStop(
                    name: "Riverside Elementary",
                    type: .school,
                    assignedChild: children[0], // Emma
                    task: "Pick up Emma",
                    estimatedMinutes: 10
                ),
                RunStop(
                    name: "Children's OT Clinic",
                    type: .ot,
                    assignedChild: children[0], // Emma
                    task: "Drop Emma for therapy",
                    estimatedMinutes: 15
                ),
                RunStop(
                    name: "Harmony Music School",
                    type: .music,
                    assignedChild: children[1], // Liam
                    task: "Pick up Liam from piano lesson",
                    estimatedMinutes: 10
                ),
                RunStop(
                    name: "Children's OT Clinic",
                    type: .ot,
                    assignedChild: children[0], // Emma
                    task: "Pick up Emma from therapy",
                    estimatedMinutes: 15
                ),
                RunStop(
                    name: "Home",
                    type: .home,
                    assignedChild: nil,
                    task: "Return home with children",
                    estimatedMinutes: 10
                )
            ]
        ),
        
        // Weekend Soccer Run
        ScheduledSchoolRun(
            name: "Saturday Soccer Practice",
            scheduledDate: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date(),
            scheduledTime: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date(),
            stops: [
                RunStop(
                    name: "Home",
                    type: .home,
                    assignedChild: nil,
                    task: "Load soccer gear",
                    estimatedMinutes: 5
                ),
                RunStop(
                    name: "Sophia's House",
                    type: .custom,
                    assignedChild: children[2], // Sophia
                    task: "Pick up Sophia",
                    estimatedMinutes: 8
                ),
                RunStop(
                    name: "Greenfield Soccer Complex",
                    type: .custom,
                    assignedChild: nil,
                    task: "Drop off for practice",
                    estimatedMinutes: 12
                )
            ]
        ),
        
        // Music Lesson Run
        ScheduledSchoolRun(
            name: "Tuesday Music Lessons",
            scheduledDate: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            scheduledTime: Calendar.current.date(bySettingHour: 16, minute: 0, second: 0, of: Date()) ?? Date(),
            stops: [
                RunStop(
                    name: "Home",
                    type: .home,
                    assignedChild: nil,
                    task: "Get instruments",
                    estimatedMinutes: 3
                ),
                RunStop(
                    name: "Harmony Music School",
                    type: .music,
                    assignedChild: children[1], // Liam
                    task: "Drop Liam for piano",
                    estimatedMinutes: 10
                ),
                RunStop(
                    name: "Melody Academy",
                    type: .music,
                    assignedChild: children[4], // Olivia
                    task: "Drop Olivia for violin",
                    estimatedMinutes: 15
                )
            ],
            isCompleted: true
        )
    ]
    
    // MARK: - Static Route Data
    
    /// Static route visualization data for demonstration purposes
    static let routeData: [String: RouteVisualization] = [
        "thursday-school-run": RouteVisualization(
            totalDistance: "12.3 miles",
            estimatedTime: "45 minutes",
            waypoints: [
                Waypoint(name: "Home", coordinate: (lat: 37.7749, lng: -122.4194)),
                Waypoint(name: "Riverside Elementary", coordinate: (lat: 37.7849, lng: -122.4094)),
                Waypoint(name: "Children's OT Clinic", coordinate: (lat: 37.7949, lng: -122.3994)),
                Waypoint(name: "Harmony Music School", coordinate: (lat: 37.8049, lng: -122.3894)),
                Waypoint(name: "Home", coordinate: (lat: 37.7749, lng: -122.4194))
            ]
        ),
        "saturday-soccer": RouteVisualization(
            totalDistance: "8.7 miles",
            estimatedTime: "25 minutes",
            waypoints: [
                Waypoint(name: "Home", coordinate: (lat: 37.7749, lng: -122.4194)),
                Waypoint(name: "Sophia's House", coordinate: (lat: 37.7649, lng: -122.4294)),
                Waypoint(name: "Greenfield Soccer Complex", coordinate: (lat: 37.7549, lng: -122.4394))
            ]
        )
    ]
    
    /// Static location data for different stop types
    static let locationData: [RunStop.StopType: [LocationInfo]] = [
        .home: [
            LocationInfo(name: "Home", address: "123 Main St", estimatedArrival: "Now")
        ],
        .school: [
            LocationInfo(name: "Riverside Elementary", address: "456 School Ave", estimatedArrival: "3:45 PM"),
            LocationInfo(name: "Oakwood Middle School", address: "789 Education Blvd", estimatedArrival: "4:00 PM"),
            LocationInfo(name: "Sunset High School", address: "321 Learning Way", estimatedArrival: "4:15 PM")
        ],
        .ot: [
            LocationInfo(name: "Children's OT Clinic", address: "654 Therapy Lane", estimatedArrival: "4:30 PM"),
            LocationInfo(name: "Pediatric Wellness Center", address: "987 Health St", estimatedArrival: "4:45 PM")
        ],
        .music: [
            LocationInfo(name: "Harmony Music School", address: "147 Melody Ave", estimatedArrival: "5:00 PM"),
            LocationInfo(name: "Melody Academy", address: "258 Symphony Dr", estimatedArrival: "5:15 PM")
        ],
        .custom: [
            LocationInfo(name: "Soccer Complex", address: "369 Sports Way", estimatedArrival: "Variable"),
            LocationInfo(name: "Community Center", address: "741 Activity Blvd", estimatedArrival: "Variable")
        ]
    ]
    
    // MARK: - Helper Methods
    
    /// Returns a random child profile for testing purposes
    static func randomChild() -> ChildProfile {
        return children.randomElement() ?? children[0]
    }
    
    /// Creates a new empty run stop with default values
    static func createEmptyStop() -> RunStop {
        return RunStop(
            name: "",
            type: .custom,
            assignedChild: nil,
            task: "",
            estimatedMinutes: 5
        )
    }
    
    /// Creates a preset stop based on type with realistic data
    static func createPresetStop(type: RunStop.StopType, assignedChild: ChildProfile? = nil) -> RunStop {
        let locations = locationData[type] ?? []
        let location = locations.randomElement() ?? LocationInfo(name: type.rawValue, address: "Unknown", estimatedArrival: "TBD")
        
        let defaultTasks: [RunStop.StopType: String] = [
            .home: "Gather items and prepare",
            .school: "Pick up \(assignedChild?.name ?? "child")",
            .ot: "Drop off for therapy session",
            .music: "Drop off for lesson",
            .custom: "Complete activity"
        ]
        
        let defaultTimes: [RunStop.StopType: Int] = [
            .home: 5,
            .school: 10,
            .ot: 15,
            .music: 10,
            .custom: 12
        ]
        
        return RunStop(
            name: location.name,
            type: type,
            assignedChild: assignedChild,
            task: defaultTasks[type] ?? "Complete stop",
            estimatedMinutes: defaultTimes[type] ?? 10
        )
    }
    
    /// Returns upcoming runs (scheduled for future dates)
    static var upcomingRuns: [ScheduledSchoolRun] {
        return sampleRuns.filter { !$0.isCompleted && $0.scheduledDate >= Date() }
    }
    
    /// Returns past runs (completed or scheduled for past dates)
    static var pastRuns: [ScheduledSchoolRun] {
        return sampleRuns.filter { $0.isCompleted || $0.scheduledDate < Date() }
    }
    
    /// Returns all runs sorted by scheduled date
    static var allRunsSorted: [ScheduledSchoolRun] {
        return sampleRuns.sorted { $0.scheduledDate < $1.scheduledDate }
    }
    
    /// Returns route visualization data for a specific run
    static func getRouteVisualization(for runName: String) -> RouteVisualization? {
        let key = runName.lowercased().replacingOccurrences(of: " ", with: "-")
        return routeData[key]
    }
    
    /// Returns location information for a specific stop type
    static func getLocationInfo(for stopType: RunStop.StopType) -> [LocationInfo] {
        return locationData[stopType] ?? []
    }
    
    /// Generates realistic estimated arrival times based on current time and stop sequence
    static func generateEstimatedTimes(for stops: [RunStop], startTime: Date = Date()) -> [Date] {
        var estimatedTimes: [Date] = []
        var currentTime = startTime
        
        for stop in stops {
            currentTime = currentTime.addingTimeInterval(TimeInterval(stop.estimatedMinutes * 60))
            estimatedTimes.append(currentTime)
        }
        
        return estimatedTimes
    }
    
    /// Creates a sample run with realistic data for testing
    static func createSampleRun(name: String, date: Date, time: Date) -> ScheduledSchoolRun {
        let sampleStops = [
            createPresetStop(type: .home),
            createPresetStop(type: .school, assignedChild: children.randomElement()),
            createPresetStop(type: .ot, assignedChild: children.randomElement()),
            createPresetStop(type: .home)
        ]
        
        return ScheduledSchoolRun(
            name: name,
            scheduledDate: date,
            scheduledTime: time,
            stops: sampleStops
        )
    }
}