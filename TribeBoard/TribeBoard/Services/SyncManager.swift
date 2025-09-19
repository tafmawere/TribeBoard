import Foundation
import SwiftData
import Network
import Combine

/// Service for managing offline mode support and automatic sync
@MainActor
class SyncManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current network connectivity status
    @Published private(set) var isNetworkAvailable = true
    
    /// Current CloudKit availability status
    @Published private(set) var isCloudKitAvailable = true
    
    /// Whether the app is in offline mode
    @Published private(set) var isOfflineMode = false
    
    /// Current sync status
    @Published private(set) var syncStatus: SyncStatus = .idle
    
    /// Number of records pending sync
    @Published private(set) var pendingSyncCount = 0
    
    /// Last successful sync timestamp
    @Published private(set) var lastSyncDate: Date?
    
    /// Current sync progress (0.0 to 1.0)
    @Published private(set) var syncProgress: Double = 0.0
    
    // MARK: - Dependencies
    
    private let dataService: DataService
    private let cloudKitService: CloudKitService
    
    // MARK: - Network Monitoring
    
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "SyncManager.NetworkMonitor")
    
    // MARK: - Sync Management
    
    private var syncTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let syncInterval: TimeInterval = 30.0 // 30 seconds
    
    // MARK: - Initialization
    
    init(dataService: DataService, cloudKitService: CloudKitService) {
        self.dataService = dataService
        self.cloudKitService = cloudKitService
        
        setupNetworkMonitoring()
        setupCloudKitMonitoring()
        setupPeriodicSync()
        
        // Initial status check
        Task {
            await checkConnectivityStatus()
            await updatePendingSyncCount()
        }
    }
    
    deinit {
        networkMonitor.cancel()
        syncTimer?.invalidate()
    }
    
    // MARK: - Network Monitoring
    
    /// Sets up network connectivity monitoring
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self = self else { return }
                
                let wasNetworkAvailable = self.isNetworkAvailable
                self.isNetworkAvailable = path.status == .satisfied
                
                // If network was restored, trigger sync
                if !wasNetworkAvailable && self.isNetworkAvailable {
                    await self.handleNetworkRestored()
                }
                
                self.updateOfflineMode()
                
                // Post notification about network status change
                NotificationCenter.default.post(
                    name: .networkStatusChanged,
                    object: self,
                    userInfo: [
                        "isAvailable": self.isNetworkAvailable,
                        "path": path
                    ]
                )
            }
        }
        
        networkMonitor.start(queue: networkQueue)
    }
    
    /// Sets up CloudKit availability monitoring
    private func setupCloudKitMonitoring() {
        // Monitor CloudKit service availability changes
        cloudKitService.$isCloudKitAvailable
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAvailable in
                guard let self = self else { return }
                
                let wasCloudKitAvailable = self.isCloudKitAvailable
                self.isCloudKitAvailable = isAvailable
                
                // If CloudKit was restored, trigger sync
                if !wasCloudKitAvailable && self.isCloudKitAvailable {
                    Task {
                        await self.handleCloudKitRestored()
                    }
                }
                
                self.updateOfflineMode()
            }
            .store(in: &cancellables)
    }
    
    /// Sets up periodic sync when online
    private func setupPeriodicSync() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: syncInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.performPeriodicSync()
            }
        }
    }
    
    // MARK: - Connectivity Management
    
    /// Updates offline mode based on network and CloudKit availability
    private func updateOfflineMode() {
        let wasOffline = isOfflineMode
        isOfflineMode = !isNetworkAvailable || !isCloudKitAvailable
        
        if wasOffline != isOfflineMode {
            // Post notification about offline mode change
            NotificationCenter.default.post(
                name: .offlineModeChanged,
                object: self,
                userInfo: [
                    "isOffline": isOfflineMode,
                    "networkAvailable": isNetworkAvailable,
                    "cloudKitAvailable": isCloudKitAvailable
                ]
            )
            
            // Show user notification about mode change
            if isOfflineMode {
                showOfflineModeNotification()
            } else {
                showOnlineModeNotification()
            }
        }
    }
    
    /// Checks current connectivity status
    func checkConnectivityStatus() async {
        // Check network connectivity
        let networkPath = networkMonitor.currentPath
        isNetworkAvailable = networkPath.status == .satisfied
        
        // Check CloudKit availability
        if isNetworkAvailable {
            isCloudKitAvailable = await cloudKitService.checkCloudKitAvailability()
        } else {
            isCloudKitAvailable = false
        }
        
        updateOfflineMode()
    }
    
    // MARK: - Sync Management
    
    /// Performs automatic sync when connectivity is restored
    private func handleNetworkRestored() async {
        print("🌐 SyncManager: Network connectivity restored")
        
        // Wait a moment for network to stabilize
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        await checkConnectivityStatus()
        
        if !isOfflineMode {
            await performAutomaticSync()
        }
    }
    
    /// Handles CloudKit availability restoration
    private func handleCloudKitRestored() async {
        print("☁️ SyncManager: CloudKit availability restored")
        
        await checkConnectivityStatus()
        
        if !isOfflineMode {
            await performAutomaticSync()
        }
    }
    
    /// Performs periodic sync if conditions are met
    private func performPeriodicSync() async {
        guard !isOfflineMode && pendingSyncCount > 0 else { return }
        
        print("⏰ SyncManager: Performing periodic sync")
        await performAutomaticSync()
    }
    
    /// Performs automatic sync of pending records
    func performAutomaticSync() async {
        guard !isOfflineMode else {
            print("📱 SyncManager: Cannot sync in offline mode")
            return
        }
        
        guard syncStatus != .syncing else {
            print("🔄 SyncManager: Sync already in progress")
            return
        }
        
        await updatePendingSyncCount()
        
        guard pendingSyncCount > 0 else {
            print("✅ SyncManager: No records pending sync")
            return
        }
        
        print("🔄 SyncManager: Starting automatic sync of \(pendingSyncCount) records")
        
        syncStatus = .syncing
        syncProgress = 0.0
        
        do {
            // Sync families
            let familiesSynced = await syncPendingFamilies()
            
            // Sync memberships
            let membershipsSynced = await syncPendingMemberships()
            
            // Sync user profiles
            let profilesSynced = await syncPendingUserProfiles()
            
            let totalSynced = familiesSynced + membershipsSynced + profilesSynced
            
            if totalSynced > 0 {
                syncStatus = .completed
                lastSyncDate = Date()
                
                print("✅ SyncManager: Sync completed successfully - \(totalSynced) records synced")
                
                // Show success notification
                ToastManager.shared.success("Synced \(totalSynced) records to iCloud")
                
                // Post notification about successful sync
                NotificationCenter.default.post(
                    name: .syncCompleted,
                    object: self,
                    userInfo: [
                        "recordsSynced": totalSynced,
                        "timestamp": Date()
                    ]
                )
            } else {
                syncStatus = .idle
                print("ℹ️ SyncManager: No records needed syncing")
            }
            
        } catch {
            syncStatus = .failed(error)
            
            print("❌ SyncManager: Sync failed - \(error.localizedDescription)")
            
            // Show error notification only for non-network errors
            if !isNetworkError(error) {
                ToastManager.shared.error("Sync failed: \(error.localizedDescription)")
            }
            
            // Post notification about sync failure
            NotificationCenter.default.post(
                name: .syncFailed,
                object: self,
                userInfo: [
                    "error": error,
                    "timestamp": Date()
                ]
            )
        }
        
        // Update pending count after sync attempt
        await updatePendingSyncCount()
        syncProgress = 1.0
        
        // Reset status after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if self.syncStatus.isCompleted || self.syncStatus.isFailed {
                self.syncStatus = .idle
                self.syncProgress = 0.0
            }
        }
    }
    
    /// Forces an immediate sync attempt
    func forceSyncNow() async {
        print("🚀 SyncManager: Force sync requested")
        
        if isOfflineMode {
            ToastManager.shared.warning("Cannot sync while offline")
            return
        }
        
        await performAutomaticSync()
    }
    
    // MARK: - Record Sync Operations
    
    /// Syncs pending families to CloudKit
    private func syncPendingFamilies() async -> Int {
        do {
            let pendingFamilies = try dataService.fetchPendingSyncFamilies()
            var syncedCount = 0
            
            for family in pendingFamilies {
                do {
                    try await cloudKitService.save(family)
                    
                    // Mark as synced
                    family.needsSync = false
                    family.lastSyncDate = Date()
                    syncedCount += 1
                    
                    print("✅ SyncManager: Synced family '\(family.name)'")
                    
                } catch {
                    print("❌ SyncManager: Failed to sync family '\(family.name)': \(error.localizedDescription)")
                    // Continue with other records
                }
                
                // Update progress
                syncProgress = Double(syncedCount) / Double(pendingFamilies.count) * 0.33 // Families are 1/3 of progress
            }
            
            if syncedCount > 0 {
                try dataService.save()
            }
            
            return syncedCount
            
        } catch {
            print("❌ SyncManager: Failed to fetch pending families: \(error.localizedDescription)")
            return 0
        }
    }
    
    /// Syncs pending memberships to CloudKit
    private func syncPendingMemberships() async -> Int {
        do {
            let pendingMemberships = try dataService.fetchPendingSyncMemberships()
            var syncedCount = 0
            
            for membership in pendingMemberships {
                do {
                    try await cloudKitService.save(membership)
                    
                    // Mark as synced
                    membership.needsSync = false
                    membership.lastSyncDate = Date()
                    syncedCount += 1
                    
                    print("✅ SyncManager: Synced membership for user \(membership.user?.displayName ?? "Unknown")")
                    
                } catch {
                    print("❌ SyncManager: Failed to sync membership: \(error.localizedDescription)")
                    // Continue with other records
                }
                
                // Update progress
                let baseProgress = 0.33 // Previous progress from families
                syncProgress = baseProgress + (Double(syncedCount) / Double(pendingMemberships.count) * 0.33)
            }
            
            if syncedCount > 0 {
                try dataService.save()
            }
            
            return syncedCount
            
        } catch {
            print("❌ SyncManager: Failed to fetch pending memberships: \(error.localizedDescription)")
            return 0
        }
    }
    
    /// Syncs pending user profiles to CloudKit
    private func syncPendingUserProfiles() async -> Int {
        do {
            let pendingProfiles = try dataService.fetchPendingSyncUserProfiles()
            var syncedCount = 0
            
            for profile in pendingProfiles {
                do {
                    try await cloudKitService.save(profile)
                    
                    // Mark as synced
                    profile.needsSync = false
                    profile.lastSyncDate = Date()
                    syncedCount += 1
                    
                    print("✅ SyncManager: Synced user profile '\(profile.displayName)'")
                    
                } catch {
                    print("❌ SyncManager: Failed to sync user profile '\(profile.displayName)': \(error.localizedDescription)")
                    // Continue with other records
                }
                
                // Update progress
                let baseProgress = 0.66 // Previous progress from families and memberships
                syncProgress = baseProgress + (Double(syncedCount) / Double(pendingProfiles.count) * 0.34)
            }
            
            if syncedCount > 0 {
                try dataService.save()
            }
            
            return syncedCount
            
        } catch {
            print("❌ SyncManager: Failed to fetch pending user profiles: \(error.localizedDescription)")
            return 0
        }
    }
    
    // MARK: - Utility Methods
    
    /// Updates the count of records pending sync
    func updatePendingSyncCount() async {
        do {
            let familyCount = try dataService.countPendingSyncFamilies()
            let membershipCount = try dataService.countPendingSyncMemberships()
            let profileCount = try dataService.countPendingSyncUserProfiles()
            
            pendingSyncCount = familyCount + membershipCount + profileCount
            
        } catch {
            print("❌ SyncManager: Failed to count pending sync records: \(error.localizedDescription)")
            pendingSyncCount = 0
        }
    }
    
    /// Checks if an error is network-related
    private func isNetworkError(_ error: Error) -> Bool {
        if let cloudKitError = error as? CloudKitError {
            switch cloudKitError {
            case .networkUnavailable:
                return true
            default:
                return false
            }
        }
        return false
    }
    
    // MARK: - User Notifications
    
    /// Shows notification when entering offline mode
    private func showOfflineModeNotification() {
        let message = pendingSyncCount > 0 
            ? "Working offline. \(pendingSyncCount) records will sync when online."
            : "Working offline. Changes will sync when online."
        
        ToastManager.shared.info(message)
        
        print("📱 SyncManager: Entered offline mode - \(pendingSyncCount) records pending sync")
    }
    
    /// Shows notification when returning to online mode
    private func showOnlineModeNotification() {
        let message = pendingSyncCount > 0 
            ? "Back online! Syncing \(pendingSyncCount) records..."
            : "Back online!"
        
        ToastManager.shared.success(message)
        
        print("🌐 SyncManager: Returned to online mode - \(pendingSyncCount) records pending sync")
    }
    
    // MARK: - Public Interface
    
    /// Gets current sync status information
    func getSyncStatusInfo() -> SyncStatusInfo {
        return SyncStatusInfo(
            isOffline: isOfflineMode,
            isNetworkAvailable: isNetworkAvailable,
            isCloudKitAvailable: isCloudKitAvailable,
            syncStatus: syncStatus,
            pendingCount: pendingSyncCount,
            lastSyncDate: lastSyncDate,
            progress: syncProgress
        )
    }
    
    /// Marks a family record for sync
    func markRecordForSync(_ record: Family) {
        record.needsSync = true
        
        Task {
            await updatePendingSyncCount()
        }
        
        print("📝 SyncManager: Marked family for sync - ID: \(record.id)")
    }
    
    /// Marks a membership record for sync
    func markRecordForSync(_ record: Membership) {
        record.needsSync = true
        
        Task {
            await updatePendingSyncCount()
        }
        
        print("📝 SyncManager: Marked membership for sync - ID: \(record.id)")
    }
    
    /// Marks a user profile record for sync
    func markRecordForSync(_ record: UserProfile) {
        record.needsSync = true
        
        Task {
            await updatePendingSyncCount()
        }
        
        print("📝 SyncManager: Marked user profile for sync - ID: \(record.id)")
    }
}

// MARK: - Supporting Types

/// Current sync status
enum SyncStatus: Equatable {
    case idle
    case syncing
    case completed
    case failed(Error)
    
    var isActive: Bool {
        if case .syncing = self {
            return true
        }
        return false
    }
    
    var isCompleted: Bool {
        if case .completed = self {
            return true
        }
        return false
    }
    
    var isFailed: Bool {
        if case .failed = self {
            return true
        }
        return false
    }
    
    var error: Error? {
        if case .failed(let error) = self {
            return error
        }
        return nil
    }
    
    var userDescription: String {
        switch self {
        case .idle:
            return "Ready"
        case .syncing:
            return "Syncing..."
        case .completed:
            return "Sync completed"
        case .failed(let error):
            return "Sync failed: \(error.localizedDescription)"
        }
    }
    
    static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.syncing, .syncing), (.completed, .completed):
            return true
        case (.failed(let lhsError), (.failed(let rhsError))):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

/// Comprehensive sync status information
struct SyncStatusInfo {
    let isOffline: Bool
    let isNetworkAvailable: Bool
    let isCloudKitAvailable: Bool
    let syncStatus: SyncStatus
    let pendingCount: Int
    let lastSyncDate: Date?
    let progress: Double
    
    var statusMessage: String {
        if isOffline {
            return pendingCount > 0 
                ? "Offline - \(pendingCount) records pending sync"
                : "Working offline"
        } else if syncStatus.isActive {
            return "Syncing \(pendingCount) records..."
        } else if pendingCount > 0 {
            return "\(pendingCount) records ready to sync"
        } else {
            return "All data synced"
        }
    }
}

// MARK: - Notification Names Extension

extension Notification.Name {
    static let networkStatusChanged = Notification.Name("networkStatusChanged")
    static let offlineModeChanged = Notification.Name("offlineModeChanged")
    static let syncCompleted = Notification.Name("syncCompleted")
    static let syncFailed = Notification.Name("syncFailed")
    static let syncStatusChanged = Notification.Name("syncStatusChanged")
}