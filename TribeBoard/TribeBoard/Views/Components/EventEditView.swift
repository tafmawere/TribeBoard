import SwiftUI

struct EventEditView: View {
    let originalEvent: CalendarEvent
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = EventEditViewModel()
    
    // Form state
    @State private var title: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isAllDay: Bool
    @State private var location: String
    @State private var notes: String
    @State private var privacyLevel: CalendarEvent.PrivacyLevel
    
    // UI state
    @State private var isUpdating = false
    @State private var showingDeleteAlert = false
    
    // Validation state
    @State private var titleError: String?
    @State private var dateError: String?
    @State private var permissionError: String?
    
    // Permission checking
    private var canEdit: Bool {
        // TODO: Implement proper permission checking
        // For now, allow editing of personal events or if user is family admin
        return originalEvent.privacyLevel == .personal || true
    }
    
    private var canDelete: Bool {
        // TODO: Implement proper permission checking
        return canEdit
    }
    
    init(event: CalendarEvent) {
        self.originalEvent = event
        
        // Initialize state with event values
        _title = State(initialValue: event.title)
        _startDate = State(initialValue: event.startDate)
        _endDate = State(initialValue: event.endDate)
        _isAllDay = State(initialValue: event.isAllDay)
        _location = State(initialValue: event.location ?? "")
        _notes = State(initialValue: event.notes ?? "")
        _privacyLevel = State(initialValue: event.privacyLevel)
    }
    
    var body: some View {
        NavigationView {
            Group {
                if !canEdit {
                    // Permission denied view
                    PermissionDeniedView(
                        message: "You don't have permission to edit this event",
                        onDismiss: { dismiss() }
                    )
                } else {
                    // Edit form
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
                        
                        // Privacy Level Section (only if user can change it)
                        if canChangePrivacyLevel {
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
                        
                        // Event Metadata Section
                        Section {
                            EventMetadataView(event: originalEvent)
                        } header: {
                            Text("Event Information")
                        }
                        
                        // Delete Section
                        if canDelete {
                            Section {
                                Button(action: {
                                    CalendarHapticManager.shared.eventDeletionWarning(originalEvent)
                                    showingDeleteAlert = true
                                }) {
                                    HStack {
                                        Image(systemName: "trash")
                                        Text("Delete Event")
                                    }
                                    .foregroundColor(.red)
                                }
                                .accessibilityLabel("Delete event")
                                .accessibilityHint("Permanently delete this event")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .accessibilityLabel("Cancel editing")
                }
                
                if canEdit {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            updateEvent()
                        }
                        .fontWeight(.semibold)
                        .disabled(!isFormValid || isUpdating || !hasChanges)
                        .accessibilityLabel("Save changes")
                        .accessibilityHint(isFormValid ? "Save the changes to the event" : "Complete all required fields to save changes")
                    }
                }
            }
            .disabled(isUpdating)
            .overlay {
                if isUpdating {
                    LoadingOverlay(message: "Updating event...")
                }
            }
            .alert("Delete Event", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteEvent()
                }
            } message: {
                Text("Are you sure you want to delete '\(originalEvent.title)'? This action cannot be undone.")
            }
        }
        .onAppear {
            validateTitle(title)
            validateDates()
            checkPermissions()
        }
    }
    
    // MARK: - Computed Properties
    
    private var canChangePrivacyLevel: Bool {
        // Only allow changing privacy level if user is family admin or event is personal
        return originalEvent.privacyLevel == .personal || true // TODO: Check if user is family admin
    }
    
    private var isFormValid: Bool {
        titleError == nil && 
        dateError == nil && 
        permissionError == nil &&
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var hasChanges: Bool {
        title != originalEvent.title ||
        startDate != originalEvent.startDate ||
        endDate != originalEvent.endDate ||
        isAllDay != originalEvent.isAllDay ||
        location != (originalEvent.location ?? "") ||
        notes != (originalEvent.notes ?? "") ||
        privacyLevel != originalEvent.privacyLevel
    }
    
    // MARK: - Validation
    
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
    
    private func checkPermissions() {
        if !canEdit {
            permissionError = "You don't have permission to edit this event"
        } else if privacyLevel == .familyShared && originalEvent.privacyLevel == .personal {
            // Check if user can create family events
            // TODO: Implement proper permission checking
            permissionError = nil
        } else {
            permissionError = nil
        }
    }
    
    // MARK: - Actions
    
    private func updateEvent() {
        guard isFormValid && hasChanges else { return }
        
        isUpdating = true
        
        // Create updated event
        let updatedEvent = originalEvent.createCopy()
        updatedEvent.updateEvent(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            location: location.isEmpty ? nil : location,
            notes: notes.isEmpty ? nil : notes,
            privacyLevel: privacyLevel,
            modifiedBy: UUID() // TODO: Get from current user
        )
        
        Task {
            do {
                try await viewModel.updateEvent(updatedEvent)
                
                await MainActor.run {
                    // Enhanced haptic feedback for successful event update
                    CalendarHapticManager.shared.eventUpdated(updatedEvent)
                    
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isUpdating = false
                    // Enhanced haptic feedback for update error
                    CalendarHapticManager.shared.calendarError(error)
                    // Handle error - could show alert or toast
                    print("Failed to update event: \(error)")
                }
            }
        }
    }
    
    private func deleteEvent() {
        isUpdating = true
        
        Task {
            do {
                try await viewModel.deleteEvent(originalEvent)
                
                await MainActor.run {
                    // Enhanced haptic feedback for successful event deletion
                    CalendarHapticManager.shared.eventDeleted(originalEvent.title)
                    
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isUpdating = false
                    // Enhanced haptic feedback for deletion error
                    CalendarHapticManager.shared.calendarError(error)
                    // Handle error - could show alert or toast
                    print("Failed to delete event: \(error)")
                }
            }
        }
    }
}

// MARK: - Permission Denied View

struct PermissionDeniedView: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text("Permission Required")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("OK") {
                onDismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Permission denied: \(message)")
    }
}

// MARK: - Event Metadata View

struct EventMetadataView: View {
    let event: CalendarEvent
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack(spacing: 12) {
            MetadataRow(
                icon: "calendar.badge.plus",
                title: "Created",
                value: dateFormatter.string(from: event.createdAt)
            )
            
            if event.lastModified != event.createdAt {
                MetadataRow(
                    icon: "pencil.circle",
                    title: "Last Modified",
                    value: dateFormatter.string(from: event.lastModified)
                )
            }
            
            MetadataRow(
                icon: "eye",
                title: "Privacy Level",
                value: event.privacyLevel.displayName
            )
            
            if let eventKitIdentifier = event.eventKitIdentifier {
                MetadataRow(
                    icon: "calendar",
                    title: "Apple Calendar",
                    value: "Synced"
                )
            }
        }
    }
}

// MARK: - Metadata Row

struct MetadataRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Event Edit ViewModel

@MainActor
class EventEditViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func updateEvent(_ event: CalendarEvent) async throws {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate API call
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // TODO: Integrate with CalendarService
        print("✅ Event updated: \(event.title)")
    }
    
    func deleteEvent(_ event: CalendarEvent) async throws {
        isLoading = true
        defer { isLoading = false }
        
        // Simulate API call
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // TODO: Integrate with CalendarService
        print("✅ Event deleted: \(event.title)")
    }
}

// MARK: - Preview

#Preview {
    EventEditView(event: CalendarEvent(
        title: "Sample Event",
        startDate: Date(),
        endDate: Date().addingTimeInterval(3600),
        isAllDay: false,
        location: "Sample Location",
        notes: "Sample notes",
        privacyLevel: .personal,
        createdBy: UUID(),
        familyId: nil
    ))
}