import SwiftUI

struct EnhancedEventDetailView: View {
    let event: CalendarEvent
    let userProfiles: [UUID: UserProfile]
    let onEdit: (CalendarEvent) -> Void
    let onDelete: (CalendarEvent) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteAlert = false
    @State private var showingShareSheet = false
    @State private var showingConflictResolution = false
    @State private var isPerformingAction = false
    
    // Permission checking
    private var canEdit: Bool {
        // TODO: Implement proper permission checking
        return event.privacyLevel == .personal || true // Assume user can edit for now
    }
    
    private var canDelete: Bool {
        return canEdit
    }
    
    private var canShare: Bool {
        return event.privacyLevel == .familyShared || canEdit
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Event Header with Privacy Indicator
                    EnhancedEventHeaderSection(event: event)
                    
                    // Event Status and Timing
                    EventStatusSection(event: event)
                    
                    // Event Details
                    EnhancedEventDetailsSection(event: event)
                    
                    // Family Event Participants (if family shared)
                    if event.privacyLevel == .familyShared {
                        FamilyParticipantsSection(
                            event: event,
                            userProfiles: userProfiles
                        )
                    }
                    
                    // Location Section
                    if let location = event.location {
                        EnhancedLocationSection(location: location)
                    }
                    
                    // Notes Section
                    if let notes = event.notes {
                        EnhancedNotesSection(notes: notes)
                    }
                    
                    // Sync Status Section
                    EventSyncStatusSection(event: event)
                    
                    // Event Metadata
                    EventMetadataSection(event: event)
                    
                    // Action Buttons
                    EventActionSection(
                        event: event,
                        canEdit: canEdit,
                        canDelete: canDelete,
                        canShare: canShare,
                        onEdit: { onEdit(event) },
                        onDelete: { showingDeleteAlert = true },
                        onShare: { showingShareSheet = true },
                        onResolveConflict: { showingConflictResolution = true }
                    )
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .accessibilityLabel("Close event details")
                }
                
                if canEdit {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Edit") {
                            onEdit(event)
                        }
                        .accessibilityLabel("Edit event")
                    }
                }
            }
            .alert("Delete Event", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    performDelete()
                }
            } message: {
                Text("Are you sure you want to delete '\(event.title)'? This action cannot be undone.")
            }
            .sheet(isPresented: $showingShareSheet) {
                EventSharingView(event: event)
            }
            .sheet(isPresented: $showingConflictResolution) {
                EventConflictResolutionView(event: event)
            }
            .disabled(isPerformingAction)
            .overlay {
                if isPerformingAction {
                    LoadingOverlay(message: "Processing...")
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func performDelete() {
        isPerformingAction = true
        
        Task {
            // Simulate deletion process
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            await MainActor.run {
                // Provide haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                impactFeedback.impactOccurred()
                
                onDelete(event)
                dismiss()
            }
        }
    }
}

// MARK: - Enhanced Event Header Section

struct EnhancedEventHeaderSection: View {
    let event: CalendarEvent
    
    var body: some View {
        VStack(spacing: 16) {
            // Privacy level and sync status indicators
            HStack {
                PrivacyLevelBadge(level: event.privacyLevel)
                
                Spacer()
                
                if event.eventKitIdentifier != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.icloud")
                            .font(.caption)
                        Text("Synced")
                            .font(.caption)
                    }
                    .foregroundColor(.green)
                } else if event.needsEventKitSync {
                    HStack(spacing: 4) {
                        Image(systemName: "icloud.and.arrow.up")
                            .font(.caption)
                        Text("Pending Sync")
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                }
            }
            
            // Event title and icon
            VStack(spacing: 12) {
                Image(systemName: event.privacyLevel.icon)
                    .font(.system(size: 50))
                    .foregroundColor(colorForPrivacyLevel(event.privacyLevel))
                
                Text(event.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
    }
    
    private func colorForPrivacyLevel(_ level: CalendarEvent.PrivacyLevel) -> Color {
        switch level {
        case .familyShared:
            return .blue
        case .personal:
            return .purple
        }
    }
}

// MARK: - Event Status Section

struct EventStatusSection: View {
    let event: CalendarEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Status", icon: "clock")
            
            VStack(spacing: 12) {
                // Current status
                StatusRow(
                    icon: statusIcon,
                    title: "Status",
                    value: statusText,
                    color: statusColor
                )
                
                // Time information
                StatusRow(
                    icon: "calendar",
                    title: "When",
                    value: event.dateRangeString,
                    color: .primary
                )
                
                if !event.isAllDay {
                    StatusRow(
                        icon: "clock",
                        title: "Duration",
                        value: event.durationString,
                        color: .primary
                    )
                }
            }
        }
    }
    
    private var statusIcon: String {
        if event.isHappening {
            return "play.circle.fill"
        } else if event.isPast {
            return "checkmark.circle.fill"
        } else {
            return "clock.circle.fill"
        }
    }
    
    private var statusText: String {
        if event.isHappening {
            return "Happening Now"
        } else if event.isPast {
            return "Completed"
        } else if event.isToday {
            return "Today"
        } else {
            let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: event.startDate).day ?? 0
            return daysUntil == 1 ? "Tomorrow" : "In \(daysUntil) days"
        }
    }
    
    private var statusColor: Color {
        if event.isHappening {
            return .green
        } else if event.isPast {
            return .secondary
        } else if event.isToday {
            return .blue
        } else {
            return .orange
        }
    }
}

// MARK: - Enhanced Event Details Section

struct EnhancedEventDetailsSection: View {
    let event: CalendarEvent
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = event.isAllDay ? .none : .short
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Details", icon: "info.circle")
            
            VStack(spacing: 12) {
                DetailRow(
                    icon: "calendar",
                    title: "Start Date",
                    value: dateFormatter.string(from: event.startDate)
                )
                
                if !Calendar.current.isDate(event.startDate, inSameDayAs: event.endDate) || !event.isAllDay {
                    DetailRow(
                        icon: "calendar.badge.clock",
                        title: "End Date",
                        value: dateFormatter.string(from: event.endDate)
                    )
                }
                
                DetailRow(
                    icon: "eye",
                    title: "Privacy",
                    value: event.privacyLevel.displayName
                )
                
                if event.isAllDay {
                    DetailRow(
                        icon: "sun.max",
                        title: "Type",
                        value: "All Day Event"
                    )
                }
            }
        }
    }
}

// MARK: - Family Participants Section

struct FamilyParticipantsSection: View {
    let event: CalendarEvent
    let userProfiles: [UUID: UserProfile]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Family Members", icon: "person.2")
            
            VStack(spacing: 8) {
                // Event creator
                if let creatorProfile = userProfiles[event.createdBy] {
                    FamilyMemberRow(
                        profile: creatorProfile,
                        role: "Event Creator",
                        isCreator: true
                    )
                }
                
                // Other family members (simulated)
                ForEach(Array(userProfiles.values.prefix(3)), id: \.id) { profile in
                    if profile.id != event.createdBy {
                        FamilyMemberRow(
                            profile: profile,
                            role: "Participant",
                            isCreator: false
                        )
                    }
                }
                
                // Add participant button (for family admins)
                Button(action: {
                    // TODO: Implement add participant functionality
                }) {
                    HStack {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.blue)
                        
                        Text("Add Family Member")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .accessibilityLabel("Add family member to event")
            }
        }
    }
}

// MARK: - Family Member Row

struct FamilyMemberRow: View {
    let profile: UserProfile
    let role: String
    let isCreator: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(isCreator ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(profile.displayName.prefix(1)))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isCreator ? .blue : .gray)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(role)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isCreator {
                Image(systemName: "crown.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(profile.displayName), \(role)")
    }
}

// MARK: - Enhanced Location Section

struct EnhancedLocationSection: View {
    let location: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Location", icon: "location")
            
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title3)
                        .foregroundColor(.red)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(location)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Tap for directions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .onTapGesture {
                    // TODO: Open Maps app with location
                    print("Opening directions to: \(location)")
                }
                
                // Quick actions
                HStack(spacing: 12) {
                    LocationActionButton(
                        icon: "map",
                        title: "Directions",
                        action: {
                            // TODO: Open Maps
                        }
                    )
                    
                    LocationActionButton(
                        icon: "doc.on.doc",
                        title: "Copy",
                        action: {
                            UIPasteboard.general.string = location
                        }
                    )
                    
                    LocationActionButton(
                        icon: "square.and.arrow.up",
                        title: "Share",
                        action: {
                            // TODO: Share location
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Location Action Button

struct LocationActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.subheadline)
                
                Text(title)
                    .font(.caption)
            }
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(8)
        }
        .accessibilityLabel(title)
    }
}

// MARK: - Enhanced Notes Section

struct EnhancedNotesSection: View {
    let notes: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Notes", icon: "text.alignleft")
            
            VStack(alignment: .leading, spacing: 8) {
                Text(notes)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                
                // Quick actions for notes
                HStack(spacing: 12) {
                    Button(action: {
                        UIPasteboard.general.string = notes
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                            Text("Copy")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                    }
                    .accessibilityLabel("Copy notes")
                    
                    Spacer()
                }
            }
        }
    }
}

// MARK: - Event Sync Status Section

struct EventSyncStatusSection: View {
    let event: CalendarEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Sync Status", icon: "icloud")
            
            VStack(spacing: 12) {
                // Apple Calendar sync status
                SyncStatusRow(
                    service: "Apple Calendar",
                    icon: "calendar",
                    status: event.eventKitIdentifier != nil ? .synced : (event.needsEventKitSync ? .pending : .disabled),
                    lastSync: event.eventKitIdentifier != nil ? Date() : nil
                )
                
                // CloudKit sync status (for family events)
                if event.privacyLevel == .familyShared {
                    SyncStatusRow(
                        service: "Family Sharing",
                        icon: "icloud",
                        status: event.ckRecordID != nil ? .synced : (event.needsSync ? .pending : .disabled),
                        lastSync: event.lastSyncDate
                    )
                }
            }
        }
    }
}

// MARK: - Sync Status Row

struct SyncStatusRow: View {
    let service: String
    let icon: String
    let status: SyncStatus
    let lastSync: Date?
    
    enum SyncStatus {
        case synced, pending, disabled, error
        
        var color: Color {
            switch self {
            case .synced: return .green
            case .pending: return .orange
            case .disabled: return .secondary
            case .error: return .red
            }
        }
        
        var text: String {
            switch self {
            case .synced: return "Synced"
            case .pending: return "Pending"
            case .disabled: return "Disabled"
            case .error: return "Error"
            }
        }
        
        var icon: String {
            switch self {
            case .synced: return "checkmark.circle.fill"
            case .pending: return "clock.circle.fill"
            case .disabled: return "xmark.circle.fill"
            case .error: return "exclamationmark.triangle.fill"
            }
        }
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(service)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let lastSync = lastSync {
                    Text("Last synced: \(dateFormatter.string(from: lastSync))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Image(systemName: status.icon)
                    .font(.caption)
                
                Text(status.text)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(status.color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Event Metadata Section

struct EventMetadataSection: View {
    let event: CalendarEvent
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Event Information", icon: "info.circle")
            
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
                    icon: "number.circle",
                    title: "Version",
                    value: "\(event.version)"
                )
                
                if let eventKitId = event.eventKitIdentifier {
                    MetadataRow(
                        icon: "link.circle",
                        title: "Apple Calendar ID",
                        value: String(eventKitId.prefix(8)) + "..."
                    )
                }
            }
        }
    }
}

// MARK: - Event Action Section

struct EventActionSection: View {
    let event: CalendarEvent
    let canEdit: Bool
    let canDelete: Bool
    let canShare: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onShare: () -> Void
    let onResolveConflict: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            SectionHeader(title: "Actions", icon: "gear")
            
            VStack(spacing: 12) {
                // Primary actions
                if canEdit || canShare {
                    HStack(spacing: 12) {
                        if canEdit {
                            ActionButton(
                                title: "Edit Event",
                                icon: "pencil",
                                style: .primary,
                                action: onEdit
                            )
                        }
                        
                        if canShare {
                            ActionButton(
                                title: "Share",
                                icon: "square.and.arrow.up",
                                style: .secondary,
                                action: onShare
                            )
                        }
                    }
                }
                
                // Conflict resolution (if needed)
                if event.version > 1 {
                    ActionButton(
                        title: "Resolve Conflicts",
                        icon: "exclamationmark.triangle",
                        style: .warning,
                        action: onResolveConflict
                    )
                }
                
                // Delete action
                if canDelete {
                    ActionButton(
                        title: "Delete Event",
                        icon: "trash",
                        style: .destructive,
                        action: onDelete
                    )
                }
            }
        }
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let title: String
    let icon: String
    let style: ButtonStyle
    let action: () -> Void
    
    enum ButtonStyle {
        case primary, secondary, warning, destructive
        
        var backgroundColor: Color {
            switch self {
            case .primary: return .blue
            case .secondary: return .blue.opacity(0.1)
            case .warning: return .orange.opacity(0.1)
            case .destructive: return .red.opacity(0.1)
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .primary: return .white
            case .secondary: return .blue
            case .warning: return .orange
            case .destructive: return .red
            }
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(style.foregroundColor)
            .frame(maxWidth: .infinity)
            .padding()
            .background(style.backgroundColor)
            .cornerRadius(12)
        }
        .accessibilityLabel(title)
    }
}

// MARK: - Status Row

struct StatusRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(color)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    EnhancedEventDetailView(
        event: CalendarEvent(
            title: "Family Dinner",
            startDate: Date(),
            endDate: Date().addingTimeInterval(7200),
            isAllDay: false,
            location: "Home",
            notes: "Don't forget to bring dessert!",
            privacyLevel: .familyShared,
            createdBy: UUID(),
            familyId: UUID()
        ),
        userProfiles: [:],
        onEdit: { _ in },
        onDelete: { _ in }
    )
}