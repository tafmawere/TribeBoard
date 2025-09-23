import SwiftUI

struct CalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @State private var selectedDate = Date()
    @State private var selectedEvent: CalendarEvent?
    @State private var showingEventDetail = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Calendar Header
                CalendarHeaderView(selectedDate: $selectedDate)
                
                // Events List
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Today's Events Section
                        if !viewModel.todaysEvents.isEmpty {
                            EventSectionView(
                                title: "Today",
                                events: viewModel.todaysEvents,
                                onEventTap: { event in
                                    selectedEvent = event
                                    showingEventDetail = true
                                }
                            )
                        }
                        
                        // Upcoming Events Section
                        if !viewModel.upcomingEvents.isEmpty {
                            EventSectionView(
                                title: "Upcoming",
                                events: viewModel.upcomingEvents,
                                onEventTap: { event in
                                    selectedEvent = event
                                    showingEventDetail = true
                                }
                            )
                        }
                        
                        // This Week's School Runs
                        if !viewModel.thisWeeksSchoolRuns.isEmpty {
                            SchoolRunSectionView(
                                schoolRuns: viewModel.thisWeeksSchoolRuns,
                                userProfiles: viewModel.userProfiles
                            )
                        }
                        
                        // Birthdays This Month
                        if !viewModel.birthdaysThisMonth.isEmpty {
                            BirthdaySectionView(
                                birthdays: viewModel.birthdaysThisMonth,
                                userProfiles: viewModel.userProfiles
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Family Calendar")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Event") {
                        viewModel.showAddEventSuccess()
                    }
                }
            }
            .sheet(isPresented: $showingEventDetail) {
                if let event = selectedEvent {
                    EventDetailView(
                        event: event,
                        userProfiles: viewModel.userProfiles
                    )
                }
            }
            .onAppear {
                viewModel.loadMockData()
            }
        }
    }
}

// MARK: - Calendar Header View

struct CalendarHeaderView: View {
    @Binding var selectedDate: Date
    
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
                
                Button(action: {
                    selectedDate = Date()
                }) {
                    Text("Today")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            // Mini Calendar View (simplified)
            CalendarMiniView(selectedDate: $selectedDate)
        }
        .padding(.vertical)
        .background(Color(.systemBackground))
    }
}

// MARK: - Mini Calendar View

struct CalendarMiniView: View {
    @Binding var selectedDate: Date
    
    var body: some View {
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
            
            // Calendar grid (simplified - showing current week)
            HStack {
                ForEach(0..<7) { dayOffset in
                    let date = Calendar.current.date(byAdding: .day, value: dayOffset - 3, to: Date()) ?? Date()
                    let day = Calendar.current.component(.day, from: date)
                    let isToday = Calendar.current.isDate(date, inSameDayAs: Date())
                    let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                    
                    Button(action: {
                        selectedDate = date
                    }) {
                        Text("\(day)")
                            .font(.subheadline)
                            .fontWeight(isToday ? .bold : .medium)
                            .foregroundColor(isSelected ? .white : (isToday ? .blue : .primary))
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(isSelected ? Color.blue : (isToday ? Color.blue.opacity(0.1) : Color.clear))
                            )
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal)
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

// MARK: - Calendar Event Card

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
                // Event type icon and color indicator
                VStack(spacing: 4) {
                    Text(event.type.icon)
                        .font(.title2)
                    
                    Rectangle()
                        .fill(colorForEventType(event.type))
                        .frame(width: 4, height: 40)
                        .cornerRadius(2)
                }
                
                // Event details
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    HStack(spacing: 8) {
                        Text(dateFormatter.string(from: event.date))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if Calendar.current.isDate(event.date, inSameDayAs: Date()) {
                            Text("• \(timeFormatter.string(from: event.date))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let location = event.location {
                        HStack(spacing: 4) {
                            Image(systemName: "location")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(location)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Participants count
                if !event.participants.isEmpty {
                    VStack(spacing: 2) {
                        Image(systemName: "person.2")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(event.participants.count)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func colorForEventType(_ type: CalendarEvent.EventType) -> Color {
        switch type {
        case .birthday:
            return .pink
        case .appointment:
            return .blue
        case .schoolEvent:
            return .orange
        case .familyActivity:
            return .green
        case .reminder:
            return .purple
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
                Text(schoolRun.route)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 8) {
                    Text("Pickup: \(timeFormatter.string(from: schoolRun.pickupTime))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("• Drop-off: \(timeFormatter.string(from: schoolRun.dropoffTime))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let driverName = userProfiles[schoolRun.driver]?.displayName {
                    Text("Driver: \(driverName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Status badge
            Text(schoolRun.status.displayName)
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
    
    private func colorForStatus(_ status: SchoolRun.RunStatus) -> Color {
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

#Preview {
    CalendarView()
}