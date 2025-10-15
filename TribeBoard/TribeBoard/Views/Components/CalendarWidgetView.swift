import SwiftUI

/// Calendar widget for quick access to calendar features
struct CalendarWidgetView: View {
    @StateObject private var viewModel: CalendarWidgetViewModel
    @EnvironmentObject var appState: AppState
    
    init(calendarService: CalendarService? = nil) {
        self._viewModel = StateObject(wrappedValue: CalendarWidgetViewModel(
            calendarService: calendarService
        ))
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Widget Header
            HStack {
                Image(systemName: "calendar")
                    .font(.title3)
                    .foregroundColor(.brandPrimary)
                
                Text("Calendar")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                NavigationLink(destination: CalendarView()) {
                    Text("View All")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .accessibilityLabel("View full calendar")
            }
            
            // Today's Events Preview
            if viewModel.todaysEvents.isEmpty {
                EmptyTodayEventsView()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(Array(viewModel.todaysEvents.prefix(3)), id: \.id) { event in
                        CompactEventCard(event: event) {
                            // Navigate to event detail
                            viewModel.showEventDetail(event)
                        }
                    }
                    
                    if viewModel.todaysEvents.count > 3 {
                        HStack {
                            Text("+\(viewModel.todaysEvents.count - 3) more events")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                        }
                    }
                }
            }
            
            // Quick Actions
            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Add Event",
                    icon: "plus.circle.fill",
                    color: .blue
                ) {
                    viewModel.showEventCreation()
                }
                
                QuickActionButton(
                    title: "Sync",
                    icon: "arrow.clockwise",
                    color: .green
                ) {
                    Task {
                        await viewModel.syncCalendar()
                    }
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .task {
            await viewModel.loadTodaysEvents()
        }
        .sheet(isPresented: $viewModel.showEventCreationSheet) {
            EventCreationView(
                selectedDate: Date(),
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
        .sheet(isPresented: $viewModel.showEventDetailSheet) {
            if let event = viewModel.selectedEvent {
                EnhancedEventDetailView(
                    event: event,
                    userProfiles: [:],
                    canEdit: viewModel.canEditEvent(event),
                    canDelete: viewModel.canDeleteEvent(event),
                    canShare: viewModel.canShareEvent(event),
                    onEdit: { event in
                        // Handle edit
                    },
                    onDelete: { event in
                        Task {
                            await viewModel.deleteEvent(event)
                        }
                    },
                    onShare: { event in
                        // Handle share
                    },
                    onUnshare: { event in
                        // Handle unshare
                    }
                )
            }
        }
    }
}

// MARK: - Supporting Views

struct EmptyTodayEventsView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.plus")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("No events today")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("Tap + to create your first event")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct CompactEventCard: View {
    let event: CalendarEvent
    let onTap: () -> Void
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Privacy level indicator
                Rectangle()
                    .fill(event.privacyLevel == .familyShared ? Color.blue : Color.purple)
                    .frame(width: 4, height: 32)
                    .cornerRadius(2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        if event.isAllDay {
                            Text("All day")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text(timeFormatter.string(from: event.startDate))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if event.isHappening {
                            Text("• Now")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(event.title), \(event.isAllDay ? "all day" : timeFormatter.string(from: event.startDate))")
        .accessibilityHint("Tap to view event details")
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(8)
        }
        .accessibilityLabel(title)
    }
}

// MARK: - Calendar Widget ViewModel

@MainActor
class CalendarWidgetViewModel: ObservableObject {
    @Published var todaysEvents: [CalendarEvent] = []
    @Published var showEventCreationSheet = false
    @Published var showEventDetailSheet = false
    @Published var selectedEvent: CalendarEvent?
    @Published var isLoading = false
    
    private let calendarService: CalendarService
    
    init(calendarService: CalendarService? = nil) {
        self.calendarService = calendarService ?? CalendarService()
    }
    
    func loadTodaysEvents() async {
        isLoading = true
        
        do {
            let today = Date()
            let startOfDay = Calendar.current.startOfDay(for: today)
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? today
            let dateRange = DateInterval(start: startOfDay, end: endOfDay)
            
            let events = try await calendarService.fetchEvents(for: dateRange)
            
            await MainActor.run {
                self.todaysEvents = events.sorted { $0.startDate < $1.startDate }
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.todaysEvents = []
                self.isLoading = false
            }
        }
    }
    
    func showEventCreation() {
        CalendarHapticManager.shared.lightImpact()
        showEventCreationSheet = true
    }
    
    func showEventDetail(_ event: CalendarEvent) {
        CalendarHapticManager.shared.eventSelected(event)
        selectedEvent = event
        showEventDetailSheet = true
    }
    
    func syncCalendar() async {
        CalendarHapticManager.shared.syncInitiated()
        
        do {
            try await calendarService.syncWithAppleCalendar()
            await loadTodaysEvents()
            
            CalendarHapticManager.shared.syncSuccess()
        } catch {
            CalendarHapticManager.shared.error()
        }
    }
    
    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        location: String?,
        notes: String?,
        privacyLevel: CalendarEvent.PrivacyLevel
    ) async {
        do {
            let event = CalendarEvent(
                title: title,
                startDate: startDate,
                endDate: endDate,
                isAllDay: isAllDay,
                location: location,
                notes: notes,
                privacyLevel: privacyLevel
            )
            
            _ = try await calendarService.createEvent(event)
            await loadTodaysEvents()
            
            CalendarHapticManager.shared.eventCreated(title)
            showEventCreationSheet = false
        } catch {
            CalendarHapticManager.shared.error()
        }
    }
    
    func deleteEvent(_ event: CalendarEvent) async {
        do {
            try await calendarService.deleteEvent(event)
            await loadTodaysEvents()
            
            CalendarHapticManager.shared.eventDeleted(event.title)
            showEventDetailSheet = false
        } catch {
            CalendarHapticManager.shared.error()
        }
    }
    
    func canEditEvent(_ event: CalendarEvent) -> Bool {
        // Check if user can edit this event
        return true // Simplified for now
    }
    
    func canDeleteEvent(_ event: CalendarEvent) -> Bool {
        // Check if user can delete this event
        return true // Simplified for now
    }
    
    func canShareEvent(_ event: CalendarEvent) -> Bool {
        // Check if user can share this event
        return event.privacyLevel == .personal
    }
}

#Preview {
    CalendarWidgetView()
        .previewEnvironment()
}