import SwiftUI
import SwiftData

/// View for bulk event management operations (admin only)
struct BulkEventManagementView: View {
    let familyId: UUID
    let currentUserId: UUID
    
    @StateObject private var coordinationService: FamilyEventCoordinationService
    @State private var familyEvents: [CalendarEvent] = []
    @State private var selectedEvents: Set<UUID> = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingConfirmation = false
    @State private var selectedOperation: BulkEventOperation?
    @State private var dateRange = DateInterval(start: Date(), duration: 30 * 24 * 60 * 60) // 30 days
    
    private var canPerformBulkOperations: Bool {
        // This would check if user has bulk operation permissions
        true // Placeholder
    }
    
    private var hasSelectedEvents: Bool {
        !selectedEvents.isEmpty
    }
    
    init(familyId: UUID, currentUserId: UUID, modelContext: ModelContext) {
        self.familyId = familyId
        self.currentUserId = currentUserId
        let permissionManager = CalendarPermissionManager(modelContext: modelContext)
        self._coordinationService = StateObject(wrappedValue: FamilyEventCoordinationService(
            modelContext: modelContext,
            permissionManager: permissionManager
        ))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            headerSection
            
            if !canPerformBulkOperations {
                insufficientPermissionsSection
            } else if isLoading {
                loadingSection
            } else if let errorMessage = errorMessage {
                errorSection(errorMessage)
            } else {
                // Date range selector
                dateRangeSection
                
                // Selection summary
                selectionSummarySection
                
                // Events list
                eventsListSection
                
                // Bulk actions
                if hasSelectedEvents {
                    bulkActionsSection
                }
            }
        }
        .onAppear {
            loadFamilyEvents()
        }
        .alert("Confirm Bulk Operation", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Confirm", role: .destructive) {
                performBulkOperation()
            }
        } message: {
            Text(confirmationMessage)
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.title2)
                    .foregroundColor(.purple)
                
                Text("Bulk Event Management")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if hasSelectedEvents {
                    Button("Clear Selection") {
                        selectedEvents.removeAll()
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            Text("Select and manage multiple family events at once")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var insufficientPermissionsSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.title)
                .foregroundColor(.orange)
            
            Text("Insufficient Permissions")
                .font(.headline)
                .fontWeight(.medium)
            
            Text("You need bulk operation permissions to use this feature.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var loadingSection: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Loading family events...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func errorSection(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title)
                .foregroundColor(.orange)
            
            Text("Loading Error")
                .font(.headline)
                .fontWeight(.medium)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Retry") {
                loadFamilyEvents()
            }
            .font(.caption)
            .foregroundColor(.blue)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private var dateRangeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Date Range")
                .font(.headline)
                .fontWeight(.medium)
            
            HStack {
                DatePicker("From", selection: Binding(
                    get: { dateRange.start },
                    set: { newStart in
                        dateRange = DateInterval(start: newStart, end: dateRange.end)
                        loadFamilyEvents()
                    }
                ), displayedComponents: .date)
                
                DatePicker("To", selection: Binding(
                    get: { dateRange.end },
                    set: { newEnd in
                        dateRange = DateInterval(start: dateRange.start, end: newEnd)
                        loadFamilyEvents()
                    }
                ), displayedComponents: .date)
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var selectionSummarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Event Selection")
                    .font(.headline)
                    .fontWeight(.medium)
                
                Spacer()
                
                if !familyEvents.isEmpty {
                    Button(selectedEvents.count == familyEvents.count ? "Deselect All" : "Select All") {
                        if selectedEvents.count == familyEvents.count {
                            selectedEvents.removeAll()
                        } else {
                            selectedEvents = Set(familyEvents.map { $0.id })
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            HStack {
                Text("\(selectedEvents.count) of \(familyEvents.count) events selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if hasSelectedEvents {
                    Text("Ready for bulk operations")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var eventsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Family Events")
                .font(.headline)
                .fontWeight(.medium)
            
            if familyEvents.isEmpty {
                EmptyStateView(
                    icon: "calendar.badge.plus",
                    title: "No Events Found",
                    message: "No family events found in the selected date range."
                )
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(familyEvents, id: \.id) { event in
                        BulkEventRowView(
                            event: event,
                            isSelected: selectedEvents.contains(event.id),
                            onToggleSelection: {
                                if selectedEvents.contains(event.id) {
                                    selectedEvents.remove(event.id)
                                } else {
                                    selectedEvents.insert(event.id)
                                }
                            }
                        )
                    }
                }
            }
        }
    }
    
    private var bulkActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Bulk Actions")
                .font(.headline)
                .fontWeight(.medium)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                bulkActionButton(
                    title: "Delete Events",
                    icon: "trash.fill",
                    color: .red,
                    operation: .delete
                )
                
                bulkActionButton(
                    title: "Make Private",
                    icon: "person.fill",
                    color: .blue,
                    operation: .updatePrivacy(.personal)
                )
                
                bulkActionButton(
                    title: "Make Shared",
                    icon: "person.2.fill",
                    color: .green,
                    operation: .updatePrivacy(.familyShared)
                )
                
                bulkActionButton(
                    title: "Send Reminders",
                    icon: "bell.fill",
                    color: .orange,
                    operation: .sendReminders
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func bulkActionButton(
        title: String,
        icon: String,
        color: Color,
        operation: BulkEventOperation
    ) -> some View {
        Button(action: {
            selectedOperation = operation
            showingConfirmation = true
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var confirmationMessage: String {
        guard let operation = selectedOperation else { return "" }
        
        let eventCount = selectedEvents.count
        let eventText = eventCount == 1 ? "event" : "events"
        
        switch operation {
        case .delete:
            return "Are you sure you want to delete \(eventCount) \(eventText)? This action cannot be undone."
        case .updatePrivacy(let level):
            let privacyText = level == .personal ? "private" : "family shared"
            return "Change \(eventCount) \(eventText) to \(privacyText)?"
        case .sendReminders:
            return "Send reminder notifications for \(eventCount) \(eventText) to all family members?"
        }
    }
    
    private func loadFamilyEvents() {
        isLoading = true
        errorMessage = nil
        selectedEvents.removeAll()
        
        Task {
            do {
                // This would fetch family events from the coordination service
                // For now, we'll simulate with empty array
                let events: [CalendarEvent] = []
                
                await MainActor.run {
                    self.familyEvents = events
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func performBulkOperation() {
        guard let operation = selectedOperation else { return }
        
        Task {
            do {
                try await coordinationService.performBulkEventOperation(
                    operation: operation,
                    eventIds: Array(selectedEvents),
                    performedBy: currentUserId,
                    familyId: familyId
                )
                
                await MainActor.run {
                    selectedEvents.removeAll()
                    selectedOperation = nil
                    loadFamilyEvents()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

/// Individual event row for bulk selection
struct BulkEventRowView: View {
    let event: CalendarEvent
    let isSelected: Bool
    let onToggleSelection: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Selection checkbox
            Button(action: onToggleSelection) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            
            // Event details
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(event.dateRangeString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: event.privacyLevel.icon)
                        .font(.caption2)
                        .foregroundColor(event.privacyLevel == .familyShared ? .blue : .green)
                    
                    Text(event.privacyLevel.displayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if let location = event.location {
                        Text("• \(location)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            // Event status
            VStack(alignment: .trailing, spacing: 2) {
                if event.isToday {
                    Text("Today")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .cornerRadius(4)
                } else if event.isUpcoming {
                    Text("Upcoming")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else if event.isPast {
                    Text("Past")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Text("Created by User \(event.createdBy.uuidString.prefix(8))...")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onToggleSelection()
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: CalendarEvent.self, configurations: config)
    
    return BulkEventManagementView(
        familyId: UUID(),
        currentUserId: UUID(),
        modelContext: container.mainContext
    )
    .padding()
}