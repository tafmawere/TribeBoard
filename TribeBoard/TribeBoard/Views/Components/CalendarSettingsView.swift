import SwiftUI

/// Comprehensive calendar settings view integrating all calendar features
struct CalendarSettingsView: View {
    @StateObject private var viewModel = CalendarSettingsViewModel()
    @State private var showBackupManagement = false
    @State private var showHelpView = false
    
    var body: some View {
        NavigationView {
            List {
                // Apple Calendar Sync Section
                Section("Apple Calendar Sync") {
                    HStack {
                        Image(systemName: "arrow.clockwise.icloud")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sync with Apple Calendar")
                                .font(.body)
                            
                            Text(viewModel.syncStatus)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $viewModel.isAppleCalendarSyncEnabled)
                            .onChange(of: viewModel.isAppleCalendarSyncEnabled) { _, newValue in
                                Task {
                                    await viewModel.toggleAppleCalendarSync(newValue)
                                }
                            }
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Apple Calendar sync, \(viewModel.syncStatus)")
                    
                    if viewModel.isAppleCalendarSyncEnabled {
                        Button("Manual Sync") {
                            Task {
                                await viewModel.performManualSync()
                            }
                        }
                        .disabled(viewModel.isSyncing)
                        
                        if viewModel.lastSyncDate != nil {
                            HStack {
                                Text("Last sync:")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(viewModel.lastSyncDateString)
                                    .foregroundColor(.secondary)
                            }
                            .font(.caption)
                        }
                    }
                }
                
                // Privacy & Permissions Section
                Section("Privacy & Permissions") {
                    NavigationLink(destination: CalendarPermissionManagementView()) {
                        HStack {
                            Image(systemName: "lock.shield")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Family Calendar Permissions")
                                Text("Manage who can create and edit events")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    HStack {
                        Image(systemName: "eye.slash")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Default Privacy Level")
                            Text("New events will be \(viewModel.defaultPrivacyLevel.displayName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Picker("Privacy Level", selection: $viewModel.defaultPrivacyLevel) {
                            ForEach(CalendarEvent.PrivacyLevel.allCases, id: \.self) { level in
                                Text(level.displayName).tag(level)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
                
                // Notifications Section
                Section("Notifications") {
                    HStack {
                        Image(systemName: "bell")
                            .foregroundColor(.red)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Event Notifications")
                            Text("Get notified about upcoming events")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $viewModel.notificationsEnabled)
                    }
                    
                    if viewModel.notificationsEnabled {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            Text("Default Reminder")
                            
                            Spacer()
                            
                            Picker("Reminder Time", selection: $viewModel.defaultReminderTime) {
                                ForEach(ReminderTime.allCases, id: \.self) { time in
                                    Text(time.displayName).tag(time)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                        
                        HStack {
                            Image(systemName: "person.2")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Family Event Notifications")
                                Text("Get notified about family events")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Toggle("", isOn: $viewModel.familyNotificationsEnabled)
                        }
                    }
                }
                
                // Backup & Data Section
                Section("Backup & Data") {
                    Button(action: { showBackupManagement = true }) {
                        HStack {
                            Image(systemName: "externaldrive.badge.icloud")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Backup & Restore")
                                    .foregroundColor(.primary)
                                Text("Manage calendar data backups")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(.green)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Auto Backup")
                            Text("Automatically backup calendar data daily")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $viewModel.autoBackupEnabled)
                            .onChange(of: viewModel.autoBackupEnabled) { _, newValue in
                                viewModel.toggleAutoBackup(newValue)
                            }
                    }
                    
                    if viewModel.lastBackupDate != nil {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.secondary)
                                .frame(width: 24)
                            
                            Text("Last backup:")
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(viewModel.lastBackupDateString)
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                    }
                }
                
                // Display & Accessibility Section
                Section("Display & Accessibility") {
                    HStack {
                        Image(systemName: "textformat.size")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        Text("Calendar View")
                        
                        Spacer()
                        
                        Picker("View Type", selection: $viewModel.defaultCalendarView) {
                            ForEach(CalendarViewType.allCases, id: \.self) { viewType in
                                Text(viewType.displayName).tag(viewType)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    
                    HStack {
                        Image(systemName: "hand.tap")
                            .foregroundColor(.purple)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Haptic Feedback")
                            Text("Feel vibrations for calendar interactions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $viewModel.hapticFeedbackEnabled)
                    }
                    
                    HStack {
                        Image(systemName: "accessibility")
                            .foregroundColor(.green)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enhanced Accessibility")
                            Text("Improved VoiceOver and navigation")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $viewModel.enhancedAccessibilityEnabled)
                    }
                }
                
                // Help & Support Section
                Section("Help & Support") {
                    Button(action: { showHelpView = true }) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Calendar Help")
                                    .foregroundColor(.primary)
                                Text("Learn how to use calendar features")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    NavigationLink(destination: CalendarShortcutsView()) {
                        HStack {
                            Image(systemName: "command")
                                .foregroundColor(.purple)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Shortcuts & Tips")
                                Text("Quick actions and productivity tips")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    Button("Reset Calendar Settings") {
                        viewModel.showResetConfirmation = true
                    }
                    .foregroundColor(.red)
                }
                
                // Debug Section (only in debug builds)
                #if DEBUG
                Section("Debug") {
                    Button("Clear Calendar Cache") {
                        Task {
                            await viewModel.clearCache()
                        }
                    }
                    
                    Button("Generate Test Events") {
                        Task {
                            await viewModel.generateTestEvents()
                        }
                    }
                    
                    Button("Export Debug Info") {
                        viewModel.exportDebugInfo()
                    }
                }
                #endif
            }
            .navigationTitle("Calendar Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showBackupManagement) {
                CalendarBackupManagementView()
            }
            .sheet(isPresented: $showHelpView) {
                CalendarHelpView()
            }
            .alert("Reset Settings", isPresented: $viewModel.showResetConfirmation) {
                Button("Reset", role: .destructive) {
                    viewModel.resetSettings()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will reset all calendar settings to their default values. This action cannot be undone.")
            }
            .task {
                await viewModel.loadSettings()
            }
        }
    }
}

// MARK: - Calendar Settings ViewModel

@MainActor
class CalendarSettingsViewModel: ObservableObject {
    @Published var isAppleCalendarSyncEnabled = false
    @Published var isSyncing = false
    @Published var syncStatus = "Not configured"
    @Published var lastSyncDate: Date?
    
    @Published var defaultPrivacyLevel: CalendarEvent.PrivacyLevel = .personal
    @Published var notificationsEnabled = true
    @Published var familyNotificationsEnabled = true
    @Published var defaultReminderTime: ReminderTime = .fifteenMinutes
    
    @Published var autoBackupEnabled = true
    @Published var lastBackupDate: Date?
    
    @Published var defaultCalendarView: CalendarViewType = .month
    @Published var hapticFeedbackEnabled = true
    @Published var enhancedAccessibilityEnabled = false
    
    @Published var showResetConfirmation = false
    
    private let calendarService = CalendarService()
    private let backupService = CalendarBackupService.shared
    
    var lastSyncDateString: String {
        guard let date = lastSyncDate else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    var lastBackupDateString: String {
        guard let date = lastBackupDate else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    func loadSettings() async {
        // Load settings from UserDefaults or Core Data
        // This is a simplified implementation
        
        isAppleCalendarSyncEnabled = UserDefaults.standard.bool(forKey: "CalendarSyncEnabled")
        defaultPrivacyLevel = CalendarEvent.PrivacyLevel(rawValue: UserDefaults.standard.string(forKey: "DefaultPrivacyLevel") ?? "personal") ?? .personal
        notificationsEnabled = UserDefaults.standard.bool(forKey: "CalendarNotificationsEnabled")
        familyNotificationsEnabled = UserDefaults.standard.bool(forKey: "FamilyNotificationsEnabled")
        autoBackupEnabled = UserDefaults.standard.bool(forKey: "AutoBackupEnabled")
        hapticFeedbackEnabled = UserDefaults.standard.bool(forKey: "HapticFeedbackEnabled")
        enhancedAccessibilityEnabled = UserDefaults.standard.bool(forKey: "EnhancedAccessibilityEnabled")
        
        if let syncDateData = UserDefaults.standard.object(forKey: "LastSyncDate") as? Date {
            lastSyncDate = syncDateData
        }
        
        if let backupDateData = UserDefaults.standard.object(forKey: "LastBackupDate") as? Date {
            lastBackupDate = backupDateData
        }
        
        updateSyncStatus()
    }
    
    func toggleAppleCalendarSync(_ enabled: Bool) async {
        isSyncing = true
        
        do {
            if enabled {
                try await calendarService.enableAppleCalendarSync()
                syncStatus = "Enabled"
            } else {
                try await calendarService.disableAppleCalendarSync()
                syncStatus = "Disabled"
            }
            
            isAppleCalendarSyncEnabled = enabled
            UserDefaults.standard.set(enabled, forKey: "CalendarSyncEnabled")
            
            CalendarHapticManager.shared.success()
        } catch {
            CalendarHapticManager.shared.error()
            syncStatus = "Error: \(error.localizedDescription)"
        }
        
        isSyncing = false
    }
    
    func performManualSync() async {
        isSyncing = true
        
        do {
            try await calendarService.syncWithAppleCalendar()
            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: "LastSyncDate")
            
            CalendarHapticManager.shared.syncSuccess()
        } catch {
            CalendarHapticManager.shared.error()
        }
        
        isSyncing = false
        updateSyncStatus()
    }
    
    func toggleAutoBackup(_ enabled: Bool) {
        autoBackupEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "AutoBackupEnabled")
        
        if enabled {
            backupService.scheduleAutomaticBackups()
        }
        
        CalendarHapticManager.shared.lightImpact()
    }
    
    func resetSettings() {
        // Reset to defaults
        isAppleCalendarSyncEnabled = false
        defaultPrivacyLevel = .personal
        notificationsEnabled = true
        familyNotificationsEnabled = true
        defaultReminderTime = .fifteenMinutes
        autoBackupEnabled = true
        defaultCalendarView = .month
        hapticFeedbackEnabled = true
        enhancedAccessibilityEnabled = false
        
        // Clear UserDefaults
        let keys = [
            "CalendarSyncEnabled", "DefaultPrivacyLevel", "CalendarNotificationsEnabled",
            "FamilyNotificationsEnabled", "AutoBackupEnabled", "HapticFeedbackEnabled",
            "EnhancedAccessibilityEnabled", "LastSyncDate", "LastBackupDate"
        ]
        
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        CalendarHapticManager.shared.success()
    }
    
    private func updateSyncStatus() {
        if isAppleCalendarSyncEnabled {
            if let lastSync = lastSyncDate {
                let formatter = RelativeDateTimeFormatter()
                syncStatus = "Last synced \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
            } else {
                syncStatus = "Enabled, never synced"
            }
        } else {
            syncStatus = "Disabled"
        }
    }
    
    // Debug functions
    func clearCache() async {
        // Clear calendar cache
        CalendarHapticManager.shared.success()
    }
    
    func generateTestEvents() async {
        // Generate test events for debugging
        CalendarHapticManager.shared.success()
    }
    
    func exportDebugInfo() {
        // Export debug information
        CalendarHapticManager.shared.lightImpact()
    }
}

// MARK: - Supporting Types

enum ReminderTime: String, CaseIterable {
    case none = "none"
    case fiveMinutes = "5min"
    case fifteenMinutes = "15min"
    case thirtyMinutes = "30min"
    case oneHour = "1hour"
    case oneDay = "1day"
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .fiveMinutes: return "5 minutes before"
        case .fifteenMinutes: return "15 minutes before"
        case .thirtyMinutes: return "30 minutes before"
        case .oneHour: return "1 hour before"
        case .oneDay: return "1 day before"
        }
    }
}

enum CalendarViewType: String, CaseIterable {
    case month = "month"
    case week = "week"
    case day = "day"
    case list = "list"
    
    var displayName: String {
        switch self {
        case .month: return "Month"
        case .week: return "Week"
        case .day: return "Day"
        case .list: return "List"
        }
    }
}

#Preview {
    CalendarSettingsView()
        .previewEnvironment()
}