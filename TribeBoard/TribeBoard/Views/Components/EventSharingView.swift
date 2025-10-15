import SwiftUI

struct EventSharingView: View {
    let event: CalendarEvent
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSharingOptions: Set<SharingOption> = []
    @State private var customMessage = ""
    @State private var isSharing = false
    
    enum SharingOption: String, CaseIterable, Identifiable {
        case familyMembers = "Family Members"
        case appleCalendar = "Apple Calendar"
        case messages = "Messages"
        case mail = "Mail"
        case copyLink = "Copy Link"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .familyMembers: return "person.2.fill"
            case .appleCalendar: return "calendar"
            case .messages: return "message.fill"
            case .mail: return "envelope.fill"
            case .copyLink: return "link"
            }
        }
        
        var description: String {
            switch self {
            case .familyMembers: return "Share with all family members"
            case .appleCalendar: return "Add to Apple Calendar"
            case .messages: return "Send via Messages"
            case .mail: return "Send via Mail"
            case .copyLink: return "Copy shareable link"
            }
        }
        
        var isAvailable: Bool {
            switch self {
            case .familyMembers: return true
            case .appleCalendar: return true
            case .messages: return true
            case .mail: return true
            case .copyLink: return true
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Event Preview
                EventSharingPreview(event: event)
                
                Form {
                    // Sharing Options
                    Section {
                        ForEach(SharingOption.allCases) { option in
                            if option.isAvailable {
                                SharingOptionRow(
                                    option: option,
                                    isSelected: selectedSharingOptions.contains(option),
                                    onToggle: { isSelected in
                                        if isSelected {
                                            selectedSharingOptions.insert(option)
                                        } else {
                                            selectedSharingOptions.remove(option)
                                        }
                                    }
                                )
                            }
                        }
                    } header: {
                        Text("Share With")
                    } footer: {
                        Text("Select how you'd like to share this event")
                    }
                    
                    // Custom Message
                    if !selectedSharingOptions.isEmpty {
                        Section {
                            TextField("Add a message (optional)", text: $customMessage, axis: .vertical)
                                .lineLimit(3...6)
                        } header: {
                            Text("Message")
                        }
                    }
                    
                    // Privacy Notice
                    if event.privacyLevel == .personal {
                        Section {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Personal Event")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    
                                    Text("This is a personal event. Sharing will make it visible to recipients.")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Share Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Share") {
                        shareEvent()
                    }
                    .disabled(selectedSharingOptions.isEmpty || isSharing)
                    .fontWeight(.semibold)
                }
            }
            .disabled(isSharing)
            .overlay {
                if isSharing {
                    LoadingOverlay(message: "Sharing event...")
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func shareEvent() {
        guard !selectedSharingOptions.isEmpty else { return }
        
        isSharing = true
        
        Task {
            // Simulate sharing process
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            
            await MainActor.run {
                // Process each sharing option
                for option in selectedSharingOptions {
                    processSharingOption(option)
                }
                
                // Provide haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                dismiss()
            }
        }
    }
    
    private func processSharingOption(_ option: SharingOption) {
        switch option {
        case .familyMembers:
            print("Sharing with family members: \(event.title)")
            // TODO: Implement family sharing
            
        case .appleCalendar:
            print("Adding to Apple Calendar: \(event.title)")
            // TODO: Implement Apple Calendar sharing
            
        case .messages:
            print("Sharing via Messages: \(event.title)")
            // TODO: Implement Messages sharing
            
        case .mail:
            print("Sharing via Mail: \(event.title)")
            // TODO: Implement Mail sharing
            
        case .copyLink:
            print("Copying link for: \(event.title)")
            // TODO: Generate and copy shareable link
            UIPasteboard.general.string = "https://tribeboard.app/events/\(event.id.uuidString)"
        }
    }
}

// MARK: - Event Sharing Preview

struct EventSharingPreview: View {
    let event: CalendarEvent
    
    var body: some View {
        VStack(spacing: 16) {
            // Event icon and title
            VStack(spacing: 8) {
                Image(systemName: event.privacyLevel.icon)
                    .font(.system(size: 40))
                    .foregroundColor(colorForPrivacyLevel(event.privacyLevel))
                
                Text(event.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
            }
            
            // Event details
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(event.dateRangeString)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                if let location = event.location {
                    HStack(spacing: 8) {
                        Image(systemName: "location")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(location)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                PrivacyLevelBadge(level: event.privacyLevel)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding()
    }
    
    private func colorForPrivacyLevel(_ level: CalendarEvent.PrivacyLevel) -> Color {
        switch level {
        case .familyShared: return .blue
        case .personal: return .purple
        }
    }
}

// MARK: - Sharing Option Row

struct SharingOptionRow: View {
    let option: EventSharingView.SharingOption
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        Button(action: {
            onToggle(!isSelected)
            
            // Provide haptic feedback
            let selectionFeedback = UISelectionFeedbackGenerator()
            selectionFeedback.selectionChanged()
        }) {
            HStack(spacing: 16) {
                // Option icon
                Image(systemName: option.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .frame(width: 24)
                
                // Option details
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(option.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(option.rawValue): \(option.description)")
        .accessibilityHint(isSelected ? "Currently selected" : "Tap to select this sharing option")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Preview

#Preview {
    EventSharingView(
        event: CalendarEvent(
            title: "Family Dinner",
            startDate: Date(),
            endDate: Date().addingTimeInterval(7200),
            isAllDay: false,
            location: "Home",
            notes: "Don't forget dessert!",
            privacyLevel: .familyShared,
            createdBy: UUID(),
            familyId: UUID()
        )
    )
}