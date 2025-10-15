import SwiftUI

// MARK: - Accessible Calendar Event Card

struct AccessibleCalendarEventCard: View {
    let event: CalendarEvent
    let onTap: () -> Void
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    @State private var isPressed = false
    
    var body: some View {
        AccessibleButton(
            action: {
                onTap()
                HapticManager.shared.selection()
            },
            label: accessibilityLabel,
            hint: "Tap to view event details",
            hapticStyle: .light
        ) {
            HStack(spacing: 16) {
                // Privacy level and status indicator
                VStack(spacing: 4) {
                    Image(systemName: event.privacyLevel.icon)
                        .font(.title3)
                        .foregroundColor(colorForPrivacyLevel(event.privacyLevel))
                        .accessibilityHidden(true)
                    
                    Rectangle()
                        .fill(colorForPrivacyLevel(event.privacyLevel))
                        .frame(width: 4, height: 40)
                        .cornerRadius(2)
                        .accessibilityHidden(true)
                }
                
                // Event details
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        AccessibleText(
                            event.title,
                            style: .subheadline,
                            weight: .semibold,
                            color: .primary,
                            alignment: .leading
                        )
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        
                        Spacer()
                        
                        // Privacy level badge
                        AccessiblePrivacyLevelBadge(level: event.privacyLevel)
                    }
                    
                    // Date and time info
                    HStack(spacing: 8) {
                        if event.isAllDay {
                            AccessibleText(
                                "All day",
                                style: .caption,
                                color: .secondary
                            )
                        } else {
                            AccessibleText(
                                event.dateRangeString,
                                style: .caption,
                                color: .secondary
                            )
                        }
                        
                        // Event status indicator
                        if event.isHappening {
                            AccessibleText(
                                "• Now",
                                style: .caption,
                                weight: .medium,
                                color: .green
                            )
                        } else if event.isToday && event.isUpcoming {
                            AccessibleText(
                                "• Today",
                                style: .caption,
                                weight: .medium,
                                color: .blue
                            )
                        }
                    }
                    
                    // Location
                    if let location = event.location {
                        HStack(spacing: 4) {
                            Image(systemName: "location")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .accessibilityHidden(true)
                            
                            AccessibleText(
                                location,
                                style: .caption,
                                color: .secondary
                            )
                            .lineLimit(1)
                        }
                    }
                    
                    // Duration
                    if !event.isAllDay {
                        AccessibleText(
                            "Duration: \(event.durationString)",
                            style: .caption2,
                            color: .secondary
                        )
                    }
                }
                
                Spacer()
                
                // Sync status and navigation indicator
                VStack(spacing: 4) {
                    if event.eventKitIdentifier != nil {
                        Image(systemName: "checkmark.icloud")
                            .font(.caption)
                            .foregroundColor(.green)
                            .accessibilityLabel("Synced with Apple Calendar")
                    } else if event.needsEventKitSync {
                        Image(systemName: "icloud.and.arrow.up")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .accessibilityLabel("Pending sync with Apple Calendar")
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                }
            }
            .padding()
            .background(backgroundColorForEvent(event))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColorForEvent(event), lineWidth: strokeWidth)
            )
            .scaleEffect(isPressed && !reduceMotion ? 0.98 : 1.0)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.1), value: isPressed)
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Tap to view event details")
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits([.isButton])
    }
    
    // MARK: - Accessibility Properties
    
    private var accessibilityLabel: String {
        var components: [String] = []
        
        // Event title
        components.append(event.title)
        
        // Privacy level
        components.append("\(event.privacyLevel.displayName) event")
        
        // Date and time
        if event.isAllDay {
            components.append("all day")
        } else {
            components.append(event.dateRangeString)
        }
        
        // Location
        if let location = event.location {
            components.append("at \(location)")
        }
        
        // Status
        if event.isHappening {
            components.append("happening now")
        } else if event.isToday && event.isUpcoming {
            components.append("today")
        } else if event.isPast {
            components.append("past event")
        }
        
        return components.joined(separator: ", ")
    }
    
    private var accessibilityValue: String {
        var values: [String] = []
        
        // Duration for non-all-day events
        if !event.isAllDay {
            values.append("Duration: \(event.durationString)")
        }
        
        // Sync status
        if event.eventKitIdentifier != nil {
            values.append("Synced with Apple Calendar")
        } else if event.needsEventKitSync {
            values.append("Pending sync")
        }
        
        return values.joined(separator: ", ")
    }
    
    // MARK: - Visual Properties
    
    private func colorForPrivacyLevel(_ level: CalendarEvent.PrivacyLevel) -> Color {
        let baseColor: Color = switch level {
        case .familyShared: .blue
        case .personal: .purple
        }
        
        // Adjust for high contrast if needed
        return colorSchemeContrast == .increased ? baseColor : baseColor
    }
    
    private func backgroundColorForEvent(_ event: CalendarEvent) -> Color {
        if event.isHappening {
            return Color.green.opacity(colorSchemeContrast == .increased ? 0.2 : 0.1)
        } else if event.isPast {
            return Color(.systemGray6)
        } else {
            return Color(.systemBackground)
        }
    }
    
    private func borderColorForEvent(_ event: CalendarEvent) -> Color {
        if event.isHappening {
            return Color.green.opacity(colorSchemeContrast == .increased ? 0.6 : 0.3)
        } else {
            return Color(.systemGray4)
        }
    }
    
    private var strokeWidth: CGFloat {
        colorSchemeContrast == .increased ? 2 : 1
    }
}

// MARK: - Accessible Privacy Level Badge

struct AccessiblePrivacyLevelBadge: View {
    let level: CalendarEvent.PrivacyLevel
    
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: level.icon)
                .font(.caption2)
                .accessibilityHidden(true)
            
            AccessibleText(
                level.displayName,
                style: .caption2,
                weight: .medium,
                color: colorForLevel
            )
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            Capsule()
                .fill(colorForLevel.opacity(colorSchemeContrast == .increased ? 0.3 : 0.2))
        )
        .overlay(
            Capsule()
                .stroke(colorForLevel.opacity(0.5), lineWidth: colorSchemeContrast == .increased ? 1 : 0)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(level.displayName) privacy level")
    }
    
    private var colorForLevel: Color {
        switch level {
        case .familyShared: return .blue
        case .personal: return .purple
        }
    }
}

// MARK: - Accessible Event Detail View

struct AccessibleEventDetailView: View {
    let event: CalendarEvent
    let userProfiles: [UUID: UserProfile]
    let onEdit: (CalendarEvent) -> Void
    let onDelete: (CalendarEvent) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Event Header
                    AccessibleEventHeaderView(event: event)
                    
                    // Event Details
                    AccessibleEventDetailsView(event: event)
                    
                    // Event Actions
                    if canEditEvent {
                        AccessibleEventActionsView(
                            event: event,
                            onEdit: { onEdit(event) },
                            onDelete: { showingDeleteAlert = true }
                        )
                    }
                    
                    // Event Metadata
                    AccessibleEventMetadataView(event: event)
                }
                .padding()
            }
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    AccessibleButton(
                        action: { dismiss() },
                        label: "Close event details",
                        hint: "Return to calendar",
                        hapticStyle: .light
                    ) {
                        Text("Done")
                    }
                }
                
                if canEditEvent {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        AccessibleButton(
                            action: { onEdit(event) },
                            label: "Edit event",
                            hint: "Modify event details",
                            hapticStyle: .medium
                        ) {
                            Text("Edit")
                        }
                    }
                }
            }
            .alert("Delete Event", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    onDelete(event)
                    HapticManager.shared.warning()
                }
            } message: {
                Text("Are you sure you want to delete '\(event.title)'? This action cannot be undone.")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Event details for \(event.title)")
    }
    
    private var canEditEvent: Bool {
        // TODO: Implement proper permission checking
        event.privacyLevel == .personal || true
    }
}

// MARK: - Accessible Event Header

struct AccessibleEventHeaderView: View {
    let event: CalendarEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                AccessibleText(
                    event.title,
                    style: .title2,
                    weight: .bold
                )
                .accessibilityAddTraits([.isHeader])
                
                Spacer()
                
                AccessiblePrivacyLevelBadge(level: event.privacyLevel)
            }
            
            // Event status
            if event.isHappening {
                HStack(spacing: 8) {
                    Image(systemName: "circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                        .accessibilityHidden(true)
                    
                    AccessibleText(
                        "Happening Now",
                        style: .subheadline,
                        weight: .medium,
                        color: .green
                    )
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Event is happening now")
            } else if event.isToday && event.isUpcoming {
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .accessibilityHidden(true)
                    
                    AccessibleText(
                        "Today",
                        style: .subheadline,
                        weight: .medium,
                        color: .blue
                    )
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Event is today")
            }
        }
    }
}

// MARK: - Accessible Event Details

struct AccessibleEventDetailsView: View {
    let event: CalendarEvent
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = event.isAllDay ? .none : .short
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Date and Time
            AccessibleDetailRow(
                icon: "calendar",
                title: "When",
                content: {
                    VStack(alignment: .leading, spacing: 4) {
                        if event.isAllDay {
                            AccessibleText(
                                dateFormatter.string(from: event.startDate),
                                style: .body,
                                weight: .medium
                            )
                            AccessibleText(
                                "All day",
                                style: .caption,
                                color: .secondary
                            )
                        } else {
                            AccessibleText(
                                dateFormatter.string(from: event.startDate),
                                style: .body,
                                weight: .medium
                            )
                            AccessibleText(
                                "to \(dateFormatter.string(from: event.endDate))",
                                style: .body,
                                weight: .medium
                            )
                            AccessibleText(
                                "Duration: \(event.durationString)",
                                style: .caption,
                                color: .secondary
                            )
                        }
                    }
                }
            )
            
            // Location
            if let location = event.location {
                AccessibleDetailRow(
                    icon: "location",
                    title: "Where",
                    content: {
                        AccessibleText(
                            location,
                            style: .body
                        )
                    }
                )
            }
            
            // Notes
            if let notes = event.notes {
                AccessibleDetailRow(
                    icon: "note.text",
                    title: "Notes",
                    content: {
                        AccessibleText(
                            notes,
                            style: .body
                        )
                    }
                )
            }
        }
    }
}

// MARK: - Accessible Detail Row

struct AccessibleDetailRow<Content: View>: View {
    let icon: String
    let title: String
    let content: () -> Content
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
                .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 8) {
                AccessibleText(
                    title,
                    style: .headline,
                    weight: .medium
                )
                .accessibilityAddTraits([.isHeader])
                
                content()
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Accessible Event Actions

struct AccessibleEventActionsView: View {
    let event: CalendarEvent
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            AccessibleText(
                "Actions",
                style: .headline,
                weight: .medium
            )
            .accessibilityAddTraits([.isHeader])
            
            HStack(spacing: 16) {
                AccessibleButton(
                    action: {
                        onEdit()
                        HapticManager.shared.mediumImpact()
                    },
                    label: "Edit event",
                    hint: "Modify event details",
                    hapticStyle: .medium
                ) {
                    HStack {
                        Image(systemName: "pencil")
                        AccessibleText("Edit", style: .subheadline, weight: .medium, color: .white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                
                AccessibleButton(
                    action: {
                        onDelete()
                        HapticManager.shared.warning()
                    },
                    label: "Delete event",
                    hint: "Permanently remove this event",
                    hapticStyle: .heavy
                ) {
                    HStack {
                        Image(systemName: "trash")
                        AccessibleText("Delete", style: .subheadline, weight: .medium, color: .white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.red)
                    .cornerRadius(8)
                }
            }
        }
    }
}

// MARK: - Accessible Event Metadata

struct AccessibleEventMetadataView: View {
    let event: CalendarEvent
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AccessibleText(
                "Event Information",
                style: .headline,
                weight: .medium
            )
            .accessibilityAddTraits([.isHeader])
            
            VStack(spacing: 8) {
                AccessibleMetadataRow(
                    icon: "calendar.badge.plus",
                    title: "Created",
                    value: dateFormatter.string(from: event.createdAt)
                )
                
                if event.lastModified != event.createdAt {
                    AccessibleMetadataRow(
                        icon: "pencil.circle",
                        title: "Last Modified",
                        value: dateFormatter.string(from: event.lastModified)
                    )
                }
                
                AccessibleMetadataRow(
                    icon: "eye",
                    title: "Privacy Level",
                    value: event.privacyLevel.displayName
                )
                
                if event.eventKitIdentifier != nil {
                    AccessibleMetadataRow(
                        icon: "checkmark.icloud",
                        title: "Apple Calendar",
                        value: "Synced"
                    )
                } else if event.needsEventKitSync {
                    AccessibleMetadataRow(
                        icon: "icloud.and.arrow.up",
                        title: "Apple Calendar",
                        value: "Pending sync"
                    )
                }
            }
        }
    }
}

// MARK: - Accessible Metadata Row

struct AccessibleMetadataRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.blue)
                .frame(width: 20)
                .accessibilityHidden(true)
            
            AccessibleText(
                title,
                style: .subheadline,
                color: .secondary
            )
            
            Spacer()
            
            AccessibleText(
                value,
                style: .subheadline,
                weight: .medium
            )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}