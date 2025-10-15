import SwiftUI

struct EventConflictResolutionView: View {
    let event: CalendarEvent
    @Environment(\.dismiss) private var dismiss
    @State private var selectedResolution: ConflictResolution?
    @State private var isResolving = false
    @State private var showingDetails = false
    
    // Simulated conflict data
    private let conflictingVersions: [ConflictingVersion] = [
        ConflictingVersion(
            source: .local,
            title: "Family Dinner",
            startDate: Date(),
            endDate: Date().addingTimeInterval(7200),
            location: "Home",
            notes: "Don't forget dessert!",
            lastModified: Date().addingTimeInterval(-300) // 5 minutes ago
        ),
        ConflictingVersion(
            source: .appleCalendar,
            title: "Family Dinner - Updated",
            startDate: Date().addingTimeInterval(1800), // 30 minutes later
            endDate: Date().addingTimeInterval(9000), // 2.5 hours total
            location: "Restaurant",
            notes: "Changed to restaurant - don't forget to make reservation!",
            lastModified: Date().addingTimeInterval(-120) // 2 minutes ago
        ),
        ConflictingVersion(
            source: .cloudKit,
            title: "Family Dinner",
            startDate: Date(),
            endDate: Date().addingTimeInterval(7200),
            location: "Home",
            notes: "Don't forget dessert! Also bring wine.",
            lastModified: Date().addingTimeInterval(-180) // 3 minutes ago
        )
    ]
    
    enum ConflictResolution: String, CaseIterable, Identifiable {
        case keepLocal = "Keep Local Version"
        case keepAppleCalendar = "Keep Apple Calendar Version"
        case keepCloudKit = "Keep Family Shared Version"
        case mergeChanges = "Merge All Changes"
        case createNew = "Create New Event"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .keepLocal: return "iphone"
            case .keepAppleCalendar: return "calendar"
            case .keepCloudKit: return "icloud"
            case .mergeChanges: return "arrow.triangle.merge"
            case .createNew: return "plus.circle"
            }
        }
        
        var description: String {
            switch self {
            case .keepLocal:
                return "Use the version stored locally on this device"
            case .keepAppleCalendar:
                return "Use the version from Apple Calendar"
            case .keepCloudKit:
                return "Use the version shared with family members"
            case .mergeChanges:
                return "Combine changes from all versions (recommended)"
            case .createNew:
                return "Keep all versions as separate events"
            }
        }
        
        var isRecommended: Bool {
            return self == .mergeChanges
        }
    }
    
    struct ConflictingVersion {
        let source: Source
        let title: String
        let startDate: Date
        let endDate: Date
        let location: String?
        let notes: String?
        let lastModified: Date
        
        enum Source: String, CaseIterable {
            case local = "Local Device"
            case appleCalendar = "Apple Calendar"
            case cloudKit = "Family Shared"
            
            var icon: String {
                switch self {
                case .local: return "iphone"
                case .appleCalendar: return "calendar"
                case .cloudKit: return "icloud"
                }
            }
            
            var color: Color {
                switch self {
                case .local: return .blue
                case .appleCalendar: return .green
                case .cloudKit: return .purple
                }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Conflict Warning Header
                ConflictWarningHeader()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Conflicting Versions
                        ConflictingVersionsSection(
                            versions: conflictingVersions,
                            showingDetails: $showingDetails
                        )
                        
                        // Resolution Options
                        ResolutionOptionsSection(
                            selectedResolution: $selectedResolution
                        )
                        
                        // Preview of Resolution
                        if let resolution = selectedResolution {
                            ResolutionPreviewSection(
                                resolution: resolution,
                                versions: conflictingVersions
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Resolve Conflict")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Resolve") {
                        resolveConflict()
                    }
                    .disabled(selectedResolution == nil || isResolving)
                    .fontWeight(.semibold)
                }
            }
            .disabled(isResolving)
            .overlay {
                if isResolving {
                    LoadingOverlay(message: "Resolving conflict...")
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func resolveConflict() {
        guard let resolution = selectedResolution else { return }
        
        isResolving = true
        
        Task {
            // Simulate conflict resolution process
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            await MainActor.run {
                print("Resolved conflict using: \(resolution.rawValue)")
                
                // Provide haptic feedback
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                
                dismiss()
            }
        }
    }
}

// MARK: - Conflict Warning Header

struct ConflictWarningHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Event Conflict Detected")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text("This event has been modified in multiple places")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.orange.opacity(0.3)),
            alignment: .bottom
        )
    }
}

// MARK: - Conflicting Versions Section

struct ConflictingVersionsSection: View {
    let versions: [EventConflictResolutionView.ConflictingVersion]
    @Binding var showingDetails: Bool
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Conflicting Versions")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(showingDetails ? "Hide Details" : "Show Details") {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showingDetails.toggle()
                    }
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            VStack(spacing: 12) {
                ForEach(versions.indices, id: \.self) { index in
                    ConflictingVersionCard(
                        version: versions[index],
                        showingDetails: showingDetails,
                        isLatest: index == versions.count - 1
                    )
                }
            }
        }
    }
}

// MARK: - Conflicting Version Card

struct ConflictingVersionCard: View {
    let version: EventConflictResolutionView.ConflictingVersion
    let showingDetails: Bool
    let isLatest: Bool
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: version.source.icon)
                        .font(.subheadline)
                        .foregroundColor(version.source.color)
                    
                    Text(version.source.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(version.source.color)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Modified")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(dateFormatter.string(from: version.lastModified))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(isLatest ? .green : .secondary)
                }
                
                if isLatest {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            // Event title
            Text(version.title)
                .font(.subheadline)
                .fontWeight(.semibold)
            
            // Basic details
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(dateFormatter.string(from: version.startDate)) - \(dateFormatter.string(from: version.endDate))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let location = version.location {
                    HStack(spacing: 8) {
                        Image(systemName: "location")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(location)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Detailed view
            if showingDetails {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    if let notes = version.notes {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes:")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Text(notes)
                                .font(.caption)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(6)
                        }
                    }
                    
                    // Differences indicator
                    if version.source != .local {
                        DifferencesIndicator(version: version)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(version.source.color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Differences Indicator

struct DifferencesIndicator: View {
    let version: EventConflictResolutionView.ConflictingVersion
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Changes:")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack {
                ForEach(["Title", "Time", "Location", "Notes"], id: \.self) { field in
                    Text(field)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(4)
                }
            }
        }
    }
}

// MARK: - Resolution Options Section

struct ResolutionOptionsSection: View {
    @Binding var selectedResolution: EventConflictResolutionView.ConflictResolution?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Resolution Options")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ForEach(EventConflictResolutionView.ConflictResolution.allCases) { resolution in
                    ResolutionOptionCard(
                        resolution: resolution,
                        isSelected: selectedResolution == resolution,
                        onSelect: {
                            selectedResolution = resolution
                            
                            // Provide haptic feedback
                            let selectionFeedback = UISelectionFeedbackGenerator()
                            selectionFeedback.selectionChanged()
                        }
                    )
                }
            }
        }
    }
}

// MARK: - Resolution Option Card

struct ResolutionOptionCard: View {
    let resolution: EventConflictResolutionView.ConflictResolution
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Option icon
                Image(systemName: resolution.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .frame(width: 24)
                
                // Option details
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(resolution.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        if resolution.isRecommended {
                            Text("RECOMMENDED")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.2))
                                .foregroundColor(.green)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(resolution.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(resolution.rawValue): \(resolution.description)")
        .accessibilityHint(isSelected ? "Currently selected" : "Tap to select this resolution option")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Resolution Preview Section

struct ResolutionPreviewSection: View {
    let resolution: EventConflictResolutionView.ConflictResolution
    let versions: [EventConflictResolutionView.ConflictingVersion]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preview")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "eye")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    
                    Text("Result after applying \(resolution.rawValue.lowercased()):")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Preview content based on resolution type
                ResolutionPreviewContent(
                    resolution: resolution,
                    versions: versions
                )
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

// MARK: - Resolution Preview Content

struct ResolutionPreviewContent: View {
    let resolution: EventConflictResolutionView.ConflictResolution
    let versions: [EventConflictResolutionView.ConflictingVersion]
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch resolution {
            case .keepLocal:
                if let localVersion = versions.first(where: { $0.source == .local }) {
                    EventPreview(version: localVersion)
                }
                
            case .keepAppleCalendar:
                if let appleVersion = versions.first(where: { $0.source == .appleCalendar }) {
                    EventPreview(version: appleVersion)
                }
                
            case .keepCloudKit:
                if let cloudVersion = versions.first(where: { $0.source == .cloudKit }) {
                    EventPreview(version: cloudVersion)
                }
                
            case .mergeChanges:
                MergedEventPreview(versions: versions)
                
            case .createNew:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Multiple events will be created:")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    ForEach(versions.indices, id: \.self) { index in
                        HStack {
                            Text("• \(versions[index].title) (\(versions[index].source.rawValue))")
                                .font(.caption)
                            Spacer()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Event Preview

struct EventPreview: View {
    let version: EventConflictResolutionView.ConflictingVersion
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(version.title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text("\(dateFormatter.string(from: version.startDate)) - \(dateFormatter.string(from: version.endDate))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let location = version.location {
                Text("📍 \(location)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let notes = version.notes {
                Text("💬 \(notes)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

// MARK: - Merged Event Preview

struct MergedEventPreview: View {
    let versions: [EventConflictResolutionView.ConflictingVersion]
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    // Simulate merged result (in real implementation, this would use proper merge logic)
    private var mergedVersion: EventConflictResolutionView.ConflictingVersion {
        let latestVersion = versions.max(by: { $0.lastModified < $1.lastModified }) ?? versions[0]
        
        // Combine notes from all versions
        let allNotes = versions.compactMap { $0.notes }.joined(separator: " | ")
        
        return EventConflictResolutionView.ConflictingVersion(
            source: .local,
            title: latestVersion.title,
            startDate: latestVersion.startDate,
            endDate: latestVersion.endDate,
            location: latestVersion.location,
            notes: allNotes.isEmpty ? nil : allNotes,
            lastModified: Date()
        )
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Merged Event:")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("✨ Smart Merge")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(4)
            }
            
            EventPreview(version: mergedVersion)
        }
    }
}

// MARK: - Preview

#Preview {
    EventConflictResolutionView(
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