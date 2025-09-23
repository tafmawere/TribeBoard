import SwiftUI

/// Security settings view for app lock and authentication options
struct SecuritySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var hasUnsavedChanges = false
    
    // MARK: - Security Settings State
    
    @State private var appLockEnabled = false
    @State private var biometricAuthEnabled = true
    @State private var autoLockTimeout: AutoLockTimeout = .fiveMinutes
    @State private var requireAuthForSensitiveActions = true
    @State private var sessionTimeout: SessionTimeout = .oneHour
    @State private var twoFactorEnabled = false
    @State private var loginNotifications = true
    @State private var deviceTrustEnabled = true
    
    let currentUserRole: Role
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    LoadingStateView(
                        message: "Updating security settings...",
                        style: .card
                    )
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            // App security section
                            appSecuritySection
                            
                            // Authentication section
                            authenticationSection
                            
                            // Session management section
                            sessionManagementSection
                            
                            // Account security section
                            accountSecuritySection
                            
                            // Device security section
                            deviceSecuritySection
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Security Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
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
    
    private var appSecuritySection: some View {
        SecuritySection(title: "App Security", icon: "lock.shield") {
            VStack(spacing: 12) {
                // App lock toggle
                SecurityToggleRow(
                    title: "App Lock",
                    subtitle: "Require authentication to open TribeBoard",
                    icon: "lock.app",
                    isOn: $appLockEnabled
                )
                
                if appLockEnabled {
                    Divider()
                    
                    // Biometric authentication
                    SecurityToggleRow(
                        title: "Face ID / Touch ID",
                        subtitle: "Use biometric authentication when available",
                        icon: "faceid",
                        isOn: $biometricAuthEnabled
                    )
                    
                    // Auto-lock timeout
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Auto-Lock Timeout")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Lock the app automatically after inactivity")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("Auto-Lock Timeout", selection: $autoLockTimeout) {
                            ForEach(AutoLockTimeout.allCases, id: \.self) { timeout in
                                Text(timeout.displayName).tag(timeout)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
            }
        }
    }
    
    private var authenticationSection: some View {
        SecuritySection(title: "Authentication", icon: "key") {
            VStack(spacing: 8) {
                SecurityToggleRow(
                    title: "Require Auth for Sensitive Actions",
                    subtitle: "Authenticate before deleting data or changing settings",
                    icon: "exclamationmark.shield",
                    isOn: $requireAuthForSensitiveActions
                )
                
                SecurityToggleRow(
                    title: "Two-Factor Authentication",
                    subtitle: "Add an extra layer of security to your account",
                    icon: "number.square",
                    isOn: $twoFactorEnabled
                )
                
                if twoFactorEnabled {
                    Divider()
                    
                    SecurityActionRow(
                        title: "Manage 2FA Methods",
                        subtitle: "Add or remove authentication methods",
                        icon: "gearshape.2",
                        action: {
                            // Mock 2FA management
                        }
                    )
                    
                    SecurityActionRow(
                        title: "Backup Codes",
                        subtitle: "Generate backup codes for account recovery",
                        icon: "doc.text",
                        action: {
                            // Mock backup codes
                        }
                    )
                }
            }
        }
    }
    
    private var sessionManagementSection: some View {
        SecuritySection(title: "Session Management", icon: "timer") {
            VStack(spacing: 12) {
                // Session timeout
                VStack(alignment: .leading, spacing: 8) {
                    Text("Session Timeout")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Automatically sign out after inactivity")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("Session Timeout", selection: $sessionTimeout) {
                        ForEach(SessionTimeout.allCases, id: \.self) { timeout in
                            Text(timeout.displayName).tag(timeout)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Divider()
                
                // Active sessions
                SecurityActionRow(
                    title: "Active Sessions",
                    subtitle: "View and manage your active login sessions",
                    icon: "desktopcomputer.and.arrow.down",
                    action: {
                        // Mock active sessions
                    }
                )
                
                SecurityActionRow(
                    title: "Sign Out All Devices",
                    subtitle: "Sign out from all devices except this one",
                    icon: "rectangle.portrait.and.arrow.right",
                    isDestructive: true,
                    action: {
                        // Mock sign out all devices
                    }
                )
            }
        }
    }
    
    private var accountSecuritySection: some View {
        SecuritySection(title: "Account Security", icon: "person.badge.shield.checkmark") {
            VStack(spacing: 8) {
                SecurityToggleRow(
                    title: "Login Notifications",
                    subtitle: "Get notified when someone signs into your account",
                    icon: "bell.badge",
                    isOn: $loginNotifications
                )
                
                SecurityActionRow(
                    title: "Change Password",
                    subtitle: "Update your account password",
                    icon: "key.horizontal",
                    action: {
                        // Mock change password
                    }
                )
                
                SecurityActionRow(
                    title: "Security Audit",
                    subtitle: "Review your account security status",
                    icon: "checkmark.shield",
                    action: {
                        // Mock security audit
                    }
                )
                
                SecurityActionRow(
                    title: "Login History",
                    subtitle: "View recent login attempts and locations",
                    icon: "clock.arrow.circlepath",
                    action: {
                        // Mock login history
                    }
                )
            }
        }
    }
    
    private var deviceSecuritySection: some View {
        SecuritySection(title: "Device Security", icon: "iphone.and.arrow.forward") {
            VStack(spacing: 8) {
                SecurityToggleRow(
                    title: "Device Trust",
                    subtitle: "Remember this device for faster authentication",
                    icon: "checkmark.iphone",
                    isOn: $deviceTrustEnabled
                )
                
                SecurityActionRow(
                    title: "Trusted Devices",
                    subtitle: "Manage devices that can access your account",
                    icon: "laptopcomputer.and.iphone",
                    action: {
                        // Mock trusted devices
                    }
                )
                
                SecurityActionRow(
                    title: "Remove Device Trust",
                    subtitle: "Require authentication on all devices",
                    icon: "xmark.iphone",
                    isDestructive: true,
                    action: {
                        // Mock remove device trust
                    }
                )
                
                if currentUserRole == .parentAdmin {
                    Divider()
                    
                    SecurityActionRow(
                        title: "Family Device Management",
                        subtitle: "Manage security settings for all family devices",
                        icon: "person.2.badge.gearshape",
                        action: {
                            // Mock family device management
                        }
                    )
                }
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
                isLoading = false
                dismiss()
            }
        }
    }
}

// MARK: - Security Section

struct SecuritySection<Content: View>: View {
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

// MARK: - Security Toggle Row

struct SecurityToggleRow: View {
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

// MARK: - Security Action Row

struct SecurityActionRow: View {
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

// MARK: - Enums

enum AutoLockTimeout: String, CaseIterable {
    case immediately = "immediately"
    case oneMinute = "one_minute"
    case fiveMinutes = "five_minutes"
    case fifteenMinutes = "fifteen_minutes"
    case thirtyMinutes = "thirty_minutes"
    case oneHour = "one_hour"
    case never = "never"
    
    var displayName: String {
        switch self {
        case .immediately: return "Immediately"
        case .oneMinute: return "1 Minute"
        case .fiveMinutes: return "5 Minutes"
        case .fifteenMinutes: return "15 Minutes"
        case .thirtyMinutes: return "30 Minutes"
        case .oneHour: return "1 Hour"
        case .never: return "Never"
        }
    }
}

enum SessionTimeout: String, CaseIterable {
    case fifteenMinutes = "fifteen_minutes"
    case thirtyMinutes = "thirty_minutes"
    case oneHour = "one_hour"
    case fourHours = "four_hours"
    case oneDay = "one_day"
    case oneWeek = "one_week"
    case never = "never"
    
    var displayName: String {
        switch self {
        case .fifteenMinutes: return "15 Minutes"
        case .thirtyMinutes: return "30 Minutes"
        case .oneHour: return "1 Hour"
        case .fourHours: return "4 Hours"
        case .oneDay: return "1 Day"
        case .oneWeek: return "1 Week"
        case .never: return "Never"
        }
    }
}

// MARK: - Preview

#Preview {
    SecuritySettingsView(currentUserRole: .parentAdmin)
}