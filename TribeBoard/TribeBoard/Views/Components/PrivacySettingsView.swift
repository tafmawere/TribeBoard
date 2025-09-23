import SwiftUI

/// Privacy settings view for managing data sharing and visibility
struct PrivacySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings: MockFamilySettings
    @State private var isLoading = false
    @State private var hasUnsavedChanges = false
    
    let onSave: (MockFamilySettings) -> Void
    
    // MARK: - Privacy Settings State
    
    @State private var profileVisibility: ProfileVisibility = .family
    @State private var locationSharing: Bool = true
    @State private var activitySharing: Bool = true
    @State private var calendarSharing: Bool = true
    @State private var taskVisibility: Bool = true
    @State private var messageHistory: Bool = true
    @State private var dataCollection: Bool = false
    @State private var analyticsSharing: Bool = false
    @State private var marketingCommunications: Bool = false
    
    // MARK: - Initialization
    
    init(settings: MockFamilySettings, onSave: @escaping (MockFamilySettings) -> Void) {
        self._settings = State(initialValue: settings)
        self.onSave = onSave
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    LoadingStateView(
                        message: "Updating privacy settings...",
                        style: .card
                    )
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            // Profile privacy section
                            profilePrivacySection
                            
                            // Data sharing section
                            dataSharingSection
                            
                            // Family visibility section
                            familyVisibilitySection
                            
                            // External sharing section
                            externalSharingSection
                            
                            // Data management section
                            dataManagementSection
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Privacy Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSettings()
                    }
                    .disabled(!hasUnsavedChanges || isLoading)
                }
            }
        }
        .onAppear {
            setupChangeTracking()
        }
    }
    
    // MARK: - View Components
    
    private var profilePrivacySection: some View {
        PrivacySection(title: "Profile Privacy", icon: "person.crop.circle.badge.questionmark") {
            VStack(spacing: 12) {
                // Profile visibility
                VStack(alignment: .leading, spacing: 8) {
                    Text("Profile Visibility")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Who can see your profile information")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Profile Visibility", selection: $profileVisibility) {
                        ForEach(ProfileVisibility.allCases, id: \.self) { visibility in
                            Text(visibility.displayName).tag(visibility)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Divider()
                
                // Location sharing
                PrivacyToggleRow(
                    title: "Location Sharing",
                    subtitle: "Share your location with family members",
                    icon: "location",
                    isOn: $locationSharing
                )
                
                // Activity sharing
                PrivacyToggleRow(
                    title: "Activity Status",
                    subtitle: "Show when you're active in the app",
                    icon: "circle.fill",
                    isOn: $activitySharing
                )
            }
        }
    }
    
    private var dataSharingSection: some View {
        PrivacySection(title: "Data Sharing", icon: "square.and.arrow.up") {
            VStack(spacing: 8) {
                PrivacyToggleRow(
                    title: "Calendar Events",
                    subtitle: "Share your calendar events with family",
                    icon: "calendar",
                    isOn: $calendarSharing
                )
                
                PrivacyToggleRow(
                    title: "Task Progress",
                    subtitle: "Show your task completion status",
                    icon: "checklist",
                    isOn: $taskVisibility
                )
                
                PrivacyToggleRow(
                    title: "Message History",
                    subtitle: "Allow family to see your message history",
                    icon: "message",
                    isOn: $messageHistory
                )
            }
        }
    }
    
    private var familyVisibilitySection: some View {
        PrivacySection(title: "Family Visibility", icon: "eye") {
            VStack(spacing: 12) {
                Text("Control what family members can see about your activities")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: 8) {
                    FamilyVisibilityRow(
                        title: "Task Assignments",
                        description: "Family can see tasks assigned to you",
                        isVisible: true,
                        isEditable: false
                    )
                    
                    FamilyVisibilityRow(
                        title: "Calendar Participation",
                        description: "Show your participation in family events",
                        isVisible: calendarSharing,
                        isEditable: true,
                        onToggle: { calendarSharing.toggle() }
                    )
                    
                    FamilyVisibilityRow(
                        title: "Message Activity",
                        description: "Show when you've read messages",
                        isVisible: messageHistory,
                        isEditable: true,
                        onToggle: { messageHistory.toggle() }
                    )
                    
                    FamilyVisibilityRow(
                        title: "Location Status",
                        description: "Share your current location",
                        isVisible: locationSharing,
                        isEditable: true,
                        onToggle: { locationSharing.toggle() }
                    )
                }
            }
        }
    }
    
    private var externalSharingSection: some View {
        PrivacySection(title: "External Sharing", icon: "globe") {
            VStack(spacing: 8) {
                PrivacyToggleRow(
                    title: "Usage Analytics",
                    subtitle: "Help improve TribeBoard by sharing anonymous usage data",
                    icon: "chart.bar",
                    isOn: $analyticsSharing
                )
                
                PrivacyToggleRow(
                    title: "Crash Reports",
                    subtitle: "Automatically send crash reports to help fix issues",
                    icon: "exclamationmark.triangle",
                    isOn: $dataCollection
                )
                
                PrivacyToggleRow(
                    title: "Marketing Communications",
                    subtitle: "Receive emails about new features and updates",
                    icon: "envelope",
                    isOn: $marketingCommunications
                )
            }
        }
    }
    
    private var dataManagementSection: some View {
        PrivacySection(title: "Data Management", icon: "folder.badge.gearshape") {
            VStack(spacing: 8) {
                PrivacyActionRow(
                    title: "Download My Data",
                    subtitle: "Get a copy of all your data in TribeBoard",
                    icon: "square.and.arrow.down",
                    action: {
                        // Mock download data
                    }
                )
                
                PrivacyActionRow(
                    title: "Data Retention Settings",
                    subtitle: "Manage how long your data is stored",
                    icon: "clock.arrow.circlepath",
                    action: {
                        // Mock data retention settings
                    }
                )
                
                Divider()
                
                PrivacyActionRow(
                    title: "Delete All My Data",
                    subtitle: "Permanently remove all your data from TribeBoard",
                    icon: "trash",
                    isDestructive: true,
                    action: {
                        // Mock delete all data
                    }
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func setupChangeTracking() {
        // In a real app, this would track changes to trigger save button
        hasUnsavedChanges = false
    }
    
    private func saveSettings() {
        isLoading = true
        hasUnsavedChanges = false
        
        Task {
            // Simulate save delay
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            
            await MainActor.run {
                onSave(settings)
                isLoading = false
                dismiss()
            }
        }
    }
}

// MARK: - Privacy Section

struct PrivacySection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.brandPrimary)
                    .font(.headline)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                content
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
}

// MARK: - Privacy Toggle Row

struct PrivacyToggleRow: View {
    let title: String
    let subtitle: String
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.brandPrimary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Privacy Action Row

struct PrivacyActionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let isDestructive: Bool
    let action: () -> Void
    
    init(
        title: String,
        subtitle: String,
        icon: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.isDestructive = isDestructive
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(isDestructive ? .red : .brandPrimary)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isDestructive ? .red : .primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Family Visibility Row

struct FamilyVisibilityRow: View {
    let title: String
    let description: String
    let isVisible: Bool
    let isEditable: Bool
    let onToggle: (() -> Void)?
    
    init(
        title: String,
        description: String,
        isVisible: Bool,
        isEditable: Bool,
        onToggle: (() -> Void)? = nil
    ) {
        self.title = title
        self.description = description
        self.isVisible = isVisible
        self.isEditable = isEditable
        self.onToggle = onToggle
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isVisible ? "eye" : "eye.slash")
                .foregroundColor(isVisible ? .green : .red)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isEditable {
                Button(isVisible ? "Hide" : "Show") {
                    onToggle?()
                }
                .font(.caption)
                .foregroundColor(.brandPrimary)
            } else {
                Text("Required")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Profile Visibility Enum

enum ProfileVisibility: String, CaseIterable {
    case family = "family"
    case adults = "adults"
    case admins = "admins"
    
    var displayName: String {
        switch self {
        case .family: return "Family"
        case .adults: return "Adults Only"
        case .admins: return "Admins Only"
        }
    }
}

// MARK: - Preview

#Preview {
    PrivacySettingsView(
        settings: MockFamilySettings(),
        onSave: { _ in }
    )
}