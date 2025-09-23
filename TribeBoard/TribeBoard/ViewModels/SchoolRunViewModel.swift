import SwiftUI
import Foundation

/// ViewModel for School Run tracking with mock GPS and navigation data
@MainActor
class SchoolRunViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// All school runs for the family
    @Published var schoolRuns: [SchoolRun] = []
    
    /// User profiles for displaying driver and passenger names
    @Published var userProfiles: [UUID: UserProfile] = [:]
    
    /// Loading state
    @Published var isLoading = false
    
    /// Error message
    @Published var errorMessage: String?
    
    /// Currently active tracking run
    @Published var activeTrackingRun: SchoolRun?
    
    /// Mock GPS tracking data
    @Published var trackingData: RouteTrackingData?
    
    /// Mock arrival notifications
    @Published var notifications: [SchoolRunNotification] = []
    
    // MARK: - Computed Properties
    
    /// Today's school runs
    var todaysRuns: [SchoolRun] {
        let calendar = Calendar.current
        let today = Date()
        
        return schoolRuns.filter { schoolRun in
            calendar.isDate(schoolRun.pickupTime, inSameDayAs: today)
        }
        .sorted { $0.pickupTime < $1.pickupTime }
    }
    
    /// Upcoming school runs (next 7 days, excluding today)
    var upcomingRuns: [SchoolRun] {
        let calendar = Calendar.current
        let today = Date()
        let nextWeek = calendar.date(byAdding: .day, value: 7, to: today) ?? today
        
        return schoolRuns.filter { schoolRun in
            !calendar.isDate(schoolRun.pickupTime, inSameDayAs: today) &&
            schoolRun.pickupTime > today &&
            schoolRun.pickupTime < nextWeek
        }
        .sorted { $0.pickupTime < $1.pickupTime }
    }
    
    // MARK: - Initialization
    
    init() {
        loadMockData()
    }
    
    // MARK: - Public Methods
    
    /// Load school runs with mock data
    func loadSchoolRuns() {
        isLoading = true
        errorMessage = nil
        
        // Simulate network delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.loadMockData()
            self.isLoading = false
        }
    }
    
    /// Start tracking a school run with mock GPS
    func startTracking(_ schoolRun: SchoolRun) {
        activeTrackingRun = schoolRun
        trackingData = generateMockTrackingData(for: schoolRun)
        
        // Start mock GPS updates
        startMockGPSUpdates()
        
        // Generate arrival notification
        generateArrivalNotification(for: schoolRun)
    }
    
    /// Stop tracking the current school run
    func stopTracking() {
        activeTrackingRun = nil
        trackingData = nil
    }
    
    /// Mark a school run as completed
    func completeRun(_ schoolRun: SchoolRun) {
        if let index = schoolRuns.firstIndex(where: { $0.id == schoolRun.id }) {
            var updatedRun = schoolRun
            updatedRun = SchoolRun(
                id: updatedRun.id,
                route: updatedRun.route,
                pickupTime: updatedRun.pickupTime,
                dropoffTime: updatedRun.dropoffTime,
                driver: updatedRun.driver,
                passengers: updatedRun.passengers,
                status: .completed,
                notes: updatedRun.notes
            )
            schoolRuns[index] = updatedRun
        }
        
        stopTracking()
    }
    
    // MARK: - Private Methods
    
    private func loadMockData() {
        // Load extended mock school runs
        schoolRuns = MockDataGenerator.mockExtendedSchoolRuns()
        
        // Load user profiles
        let (_, users, _) = MockDataGenerator.mockMawereFamily()
        userProfiles = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
        
        // Load mock notifications
        notifications = MockDataGenerator.mockSchoolRunNotifications()
    }
    

    
    private func generateMockTrackingData(for schoolRun: SchoolRun) -> RouteTrackingData {
        return RouteTrackingData(
            currentLocation: MockLocation(
                latitude: 34.0522,
                longitude: -118.2437,
                address: "Starting location"
            ),
            destination: MockLocation(
                latitude: 34.0622,
                longitude: -118.2337,
                address: schoolRun.route.components(separatedBy: " → ").last ?? "Destination"
            ),
            estimatedArrival: schoolRun.dropoffTime,
            distanceRemaining: 2.5,
            progress: 0.0,
            isNavigating: true
        )
    }
    
    private func startMockGPSUpdates() {
        guard trackingData != nil else { return }
        
        // Simulate GPS updates every 5 seconds
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { timer in
            Task { @MainActor in
                guard let activeRun = self.activeTrackingRun,
                      var tracking = self.trackingData else {
                    timer.invalidate()
                    return
                }
                
                // Update progress
                tracking.progress = min(tracking.progress + 0.1, 1.0)
                tracking.distanceRemaining = max(tracking.distanceRemaining - 0.3, 0.0)
                
                // Update current location (mock movement)
                let progressLat = tracking.destination.latitude - tracking.currentLocation.latitude
                let progressLng = tracking.destination.longitude - tracking.currentLocation.longitude
                
                tracking.currentLocation = MockLocation(
                    latitude: tracking.currentLocation.latitude + (progressLat * 0.1),
                    longitude: tracking.currentLocation.longitude + (progressLng * 0.1),
                    address: "En route"
                )
                
                self.trackingData = tracking
                
                // Complete when progress reaches 100%
                if tracking.progress >= 1.0 {
                    timer.invalidate()
                    self.completeRun(activeRun)
                }
            }
        }
    }
    
    private func generateArrivalNotification(for schoolRun: SchoolRun) {
        let notification = SchoolRunNotification(
            id: UUID(),
            title: "School Run Started",
            message: "Navigation started for \(schoolRun.route)",
            timestamp: Date(),
            type: .started,
            schoolRunId: schoolRun.id
        )
        
        notifications.append(notification)
        
        // Generate arrival notification after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            let arrivalNotification = SchoolRunNotification(
                id: UUID(),
                title: "Arriving Soon",
                message: "Estimated arrival in 2 minutes",
                timestamp: Date(),
                type: .arriving,
                schoolRunId: schoolRun.id
            )
            self.notifications.append(arrivalNotification)
        }
    }
}

// MARK: - Supporting Data Models

/// Mock GPS tracking data for school runs
struct RouteTrackingData {
    var currentLocation: MockLocation
    let destination: MockLocation
    let estimatedArrival: Date
    var distanceRemaining: Double // in miles
    var progress: Double // 0.0 to 1.0
    var isNavigating: Bool
}

/// Mock location data
struct MockLocation {
    let latitude: Double
    let longitude: Double
    let address: String
}

