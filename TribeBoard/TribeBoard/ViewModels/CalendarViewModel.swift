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
    
    // MARK: - Enhanced Calendar Properties
    
    /// Current selected date for calendar view
    @Published var selectedDate = Date()
    
    /// Current event filter
    @Published var currentFilter: EventFilter = .all
    
    /// Current user ID for permission checking
    @Published var currentUserId: UUID?
    
    /// Current family ID for family events
    @Published var currentFamilyId: UUID?
    
    /// Calendar permissions for current user
    @Published var calendarPermissions: FamilyCalendarPermissions?
    
    /// Show event creation sheet
    @Published var showEventCreation = false
    
    /// Show event detail sheet
    @Published var showEventDetail = false
    
    /// Selected event for detail view
    @Published var selectedEvent: CalendarEvent?
    
    /// Event being edited
    @Published var editingEvent: CalendarEvent?
    
    /// Show event edit sheet
    @Published var showEventEdit = false
    
    // MARK: - Dependencies
    
    private let calendarService: CalendarService?
    private let familyCalendarService: FamilyCalendarIntegrationService?
    
    // MARK: - Initialization
    
    init(
        calendarService: CalendarService? = nil,
        familyCalendarService: FamilyCalendarIntegrationService? = nil
    ) {
        self.calendarService = calendarService
        self.familyCalendarService = familyCalendarService
        print("📅 CalendarViewModel: Initialized with enhanced calendar service integration")
    }
    
    // MARK: - Event Filter Enum
    
    enum EventFilter: String, CaseIterable {
        case all = "all"
        case family = "family"
        case personal = "personal"
        
        var displayName: String {
            switch self {
            case .all:
                return "All Events"
            case .family:
                return "Family Events"
            case .personal:
                return "Personal Events"
            }
        }
        
        var icon: String {
            switch self {
            case .all:
                return "calendar"
            case .family:
                return "person.2.fill"
            case .personal:
                return "person.fill"
            }
        }
    }
    
    // Computed properties for filtered data
    var todaysEvents: [CalendarEvent] {
        let today = Date()
        return allEvents.filter { Calendar.current.isDate($0.startDate, inSameDayAs: today) }
            .sorted { $0.startDate < $1.startDate }
    }
    
    var upcomingEvents: [CalendarEvent] {
        let today = Date()
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: today) ?? today
        
        return allEvents.filter { event in
            event.startDate > today && event.startDate <= nextWeek
        }
        .sorted { $0.startDate < $1.startDate }
    }
    
    var birthdaysThisMonth: [CalendarEvent] {
        let today = Date()
        let startOfMonth = Calendar.current.dateInterval(of: .month, for: today)?.start ?? today
        let endOfMonth = Calendar.current.dateInterval(of: .month, for: today)?.end ?? today
        
        return allEvents.filter { event in
            // For now, we'll simulate birthday events by checking if title contains "Birthday"
            event.title.lowercased().contains("birthday") && 
            event.startDate >= startOfMonth && 
            event.startDate <= endOfMonth
        }
        .sorted { $0.startDate < $1.startDate }
    }
    
    var thisWeeksSchoolRuns: [SchoolRun] {
        let today = Date()
        let startOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: today)?.start ?? today
        let endOfWeek = Calendar.current.dateInterval(of: .weekOfYear, for: today)?.end ?? today
        
        return schoolRuns.filter { schoolRun in
            schoolRun.date >= startOfWeek && schoolRun.date <= endOfWeek
        }
        .sorted(by: { $0.date < $1.date })
    }
    
    // MARK: - Filtered Event Methods
    
    func filteredTodaysEvents(filter: CalendarView.EventFilter) -> [CalendarEvent] {
        return applyEventFilter(todaysEvents, filter: filter)
    }
    
    func filteredUpcomingEvents(filter: CalendarView.EventFilter) -> [CalendarEvent] {
        return applyEventFilter(upcomingEvents, filter: filter)
    }
    
    func filteredBirthdaysThisMonth(filter: CalendarView.EventFilter) -> [CalendarEvent] {
        return applyEventFilter(birthdaysThisMonth, filter: filter)
    }
    
    func eventsForDate(_ date: Date, filter: CalendarView.EventFilter) -> [CalendarEvent] {
        let dateEvents = allEvents.filter { Calendar.current.isDate($0.startDate, inSameDayAs: date) }
            .sorted { $0.startDate < $1.startDate }
        return applyEventFilter(dateEvents, filter: filter)
    }
    
    func isEmpty(for filter: CalendarView.EventFilter) -> Bool {
        let filteredEvents = applyEventFilter(allEvents, filter: filter)
        return filteredEvents.isEmpty && (filter != .all || schoolRuns.isEmpty)
    }
    
    private func applyEventFilter(_ events: [CalendarEvent], filter: CalendarView.EventFilter) -> [CalendarEvent] {
        switch filter {
        case .all:
            return events
        case .family:
            return events.filter { $0.privacyLevel == .familyShared }
        case .personal:
            return events.filter { $0.privacyLevel == .personal }
        }
    }
    
    // MARK: - Enhanced Data Loading
    
    /// Load events using the enhanced calendar service with performance optimizations
    func loadEvents(for dateRange: DateInterval? = nil, forceRefresh: Bool = false) async {
        guard let calendarService = calendarService else {
            // Fallback to mock data if no service available
            loadMockData()
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let range = dateRange ?? defaultDateRange()
            
            // Use performance-optimized loading
            let events = try await calendarService.fetchEvents(for: range)
            
            allEvents = events
            
            // Load user permissions if user and family are set
            if let userId = currentUserId, let familyId = currentFamilyId {
                calendarPermissions = try await calendarService.getFamilyCalendarPermissions(
                    userId: userId,
                    familyId: familyId
                )
            }
            
            // Preload surrounding events for better UX
            if !forceRefresh {
                let centerDate = range.start.addingTimeInterval(range.duration / 2)
                await calendarService.preloadEvents(around: centerDate, userId: currentUserId, familyId: currentFamilyId)
            }
            
            print("✅ CalendarViewModel: Loaded \(events.count) events")
            
        } catch {
            errorMessage = "Failed to load calendar events: \(error.localizedDescription)"
            print("❌ CalendarViewModel: Failed to load events: \(error)")
        }
        
        isLoading = false
    }
    
    /// Load events with pagination support
    func loadEventsPaginated(for dateRange: DateInterval? = nil, pageSize: Int = 50) async {
        guard let calendarService = calendarService else {
            loadMockData()
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let range = dateRange ?? defaultDateRange()
            
            let result = try await calendarService.fetchEventsPaginated(
                for: range,
                pageSize: pageSize,
                sortBy: .startDate
            )
            
            allEvents = result.events
            
            print("✅ CalendarViewModel: Loaded \(result.events.count) events (paginated, has more: \(result.hasMorePages))")
            
        } catch {
            errorMessage = "Failed to load paginated events: \(error.localizedDescription)"
            print("❌ CalendarViewModel: Failed to load paginated events: \(error)")
        }
        
        isLoading = false
    }
    
    /// Load events for a specific user
    func loadEventsForUser(_ userId: UUID, familyId: UUID?, includeFamily: Bool = true) async {
        guard let calendarService = calendarService else {
            loadMockData()
            return
        }
        
        self.currentUserId = userId
        self.currentFamilyId = familyId
        
        isLoading = true
        errorMessage = nil
        
        do {
            let dateRange = defaultDateRange()
            let events = try await calendarService.fetchEventsForUser(
                userId,
                dateRange: dateRange,
                includeFamily: includeFamily
            )
            
            allEvents = events
            
            // Load permissions if family is available
            if let familyId = familyId {
                calendarPermissions = try await calendarService.getFamilyCalendarPermissions(
                    userId: userId,
                    familyId: familyId
                )
            }
            
            print("✅ CalendarViewModel: Loaded \(events.count) events for user")
            
        } catch {
            errorMessage = "Failed to load user events: \(error.localizedDescription)"
            print("❌ CalendarViewModel: Failed to load user events: \(error)")
        }
        
        isLoading = false
    }
    
    /// Load mock data (fallback)
    func loadMockData() {
        isLoading = true
        
        // Simulate loading delay for realistic experience
        Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            loadCalendarEvents()
            loadSchoolRuns()
            loadUserProfiles()
            isLoading = false
        }
    }
    
    private func loadCalendarEvents() {
        allEvents = MockDataGenerator.mockCalendarEvents().map { $0.toCalendarEvent() }
    }
    
    private func loadSchoolRuns() {
        schoolRuns = MockDataGenerator.mockSchoolRuns()
    }
    
    private func loadUserProfiles() {
        let (_, users, _) = MockDataGenerator.mockMawereFamily()
        userProfiles = Dictionary(uniqueKeysWithValues: users.map { ($0.id, $0) })
    }
    
    /// Get default date range (3 months back to 3 months forward)
    private func defaultDateRange() -> DateInterval {
        let now = Date()
        let start = Calendar.current.date(byAdding: .month, value: -3, to: now) ?? now
        let end = Calendar.current.date(byAdding: .month, value: 3, to: now) ?? now
        return DateInterval(start: start, end: end)
    }
    
    // MARK: - Performance Optimization Methods
    
    /// Searches events with optimized text search
    func searchEvents(searchText: String, limit: Int = 50) async {
        guard let calendarService = calendarService else { return }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let events = try await calendarService.searchEvents(
                searchText: searchText,
                dateRange: defaultDateRange(),
                userId: currentUserId,
                familyId: currentFamilyId,
                limit: limit
            )
            
            allEvents = events
            print("✅ CalendarViewModel: Found \(events.count) events matching '\(searchText)'")
            
        } catch {
            errorMessage = "Failed to search events: \(error.localizedDescription)"
            print("❌ CalendarViewModel: Failed to search events: \(error)")
        }
        
        isLoading = false
    }
    
    /// Gets calendar statistics
    func getCalendarStatistics() async -> CalendarAggregateStats? {
        guard let calendarService = calendarService else { return nil }
        
        do {
            let stats = try await calendarService.getCalendarStatistics(
                dateRange: defaultDateRange(),
                userId: currentUserId,
                familyId: currentFamilyId
            )
            
            print("📊 CalendarViewModel: Retrieved calendar statistics")
            return stats
            
        } catch {
            errorMessage = "Failed to get calendar statistics: \(error.localizedDescription)"
            print("❌ CalendarViewModel: Failed to get statistics: \(error)")
            return nil
        }
    }
    
    /// Finds conflicting events for a given event
    func findConflictingEvents(for event: CalendarEvent) async -> [CalendarEvent] {
        guard let calendarService = calendarService else { return [] }
        
        do {
            let conflicts = try await calendarService.findConflictingEvents(
                for: event,
                userId: currentUserId
            )
            
            print("⚠️ CalendarViewModel: Found \(conflicts.count) conflicting events")
            return conflicts
            
        } catch {
            print("❌ CalendarViewModel: Failed to find conflicts: \(error)")
            return []
        }
    }
    
    /// Optimizes calendar performance
    func optimizePerformance() async {
        guard let calendarService = calendarService else { return }
        
        await calendarService.optimizePerformance()
        print("🔧 CalendarViewModel: Performance optimization completed")
    }
    
    /// Gets performance metrics
    func getPerformanceMetrics() -> ComprehensivePerformanceMetrics? {
        guard let calendarService = calendarService else { return nil }
        
        return calendarService.getPerformanceMetrics()
    }
    
    /// Invalidates cache for current user/family
    func invalidateCache() {
        guard let calendarService = calendarService else { return }
        
        calendarService.invalidateCache(userId: currentUserId, familyId: currentFamilyId)
        print("🗑️ CalendarViewModel: Cache invalidated")
    }
    
    /// Processes background sync
    func processBackgroundSync() async {
        guard let calendarService = calendarService else { return }
        
        await calendarService.processBackgroundSync()
        print("🔄 CalendarViewModel: Background sync processed")
    }
    
    // MARK: - Enhanced Event Actions
    
    /// Create a new event
    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        location: String? = nil,
        notes: String? = nil,
        privacyLevel: CalendarEvent.PrivacyLevel = .personal
    ) async {
        guard let calendarService = calendarService,
              let userId = currentUserId else {
            showAddEventSuccess() // Fallback to mock behavior
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let event = CalendarEvent(
                title: title,
                startDate: startDate,
                endDate: endDate,
                isAllDay: isAllDay,
                location: location,
                notes: notes,
                privacyLevel: privacyLevel,
                createdBy: userId,
                familyId: privacyLevel == .familyShared ? currentFamilyId : nil
            )
            
            let createdEvent = try await calendarService.createEvent(event)
            
            // Add to local array
            allEvents.append(createdEvent)
            allEvents.sort { $0.startDate < $1.startDate }
            
            successMessage = "Event '\(title)' created successfully! 🎉"
            showEventCreation = false
            
            print("✅ CalendarViewModel: Created event: \(title)")
            
        } catch {
            errorMessage = "Failed to create event: \(error.localizedDescription)"
            print("❌ CalendarViewModel: Failed to create event: \(error)")
        }
        
        isLoading = false
        clearSuccessMessage()
    }
    
    /// Update an existing event
    func updateEvent(_ event: CalendarEvent) async {
        guard let calendarService = calendarService,
              let userId = currentUserId else {
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Set the modifier
            event.modifiedBy = userId
            
            let updatedEvent = try await calendarService.updateEvent(event)
            
            // Update in local array
            if let index = allEvents.firstIndex(where: { $0.id == updatedEvent.id }) {
                allEvents[index] = updatedEvent
            }
            
            successMessage = "Event updated successfully! ✅"
            showEventEdit = false
            editingEvent = nil
            
            print("✅ CalendarViewModel: Updated event: \(event.title)")
            
        } catch {
            errorMessage = "Failed to update event: \(error.localizedDescription)"
            print("❌ CalendarViewModel: Failed to update event: \(error)")
        }
        
        isLoading = false
        clearSuccessMessage()
    }
    
    /// Delete an event
    func deleteEvent(_ event: CalendarEvent) async {
        guard let calendarService = calendarService else {
            // Fallback to mock behavior
            allEvents.removeAll { $0.id == event.id }
            successMessage = "Event deleted successfully"
            clearSuccessMessage()
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try await calendarService.deleteEvent(event)
            
            // Remove from local array
            allEvents.removeAll { $0.id == event.id }
            
            successMessage = "Event deleted successfully"
            showEventDetail = false
            selectedEvent = nil
            
            print("✅ CalendarViewModel: Deleted event: \(event.title)")
            
        } catch {
            errorMessage = "Failed to delete event: \(error.localizedDescription)"
            print("❌ CalendarViewModel: Failed to delete event: \(error)")
        }
        
        isLoading = false
        clearSuccessMessage()
    }
    
    /// Share a personal event with family
    func shareEventWithFamily(_ event: CalendarEvent) async {
        guard let calendarService = calendarService,
              let userId = currentUserId,
              let familyId = currentFamilyId else {
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let sharedEvent = try await calendarService.shareEventWithFamily(
                event,
                familyId: familyId,
                sharedBy: userId
            )
            
            // Update in local array
            if let index = allEvents.firstIndex(where: { $0.id == sharedEvent.id }) {
                allEvents[index] = sharedEvent
            }
            
            successMessage = "Event shared with family! 👨‍👩‍👧‍👦"
            
            print("✅ CalendarViewModel: Shared event with family: \(event.title)")
            
        } catch {
            errorMessage = "Failed to share event: \(error.localizedDescription)"
            print("❌ CalendarViewModel: Failed to share event: \(error)")
        }
        
        isLoading = false
        clearSuccessMessage()
    }
    
    /// Unshare a family event (make it personal)
    func unshareEventFromFamily(_ event: CalendarEvent) async {
        guard let calendarService = calendarService,
              let userId = currentUserId else {
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let unsharedEvent = try await calendarService.unshareEventFromFamily(
                event,
                unsharedBy: userId
            )
            
            // Update in local array
            if let index = allEvents.firstIndex(where: { $0.id == unsharedEvent.id }) {
                allEvents[index] = unsharedEvent
            }
            
            successMessage = "Event made personal"
            
            print("✅ CalendarViewModel: Unshared event from family: \(event.title)")
            
        } catch {
            errorMessage = "Failed to unshare event: \(error.localizedDescription)"
            print("❌ CalendarViewModel: Failed to unshare event: \(error)")
        }
        
        isLoading = false
        clearSuccessMessage()
    }
    
    func showAddEventSuccess() {
        successMessage = "Add Event feature coming soon! 📅"
        clearSuccessMessage()
    }
    
    func refreshData() async {
        if calendarService != nil {
            await loadEvents()
        } else {
            loadMockData()
        }
    }
    
    /// Clear success message after delay
    private func clearSuccessMessage() {
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            successMessage = nil
        }
    }
    
    // MARK: - Enhanced Event Filtering and UI State
    
    /// Apply event filter
    func applyFilter(_ filter: EventFilter) {
        currentFilter = filter
        print("Applied filter: \(filter.rawValue)")
    }
    
    /// Load events for a specific date
    func loadEventsForDate(_ date: Date) async {
        selectedDate = date
        
        if let calendarService = calendarService {
            // Load events for the specific date range (day)
            let startOfDay = Calendar.current.startOfDay(for: date)
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? date
            let dateRange = DateInterval(start: startOfDay, end: endOfDay)
            
            await loadEvents(for: dateRange)
        } else {
            print("Loading events for date: \(date)")
        }
    }
    
    /// Show event creation sheet
    func showEventCreationSheet(for date: Date? = nil) {
        if let date = date {
            selectedDate = date
        }
        showEventCreation = true
    }
    
    /// Show event detail sheet
    func showEventDetailSheet(for event: CalendarEvent) {
        selectedEvent = event
        showEventDetail = true
    }
    
    /// Show event edit sheet
    func showEventEditSheet(for event: CalendarEvent) {
        editingEvent = event.createCopy()
        showEventEdit = true
    }
    
    /// Dismiss all sheets
    func dismissSheets() {
        showEventCreation = false
        showEventDetail = false
        showEventEdit = false
        selectedEvent = nil
        editingEvent = nil
    }
    
    /// Check if user can create events
    var canCreateEvents: Bool {
        return calendarPermissions?.canCreate ?? true // Default to true for mock data
    }
    
    /// Check if user can edit a specific event
    func canEditEvent(_ event: CalendarEvent) -> Bool {
        guard let userId = currentUserId else { return false }
        
        // User can edit their own events
        if event.createdBy == userId {
            return true
        }
        
        // Check family event permissions
        if event.privacyLevel == .familyShared {
            return calendarPermissions?.canModifyAll ?? false
        }
        
        return false
    }
    
    /// Check if user can delete a specific event
    func canDeleteEvent(_ event: CalendarEvent) -> Bool {
        guard let userId = currentUserId else { return false }
        
        // User can delete their own events
        if event.createdBy == userId {
            return true
        }
        
        // Check family event permissions
        if event.privacyLevel == .familyShared {
            return calendarPermissions?.canDeleteAll ?? false
        }
        
        return false
    }
    
    /// Check if user can share/unshare an event
    func canShareEvent(_ event: CalendarEvent) -> Bool {
        guard let userId = currentUserId else { return false }
        return event.createdBy == userId && currentFamilyId != nil
    }
    
    func schoolRunsForDate(_ date: Date) -> [SchoolRun] {
        return schoolRuns.filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .sorted(by: { $0.date < $1.date })
    }
    
    // MARK: - Legacy Event Management (Mock Actions)
    
    /// Legacy method for adding events (kept for compatibility)
    func addEvent(_ event: CalendarEvent) {
        if calendarService != nil {
            // Use the new async method
            Task {
                await createEvent(
                    title: event.title,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    isAllDay: event.isAllDay,
                    location: event.location,
                    notes: event.notes,
                    privacyLevel: event.privacyLevel
                )
            }
        } else {
            // Fallback to mock behavior
            allEvents.append(event)
            successMessage = "Event '\(event.title)' added successfully! 🎉"
            clearSuccessMessage()
        }
    }
    
    /// Legacy method for deleting events (kept for compatibility)
    func deleteEvent(_ event: CalendarEvent) {
        if calendarService != nil {
            // Use the new async method
            Task {
                await deleteEvent(event)
            }
        } else {
            // Fallback to mock behavior
            allEvents.removeAll { $0.id == event.id }
            successMessage = "Event deleted successfully"
            clearSuccessMessage()
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
            event.startDate >= startOfWeek && event.startDate <= endOfWeek
        }.count
    }
    
    var eventsThisMonth: Int {
        let today = Date()
        let startOfMonth = Calendar.current.dateInterval(of: .month, for: today)?.start ?? today
        let endOfMonth = Calendar.current.dateInterval(of: .month, for: today)?.end ?? today
        
        return allEvents.filter { event in
            event.startDate >= startOfMonth && event.startDate <= endOfMonth
        }.count
    }
    
    var upcomingBirthdays: Int {
        let today = Date()
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: today) ?? today
        
        return allEvents.filter { event in
            event.privacyLevel == .personal && event.startDate >= today && event.startDate <= nextMonth
        }.count
    }
}

// MARK: - Mock Error Handling

extension CalendarViewModel {
    func simulateNetworkError() {
        errorMessage = "Unable to load calendar events. Please check your connection and try again."
        
        // Clear error after delay
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            errorMessage = nil
        }
    }
    
    func simulateLoadingError() {
        errorMessage = "Something went wrong while loading your calendar. Please try again."
        
        // Clear error after delay
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            errorMessage = nil
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