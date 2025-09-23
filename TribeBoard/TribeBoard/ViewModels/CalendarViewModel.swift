import SwiftUI
import Foundation

@MainActor
class CalendarViewModel: ObservableObject {
    @Published var allEvents: [CalendarEvent] = []
    @Published var schoolRuns: [SchoolRun] = []
    @Published var userProfiles: [UUID: UserProfile] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // Computed properties for filtered data
    var todaysEvents: [CalendarEvent] {
        let today = Date()
        return allEvents.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }
            .sorted { $0.date < $1.date }
    }
    
    var upcomingEvents: [CalendarEvent] {
        let today = Date()
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: today) ?? today
        
        return allEvents.filter { event in
            event.date > today && event.date <= nextWeek
        }
        .sorted { $0.date < $1.date }
    }
    
    var birthdaysThisMonth: [CalendarEvent] {
        let today = Date()
        let startOfMonth = Calendar.current.dateInterval(of: .month, for: today)?.start ?? today
        let endOfMonth = Calendar.current.dateInterval(of: .month, for: today)?.end ?? today
        
        return allEvents.filter { event in
            event.type == .birthday && 
            event.date >= startOfMonth && 
            event.date <= endOfMonth
        }
        .sorted { $0.date < $1.date }
    }
    
    var thisWeeksSchoolRuns: [SchoolRun] {
        let today = Date()
        let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let endOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: today)?.end ?? today
        
        return schoolRuns.filter { schoolRun in
            schoolRun.pickupTime >= startOfWeek && schoolRun.pickupTime <= endOfWeek
        }
        .sorted { $0.pickupTime < $1.pickupTime }
    }
    
    // MARK: - Mock Data Loading
    
    func loadMockData() {
        isLoading = true
        
        // Simulate loading delay for realistic experience
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.loadCalendarEvents()
            self.loadSchoolRuns()
            self.loadUserProfiles()
            self.isLoading = false
        }
    }
    
    private func loadCalendarEvents() {
        allEvents = MockDataGenerator.mockCalendarEvents()
    }
    
    private func loadSchoolRuns() {
        schoolRuns = MockDataGenerator.mockSchoolRuns()
    }
    
    private func loadUserProfiles() {
        let (_, users, _) = MockDataGenerator.mockMawereFamily()
        userProfiles = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
    }
    
    // MARK: - Event Actions
    
    func showAddEventSuccess() {
        successMessage = "Add Event feature coming soon! 📅"
        
        // Clear message after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.successMessage = nil
        }
    }
    
    func refreshData() {
        loadMockData()
    }
    
    // MARK: - Event Filtering
    
    func eventsForDate(_ date: Date) -> [CalendarEvent] {
        return allEvents.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date < $1.date }
    }
    
    func schoolRunsForDate(_ date: Date) -> [SchoolRun] {
        return schoolRuns.filter { Calendar.current.isDate($0.pickupTime, inSameDayAs: date) }
            .sorted { $0.pickupTime < $1.pickupTime }
    }
    
    // MARK: - Event Management (Mock Actions)
    
    func addEvent(title: String, date: Date, type: CalendarEvent.EventType, description: String? = nil, location: String? = nil) {
        let newEvent = CalendarEvent(
            id: UUID(),
            title: title,
            date: date,
            type: type,
            participants: [], // Empty for now
            description: description,
            location: location
        )
        
        allEvents.append(newEvent)
        successMessage = "Event '\(title)' added successfully! 🎉"
        
        // Clear message after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.successMessage = nil
        }
    }
    
    func deleteEvent(_ event: CalendarEvent) {
        allEvents.removeAll { $0.id == event.id }
        successMessage = "Event deleted successfully"
        
        // Clear message after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.successMessage = nil
        }
    }
    
    // MARK: - User Profile Helpers
    
    func userName(for userId: UUID) -> String {
        return userProfiles[userId]?.displayName ?? "Unknown User"
    }
    
    func participantNames(for event: CalendarEvent) -> [String] {
        return event.participants.compactMap { userProfiles[$0]?.displayName }
    }
    
    // MARK: - Statistics
    
    var eventsThisWeek: Int {
        let today = Date()
        let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let endOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: today)?.end ?? today
        
        return allEvents.filter { event in
            event.date >= startOfWeek && event.date <= endOfWeek
        }.count
    }
    
    var eventsThisMonth: Int {
        let today = Date()
        let startOfMonth = Calendar.current.dateInterval(of: .month, for: today)?.start ?? today
        let endOfMonth = Calendar.current.dateInterval(of: .month, for: today)?.end ?? today
        
        return allEvents.filter { event in
            event.date >= startOfMonth && event.date <= endOfMonth
        }.count
    }
    
    var upcomingBirthdays: Int {
        let today = Date()
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: today) ?? today
        
        return allEvents.filter { event in
            event.type == .birthday && event.date >= today && event.date <= nextMonth
        }.count
    }
}

// MARK: - Mock Error Handling

extension CalendarViewModel {
    func simulateNetworkError() {
        errorMessage = "Unable to load calendar events. Please check your connection and try again."
        
        // Clear error after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.errorMessage = nil
        }
    }
    
    func simulateLoadingError() {
        errorMessage = "Something went wrong while loading your calendar. Please try again."
        
        // Clear error after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.errorMessage = nil
        }
    }
}

// MARK: - Preview Helper

#if DEBUG
extension CalendarViewModel {
    static let preview: CalendarViewModel = {
        let viewModel = CalendarViewModel()
        viewModel.loadMockData()
        return viewModel
    }()
}
#endif