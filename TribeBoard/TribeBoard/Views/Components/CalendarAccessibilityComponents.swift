import SwiftUI
import Foundation

// MARK: - Calendar Accessibility Components

/// Enhanced calendar view with comprehensive accessibility support
struct AccessibleCalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @State private var selectedDate = Date()
    @State private var selectedEvent: CalendarEvent?
    @State private var showingEventDetail = false
    @State private var showingEventCreation = false
    @State private var showingEventEdit = false
    @State private var eventFilter: CalendarView.EventFilter = .all
    @State private var isRefreshing = false
    
    // Accessibility state
    @State private var lastAnnouncedDate: Date?
    @State private var lastAnnouncedFilter: CalendarView.EventFilter?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Accessible Calendar Header
                AccessibleCalendarHeaderView(
                    selectedDate: $selectedDate,
                    onDateSelected: handleDateSelection,
                    onCreateEvent: handleCreateEvent
                )
                
                // Accessible Event Filter
                AccessibleEventFilterPicker(
                    selectedFilter: $eventFilter,
                    onFilterChanged: handleFilterChange
                )
                
                // Accessible Events List
                AccessibleEventsScrollView(
                    selectedDate: selectedDate,
                    eventFilter: eventFilter,
                    viewModel: viewModel,
                    isRefreshing: isRefreshing,
                    onEventTap: handleEventTap,
                    onRefresh: performRefresh
                )
            }
            .navigationTitle("Family Calendar")
            .navigationBarTitleDisplayMode(.large)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Family Calendar")
            .accessibilityHint("Navigate through calendar events and create new events")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    AccessibleButton(
                        action: { Task { await performRefresh() } },
                        label: "Refresh calendar",
                        hint: "Sync calendar with latest events",
                        hapticStyle: .light
                    ) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    AccessibleButton(
                        action: handleCreateEvent,
                        label: "Create new event",
                        hint: "Add a new event to your calendar",
                        hapticStyle: .medium
                    ) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEventCreation) {
                AccessibleEventCreationView()
            }
            .sheet(isPresented: $showingEventDetail) {
                if let event = selectedEvent {
                    AccessibleEventDetailView(
                        event: event,
                        userProfiles: viewModel.userProfiles,
                        onEdit: handleEventEdit,
                        onDelete: handleEventDelete
                    )
                }
            }
            .sheet(isPresented: $showingEventEdit) {
                if let event = selectedEvent {
                    AccessibleEventEditView(event: event)
                }
            }
            .onAppear {
                viewModel.loadMockData()
                announceCalendarLoad()
            }
            .onChange(of: selectedDate) { _, newDate in
                announceSelectedDate(newDate)
            }
            .onChange(of: eventFilter) { _, newFilter in
                announceFilterChange(newFilter)
            }
        }
    }
    
    // MARK: - Event Handlers
    
    private func handleDateSelection(_ date: Date) {
        selectedDate = date
        viewModel.loadEventsForDate(date)
        HapticManager.shared.selection()
    }
    
    private func handleCreateEvent() {
        showingEventCreation = true
        HapticManager.shared.lightImpact()
    }
    
    private func handleFilterChange(_ filter: CalendarView.EventFilter) {
        eventFilter = filter
        viewModel.applyFilter(filter)
        HapticManager.shared.lightImpact()
    }
    
    private func handleEventTap(_ event: CalendarEvent) {
        selectedEvent = event
        showingEventDetail = true
        HapticManager.shared.selection()
    }
    
    private func handleEventEdit(_ event: CalendarEvent) {
        selectedEvent = event
        showingEventDetail = false
        showingEventEdit = true
        HapticManager.shared.lightImpact()
    }
    
    private func handleEventDelete(_ event: CalendarEvent) {
        viewModel.deleteEvent(event)
        showingEventDetail = false
        HapticManager.shared.warning()
        
        // Announce deletion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UIAccessibility.post(
                notification: .announcement,
                argument: "Event '\(event.title)' deleted"
            )
        }
    }
    
    private func performRefresh() async {
        isRefreshing = true
        
        // Simulate sync operation
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        
        await MainActor.run {
            viewModel.refreshData()
            isRefreshing = false
            HapticManager.shared.success()
            
            // Announce refresh completion
            UIAccessibility.post(
                notification: .announcement,
                argument: "Calendar refreshed"
            )
        }
    }
    
    // MARK: - Accessibility Announcements
    
    private func announceCalendarLoad() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let eventCount = viewModel.allEvents.count
            let message = "Calendar loaded with \(eventCount) events"
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
    
    private func announceSelectedDate(_ date: Date) {
        guard lastAnnouncedDate != date else { return }
        lastAnnouncedDate = date
        
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        let dateString = formatter.string(from: date)
        
        let events = viewModel.eventsForDate(date, filter: eventFilter)
        let eventCount = events.count
        
        let message = if eventCount == 0 {
            "Selected \(dateString), no events"
        } else if eventCount == 1 {
            "Selected \(dateString), 1 event"
        } else {
            "Selected \(dateString), \(eventCount) events"
        }
        
        UIAccessibility.post(notification: .announcement, argument: message)
    }
    
    private func announceFilterChange(_ filter: CalendarView.EventFilter) {
        guard lastAnnouncedFilter != filter else { return }
        lastAnnouncedFilter = filter
        
        let filteredEvents = viewModel.isEmpty(for: filter) ? 0 : viewModel.allEvents.count
        let message = "Showing \(filter.rawValue.lowercased()) events, \(filteredEvents) total"
        
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}

// MARK: - Accessible Calendar Header

struct AccessibleCalendarHeaderView: View {
    @Binding var selectedDate: Date
    let onDateSelected: (Date) -> Void
    let onCreateEvent: () -> Void
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                AccessibleText(
                    dateFormatter.string(from: selectedDate),
                    style: .title2,
                    weight: .semibold
                )
                .accessibilityLabel("Current month: \(dateFormatter.string(from: selectedDate))")
                
                Spacer()
                
                HStack(spacing: 12) {
                    AccessibleButton(
                        action: {
                            selectedDate = Date()
                            onDateSelected(Date())
                        },
                        label: "Go to today",
                        hint: "Navigate to today's date",
                        hapticStyle: .light
                    ) {
                        AccessibleText("Today", style: .subheadline, weight: .medium, color: .blue)
                    }
                    
                    AccessibleButton(
                        action: onCreateEvent,
                        label: "Create event for selected date",
                        hint: "Add a new event on \(DateFormatter.accessibilityDate.string(from: selectedDate))",
                        hapticStyle: .medium
                    ) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal)
            
            // Enhanced Mini Calendar with Accessibility
            AccessibleCalendarMiniView(
                selectedDate: $selectedDate,
                onDateSelected: onDateSelected
            )
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Accessible Mini Calendar

struct AccessibleCalendarMiniView: View {
    @Binding var selectedDate: Date
    let onDateSelected: (Date) -> Void
    @State private var currentWeekOffset = 0
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private var weekDates: [Date] {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        let offsetWeek = calendar.date(byAdding: .weekOfYear, value: currentWeekOffset, to: startOfWeek) ?? startOfWeek
        
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: offsetWeek)
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Week navigation with accessibility
            HStack {
                AccessibleButton(
                    action: {
                        currentWeekOffset -= 1
                        HapticManager.shared.selection()
                    },
                    label: "Previous week",
                    hint: "Navigate to previous week",
                    hapticStyle: .light
                ) {
                    Image(systemName: "chevron.left")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                AccessibleText(
                    weekRangeText,
                    style: .subheadline,
                    weight: .medium
                )
                .accessibilityLabel("Week of \(weekRangeText)")
                
                Spacer()
                
                AccessibleButton(
                    action: {
                        currentWeekOffset += 1
                        HapticManager.shared.selection()
                    },
                    label: "Next week",
                    hint: "Navigate to next week",
                    hapticStyle: .light
                ) {
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            VStack(spacing: 8) {
                // Weekday headers with accessibility
                HStack {
                    ForEach(["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"], id: \.self) { day in
                        AccessibleText(
                            String(day.prefix(1)),
                            style: .caption,
                            weight: .medium,
                            color: .secondary
                        )
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true) // Hide individual headers, use rotor instead
                    }
                }
                
                // Calendar grid with enhanced accessibility
                HStack {
                    ForEach(weekDates, id: \.self) { date in
                        AccessibleCalendarDayButton(
                            date: date,
                            selectedDate: selectedDate,
                            onDateSelected: onDateSelected
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.horizontal)
        .accessibilityRotor("Days") {
            ForEach(weekDates, id: \.self) { date in
                AccessibilityRotorEntry(
                    DateFormatter.accessibilityDate.string(from: date),
                    id: date
                ) {
                    selectedDate = date
                    onDateSelected(date)
                }
            }
        }
    }
    
    private var weekRangeText: String {
        guard let firstDate = weekDates.first,
              let lastDate = weekDates.last else {
            return ""
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        if Calendar.current.isDate(firstDate, equalTo: lastDate, toGranularity: .month) {
            return "\(formatter.string(from: firstDate)) - \(Calendar.current.component(.day, from: lastDate))"
        } else {
            return "\(formatter.string(from: firstDate)) - \(formatter.string(from: lastDate))"
        }
    }
}

// MARK: - Accessible Calendar Day Button

struct AccessibleCalendarDayButton: View {
    let date: Date
    let selectedDate: Date
    let onDateSelected: (Date) -> Void
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private var day: Int {
        Calendar.current.component(.day, from: date)
    }
    
    private var isToday: Bool {
        Calendar.current.isDate(date, inSameDayAs: Date())
    }
    
    private var isSelected: Bool {
        Calendar.current.isDate(date, inSameDayAs: selectedDate)
    }
    
    private var hasEvents: Bool {
        // TODO: Check if date has events
        false
    }
    
    var body: some View {
        AccessibleButton(
            action: {
                onDateSelected(date)
                HapticManager.shared.selection()
            },
            label: accessibilityLabel,
            hint: accessibilityHint,
            hapticStyle: .light
        ) {
            VStack(spacing: 2) {
                AccessibleText(
                    "\(day)",
                    style: .subheadline,
                    weight: isToday ? .bold : .medium,
                    color: isSelected ? .white : (isToday ? .blue : .primary)
                )
                
                // Event indicator dot
                Circle()
                    .fill(hasEvents ? (isSelected ? Color.white : Color.blue) : Color.clear)
                    .frame(width: 4, height: 4)
                    .accessibilityHidden(true)
            }
            .frame(width: 36, height: 36)
            .background(
                Circle()
                    .fill(isSelected ? Color.blue : (isToday ? Color.blue.opacity(0.1) : Color.clear))
            )
            .scaleEffect(isSelected && !reduceMotion ? 1.1 : 1.0)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isSelected)
        }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
    
    private var accessibilityLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
    
    private var accessibilityHint: String {
        if isSelected {
            return "Currently selected date"
        } else if isToday {
            return "Today, tap to select"
        } else {
            return "Tap to select this date"
        }
    }
}

// MARK: - Accessible Event Filter Picker

struct AccessibleEventFilterPicker: View {
    @Binding var selectedFilter: CalendarView.EventFilter
    let onFilterChanged: (CalendarView.EventFilter) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(CalendarView.EventFilter.allCases, id: \.self) { filter in
                    AccessibleFilterChip(
                        filter: filter,
                        isSelected: selectedFilter == filter,
                        onTap: {
                            selectedFilter = filter
                            onFilterChanged(filter)
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Event filters")
        .accessibilityRotor("Filters") {
            ForEach(CalendarView.EventFilter.allCases, id: \.self) { filter in
                AccessibilityRotorEntry(
                    "\(filter.rawValue) filter",
                    id: filter
                ) {
                    selectedFilter = filter
                    onFilterChanged(filter)
                }
            }
        }
    }
}

// MARK: - Accessible Filter Chip

struct AccessibleFilterChip: View {
    let filter: CalendarView.EventFilter
    let isSelected: Bool
    let onTap: () -> Void
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        AccessibleButton(
            action: {
                onTap()
                HapticManager.shared.lightImpact()
            },
            label: "\(filter.rawValue) filter",
            hint: isSelected ? "Currently selected filter" : "Tap to filter by \(filter.rawValue.lowercased())",
            hapticStyle: .light
        ) {
            HStack(spacing: 6) {
                Image(systemName: filter.icon)
                    .font(.caption)
                
                AccessibleText(
                    filter.rawValue,
                    style: .caption,
                    weight: .medium,
                    color: isSelected ? .white : .primary
                )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? Color.blue : Color(.systemBackground))
            )
            .overlay(
                Capsule()
                    .stroke(Color.blue.opacity(0.3), lineWidth: isSelected ? 0 : 1)
            )
            .scaleEffect(isSelected && !reduceMotion ? 1.05 : 1.0)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isSelected)
        }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Accessible Events Scroll View

struct AccessibleEventsScrollView: View {
    let selectedDate: Date
    let eventFilter: CalendarView.EventFilter
    let viewModel: CalendarViewModel
    let isRefreshing: Bool
    let onEventTap: (CalendarEvent) -> Void
    let onRefresh: () async -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Pull-to-refresh indicator
                if isRefreshing {
                    AccessibleLoadingView(
                        message: "Syncing calendar...",
                        isLoading: true
                    )
                    .padding()
                }
                
                // Selected Date Events
                let selectedDateEvents = viewModel.eventsForDate(selectedDate, filter: eventFilter)
                if !selectedDateEvents.isEmpty {
                    AccessibleEventSectionView(
                        title: Calendar.current.isDate(selectedDate, inSameDayAs: Date()) ? "Today" : "Selected Date",
                        events: selectedDateEvents,
                        onEventTap: onEventTap
                    )
                }
                
                // Today's Events (if different from selected date)
                if !Calendar.current.isDate(selectedDate, inSameDayAs: Date()) {
                    let todaysEvents = viewModel.filteredTodaysEvents(filter: eventFilter)
                    if !todaysEvents.isEmpty {
                        AccessibleEventSectionView(
                            title: "Today",
                            events: todaysEvents,
                            onEventTap: onEventTap
                        )
                    }
                }
                
                // Upcoming Events Section
                let upcomingEvents = viewModel.filteredUpcomingEvents(filter: eventFilter)
                if !upcomingEvents.isEmpty {
                    AccessibleEventSectionView(
                        title: "Upcoming",
                        events: upcomingEvents,
                        onEventTap: onEventTap
                    )
                }
                
                // Empty state
                if viewModel.isEmpty(for: eventFilter) {
                    AccessibleEmptyCalendarStateView(
                        filter: eventFilter,
                        onCreateEvent: {
                            // Handle create event
                        }
                    )
                }
            }
            .padding()
        }
        .refreshable {
            await onRefresh()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Calendar events")
    }
}

// MARK: - Accessible Event Section

struct AccessibleEventSectionView: View {
    let title: String
    let events: [CalendarEvent]
    let onEventTap: (CalendarEvent) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                AccessibleText(
                    title,
                    style: .headline,
                    weight: .semibold
                )
                .accessibilityAddTraits([.isHeader])
                
                Spacer()
            }
            
            ForEach(events, id: \.id) { event in
                AccessibleCalendarEventCard(
                    event: event,
                    onTap: { onEventTap(event) }
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title) section with \(events.count) events")
        .accessibilityRotor("Events in \(title)") {
            ForEach(events, id: \.id) { event in
                AccessibilityRotorEntry(
                    event.title,
                    id: event.id
                ) {
                    onEventTap(event)
                }
            }
        }
    }
}

// MARK: - Accessible Empty State

struct AccessibleEmptyCalendarStateView: View {
    let filter: CalendarView.EventFilter
    let onCreateEvent: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            
            VStack(spacing: 8) {
                AccessibleText(
                    emptyStateTitle,
                    style: .title3,
                    weight: .semibold
                )
                
                AccessibleText(
                    emptyStateMessage,
                    style: .subheadline,
                    color: .secondary,
                    alignment: .center
                )
            }
            
            AccessibleButton(
                action: {
                    onCreateEvent()
                    HapticManager.shared.mediumImpact()
                },
                label: "Create your first event",
                hint: "Add a new event to get started",
                hapticStyle: .medium
            ) {
                HStack {
                    Image(systemName: "plus")
                    AccessibleText("Create Event", style: .subheadline, weight: .medium, color: .white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.blue)
                .cornerRadius(20)
            }
        }
        .padding(40)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(emptyStateTitle). \(emptyStateMessage)")
    }
    
    private var emptyStateIcon: String {
        switch filter {
        case .all: return "calendar"
        case .family: return "person.2"
        case .personal: return "person"
        }
    }
    
    private var emptyStateTitle: String {
        switch filter {
        case .all: return "No Events"
        case .family: return "No Family Events"
        case .personal: return "No Personal Events"
        }
    }
    
    private var emptyStateMessage: String {
        switch filter {
        case .all: return "You don't have any events scheduled. Create your first event to get started!"
        case .family: return "No family events are scheduled. Create a family event to share with everyone!"
        case .personal: return "You don't have any personal events. Add some to keep track of your schedule!"
        }
    }
}

// MARK: - DateFormatter Extensions

extension DateFormatter {
    static let accessibilityDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }()
    
    static let accessibilityTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
    
    static let accessibilityDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter
    }()
}