import SwiftUI

/// Settings view with profile management and family settings for UI/UX prototype
struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Initialization
    
    init(currentUserId: UUID, currentUserRole: Role) {
        self._viewModel = StateObject(wrappedValue: SettingsViewModel(
            currentUserId: currentUserId,
            currentUserRole: currentUserRole
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if viewModel.isLoading {
                    LoadingStateView(
                        message: "Loading settings...",
                        style: .card
                    )
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            // Profile section
                            profileSection
                            
                            // Family settings section
                            familySettingsSection
                            
                            // Notification settings section
                            notificationSettingsSection
                            
                            // Privacy & Security section
                            privacySecuritySection
                            
                            // Family management section (admin only)
                            if viewModel.canManageFamily {
                                familyManagementSection
                            }
                            
                            // App settings section
                            appSettingsSection
                            
                            // Account actions section
                            accountActionsSection
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.saveSettings()
                        }
                    }
                    .disabled(!viewModel.hasUnsavedChanges)
                }
            }
        }
        .task {
            await viewModel.loadSettings()
        }
        .withToast()
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .sheet(isPresented: $viewModel.showProfileEditor) {
            ProfileEditorView(
                userProfile: viewModel.currentUserProfile,
                onSave: { updatedProfile in
                    viewModel.updateProfile(updatedProfile)
                }
            )
        }
        .sheet(isPresented: $viewModel.showFamilyMemberManagement) {
            FamilyMemberManagementView(
                familyId: appState.currentFamily?.id ?? UUID(),
                currentUserRole: viewModel.currentUserRole
            )
        }
        .sheet(isPresented: $viewModel.showPrivacySettings) {
            PrivacySettingsView(
                settings: viewModel.familySettings,
                onSave: { updatedSettings in
                    viewModel.updateFamilySettings(updatedSettings)
                }
            )
        }
        .sheet(isPresented: $viewModel.showSecuritySettings) {
            SecuritySettingsView(
                currentUserRole: viewModel.currentUserRole
            )
        }
    }
    
    // MARK: - View Components
    
    private var profileSection: some View {
        SettingsSection(title: "Profile", icon: "person.circle") {
            VStack(spacing: 12) {
                // Profile info row
                HStack(spacing: 12) {
                    MemberAvatarView(userProfile: viewModel.currentUserProfile)
                        .frame(width: 60, height: 60)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.currentUserProfile?.displayName ?? "Unknown User")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        RoleBadge(role: viewModel.currentUserRole)
                        
                        if let family = appState.currentFamily {
                            Text("Member of \(family.name)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button("Edit") {
                        viewModel.showProfileEditor = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.brandPrimary)
                }
                
                Divider()
                
                // Profile actions
                SettingsRow(
                    title: "Edit Profile",
                    icon: "pencil",
                    action: {
                        viewModel.showProfileEditor = true
                    }
                )
                
                SettingsRow(
                    title: "Change Display Name",
                    icon: "textformat",
                    action: {
                        viewModel.successMessage = "Display name editing coming soon!"
                    }
                )
            }
        }
    }
    
    private var familySettingsSection: some View {
        SettingsSection(title: "Family Settings", icon: "house") {
            VStack(spacing: 8) {
                if let family = appState.currentFamily {
                    // Family info
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(family.name)
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text("Family Code: \(family.code)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Share Code") {
                            viewModel.shareFamilyCode(family.code)
                        }
                        .font(.subheadline)
                        .foregroundColor(.brandPrimary)
                    }
                    
                    Divider()
                }
                
                // Points system toggle
                SettingsToggleRow(
                    title: "Points System",
                    subtitle: "Enable point rewards for completed tasks",
                    icon: "star.fill",
                    isOn: $viewModel.familySettings.pointsSystemEnabled
                )
                
                // Task approval toggle
                SettingsToggleRow(
                    title: "Require Task Approval",
                    subtitle: "Tasks need parent approval before completion",
                    icon: "checkmark.circle",
                    isOn: $viewModel.familySettings.requireTaskApproval
                )
                
                // Child messaging toggle
                SettingsToggleRow(
                    title: "Allow Child Messaging",
                    subtitle: "Children can send messages to family",
                    icon: "message",
                    isOn: $viewModel.familySettings.allowChildMessaging
                )
                
                // Max points per task
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Max Points Per Task")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Maximum points that can be earned from a single task")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Stepper(
                        value: $viewModel.familySettings.maxPointsPerTask,
                        in: 1...100,
                        step: 5
                    ) {
                        Text("\(viewModel.familySettings.maxPointsPerTask)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.brandPrimary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private var notificationSettingsSection: some View {
        SettingsSection(title: "Notifications", icon: "bell") {
            VStack(spacing: 8) {
                // Master notifications toggle
                SettingsToggleRow(
                    title: "Enable Notifications",
                    subtitle: "Receive push notifications from TribeBoard",
                    icon: "bell.fill",
                    isOn: $viewModel.familySettings.notificationsEnabled
                )
                
                if viewModel.familySettings.notificationsEnabled {
                    Divider()
                    
                    // Specific notification types
                    SettingsToggleRow(
                        title: "Task Assignments",
                        subtitle: "When new tasks are assigned to you",
                        icon: "checklist",
                        isOn: $viewModel.notificationPreferences.taskAssignments
                    )
                    
                    SettingsToggleRow(
                        title: "Family Messages",
                        subtitle: "New messages in family chat",
                        icon: "message.fill",
                        isOn: $viewModel.notificationPreferences.familyMessages
                    )
                    
                    SettingsToggleRow(
                        title: "Calendar Events",
                        subtitle: "Upcoming family events and reminders",
                        icon: "calendar",
                        isOn: $viewModel.notificationPreferences.calendarEvents
                    )
                    
                    SettingsToggleRow(
                        title: "School Run Updates",
                        subtitle: "Pickup and drop-off notifications",
                        icon: "car",
                        isOn: $viewModel.notificationPreferences.schoolRunUpdates
                    )
                    
                    Divider()
                    
                    // Quiet hours
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quiet Hours")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("No notifications will be sent during these hours")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            DatePicker(
                                "Start",
                                selection: $viewModel.familySettings.quietHoursStart,
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                            
                            Text("to")
                                .foregroundColor(.secondary)
                            
                            DatePicker(
                                "End",
                                selection: $viewModel.familySettings.quietHoursEnd,
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
    
    private var privacySecuritySection: some View {
        SettingsSection(title: "Privacy & Security", icon: "lock.shield") {
            VStack(spacing: 8) {
                SettingsRow(
                    title: "Privacy Settings",
                    subtitle: "Manage data sharing and visibility",
                    icon: "eye.slash",
                    action: {
                        viewModel.showPrivacySettings = true
                    }
                )
                
                SettingsRow(
                    title: "Security Settings",
                    subtitle: "App lock and authentication options",
                    icon: "lock",
                    action: {
                        viewModel.showSecuritySettings = true
                    }
                )
                
                SettingsRow(
                    title: "Data Export",
                    subtitle: "Download your family data",
                    icon: "square.and.arrow.up",
                    action: {
                        viewModel.exportFamilyData()
                    }
                )
                
                SettingsRow(
                    title: "Delete Family Data",
                    subtitle: "Permanently remove all family information",
                    icon: "trash",
                    isDestructive: true,
                    action: {
                        viewModel.showDeleteFamilyDataConfirmation()
                    }
                )
            }
        }
    }
    
    private var familyManagementSection: some View {
        SettingsSection(title: "Family Management", icon: "person.2") {
            VStack(spacing: 8) {
                SettingsRow(
                    title: "Manage Members",
                    subtitle: "Add, remove, or change member roles",
                    icon: "person.badge.gearshape",
                    action: {
                        viewModel.showFamilyMemberManagement = true
                    }
                )
                
                SettingsRow(
                    title: "Invite New Member",
                    subtitle: "Send invitation to join family",
                    icon: "person.badge.plus",
                    action: {
                        viewModel.inviteNewMember()
                    }
                )
                
                SettingsRow(
                    title: "Family Roles",
                    subtitle: "Configure role permissions",
                    icon: "person.3",
                    action: {
                        viewModel.successMessage = "Role configuration coming soon!"
                    }
                )
                
                SettingsRow(
                    title: "Transfer Ownership",
                    subtitle: "Transfer admin rights to another member",
                    icon: "arrow.triangle.2.circlepath",
                    isDestructive: true,
                    action: {
                        viewModel.successMessage = "Ownership transfer coming soon!"
                    }
                )
            }
        }
    }
    
    private var appSettingsSection: some View {
        SettingsSection(title: "App Settings", icon: "gear") {
            VStack(spacing: 8) {
                SettingsRow(
                    title: "Theme",
                    subtitle: "Light, Dark, or System",
                    icon: "paintbrush",
                    action: {
                        viewModel.successMessage = "Theme selection coming soon!"
                    }
                )
                
                SettingsRow(
                    title: "Language",
                    subtitle: "English",
                    icon: "globe",
                    action: {
                        viewModel.successMessage = "Language selection coming soon!"
                    }
                )
                
                SettingsRow(
                    title: "Storage",
                    subtitle: "Manage app storage and cache",
                    icon: "internaldrive",
                    action: {
                        viewModel.clearAppCache()
                    }
                )
                
                SettingsRow(
                    title: "About TribeBoard",
                    subtitle: "Version 1.0.0 (Prototype)",
                    icon: "info.circle",
                    action: {
                        viewModel.showAboutApp()
                    }
                )
            }
        }
    }
    
    private var accountActionsSection: some View {
        SettingsSection(title: "Account", icon: "person.crop.circle") {
            VStack(spacing: 8) {
                SettingsRow(
                    title: "Leave Family",
                    subtitle: "Remove yourself from this family",
                    icon: "arrow.right.square",
                    isDestructive: true,
                    action: {
                        viewModel.showLeaveFamilyConfirmation()
                    }
                )
                
                SettingsRow(
                    title: "Sign Out",
                    subtitle: "Sign out of your account",
                    icon: "rectangle.portrait.and.arrow.right",
                    isDestructive: true,
                    action: {
                        viewModel.signOut()
                    }
                )
            }
        }
    }
}

// MARK: - Settings Section

struct SettingsSection<Content: View>: View {
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
                    .foregroundColor(.primary)
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

// MARK: - Settings Row

struct SettingsRow: View {
    let title: String
    let subtitle: String?
    let icon: String
    let isDestructive: Bool
    let action: () -> Void
    
    init(
        title: String,
        subtitle: String? = nil,
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
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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

// MARK: - Settings Toggle Row

struct SettingsToggleRow: View {
    let title: String
    let subtitle: String?
    let icon: String
    @Binding var isOn: Bool
    
    init(
        title: String,
        subtitle: String? = nil,
        icon: String,
        isOn: Binding<Bool>
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self._isOn = isOn
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.brandPrimary)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

#Preview {
    SettingsView(
        currentUserId: UUID(),
        currentUserRole: .parentAdmin
    )
    .environmentObject(AppState())
}