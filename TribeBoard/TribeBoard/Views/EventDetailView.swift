import SwiftUI

struct EventDetailView: View {
    let event: CalendarEvent
    let userProfiles: [UUID: UserProfile]
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditView = false
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter
    }
    
    private var participantNames: [String] {
        event.participants.compactMap { userProfiles[$0]?.displayName }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Event Header
                    EventHeaderSection(event: event)
                    
                    // Event Details
                    EventDetailsSection(event: event, dateFormatter: dateFormatter)
                    
                    // Participants Section
                    if !event.participants.isEmpty {
                        ParticipantsSection(
                            participants: participantNames,
                            event: event
                        )
                    }
                    
                    // Location Section
                    if let location = event.location {
                        LocationSection(location: location)
                    }
                    
                    // Description Section
                    if let description = event.description {
                        DescriptionSection(description: description)
                    }
                    
                    // Action Buttons
                    EventActionButtonsSection(
                        event: event,
                        onEdit: { showingEditView = true },
                        onDelete: { 
                            // Mock delete action
                            dismiss()
                        }
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
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showingEditView = true
                    }
                }
            }
            .sheet(isPresented: $showingEditView) {
                EditEventView(event: event)
            }
        }
    }
}

// MARK: - Event Header Section

struct EventHeaderSection: View {
    let event: CalendarEvent
    
    var body: some View {
        VStack(spacing: 16) {
            // Event type icon and color
            VStack(spacing: 8) {
                Text(event.type.icon)
                    .font(.system(size: 60))
                
                Text(event.type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(colorForEventType(event.type).opacity(0.2))
                    .foregroundColor(colorForEventType(event.type))
                    .cornerRadius(12)
            }
            
            // Event title
            Text(event.title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
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

// MARK: - Event Details Section

struct EventDetailsSection: View {
    let event: CalendarEvent
    let dateFormatter: DateFormatter
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Details", icon: "info.circle")
            
            VStack(spacing: 12) {
                DetailRow(
                    icon: "calendar",
                    title: "Date & Time",
                    value: dateFormatter.string(from: event.date)
                )
                
                if Calendar.current.isDate(event.date, inSameDayAs: Date()) {
                    DetailRow(
                        icon: "clock",
                        title: "Status",
                        value: "Today"
                    )
                } else {
                    let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: event.date).day ?? 0
                    if daysUntil > 0 {
                        DetailRow(
                            icon: "clock",
                            title: "Time Until",
                            value: "\(daysUntil) day\(daysUntil == 1 ? "" : "s")"
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Participants Section

struct ParticipantsSection: View {
    let participants: [String]
    let event: CalendarEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Participants", icon: "person.2")
            
            VStack(spacing: 8) {
                ForEach(participants, id: \.self) { participant in
                    ParticipantRow(name: participant)
                }
                
                if participants.isEmpty {
                    Text("No participants added")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
    }
}

// MARK: - Participant Row

struct ParticipantRow: View {
    let name: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar placeholder
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(name.prefix(1)))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                )
            
            Text(name)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundColor(.green)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Location Section

struct LocationSection: View {
    let location: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Location", icon: "location")
            
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .font(.title3)
                    .foregroundColor(.red)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(location)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Button("Get Directions") {
                        // Mock directions action
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

// MARK: - Description Section

struct DescriptionSection: View {
    let description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Description", icon: "text.alignleft")
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.primary)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
        }
    }
}

// MARK: - Action Buttons Section

struct EventActionButtonsSection: View {
    let event: CalendarEvent
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Primary actions
            HStack(spacing: 12) {
                Button(action: onEdit) {
                    HStack {
                        Image(systemName: "pencil")
                        Text("Edit Event")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                
                Button(action: {
                    // Mock share action
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            
            // Delete button
            Button(action: {
                showingDeleteAlert = true
            }) {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Event")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .alert("Delete Event", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                onDelete()
            }
        } message: {
            Text("Are you sure you want to delete '\(event.title)'? This action cannot be undone.")
        }
    }
}

// MARK: - Helper Views

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.blue)
            
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
        }
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Edit Event View (Placeholder)

struct EditEventView: View {
    let event: CalendarEvent
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "pencil.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Edit Event")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Event editing functionality coming soon!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    EventDetailView(
        event: MockDataGenerator.mockCalendarEvents().first!,
        userProfiles: Dictionary(uniqueKeysWithValues: MockDataGenerator.mockMawereFamily().users.map { ($0.id, $0) })
    )
}