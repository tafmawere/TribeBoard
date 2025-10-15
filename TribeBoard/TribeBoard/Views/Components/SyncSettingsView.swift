import SwiftUI
import SwiftData
import EventKit

/// View for managing Apple Calendar sync settings and controls
struct SyncSettingsView: View {
    @StateObject private var viewModel: SyncSettingsViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingPermissionAlert = false
    @State private var showingErrorAlert = false
    @State private var showingSyncHistory = false
    @State private var showingConflictResolutionInfo = false
    
    init(userId: UUID, syncService: CalendarSyncService, eventKitManager: EventKitManager, modelContext: ModelContext) {
        self._viewModel = StateObject(wrappedValue: SyncSettingsViewModel(
            userId: userId,
            syncService: syncService,
            eventKitManager: eventKitManager,
            modelContext: modelContext
        ))
    }
    
    var body: some View {
        NavigationView {
            Form {
                syncStatusSection
                syncSettingsSection
                syncPreferencesSection
                syncControlsSection
                syncHistorySection
                troubleshootingSection
            }
            .navigationTitle("Calendar Sync")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Calendar Permission Required", isPresented: $showingPermissionAlert) {
                Button("Settings") {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("TribeBoard needs access to your calendar to sync events with Apple Calendar. Please enable calendar access in Settings.")
            }
            .alert("Sync Error", isPresented: $showingErrorAlert) {
                Button("OK") { }
                Button("Retry") {
                    Task {
                        await viewModel.performManualSync()
                    }
                }
            } message: {
                Text(viewModel.lastError?.localizedDescription ?? "An unknown error occurred during sync.")
            }
            .sheet(isPresented: $showingSyncHistory) {
                SyncHistoryView(userId: viewModel.userId, modelContext: viewModel.modelContext)
            }
            .onAppear {
                Task {
                    await viewModel.loadSyncConfiguration()
                }
            }
        }
    }
    
    // MARK: - Sync Status Section
    
    private var syncStatusSection: some View {
        Section {
            HStack {
                syncStatusIcon
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sync Status")
                        .font(.headline)
                    
                    Text(viewModel.syncStatusDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let lastSync = viewModel.lastSyncDate {
                        Text("Last synced \(lastSync, style: .relative) ago")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if viewModel.isSyncing {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if viewModel.pendingOperationsCount > 0 {
                    Text("\(viewModel.pendingOperationsCount)")
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 4)
            
            if viewModel.isSyncing {
                ProgressView(value: viewModel.syncProgress)
                    .progressViewStyle(LinearProgressViewStyle())
            }
        } header: {
            Text("Status")
        }
    }
    
    @ViewBuilder
    private var syncStatusIcon: some View {
        Group {
            switch viewModel.syncHealthStatus {
            case .healthy:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .warning:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            case .error:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            case .disabled:
                Image(systemName: "pause.circle.fill")
                    .foregroundColor(.gray)
            case .permissionRequired:
                Image(systemName: "lock.circle.fill")
                    .foregroundColor(.blue)
            case .notConfigured:
                Image(systemName: "gear.circle.fill")
                    .foregroundColor(.yellow)
            }
        }
        .font(.title2)
    }
    
    // MARK: - Sync Settings Section
    
    private var syncSettingsSection: some View {
        Section {
            Toggle("Apple Calendar Sync", isOn: $viewModel.isAppleCalendarSyncEnabled)
                .onChange(of: viewModel.isAppleCalendarSyncEnabled) { _, newValue in
                    Task {
                        if newValue {
                            await viewModel.enableAppleCalendarSync()
                        } else {
                            await viewModel.disableAppleCalendarSync()
                        }
                    }
                }
            
            if viewModel.isAppleCalendarSyncEnabled {
                HStack {
                    Text("EventKit Permission")
                    Spacer()
                    
                    if viewModel.eventKitPermissionGranted {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Granted")
                                .foregroundColor(.green)
                        }
                    } else {
                        Button("Request Permission") {
                            Task {
                                await viewModel.requestEventKitPermission()
                            }
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                if !viewModel.eventKitPermissionGranted && viewModel.isAppleCalendarSyncEnabled {
                    Text("Calendar access is required to sync events with Apple Calendar.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Sync Settings")
        } footer: {
            if viewModel.isAppleCalendarSyncEnabled {
                Text("Events will be synced to dedicated TribeBoard calendars in Apple Calendar.")
            } else {
                Text("Enable sync to keep your TribeBoard events synchronized with Apple Calendar across all your devices.")
            }
        }
    }
    
    // MARK: - Sync Preferences Section
    
    private var syncPreferencesSection: some View {
        Section {
            if viewModel.isAppleCalendarSyncEnabled && viewModel.eventKitPermissionGranted {
                // Sync Direction
                Picker("Sync Direction", selection: $viewModel.syncDirection) {
                    ForEach(SyncConfiguration.SyncDirection.allCases, id: \.self) { direction in
                        VStack(alignment: .leading) {
                            Text(direction.displayName)
                            Text(direction.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .tag(direction)
                    }
                }
                .pickerStyle(.navigationLink)
                
                // Conflict Resolution
                HStack {
                    Text("Conflict Resolution")
                    Spacer()
                    Button(viewModel.conflictResolution.displayName) {
                        showingConflictResolutionInfo = true
                    }
                    .foregroundColor(.blue)
                }
                .sheet(isPresented: $showingConflictResolutionInfo) {
                    ConflictResolutionSettingsView(
                        selectedStrategy: $viewModel.conflictResolution,
                        onSave: {
                            Task {
                                await viewModel.updateSyncPreferences()
                            }
                        }
                    )
                }
                
                // Auto Sync
                Toggle("Automatic Sync", isOn: $viewModel.autoSyncEnabled)
                    .onChange(of: viewModel.autoSyncEnabled) { _, _ in
                        Task {
                            await viewModel.updateSyncPreferences()
                        }
                    }
                
                if viewModel.autoSyncEnabled {
                    Picker("Sync Frequency", selection: $viewModel.syncFrequencyMinutes) {
                        Text("Every 5 minutes").tag(5)
                        Text("Every 15 minutes").tag(15)
                        Text("Every 30 minutes").tag(30)
                        Text("Every hour").tag(60)
                        Text("Every 2 hours").tag(120)
                        Text("Every 4 hours").tag(240)
                    }
                    .pickerStyle(.navigationLink)
                    .onChange(of: viewModel.syncFrequencyMinutes) { _, _ in
                        Task {
                            await viewModel.updateSyncPreferences()
                        }
                    }
                }
            }
        } header: {
            Text("Preferences")
        } footer: {
            if viewModel.autoSyncEnabled {
                Text("Events will automatically sync every \(viewModel.syncFrequencyDescription).")
            }
        }
    }
    
    // MARK: - Sync Controls Section
    
    private var syncControlsSection: some View {
        Section {
            if viewModel.isAppleCalendarSyncEnabled && viewModel.eventKitPermissionGranted {
                Button(action: {
                    Task {
                        await viewModel.performManualSync()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Sync Now")
                        
                        Spacer()
                        
                        if viewModel.isSyncing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if viewModel.pendingOperationsCount > 0 {
                            Text("(\(viewModel.pendingOperationsCount) pending)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .disabled(viewModel.isSyncing)
                
                if viewModel.lastError != nil {
                    Button(action: {
                        showingErrorAlert = true
                    }) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                            Text("View Last Error")
                            Spacer()
                        }
                    }
                }
                
                Button(action: {
                    Task {
                        await viewModel.resetSyncErrors()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Reset Sync Status")
                        Spacer()
                    }
                }
                .disabled(viewModel.syncErrorCount == 0)
            }
        } header: {
            Text("Manual Controls")
        }
    }
    
    // MARK: - Sync History Section
    
    private var syncHistorySection: some View {
        Section {
            Button(action: {
                showingSyncHistory = true
            }) {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                    Text("Sync History")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let lastSync = viewModel.lastSyncDate {
                HStack {
                    Text("Last Successful Sync")
                    Spacer()
                    Text(lastSync, style: .relative)
                        .foregroundColor(.secondary)
                }
            }
            
            if viewModel.syncErrorCount > 0 {
                HStack {
                    Text("Recent Errors")
                    Spacer()
                    Text("\(viewModel.syncErrorCount)")
                        .foregroundColor(.red)
                }
            }
        } header: {
            Text("History")
        }
    }
    
    // MARK: - Troubleshooting Section
    
    private var troubleshootingSection: some View {
        Section {
            NavigationLink(destination: SyncTroubleshootingView(viewModel: viewModel)) {
                HStack {
                    Image(systemName: "wrench.and.screwdriver")
                    Text("Troubleshooting")
                }
            }
            
            Button(action: {
                Task {
                    await viewModel.validateSyncSetup()
                }
            }) {
                HStack {
                    Image(systemName: "checkmark.shield")
                    Text("Validate Setup")
                    Spacer()
                }
            }
            
            if viewModel.isAppleCalendarSyncEnabled {
                Button(action: {
                    Task {
                        await viewModel.recreateCalendars()
                    }
                }) {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                        Text("Recreate Calendars")
                        Spacer()
                    }
                }
            }
        } header: {
            Text("Troubleshooting")
        } footer: {
            Text("Use these tools if you're experiencing sync issues or need to reset your calendar setup.")
        }
    }
}

// MARK: - Conflict Resolution Settings View

struct ConflictResolutionSettingsView: View {
    @Binding var selectedStrategy: SyncConfiguration.ConflictResolutionStrategy
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    ForEach(SyncConfiguration.ConflictResolutionStrategy.allCases, id: \.self) { strategy in
                        Button(action: {
                            selectedStrategy = strategy
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(strategy.displayName)
                                        .foregroundColor(.primary)
                                    Text(strategy.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedStrategy == strategy {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                } header: {
                    Text("When conflicts occur")
                } footer: {
                    Text("Choose how to handle conflicts when the same event is modified in both TribeBoard and Apple Calendar.")
                }
            }
            .navigationTitle("Conflict Resolution")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let tempContainer = try! ModelContainerConfiguration.createInMemory()
    let mockEventKitManager = EventKitManager()
    let mockSyncService = CalendarSyncService(
        eventKitManager: mockEventKitManager,
        modelContext: tempContainer.mainContext
    )
    
    return SyncSettingsView(
        userId: UUID(),
        syncService: mockSyncService,
        eventKitManager: mockEventKitManager,
        modelContext: tempContainer.mainContext
    )
}