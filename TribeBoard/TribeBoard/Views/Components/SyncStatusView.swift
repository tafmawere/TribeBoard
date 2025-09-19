import SwiftUI

/// View component that displays current sync status and offline mode information
struct SyncStatusView: View {
    @ObservedObject private var syncManager: SyncManager
    @State private var showDetails = false
    
    init(syncManager: SyncManager) {
        self.syncManager = syncManager
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main status bar
            HStack(spacing: 8) {
                statusIcon
                statusText
                Spacer()
                
                if syncManager.pendingSyncCount > 0 {
                    pendingCountBadge
                }
                
                if syncManager.syncStatus.isActive {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                
                Button(action: { showDetails.toggle() }) {
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(statusBackgroundColor)
            .onTapGesture {
                if syncManager.pendingSyncCount > 0 && !syncManager.isOfflineMode {
                    Task {
                        await syncManager.forceSyncNow()
                    }
                }
            }
            
            // Detailed status (expandable)
            if showDetails {
                detailsView
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showDetails)
        .animation(.easeInOut(duration: 0.2), value: syncManager.syncStatus)
    }
    
    // MARK: - Status Components
    
    @ViewBuilder
    private var statusIcon: some View {
        Group {
            if syncManager.isOfflineMode {
                Image(systemName: "wifi.slash")
                    .foregroundColor(.orange)
            } else if syncManager.syncStatus.isActive {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.blue)
            } else if syncManager.pendingSyncCount > 0 {
                Image(systemName: "clock")
                    .foregroundColor(.orange)
            } else {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.green)
            }
        }
        .font(.caption)
    }
    
    private var statusText: some View {
        Text(statusMessage)
            .font(.caption)
            .foregroundColor(.primary)
    }
    
    private var statusMessage: String {
        let info = syncManager.getSyncStatusInfo()
        return info.statusMessage
    }
    
    private var pendingCountBadge: some View {
        Text("\(syncManager.pendingSyncCount)")
            .font(.caption2)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange)
            .clipShape(Capsule())
    }
    
    private var statusBackgroundColor: Color {
        if syncManager.isOfflineMode {
            return Color.orange.opacity(0.1)
        } else if syncManager.syncStatus.isActive {
            return Color.blue.opacity(0.1)
        } else if syncManager.pendingSyncCount > 0 {
            return Color.orange.opacity(0.05)
        } else {
            return Color.green.opacity(0.05)
        }
    }
    
    // MARK: - Details View
    
    private var detailsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Network:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(syncManager.isNetworkAvailable ? "Connected" : "Disconnected")
                        .font(.caption2)
                        .foregroundColor(syncManager.isNetworkAvailable ? .green : .red)
                }
                
                HStack {
                    Text("iCloud:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(syncManager.isCloudKitAvailable ? "Available" : "Unavailable")
                        .font(.caption2)
                        .foregroundColor(syncManager.isCloudKitAvailable ? .green : .red)
                }
                
                if let lastSync = syncManager.lastSyncDate {
                    HStack {
                        Text("Last sync:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatLastSyncDate(lastSync))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                if syncManager.syncStatus.isActive {
                    HStack {
                        Text("Progress:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(Int(syncManager.syncProgress * 100))%")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    
                    ProgressView(value: syncManager.syncProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .scaleEffect(y: 0.5)
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                if syncManager.pendingSyncCount > 0 && !syncManager.isOfflineMode {
                    Button("Sync Now") {
                        Task {
                            await syncManager.forceSyncNow()
                        }
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
                
                Spacer()
                
                Button("Refresh") {
                    Task {
                        await syncManager.checkConnectivityStatus()
                    }
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))
                .foregroundColor(.primary)
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
    
    // MARK: - Helper Methods
    
    private func formatLastSyncDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Compact Sync Status View

/// A more compact version for use in navigation bars or toolbars
struct CompactSyncStatusView: View {
    @ObservedObject private var syncManager: SyncManager
    
    init(syncManager: SyncManager) {
        self.syncManager = syncManager
    }
    
    var body: some View {
        HStack(spacing: 4) {
            statusIcon
            
            if syncManager.pendingSyncCount > 0 {
                Text("\(syncManager.pendingSyncCount)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .onTapGesture {
            if syncManager.pendingSyncCount > 0 && !syncManager.isOfflineMode {
                Task {
                    await syncManager.forceSyncNow()
                }
            }
        }
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        Group {
            if syncManager.isOfflineMode {
                Image(systemName: "wifi.slash")
                    .foregroundColor(.orange)
            } else if syncManager.syncStatus.isActive {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.blue)
            } else if syncManager.pendingSyncCount > 0 {
                Image(systemName: "clock")
                    .foregroundColor(.orange)
            } else {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.green)
            }
        }
        .font(.caption)
    }
}

// MARK: - Sync Status Banner

/// A banner that appears at the top of screens to show important sync information
struct SyncStatusBanner: View {
    @ObservedObject private var syncManager: SyncManager
    @State private var isVisible = true
    
    init(syncManager: SyncManager) {
        self.syncManager = syncManager
    }
    
    var body: some View {
        Group {
            if shouldShowBanner && isVisible {
                HStack {
                    statusIcon
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(bannerTitle)
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text(bannerMessage)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if syncManager.pendingSyncCount > 0 && !syncManager.isOfflineMode {
                        Button("Sync") {
                            Task {
                                await syncManager.forceSyncNow()
                            }
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                    }
                    
                    Button(action: { isVisible = false }) {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(bannerBackgroundColor)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isVisible)
        .animation(.easeInOut(duration: 0.3), value: shouldShowBanner)
    }
    
    private var shouldShowBanner: Bool {
        return syncManager.isOfflineMode || syncManager.pendingSyncCount > 0
    }
    
    private var bannerTitle: String {
        if syncManager.isOfflineMode {
            return "Working Offline"
        } else if syncManager.pendingSyncCount > 0 {
            return "Sync Pending"
        } else {
            return "All Synced"
        }
    }
    
    private var bannerMessage: String {
        if syncManager.isOfflineMode {
            return syncManager.pendingSyncCount > 0 
                ? "\(syncManager.pendingSyncCount) items will sync when online"
                : "Changes will sync when connection is restored"
        } else if syncManager.pendingSyncCount > 0 {
            return "\(syncManager.pendingSyncCount) items ready to sync to iCloud"
        } else {
            return "All data is up to date"
        }
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        Group {
            if syncManager.isOfflineMode {
                Image(systemName: "wifi.slash")
                    .foregroundColor(.orange)
            } else if syncManager.pendingSyncCount > 0 {
                Image(systemName: "clock")
                    .foregroundColor(.orange)
            } else {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.green)
            }
        }
        .font(.title3)
    }
    
    private var bannerBackgroundColor: Color {
        if syncManager.isOfflineMode {
            return Color.orange.opacity(0.1)
        } else if syncManager.pendingSyncCount > 0 {
            return Color.orange.opacity(0.05)
        } else {
            return Color.green.opacity(0.05)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Mock SyncManager for preview
        let tempContainer = try! ModelContainerConfiguration.createInMemory()
        let mockSyncManager = SyncManager(
            dataService: DataService(modelContext: tempContainer.mainContext),
            cloudKitService: CloudKitService()
        )
        
        SyncStatusView(syncManager: mockSyncManager)
        CompactSyncStatusView(syncManager: mockSyncManager)
        SyncStatusBanner(syncManager: mockSyncManager)
    }
    .padding()
}