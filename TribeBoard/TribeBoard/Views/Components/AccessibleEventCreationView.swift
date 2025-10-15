import SwiftUI

// MARK: - Accessible Event Creation View

struct AccessibleEventCreationView: View {
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
    @State private var isCreating = false
    @State private var showingSuccessMessage = false
    
    // Validation state
    @State private var titleValidation = ValidationResult()
    @State private var dateValidation = ValidationResult()
    
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
    
    var body: some View {
        NavigationView {
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
                
                // Privacy Level Section
                Section {
                    AccessiblePrivacyLevelPicker(
                        selectedLevel: $privacyLevel,
                        onLevelChanged: { level in
                            privacyLevel = level
                            HapticManager.shared.selection()
                            announcePrivacyLevelChange(level)
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
            }
            .navigationTitle("New Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    AccessibleButton(
                        action: {
                            dismiss()
                            HapticManager.shared.lightImpact()
                        },
                        label: "Cancel event creation",
                        hint: "Discard changes and return to calendar",
                        hapticStyle: .light
                    ) {
                        Text("Cancel")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    AccessibleButton(
                        action: createEvent,
                        label: "Create event",
                        hint: isFormValid ? "Create the event with the entered details" : "Complete all required fields to create the event",
                        isEnabled: isFormValid && !isCreating,
                        isLoading: isCreating,
                        hapticStyle: .medium
                    ) {
                        if isCreating {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Creating...")
                            }
                        } else {
                            Text("Create")
                                .fontWeight(.semibold)
                        }
                    }
                }
            }
            .disabled(isCreating)
            .overlay {
                if isCreating {
                    AccessibleLoadingOverlay(message: "Creating event...")
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Create new event form")
            .onAppear {
                // Set initial end date
                if !isAllDay {
                    endDate = startDate.addingTimeInterval(3600)
                }
                validateTitle(title)
                validateDates()
                
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
                        argument: "Event created successfully"
                    )
                }
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
    
    // MARK: - Validation
    
    private var isFormValid: Bool {
        titleValidation.isValid && 
        dateValidation.isValid && 
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
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
    
    // MARK: - Actions
    
    private func createEvent() {
        guard isFormValid else { 
            HapticManager.shared.error()
            announceFormErrors()
            return 
        }
        
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
                    isCreating = false
                    showingSuccessMessage = true
                    
                    // Announce success and dismiss
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    HapticManager.shared.error()
                    
                    // Announce error
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: "Failed to create event. Please try again."
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
        
        if !errors.isEmpty {
            let message = "Please fix the following errors: \(errors.joined(separator: ", "))"
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
}

// MARK: - Accessible Privacy Level Picker

struct AccessiblePrivacyLevelPicker: View {
    @Binding var selectedLevel: CalendarEvent.PrivacyLevel
    let onLevelChanged: (CalendarEvent.PrivacyLevel) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AccessibleText(
                "Who can see this event?",
                style: .subheadline,
                weight: .medium
            )
            
            ForEach(CalendarEvent.PrivacyLevel.allCases, id: \.self) { level in
                AccessiblePrivacyLevelRow(
                    level: level,
                    isSelected: selectedLevel == level,
                    onTap: {
                        selectedLevel = level
                        onLevelChanged(level)
                    }
                )
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Privacy level selection")
        .accessibilityRotor("Privacy Levels") {
            ForEach(CalendarEvent.PrivacyLevel.allCases, id: \.self) { level in
                AccessibilityRotorEntry(
                    "\(level.displayName): \(level.description)",
                    id: level
                ) {
                    selectedLevel = level
                    onLevelChanged(level)
                }
            }
        }
    }
}

// MARK: - Accessible Privacy Level Row

struct AccessiblePrivacyLevelRow: View {
    let level: CalendarEvent.PrivacyLevel
    let isSelected: Bool
    let onTap: () -> Void
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        AccessibleButton(
            action: onTap,
            label: "\(level.displayName): \(level.description)",
            hint: isSelected ? "Currently selected" : "Tap to select this privacy level",
            hapticStyle: .light
        ) {
            HStack(spacing: 12) {
                Image(systemName: level.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 2) {
                    AccessibleText(
                        level.displayName,
                        style: .subheadline,
                        weight: .medium,
                        color: .primary
                    )
                    
                    AccessibleText(
                        level.description,
                        style: .caption,
                        color: .secondary
                    )
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .scaleEffect(isSelected && !reduceMotion ? 1.02 : 1.0)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: isSelected)
        }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Accessible Date Time Section

struct AccessibleDateTimeSection: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var isAllDay: Bool
    let validation: ValidationResult
    let onDateChange: () -> Void
    let onAllDayToggle: (Bool) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            // All Day Toggle
            HStack {
                AccessibleText("All Day", style: .body)
                
                Spacer()
                
                Toggle("", isOn: $isAllDay)
                    .accessibilityLabel("All day event")
                    .accessibilityHint(isAllDay ? "Event is set to all day" : "Event has specific times")
                    .onChange(of: isAllDay) { _, newValue in
                        onAllDayToggle(newValue)
                    }
            }
            
            // Start Date
            AccessibleDateTimePickerRow(
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
                onDateChange()
            }
            
            // End Date
            AccessibleDateTimePickerRow(
                title: "Ends",
                date: $endDate,
                isAllDay: isAllDay,
                accessibilityLabel: "Event end date and time"
            )
            .onChange(of: endDate) { _, _ in
                onDateChange()
            }
        }
    }
}

// MARK: - Accessible Date Time Picker Row

struct AccessibleDateTimePickerRow: View {
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
            AccessibleText(title, style: .body, color: .primary)
            
            Spacer()
            
            DatePicker(
                "",
                selection: $date,
                displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute]
            )
            .labelsHidden()
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(dateFormatter.string(from: date))
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Accessible Loading Overlay

struct AccessibleLoadingOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                    .accessibilityHidden(true)
                
                AccessibleText(
                    message,
                    style: .subheadline,
                    weight: .medium
                )
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 10)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(message)
        .accessibilityAddTraits([.updatesFrequently])
    }
}

// Note: ValidationResult is now defined in CalendarService.swift

// MARK: - Preview

#Preview {
    AccessibleEventCreationView()
}