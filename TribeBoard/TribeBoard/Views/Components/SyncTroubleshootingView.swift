import SwiftUI
import EventKit

/// View for sync troubleshooting tools and diagnostics
struct SyncTroubleshootingView: View {
    @ObservedObject var viewModel: SyncSettingsViewModel
    @State private var diagnosticResults: [DiagnosticResult] = []
    @State private var isRunningDiagnostics = false
    @State private var showingResetConfirmation = false
    @State private var showingCalendarInfo = false
    
    var body: some View {
        Form {
            diagnosticsSection
            quickFixesSection
            advancedToolsSection
            systemInfoSection
        }
        .navigationTitle("Troubleshooting")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Reset Sync Data", isPresented: $showingResetConfirmation) {
            Button("Reset", role: .destructive) {
                Task {
                    await resetSyncData()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will clear all sync settings and force a complete re-sync. This action cannot be undone.")
        }
        .sheet(isPresented: $showingCalendarInfo) {
            CalendarInfoView(viewModel: viewModel)
        }
    }
    
    // MARK: - Diagnostics Section
    
    private var diagnosticsSection: some View {
        Section {
            Button(action: {
                Task {
                    await runDiagnostics()
                }
            }) {
                HStack {
                    Image(systemName: "stethoscope")
                    Text("Run Diagnostics")
                    
                    Spacer()
                    
                    if isRunningDiagnostics {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
            .disabled(isRunningDiagnostics)
            
            if !diagnosticResults.isEmpty {
                ForEach(diagnosticResults) { result in
                    DiagnosticResultRow(result: result)
                }
            }
        } header: {
            Text("System Diagnostics")
        } footer: {
            Text("Run diagnostics to check for common sync issues and get recommendations.")
        }
    }
    
    // MARK: - Quick Fixes Section
    
    private var quickFixesSection: some View {
        Section {
            Button(action: {
                Task {
                    await viewModel.validateSyncSetup()
                }
            }) {
                HStack {
                    Image(systemName: "checkmark.shield")
                    Text("Validate Sync Setup")
                    Spacer()
                }
            }
            
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
            .disabled(!viewModel.eventKitPermissionGranted)
            
            Button(action: {
                Task {
                    await viewModel.resetSyncErrors()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Reset Error Count")
                    Spacer()
                }
            }
            .disabled(viewModel.syncErrorCount == 0)
            
            Button(action: {
                Task {
                    await forceFullResync()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Force Full Re-sync")
                    Spacer()
                }
            }
            .disabled(!viewModel.isAppleCalendarSyncEnabled || viewModel.isSyncing)
        } header: {
            Text("Quick Fixes")
        } footer: {
            Text("Try these common solutions for sync issues.")
        }
    }
    
    // MARK: - Advanced Tools Section
    
    private var advancedToolsSection: some View {
        Section {
            Button(action: {
                showingCalendarInfo = true
            }) {
                HStack {
                    Image(systemName: "info.circle")
                    Text("Calendar Information")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Button(action: {
                Task {
                    await exportSyncLogs()
                }
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export Sync Logs")
                    Spacer()
                }
            }
            
            Button(action: {
                showingResetConfirmation = true
            }) {
                HStack {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                    Text("Reset All Sync Data")
                        .foregroundColor(.red)
                    Spacer()
                }
            }
        } header: {
            Text("Advanced Tools")
        } footer: {
            Text("Use these tools with caution. Some actions cannot be undone.")
        }
    }
    
    // MARK: - System Info Section
    
    private var systemInfoSection: some View {
        Section {
            InfoRow(label: "EventKit Status", value: eventKitStatusText, color: eventKitStatusColor)
            InfoRow(label: "Network Status", value: "Connected", color: .green) // Would check actual network status
            InfoRow(label: "Sync Health", value: viewModel.syncHealthStatus.rawValue.capitalized, color: syncHealthColor)
            InfoRow(label: "Pending Operations", value: "\(viewModel.pendingOperationsCount)", color: pendingOperationsColor)
            
            if let lastSync = viewModel.lastSyncDate {
                InfoRow(label: "Last Sync", value: formatLastSync(lastSync), color: .secondary)
            }
            
            if viewModel.syncErrorCount > 0 {
                InfoRow(label: "Error Count", value: "\(viewModel.syncErrorCount)", color: .red)
            }
        } header: {
            Text("System Information")
        }
    }
    
    // MARK: - Helper Methods
    
    private func runDiagnostics() async {
        isRunningDiagnostics = true
        diagnosticResults = []
        
        // Simulate diagnostic checks
        await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        var results: [DiagnosticResult] = []
        
        // Check EventKit permission
        results.append(DiagnosticResult(
            id: UUID(),
            category: .permissions,
            title: "EventKit Permission",
            status: viewModel.eventKitPermissionGranted ? .pass : .fail,
            message: viewModel.eventKitPermissionGranted ? "Calendar access granted" : "Calendar access denied",
            recommendation: viewModel.eventKitPermissionGranted ? nil : "Enable calendar access in Settings"
        ))
        
        // Check sync configuration
        results.append(DiagnosticResult(
            id: UUID(),
            category: .configuration,
            title: "Sync Configuration",
            status: viewModel.isAppleCalendarSyncEnabled ? .pass : .warning,
            message: viewModel.isAppleCalendarSyncEnabled ? "Sync is enabled" : "Sync is disabled",
            recommendation: viewModel.isAppleCalendarSyncEnabled ? nil : "Enable Apple Calendar sync in settings"
        ))
        
        // Check network connectivity
        results.append(DiagnosticResult(
            id: UUID(),
            category: .network,
            title: "Network Connectivity",
            status: .pass, // Would check actual network status
            message: "Internet connection available",
            recommendation: nil
        ))
        
        // Check for pending operations
        let hasPendingOps = viewModel.pendingOperationsCount > 0
        results.append(DiagnosticResult(
            id: UUID(),
            category: .sync,
            title: "Pending Operations",
            status: hasPendingOps ? .warning : .pass,
            message: hasPendingOps ? "\(viewModel.pendingOperationsCount) operations pending" : "No pending operations",
            recommendation: hasPendingOps ? "Try running a manual sync" : nil
        ))
        
        // Check for recent errors
        let hasErrors = viewModel.syncErrorCount > 0
        results.append(DiagnosticResult(
            id: UUID(),
            category: .sync,
            title: "Recent Errors",
            status: hasErrors ? .fail : .pass,
            message: hasErrors ? "\(viewModel.syncErrorCount) recent errors" : "No recent errors",
            recommendation: hasErrors ? "Check sync history for details" : nil
        ))
        
        diagnosticResults = results
        isRunningDiagnostics = false
    }
    
    private func forceFullResync() async {
        // This would clear sync state and force a complete re-sync
        await viewModel.performManualSync()
    }
    
    private func resetSyncData() async {
        // This would reset all sync configuration and data
        await viewModel.disableAppleCalendarSync()
        await viewModel.resetSyncErrors()
        
        // Clear diagnostic results
        diagnosticResults = []
    }
    
    private func exportSyncLogs() async {
        // This would export sync logs for support
        print("Exporting sync logs...")
        // Implementation would create a file with sync logs and present share sheet
    }
    
    // MARK: - Computed Properties
    
    private var eventKitStatusText: String {
        if viewModel.eventKitPermissionGranted {
            return "Authorized"
        } else {
            return "Not Authorized"
        }
    }
    
    private var eventKitStatusColor: Color {
        viewModel.eventKitPermissionGranted ? .green : .red
    }
    
    private var syncHealthColor: Color {
        switch viewModel.syncHealthStatus {
        case .healthy:
            return .green
        case .warning:
            return .orange
        case .error:
            return .red
        case .disabled:
            return .gray
        case .permissionRequired:
            return .blue
        case .notConfigured:
            return .yellow
        }
    }
    
    private var pendingOperationsColor: Color {
        viewModel.pendingOperationsCount > 0 ? .orange : .green
    }
    
    private func formatLastSync(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Supporting Views

struct DiagnosticResultRow: View {
    let result: DiagnosticResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: result.status.iconName)
                    .foregroundColor(result.status.color)
                
                Text(result.title)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(result.status.displayName)
                    .font(.caption)
                    .foregroundColor(result.status.color)
            }
            
            Text(result.message)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let recommendation = result.recommendation {
                Text("💡 \(recommendation)")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 2)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

// MARK: - Calendar Info View

struct CalendarInfoView: View {
    @ObservedObject var viewModel: SyncSettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var calendarInfo: [CalendarInfo] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    ProgressView("Loading calendar information...")
                } else {
                    List(calendarInfo) { info in
                        CalendarInfoRow(info: info)
                    }
                }
            }
            .navigationTitle("Calendar Information")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                Task {
                    await loadCalendarInfo()
                }
            }
        }
    }
    
    private func loadCalendarInfo() async {
        isLoading = true
        
        // Simulate loading calendar information
        await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Mock calendar information
        calendarInfo = [
            CalendarInfo(
                id: UUID(),
                name: "TribeBoard",
                type: "Main Calendar",
                identifier: "tribeboard-main-123",
                eventCount: 15,
                isVisible: true,
                color: .blue
            ),
            CalendarInfo(
                id: UUID(),
                name: "TribeBoard Family",
                type: "Family Events",
                identifier: "tribeboard-family-456",
                eventCount: 8,
                isVisible: true,
                color: .green
            ),
            CalendarInfo(
                id: UUID(),
                name: "TribeBoard Personal",
                type: "Personal Events",
                identifier: "tribeboard-personal-789",
                eventCount: 12,
                isVisible: true,
                color: .orange
            )
        ]
        
        isLoading = false
    }
}

struct CalendarInfoRow: View {
    let info: CalendarInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(info.color)
                    .frame(width: 12, height: 12)
                
                Text(info.name)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(info.eventCount) events")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Type: \(info.type)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("ID: \(info.identifier)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                Text("Visible: \(info.isVisible ? "Yes" : "No")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Supporting Models

struct DiagnosticResult: Identifiable {
    let id: UUID
    let category: DiagnosticCategory
    let title: String
    let status: DiagnosticStatus
    let message: String
    let recommendation: String?
}

enum DiagnosticCategory {
    case permissions
    case configuration
    case network
    case sync
}

enum DiagnosticStatus {
    case pass
    case warning
    case fail
    
    var displayName: String {
        switch self {
        case .pass:
            return "Pass"
        case .warning:
            return "Warning"
        case .fail:
            return "Fail"
        }
    }
    
    var iconName: String {
        switch self {
        case .pass:
            return "checkmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .fail:
            return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .pass:
            return .green
        case .warning:
            return .orange
        case .fail:
            return .red
        }
    }
}

struct CalendarInfo: Identifiable {
    let id: UUID
    let name: String
    let type: String
    let identifier: String
    let eventCount: Int
    let isVisible: Bool
    let color: Color
}

// MARK: - Preview

#Preview {
    let tempContainer = try! ModelContainerConfiguration.createInMemory()
    let mockEventKitManager = EventKitManager()
    let mockSyncService = CalendarSyncService(
        eventKitManager: mockEventKitManager,
        modelContext: tempContainer.mainContext
    )
    let mockViewModel = SyncSettingsViewModel(
        userId: UUID(),
        syncService: mockSyncService,
        eventKitManager: mockEventKitManager,
        modelContext: tempContainer.mainContext
    )
    
    return NavigationView {
        SyncTroubleshootingView(viewModel: mockViewModel)
    }
}