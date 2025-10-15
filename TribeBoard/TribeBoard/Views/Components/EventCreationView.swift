import SwiftUI

struct EventCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = EventCreationViewModel()
    
    // Form state
    @State private var title = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600) // 1 hour later
    @State private var isAllDay = false
    @State private var location = ""
    @State private var notes = ""
    @State private var privacyLevel: CalendarEvent.PrivacyLevel = .personal
    
    // UI state
    @State private var showingDatePicker = false
    @State private var showingEndDatePicker = false
    @State private var isCreating = false
    
    // Validation state
    @State private var titleError: String?
    @State private var dateError: String?
    
    var body: some View {
        NavigationView {
            Form {
                // Event Title Section
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Event title", text: $title)
                            .font(.body)
                            .textFieldStyle(.plain)
                            .accessibilityLabel("Event title")
                            .accessibilityHint("Enter a title for your event")
                            .onChange(of: title) { _, newValue in
                                validateTitle(newValue)
                            }
                        
                        if let titleError = titleError {
                            Text(titleError)
                                .font(.caption)
                                .foregroundColor(.red)
                                .accessibilityLabel("Title error: \(titleError)")
                        }
                    }
                } header: {
                    Text("Event Details")
                }
                
                // Privacy Level Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Who can see this event?")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        ForEach(CalendarEvent.PrivacyLevel.allCases, id: \.self) { level in
                            PrivacyLevelRow(
                                level: level,
                                isSelected: privacyLevel == level,
                                onTap: { 
                                    privacyLevel = level
                                    CalendarHapticManager.shared.privacyLevelChanged(level)
                                }
                            )
                        }
                    }
                } header: {
                    Text("Privacy")
                } footer: {
                    Text(privacyLevel.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Date and Time Section
                Section {
                    VStack(spacing: 16) {
                        // All Day Toggle
                        HStack {
                            Text("All Day")
                                .font(.body)
                            
                            Spacer()
                            
                            Toggle("", isOn: $isAllDay)
                                .accessibilityLabel("All day event")
                                .onChange(of: isAllDay) { _, newValue in
                                    if newValue {
                                        // Set to start of day
                                        startDate = Calendar.current.startOfDay(for: startDate)
                                        endDate = Calendar.current.startOfDay(for: endDate)
                                    }
                                    validateDates()
                                    CalendarHapticManager.shared.allDayToggled(newValue)
                                }
                        }
                        
                        // Start Date
                        DateTimePickerRow(
                            title: "Starts",
                            date: $startDate,
                            isAllDay: isAllDay,
                            accessibilityLabel: "Event start date and time"
                        )
                        .onChange(of: startDate) { _, newValue in
                            // Auto-adjust end date if it's before start date
                            if endDate <= newValue {
                                endDate = isAllDay ? 
                                    Calendar.current.startOfDay(for: newValue) :
                                    newValue.addingTimeInterval(3600)
                            }
                            validateDates()
                        }
                        
                        // End Date
                        DateTimePickerRow(
                            title: "Ends",
                            date: $endDate,
                            isAllDay: isAllDay,
                            accessibilityLabel: "Event end date and time"
                        )
                        .onChange(of: endDate) { _, _ in
                            validateDates()
                        }
                        
                        if let dateError = dateError {
                            Text(dateError)
                                .font(.caption)
                                .foregroundColor(.red)
                                .accessibilityLabel("Date error: \(dateError)")
                        }
                    }
                } header: {
                    Text("When")
                }
                
                // Location Section
                Section {
                    TextField("Add location", text: $location)
                        .font(.body)
                        .accessibilityLabel("Event location")
                        .accessibilityHint("Enter a location for your event")
                } header: {
                    Text("Where")
                }
                
                // Notes Section
                Section {
                    TextField("Add notes", text: $notes, axis: .vertical)
                        .font(.body)
                        .lineLimit(3...6)
                        .accessibilityLabel("Event notes")
                        .accessibilityHint("Enter additional details about your event")
                } header: {
                    Text("Notes")
                }
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityLabel("Cancel event creation")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createEvent()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isFormValid || isCreating)
                    .accessibilityLabel("Create event")
                    .accessibilityHint(isFormValid ? "Create the event with the entered details" : "Complete all required fields to create the event")
                }
            }
            .disabled(isCreating)
            .overlay {
                if isCreating {
                    LoadingOverlay(message: "Creating event...")
                }
            }
        }
        .onAppear {
            // Set initial end date
            if !isAllDay {
                endDate = startDate.addingTimeInterval(3600)
            }
        }
    }
    
    // MARK: - Validation
    
    private var isFormValid: Bool {
        titleError == nil && 
        dateError == nil && 
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func validateTitle(_ newTitle: String) {
        let trimmedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedTitle.isEmpty {
            titleError = "Event title is required"
        } else if trimmedTitle.count > 200 {
            titleError = "Title must be 200 characters or less"
        } else {
            titleError = nil
        }
    }
    
    private func validateDates() {
        if isAllDay {
            // For all-day events, end date should be same day or later
            if Calendar.current.compare(endDate, to: startDate, toGranularity: .day) == .orderedAscending {
                dateError = "End date cannot be before start date"
            } else {
                dateError = nil
            }
        } else {
            // For timed events, end must be after start
            if endDate <= startDate {
                dateError = "End time must be after start time"
            } else {
                let duration = endDate.timeIntervalSince(startDate)
                if duration > 24 * 60 * 60 { // More than 24 hours
                    dateError = "Event duration cannot exceed 24 hours"
                } else {
                    dateError = nil
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func createEvent() {
        guard isFormValid else { return }
        
        isCreating = true
        
        // Create the event
        let event = CalendarEvent(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            location: location.isEmpty ? nil : location,
            notes: notes.isEmpty ? nil : notes,
            privacyLevel: privacyLevel,
            createdBy: UUID(), // TODO: Get from current user
            familyId: privacyLevel == .familyShared ? UUID() : nil // TODO: Get from current family
        )
        
        Task {
            do {
                try await viewModel.createEvent(event)
                
                await MainActor.run {
                    // Enhanced haptic feedback for successful event creation
                    CalendarHapticManager.shared.eventCreated(event)
                    
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    // Enhanced haptic feedback for creation error
                    CalendarHapticManager.shared.calendarError(error)
                    // Handle error - could show alert or toast
                    print("Failed to create event: \(error)")
                }
            }
        }
    }
}

// MARK: - Privacy Level Row

struct PrivacyLevelRow: View {
    let level: CalendarEvent.PrivacyLevel
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: level.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(level.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(level.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(level.displayName): \(level.description)")
        .accessibilityHint(isSelected ? "Currently selected" : "Tap to select this privacy level")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Date Time Picker Row

struct DateTimePickerRow: View {
    let title: String
    @Binding var date: Date
    let isAllDay: Bool
    let accessibilityLabel: String
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        if isAllDay {
            formatter.dateStyle = .full
            formatter.timeStyle = .none
        } else {
            formatter.dateStyle = .full
            formatter.timeStyle = .short
        }
        return formatter
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            DatePicker(
                "",
                selection: $date,
                displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
            )
            .labelsHidden()
            .accessibilityLabel(accessibilityLabel)
        }
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                
                Text(message)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 10)
        }
    }
}

// MARK: - Event Creation ViewModel

@MainActor
class EventCreationViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func createEvent(_ event: CalendarEvent) async throws {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate API call
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // TODO: Integrate with CalendarService
        print("✅ Event created: \(event.title)")
    }
}

// MARK: - Preview

#Preview {
    EventCreationView()
}