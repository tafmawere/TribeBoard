import SwiftUI

// MARK: - Accessible Event Edit View

struct AccessibleEventEditView: View {
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
    @State private var showingSuccessMessage = false
    
    // Validation state
    @State private var titleValidation = ValidationResult()
    @State private var dateValidation = ValidationResult()
    @State private var permissionValidation = ValidationResult()
    
    // Focus state for keyboard navigation
    @FocusState private var focusedField: FormField?
    
    enum FormField: CaseIterable {
        case title, location, notes
        
        var accessibilityLabel: String {
            switch self {
            case .title: return "Event title"
            case .location: return "Event location"
            case .notes: return "Event notes"
            }
        }
    }
    
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
    
    private var canChangePrivacyLevel: Bool {
        // Only allow changing privacy level if user is family admin or event is personal
        return originalEvent.privacyLevel == .personal || true // TODO: Check if user is family admin
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
                    AccessiblePermissionDeniedView(
                        message: "You don't have permission to edit this event",
                        onDismiss: { dismiss() }
                    )
                } else {
                    // Edit form
                    Form {
                        // Event Title Section
                        Section {
                            AccessibleFormField(
                                title: "Event Title",
                                text: $title,
                                placeholder: "Enter event title",
                                validation: titleValidation,
                                keyboardType: .default
                            )
                            .focused($focusedField, equals: .title)
                            .onChange(of: title) { _, newValue in
                                validateTitle(newValue)
                                announceValidationChange(for: .title)
                            }
                        } header: {
                            AccessibleText("Event Details", style: .headline, weight: .medium)
                                .accessibilityAddTraits([.isHeader])
                        } footer: {
                            if !titleValidation.isValid && !titleValidation.message.isEmpty {
                                AccessibleText(
                                    titleValidation.message,
                                    style: .caption,
                                    color: .red
                                )
                                .accessibilityLabel("Title error: \(titleValidation.message)")
                            }
                        }
                        
                        // Privacy Level Section (only if user can change it)
                        if canChangePrivacyLevel {
                            Section {
                                AccessiblePrivacyLevelPicker(
                                    selectedLevel: $privacyLevel,
                                    onLevelChanged: { level in
                                        privacyLevel = level
                                        HapticManager.shared.selection()
                                        announcePrivacyLevelChange(level)
                                        checkPermissions()
                                    }
                                )
                            } header: {
                                AccessibleText("Privacy", style: .headline, weight: .medium)
                                    .accessibilityAddTraits([.isHeader])
                            } footer: {
                                AccessibleText(
                                    privacyLevel.description,
                                    style: .caption,
                                    color: .secondary
                                )
                            }
                        }
                        
                        // Date and Time Section
                        Section {
                            AccessibleDateTimeSection(
                                startDate: $startDate,
                                endDate: $endDate,
                                isAllDay: $isAllDay,
                                validation: dateValidation,
                                onDateChange: { validateDates() },
                                onAllDayToggle: { newValue in
                                    isAllDay = newValue
                                    if newValue {
                                        // Set to start of day
                                        startDate = Calendar.current.startOfDay(for: startDate)
                                        endDate = Calendar.current.startOfDay(for: endDate)
                                    }
                                    validateDates()
                                    HapticManager.shared.selection()
                                    announceAllDayToggle(newValue)
                                }
                            )
                        } header: {
                            AccessibleText("When", style: .headline, weight: .medium)
                                .accessibilityAddTraits([.isHeader])
                        } footer: {
                            if !dateValidation.isValid && !dateValidation.message.isEmpty {
                                AccessibleText(
                                    dateValidation.message,
                                    style: .caption,
                                    color: .red
                                )
                                .accessibilityLabel("Date error: \(dateValidation.message)")
                            }
                        }
                        
                        // Location Section
                        Section {
                            AccessibleFormField(
                                title: "Location",
                                text: $location,
                                placeholder: "Add location (optional)",
                                keyboardType: .default
                            )
                            .focused($focusedField, equals: .location)
                        } header: {
                            AccessibleText("Where", style: .headline, weight: .medium)
                                .accessibilityAddTraits([.isHeader])
                        }
                        
                        // Notes Section
                        Section {
                            AccessibleFormField(
                                title: "Notes",
                                text: $notes,
                                placeholder: "Add notes (optional)",
                                isMultiline: true,
                                keyboardType: .default
                            )
                            .focused($focusedField, equals: .notes)
                        } header: {
                            AccessibleText("Notes", style: .headline, weight: .medium)
                                .accessibilityAddTraits([.isHeader])
                        }
                        
                        // Event Metadata Section
                        Section {
                            AccessibleEventMetadataView(event: originalEvent)
                        } header: {
                            AccessibleText("Event Information", style: .headline, weight: .medium)
                                .accessibilityAddTraits([.isHeader])
                        }
                        
                        // Delete Section
                        if canDelete {
                            Section {
                                AccessibleButton(
                                    action: {
                                        showingDeleteAlert = true
                                        HapticManager.shared.warning()
                                    },
                                    label: "Delete event",
                                    hint: "Permanently delete this event",
                                    hapticStyle: .heavy
                                ) {
                                    HStack {
                                        Image(systemName: "trash")
                                            .accessibilityHidden(true)
                                        AccessibleText("Delete Event", color: .red)
                                    }
                                    .foregroundColor(.red)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    AccessibleButton(
                        action: {
                            dismiss()
                            HapticManager.shared.lightImpact()
                        },
                        label: "Cancel editing",
                        hint: "Discard changes and return to event details",
                        hapticStyle: .light
                    ) {
                        Text("Cancel")
                    }
                }
                
                if canEdit {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        AccessibleButton(
                            action: updateEvent,
                            label: "Save changes",
                            hint: isFormValid ? "Save the changes to the event" : "Complete all required fields to save changes",
                            isEnabled: isFormValid && !isUpdating && hasChanges,
                            isLoading: isUpdating,
                            hapticStyle: .medium
                        ) {
                            if isUpdating {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Saving...")
                                }
                            } else {
                                Text("Save")
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            }
            .disabled(isUpdating)
            .overlay {
                if isUpdating {
                    AccessibleLoadingOverlay(message: "Updating event...")
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
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Edit event form for \(originalEvent.title)")
        }
        .onAppear {
            validateTitle(title)
            validateDates()
            checkPermissions()
            
            // Focus on title field for keyboard users
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                focusedField = .title
            }
        }
        .onChange(of: showingSuccessMessage) { _, isShowing in
            if isShowing {
                HapticManager.shared.success()
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "Event updated successfully"
                )
            }
        }
        .accessibilityRotor("Form Fields") {
            ForEach(FormField.allCases, id: \.self) { field in
                AccessibilityRotorEntry(field.accessibilityLabel, id: field) {
                    focusedField = field
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        titleValidation.isValid && 
        dateValidation.isValid && 
        permissionValidation.isValid &&
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
            titleValidation = ValidationResult(isValid: false, message: "Event title is required")
        } else if trimmedTitle.count > 200 {
            titleValidation = ValidationResult(isValid: false, message: "Title must be 200 characters or less")
        } else {
            titleValidation = ValidationResult(isValid: true, message: "")
        }
    }
    
    private func validateDates() {
        if isAllDay {
            // For all-day events, end date should be same day or later
            if Calendar.current.compare(endDate, to: startDate, toGranularity: .day) == .orderedAscending {
                dateValidation = ValidationResult(isValid: false, message: "End date cannot be before start date")
            } else {
                dateValidation = ValidationResult(isValid: true, message: "")
            }
        } else {
            // For timed events, end must be after start
            if endDate <= startDate {
                dateValidation = ValidationResult(isValid: false, message: "End time must be after start time")
            } else {
                let duration = endDate.timeIntervalSince(startDate)
                if duration > 24 * 60 * 60 { // More than 24 hours
                    dateValidation = ValidationResult(isValid: false, message: "Event duration cannot exceed 24 hours")
                } else {
                    dateValidation = ValidationResult(isValid: true, message: "")
                }
            }
        }
    }
    
    private func checkPermissions() {
        if !canEdit {
            permissionValidation = ValidationResult(isValid: false, message: "You don't have permission to edit this event")
        } else if privacyLevel == .familyShared && originalEvent.privacyLevel == .personal {
            // Check if user can create family events
            // TODO: Implement proper permission checking
            permissionValidation = ValidationResult(isValid: true, message: "")
        } else {
            permissionValidation = ValidationResult(isValid: true, message: "")
        }
    }
    
    // MARK: - Actions
    
    private func updateEvent() {
        guard isFormValid && hasChanges else { 
            HapticManager.shared.error()
            announceFormErrors()
            return 
        }
        
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
                    isUpdating = false
                    showingSuccessMessage = true
                    
                    // Announce success and dismiss
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isUpdating = false
                    HapticManager.shared.error()
                    
                    // Announce error
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: "Failed to update event. Please try again."
                    )
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
                    isUpdating = false
                    HapticManager.shared.warning()
                    
                    // Announce deletion and dismiss
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: "Event '\(originalEvent.title)' deleted"
                    )
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isUpdating = false
                    HapticManager.shared.error()
                    
                    // Announce error
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: "Failed to delete event. Please try again."
                    )
                }
            }
        }
    }
    
    // MARK: - Accessibility Announcements
    
    private func announceValidationChange(for field: FormField) {
        let validation = field == .title ? titleValidation : ValidationResult()
        
        if !validation.isValid && !validation.message.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "Error: \(validation.message)"
                )
            }
        }
    }
    
    private func announcePrivacyLevelChange(_ level: CalendarEvent.PrivacyLevel) {
        UIAccessibility.post(
            notification: .announcement,
            argument: "Privacy level changed to \(level.displayName)"
        )
    }
    
    private func announceAllDayToggle(_ isAllDay: Bool) {
        let message = isAllDay ? "All day event enabled" : "All day event disabled"
        UIAccessibility.post(notification: .announcement, argument: message)
    }
    
    private func announceFormErrors() {
        var errors: [String] = []
        
        if !titleValidation.isValid {
            errors.append(titleValidation.message)
        }
        
        if !dateValidation.isValid {
            errors.append(dateValidation.message)
        }
        
        if !permissionValidation.isValid {
            errors.append(permissionValidation.message)
        }
        
        if !errors.isEmpty {
            let message = "Please fix the following errors: \(errors.joined(separator: ", "))"
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
}

// MARK: - Accessible Permission Denied View

struct AccessiblePermissionDeniedView: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
                .accessibilityHidden(true)
            
            VStack(spacing: 8) {
                AccessibleText(
                    "Permission Required",
                    style: .title2,
                    weight: .bold
                )
                .accessibilityAddTraits([.isHeader])
                
                AccessibleText(
                    message,
                    style: .subheadline,
                    color: .secondary,
                    alignment: .center
                )
            }
            
            AccessibleButton(
                action: {
                    onDismiss()
                    HapticManager.shared.lightImpact()
                },
                label: "OK",
                hint: "Return to previous screen",
                hapticStyle: .light
            ) {
                Text("OK")
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Permission denied: \(message)")
    }
}

// MARK: - Preview

#Preview {
    AccessibleEventEditView(event: CalendarEvent(
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