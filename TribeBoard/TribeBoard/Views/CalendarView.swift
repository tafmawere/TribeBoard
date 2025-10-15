import SwiftUI

struct CalendarView: View {
    @StateObject private var viewModel: CalendarViewModel
    @State private var isRefreshing = false
    @EnvironmentObject var appState: AppState
    
    // MARK: - Initialization
    
    init(
        calendarService: CalendarService? = nil,
        familyCalendarService: FamilyCalendarIntegrationService? = nil
    ) {
        self._viewModel = StateObject(wrappedValue: CalendarViewModel(
            calendarService: calendarService,
            familyCalendarService: familyCalendarService
        ))
    }
    
    // Legacy EventFilter for compatibility
    enum EventFilter: String, CaseIterable {
        case all = "All Events"
        case family = "Family"
        case personal = "Personal"
        
        var icon: String {
            switch self {
            case .all: return "calendar"
            case .family: return "person.2.fill"
            case .personal: return "person.fill"
            }
        }
        
        // Convert to new EventFilter
        var toViewModelFilter: CalendarViewModel.EventFilter {
            switch self {
            case .all: return .all
            case .family: return .family
            case .personal: return .personal
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Calendar Header with Date Selection
                EnhancedCalendarHeaderView(
                    selectedDate: $viewModel.selectedDate,
                    onDateSelected: { date in
                        Task {
                            await viewModel.loadEventsForDate(date)
                        }
                        
                        // Enhanced haptic feedback for date selection
                        let isToday = Calendar.current.isDate(date, inSameDayAs: Date())
                        CalendarHapticManager.shared.dateSelected(date, isToday: isToday)
                    },
                    onCreateEvent: {
                        viewModel.showEventCreationSheet()
                        CalendarHapticManager.shared.lightImpact()
                    }
                )
                
                // Event Filter Picker
                EnhancedEventFilterPicker(
                    selectedFilter: $viewModel.currentFilter,
                    onFilterChanged: { filter in
                        viewModel.applyFilter(filter)
                        
                        // Enhanced haptic feedback for filter change
                        CalendarHapticManager.shared.filterChanged(filter.rawValue)
                    }
                )
                
                // Events List with Pull-to-Refresh
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Pull-to-refresh indicator
                        if isRefreshing {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Syncing...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                        }
                        
                        // Selected Date Events
                        let selectedDateEvents = viewModel.eventsForDate(viewModel.selectedDate, filter: viewModel.currentFilter.toEventFilter())
                        if !selectedDateEvents.isEmpty {
                            EventSectionView(
                                title: Calendar.current.isDate(viewModel.selectedDate, inSameDayAs: Date()) ? "Today" : "Selected Date",
                                events: selectedDateEvents,
                                onEventTap: { event in
                                    viewModel.showEventDetailSheet(for: event)
                                    
                                    // Enhanced haptic feedback for event selection
                                    CalendarHapticManager.shared.eventSelected(event)
                                }
                            )
                        }
                        
                        // Today's Events (if different from selected date)
                        if !Calendar.current.isDate(viewModel.selectedDate, inSameDayAs: Date()) {
                            let todaysEvents = viewModel.filteredTodaysEvents(filter: viewModel.currentFilter.toEventFilter())
                            if !todaysEvents.isEmpty {
                                EventSectionView(
                                    title: "Today",
                                    events: todaysEvents,
                                    onEventTap: { event in
                                        viewModel.showEventDetailSheet(for: event)
                                        
                                        // Enhanced haptic feedback for event selection
                                        CalendarHapticManager.shared.eventSelected(event)
                                    }
                                )
                            }
                        }
                        
                        // Upcoming Events Section
                        let upcomingEvents = viewModel.filteredUpcomingEvents(filter: viewModel.currentFilter.toEventFilter())
                        if !upcomingEvents.isEmpty {
                            EventSectionView(
                                title: "Upcoming",
                                events: upcomingEvents,
                                onEventTap: { event in
                                    viewModel.showEventDetailSheet(for: event)
                                    
                                    // Enhanced haptic feedback for event selection
                                    CalendarHapticManager.shared.eventSelected(event)
                                }
                            )
                        }
                        
                        // This Week's School Runs (only show in All or Family filter)
                        if viewModel.currentFilter == .all || viewModel.currentFilter == .family {
                            if !viewModel.thisWeeksSchoolRuns.isEmpty {
                                SchoolRunSectionView(
                                    schoolRuns: viewModel.thisWeeksSchoolRuns,
                                    userProfiles: viewModel.userProfiles
                                )
                            }
                        }
                        
                        // Birthdays This Month (only show in All or Family filter)
                        if viewModel.currentFilter == .all || viewModel.currentFilter == .family {
                            let birthdayEvents = viewModel.filteredBirthdaysThisMonth(filter: viewModel.currentFilter.toEventFilter())
                            if !birthdayEvents.isEmpty {
                                BirthdaySectionView(
                                    birthdays: birthdayEvents,
                                    userProfiles: viewModel.userProfiles
                                )
                            }
                        }
                        
                        // Empty state
                        if viewModel.isEmpty(for: viewModel.currentFilter.toEventFilter()) {
                            EmptyCalendarStateView(
                                filter: viewModel.currentFilter.toEventFilter(),
                                canCreateEvents: viewModel.canCreateEvents,
                                onCreateEvent: {
                                    viewModel.showEventCreationSheet()
                                }
                            )
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await performRefresh()
                }
            }
            .navigationTitle("Family Calendar")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button("Sync Calendar") {
                            CalendarHapticManager.shared.syncInitiated()
                            Task {
                                await performRefresh()
                            }
                        }
                        
                        Button("Calendar Help") {
                            // Show help view
                        }
                        
                        Button("Backup & Restore") {
                            // Show backup management
                        }
                        
                        Divider()
                        
                        Button("Calendar Settings") {
                            // Show calendar settings
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Calendar options")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        CalendarHapticManager.shared.lightImpact()
                        viewModel.showEventCreationSheet()
                    }) {
                        Image(systemName: "plus")
                    }
                    .disabled(!viewModel.canCreateEvents)
                    .accessibilityLabel("Create new event")
                }
            }
            .sheet(isPresented: $viewModel.showEventCreation) {
                EventCreationView(
                    selectedDate: viewModel.selectedDate,
                    onEventCreated: { title, startDate, endDate, isAllDay, location, notes, privacyLevel in
                        Task {
                            await viewModel.createEvent(
                                title: title,
                                startDate: startDate,
                                endDate: endDate,
                                isAllDay: isAllDay,
                                location: location,
                                notes: notes,
                                privacyLevel: privacyLevel
                            )
                        }
                    }
                )
            }
            .sheet(isPresented: $viewModel.showEventDetail) {
                if let event = viewModel.selectedEvent {
                    EnhancedEventDetailView(
                        event: event,
                        userProfiles: viewModel.userProfiles,
                        canEdit: viewModel.canEditEvent(event),
                        canDelete: viewModel.canDeleteEvent(event),
                        canShare: viewModel.canShareEvent(event),
                        onEdit: { event in
                            viewModel.showEventEditSheet(for: event)
                        },
                        onDelete: { event in
                            // Enhanced haptic feedback for event deletion
                            CalendarHapticManager.shared.eventDeleted(event.title)
                            Task {
                                await viewModel.deleteEvent(event)
                            }
                        },
                        onShare: { event in
                            Task {
                                await viewModel.shareEventWithFamily(event)
                            }
                        },
                        onUnshare: { event in
                            Task {
                                await viewModel.unshareEventFromFamily(event)
                            }
                        }
                    )
                }
            }
            .sheet(isPresented: $viewModel.showEventEdit) {
                if let event = viewModel.editingEvent {
                    EventEditView(
                        event: event,
                        onEventUpdated: { updatedEvent in
                            Task {
                                await viewModel.updateEvent(updatedEvent)
                            }
                        }
                    )
                }
            }
            .task {
                // Initialize with current user and family context
                if let currentUser = appState.currentUser,
                   let currentFamily = appState.currentFamily {
                    await viewModel.loadEventsForUser(
                        currentUser.id,
                        familyId: currentFamily.id,
                        includeFamily: true
                    )
                } else {
                    await viewModel.refreshData()
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func performRefresh() async {
        isRefreshing = true
        
        // Simulate sync operation
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
        
        await MainActor.run {
            viewModel.refreshData()
            isRefreshing = false
            
            // Enhanced haptic feedback for sync completion
            CalendarHapticManager.shared.syncSuccess()
        }
    }
}

// MARK: - Enhanced Calendar Header View

struct EnhancedCalendarHeaderView: View {
    @Binding var selectedDate: Date
    let onDateSelected: (Date) -> Void
    let onCreateEvent: () -> Void
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(dateFormatter.string(from: selectedDate))
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: {
                        selectedDate = Date()
                        onDateSelected(Date())
                        CalendarHapticManager.shared.calendarNavigation(.today)
                    }) {
                        Text("Today")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    .accessibilityLabel("Go to today")
                    
                    Button(action: onCreateEvent) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                    .accessibilityLabel("Create event for selected date")
                }
            }
            .padding(.horizontal)
            
            // Enhanced Mini Calendar View
            EnhancedCalendarMiniView(
                selectedDate: $selectedDate,
                onDateSelected: onDateSelected
            )
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
    }
}

// MARK: - Enhanced Mini Calendar View

struct EnhancedCalendarMiniView: View {
    @Binding var selectedDate: Date
    let onDateSelected: (Date) -> Void
    @State private var currentWeekOffset = 0
    
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
            // Week navigation
            HStack {
                Button(action: {
                    currentWeekOffset -= 1
                    CalendarHapticManager.shared.calendarNavigation(.previous)
                }) {
                    Image(systemName: "chevron.left")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .accessibilityLabel("Previous week")
                
                Spacer()
                
                Text(weekRangeText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button(action: {
                    currentWeekOffset += 1
                    CalendarHapticManager.shared.calendarNavigation(.next)
                }) {
                    Image(systemName: "chevron.right")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                .accessibilityLabel("Next week")
            }
            .padding(.horizontal)
            
            VStack(spacing: 8) {
                // Weekday headers
                HStack {
                    ForEach(["S", "M", "T", "W", "T", "F", "S"], id: \.self) { day in
                        Text(day)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // Calendar grid
                HStack {
                    ForEach(weekDates, id: \.self) { date in
                        let day = Calendar.current.component(.day, from: date)
                        let isToday = Calendar.current.isDate(date, inSameDayAs: Date())
                        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                        let hasEvents = false // TODO: Check if date has events
                        
                        Button(action: {
                            selectedDate = date
                            onDateSelected(date)
                        }) {
                            VStack(spacing: 2) {
                                Text("\(day)")
                                    .font(.subheadline)
                                    .fontWeight(isToday ? .bold : .medium)
                                    .foregroundColor(isSelected ? .white : (isToday ? .blue : .primary))
                                
                                // Event indicator dot
                                if hasEvents {
                                    Circle()
                                        .fill(isSelected ? Color.white : Color.blue)
                                        .frame(width: 4, height: 4)
                                } else {
                                    Circle()
                                        .fill(Color.clear)
                                        .frame(width: 4, height: 4)
                                }
                            }
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(isSelected ? Color.blue : (isToday ? Color.blue.opacity(0.1) : Color.clear))
                            )
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("\(DateFormatter.accessibilityDate.string(from: date))")
                        .accessibilityHint(isSelected ? "Currently selected" : "Tap to select this date")
                        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                    }
                }
            }
        }
        .padding(.horizontal)
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

// MARK: - Enhanced Event Filter Picker

struct EnhancedEventFilterPicker: View {
    @Binding var selectedFilter: CalendarViewModel.EventFilter
    let onFilterChanged: (CalendarViewModel.EventFilter) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(CalendarViewModel.EventFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.displayName,
                        icon: filter.icon,
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
    }
}

// MARK: - Legacy Event Filter Picker (for compatibility)

struct EventFilterPicker: View {
    @Binding var selectedFilter: CalendarView.EventFilter
    let onFilterChanged: (CalendarView.EventFilter) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(CalendarView.EventFilter.allCases, id: \.self) { filter in
                    FilterChip(
                        title: filter.rawValue,
                        icon: filter.icon,
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
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? Color.blue : Color(.systemBackground))
            )
            .foregroundColor(isSelected ? .white : .primary)
            .overlay(
                Capsule()
                    .stroke(Color.blue.opacity(0.3), lineWidth: isSelected ? 0 : 1)
            )
        }
        .accessibilityLabel("\(title) filter")
        .accessibilityHint(isSelected ? "Currently selected filter" : "Tap to filter by \(title.lowercased())")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Event Section View

struct EventSectionView: View {
    let title: String
    let events: [CalendarEvent]
    let onEventTap: (CalendarEvent) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            ForEach(events, id: \.id) { event in
                CalendarEventCard(
                    event: event,
                    onTap: { onEventTap(event) }
                )
            }
        }
    }
}

// MARK: - Enhanced Calendar Event Card

struct CalendarEventCard: View {
    let event: CalendarEvent
    let onTap: () -> Void
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Privacy level and status indicator
                VStack(spacing: 4) {
                    Image(systemName: event.privacyLevel.icon)
                        .font(.title3)
                        .foregroundColor(colorForPrivacyLevel(event.privacyLevel))
                    
                    Rectangle()
                        .fill(colorForPrivacyLevel(event.privacyLevel))
                        .frame(width: 4, height: 40)
                        .cornerRadius(2)
                }
                
                // Event details
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(event.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        // Privacy level badge
                        PrivacyLevelBadge(level: event.privacyLevel)
                    }
                    
                    // Date and time info
                    HStack(spacing: 8) {
                        if event.isAllDay {
                            Text("All day")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text(event.dateRangeString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Event status indicator
                        if event.isHappening {
                            Text("• Now")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        } else if event.isToday && event.isUpcoming {
                            Text("• Today")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    // Location
                    if let location = event.location {
                        HStack(spacing: 4) {
                            Image(systemName: "location")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(location)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    
                    // Duration
                    if !event.isAllDay {
                        Text("Duration: \(event.durationString)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Sync status indicator
                VStack(spacing: 4) {
                    if event.eventKitIdentifier != nil {
                        Image(systemName: "checkmark.icloud")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else if event.needsEventKitSync {
                        Image(systemName: "icloud.and.arrow.up")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(backgroundColorForEvent(event))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColorForEvent(event), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Tap to view event details")
    }
    
    private var accessibilityLabel: String {
        var label = "\(event.title), \(event.privacyLevel.displayName) event"
        
        if event.isAllDay {
            label += ", all day"
        } else {
            label += ", \(event.dateRangeString)"
        }
        
        if let location = event.location {
            label += ", at \(location)"
        }
        
        if event.isHappening {
            label += ", happening now"
        } else if event.isToday && event.isUpcoming {
            label += ", today"
        }
        
        return label
    }
    
    private func colorForPrivacyLevel(_ level: CalendarEvent.PrivacyLevel) -> Color {
        switch level {
        case .familyShared:
            return .blue
        case .personal:
            return .purple
        }
    }
    
    private func backgroundColorForEvent(_ event: CalendarEvent) -> Color {
        if event.isHappening {
            return Color.green.opacity(0.1)
        } else if event.isPast {
            return Color(.systemGray6)
        } else {
            return Color(.systemBackground)
        }
    }
    
    private func borderColorForEvent(_ event: CalendarEvent) -> Color {
        if event.isHappening {
            return Color.green.opacity(0.3)
        } else {
            return Color(.systemGray4)
        }
    }
}

// MARK: - Privacy Level Badge

struct PrivacyLevelBadge: View {
    let level: CalendarEvent.PrivacyLevel
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: level.icon)
                .font(.caption2)
            
            Text(level.displayName)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(colorForLevel.opacity(0.2))
        )
        .foregroundColor(colorForLevel)
    }
    
    private var colorForLevel: Color {
        switch level {
        case .familyShared:
            return .blue
        case .personal:
            return .purple
        }
    }
}

// MARK: - Empty Calendar State View

struct EmptyCalendarStateView: View {
    let filter: CalendarView.EventFilter
    let canCreateEvents: Bool
    let onCreateEvent: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(emptyStateTitle)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Text(emptyStateMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if canCreateEvents {
                Button(action: onCreateEvent) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Create Event")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(20)
                }
                .accessibilityLabel("Create your first event")
            } else {
                Text("Contact your family admin to create events")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
    }
    
    private var emptyStateIcon: String {
        switch filter {
        case .all:
            return "calendar"
        case .family:
            return "person.2"
        case .personal:
            return "person"
        }
    }
    
    private var emptyStateTitle: String {
        switch filter {
        case .all:
            return "No Events"
        case .family:
            return "No Family Events"
        case .personal:
            return "No Personal Events"
        }
    }
    
    private var emptyStateMessage: String {
        switch filter {
        case .all:
            return "You don't have any events scheduled. Create your first event to get started!"
        case .family:
            return "No family events are scheduled. Create a family event to share with everyone!"
        case .personal:
            return "You don't have any personal events. Add some to keep track of your schedule!"
        }
    }
}

// MARK: - Filter Conversion Extensions

extension CalendarViewModel.EventFilter {
    /// Convert to legacy EventFilter for compatibility
    func toEventFilter() -> CalendarView.EventFilter {
        switch self {
        case .all: return .all
        case .family: return .family
        case .personal: return .personal
        }
    }
}

// MARK: - School Run Section View

struct SchoolRunSectionView: View {
    let schoolRuns: [SchoolRun]
    let userProfiles: [UUID: UserProfile]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("School Runs This Week")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            ForEach(schoolRuns, id: \.id) { schoolRun in
                SchoolRunCard(
                    schoolRun: schoolRun,
                    userProfiles: userProfiles
                )
            }
        }
    }
}

// MARK: - School Run Card

struct SchoolRunCard: View {
    let schoolRun: SchoolRun
    let userProfiles: [UUID: UserProfile]
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Status indicator
            VStack(spacing: 4) {
                Image(systemName: "car")
                    .font(.title2)
                    .foregroundColor(colorForStatus(schoolRun.status))
                
                Rectangle()
                    .fill(colorForStatus(schoolRun.status))
                    .frame(width: 4, height: 40)
                    .cornerRadius(2)
            }
            
            // School run details
            VStack(alignment: .leading, spacing: 4) {
                Text(schoolRun.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 8) {
                    if let firstPickup = schoolRun.pickupStops.first {
                        Text("Pickup: \(timeFormatter.string(from: firstPickup.time))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let firstDropoff = schoolRun.dropoffStops.first {
                        Text("• Drop-off: \(timeFormatter.string(from: firstDropoff.time))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Driver information would be added when driver assignment is implemented
            }
            
            Spacer()
            
            // Status badge
            Text(schoolRun.status.displayText)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(colorForStatus(schoolRun.status).opacity(0.2))
                .foregroundColor(colorForStatus(schoolRun.status))
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func colorForStatus(_ status: RunStatus) -> Color {
        switch status {
        case .scheduled:
            return .blue
        case .inProgress:
            return .orange
        case .completed:
            return .green
        case .cancelled:
            return .red
        }
    }
}

// MARK: - Birthday Section View

struct BirthdaySectionView: View {
    let birthdays: [CalendarEvent]
    let userProfiles: [UUID: UserProfile]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Birthdays This Month")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            ForEach(birthdays, id: \.id) { birthday in
                BirthdayCard(
                    birthday: birthday,
                    userProfiles: userProfiles
                )
            }
        }
    }
}

// MARK: - Birthday Card

struct BirthdayCard: View {
    let birthday: CalendarEvent
    let userProfiles: [UUID: UserProfile]
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Birthday icon
            VStack(spacing: 4) {
                Text("🎂")
                    .font(.title2)
                
                Rectangle()
                    .fill(Color.pink)
                    .frame(width: 4, height: 40)
                    .cornerRadius(2)
            }
            
            // Birthday details
            VStack(alignment: .leading, spacing: 4) {
                Text(birthday.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(dateFormatter.string(from: birthday.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let description = birthday.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Days until birthday
            VStack(spacing: 2) {
                let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: birthday.date).day ?? 0
                
                if daysUntil == 0 {
                    Text("Today!")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.pink)
                } else if daysUntil > 0 {
                    Text("\(daysUntil)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.pink)
                    
                    Text("days")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.pink.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Preview

// MARK: - DateFormatter Extensions

extension DateFormatter {
    static let accessibilityDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter
    }()
}

#Preview {
    CalendarView()
}