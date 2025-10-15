import SwiftUI
import SwiftData
import EventKit
import Combine

/// ViewModel for managing Apple Calendar sync settings and operations
@MainActor
class SyncSettingsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isAppleCalendarSyncEnabled = false
    @Published var eventKitPermissionGranted = false
    @Published var syncDirection: SyncConfiguration.SyncDirection = .bidirectional
    @Published var conflictResolution: SyncConfiguration.ConflictResolutionStrategy = .lastModifiedWins
    @Published var autoSyncEnabled = true
    @Published var syncFrequencyMinutes = 15
    
    @Published var isSyncing = false
    @Published var syncProgress: Double = 0.0
    @Published var lastSyncDate: Date?
    @Published var syncErrorCount = 0
    @Published var pendingOperationsCount = 0
    @Published var lastError: Error?
    
    @Published var syncHealthStatus: SyncConfiguration.SyncHealthStatus = .notConfigured
    
    // MARK: - Properties
    
    let userId: UUID
    let syncService: CalendarSyncService
    let eventKitManager: EventKitManager
    let modelContext: ModelContext
    
    private var syncConfiguration: SyncConfiguration?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(userId: UUID, syncService: CalendarSyncService, eventKitManager: EventKitManager, modelContext: ModelContext) {
        self.userId = userId
        self.syncService = syncService
        self.eventKitManager = eventKitManager
        self.modelContext = modelContext
        
        setupObservers()
        print("🔧 SyncSettingsViewModel: Initialized for user: \(userId)")
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        // Observe sync service changes
        syncService.$isSyncing
            .receive(on: DispatchQueue.main)
            .assign(to: \.isSyncing, on: self)
            .store(in: &cancellables)
        
        syncService.$syncProgress
            .receive(on: DispatchQueue.main)
            .assign(to: \.syncProgress, on: self)
            .store(in: &cancellables)
        
        syncService.$lastSyncDate
            .receive(on: DispatchQueue.main)
            .assign(to: \.lastSyncDate, on: self)
            .store(in: &cancellables)
        
        syncService.$syncError
            .receive(on: DispatchQueue.main)
            .assign(to: \.lastError, on: self)
            .store(in: &cancellables)
    }
    
    // MARK: - Configuration Loading
    
    func loadSyncConfiguration() async {
        do {
            syncConfiguration = try getSyncConfiguration()
            
            if let config = syncConfiguration {
                // Update published properties from configuration
                isAppleCalendarSyncEnabled = config.isAppleCalendarSyncEnabled
                eventKitPermissionGranted = config.eventKitPermissionGranted
                syncDirection = config.syncDirection
                conflictResolution = config.syncConflictResolution
                autoSyncEnabled = config.autoSyncEnabled
                syncFrequencyMinutes = config.syncFrequencyMinutes
                lastSyncDate = config.lastSuccessfulSyncDate
                syncErrorCount = config.syncErrorCount
                syncHealthStatus = config.syncHealthStatus
                
                // Get pending operations count
                pendingOperationsCount = try getPendingOperationsCount()
                
                print("✅ SyncSettingsViewModel: Loaded sync configuration")
            } else {
                // Create new configuration
                await createDefaultSyncConfiguration()
            }
            
            // Check EventKit permission status
            await checkEventKitPermissionStatus()
            
        } catch {
            print("❌ SyncSettingsViewModel: Failed to load sync configuration: \(error)")
            lastError = error
        }
    }
    
    private func createDefaultSyncConfiguration() async {
        do {
            let newConfig = SyncConfiguration(userId: userId)
            modelContext.insert(newConfig)
            try modelContext.save()
            
            syncConfiguration = newConfig
            
            // Update published properties with defaults
            isAppleCalendarSyncEnabled = newConfig.isAppleCalendarSyncEnabled
            eventKitPermissionGranted = newConfig.eventKitPermissionGranted
            syncDirection = newConfig.syncDirection
            conflictResolution = newConfig.syncConflictResolution
            autoSyncEnabled = newConfig.autoSyncEnabled
            syncFrequencyMinutes = newConfig.syncFrequencyMinutes
            syncHealthStatus = newConfig.syncHealthStatus
            
            print("✅ SyncSettingsViewModel: Created default sync configuration")
            
        } catch {
            print("❌ SyncSettingsViewModel: Failed to create default sync configuration: \(error)")
            lastError = error
        }
    }
    
    // MARK: - Sync Control Methods
    
    func enableAppleCalendarSync() async {
        do {
            // First request EventKit permission
            let permissionGranted = try await eventKitManager.requestAccess()
            
            if permissionGranted {
                // Set up TribeBoard calendars
                let calendars = try await eventKitManager.setupAllTribeBoardCalendars()
                
                // Update configuration
                guard let config = syncConfiguration else {
                    throw SyncSettingsError.configurationNotFound
                }
                
                config.enableAppleCalendarSync(
                    calendarIdentifier: calendars.main.calendarIdentifier,
                    familyCalendarIdentifier: calendars.family.calendarIdentifier,
                    personalCalendarIdentifier: calendars.personal.calendarIdentifier
                )
                config.updateEventKitPermission(granted: true)
                
                try modelContext.save()
                
                // Update published properties
                isAppleCalendarSyncEnabled = true
                eventKitPermissionGranted = true
                syncHealthStatus = config.syncHealthStatus
                
                print("✅ SyncSettingsViewModel: Apple Calendar sync enabled")
                
                // Perform initial sync
                await performManualSync()
                
            } else {
                // Permission denied
                guard let config = syncConfiguration else {
                    throw SyncSettingsError.configurationNotFound
                }
                
                config.updateEventKitPermission(granted: false)
                try modelContext.save()
                
                eventKitPermissionGranted = false
                isAppleCalendarSyncEnabled = false
                syncHealthStatus = .permissionRequired
                
                print("❌ SyncSettingsViewModel: EventKit permission denied")
            }
            
        } catch {
            print("❌ SyncSettingsViewModel: Failed to enable Apple Calendar sync: \(error)")
            lastError = error
            isAppleCalendarSyncEnabled = false
        }
    }
    
    func disableAppleCalendarSync() async {
        do {
            guard let config = syncConfiguration else {
                throw SyncSettingsError.configurationNotFound
            }
            
            config.disableAppleCalendarSync()
            try modelContext.save()
            
            isAppleCalendarSyncEnabled = false
            syncHealthStatus = .disabled
            
            print("✅ SyncSettingsViewModel: Apple Calendar sync disabled")
            
        } catch {
            print("❌ SyncSettingsViewModel: Failed to disable Apple Calendar sync: \(error)")
            lastError = error
        }
    }
    
    func requestEventKitPermission() async {
        do {
            let permissionGranted = try await eventKitManager.requestAccess()
            
            guard let config = syncConfiguration else {
                throw SyncSettingsError.configurationNotFound
            }
            
            config.updateEventKitPermission(granted: permissionGranted)
            try modelContext.save()
            
            eventKitPermissionGranted = permissionGranted
            syncHealthStatus = config.syncHealthStatus
            
            if permissionGranted {
                print("✅ SyncSettingsViewModel: EventKit permission granted")
                
                // If sync was enabled but permission was missing, set up calendars now
                if isAppleCalendarSyncEnabled {
                    await enableAppleCalendarSync()
                }
            } else {
                print("❌ SyncSettingsViewModel: EventKit permission denied")
                isAppleCalendarSyncEnabled = false
            }
            
        } catch {
            print("❌ SyncSettingsViewModel: Failed to request EventKit permission: \(error)")
            lastError = error
        }
    }
    
    func performManualSync() async {
        do {
            guard let config = syncConfiguration, config.isSyncConfigured else {
                throw SyncSettingsError.syncNotConfigured
            }
            
            print("🔄 SyncSettingsViewModel: Starting manual sync")
            
            // Perform full bidirectional sync
            try await syncService.performFullSync(userId: userId)
            
            // Update configuration with successful sync
            config.recordSuccessfulSync()
            try modelContext.save()
            
            // Update published properties
            lastSyncDate = config.lastSuccessfulSyncDate
            syncErrorCount = config.syncErrorCount
            syncHealthStatus = config.syncHealthStatus
            pendingOperationsCount = try getPendingOperationsCount()
            
            print("✅ SyncSettingsViewModel: Manual sync completed successfully")
            
        } catch {
            print("❌ SyncSettingsViewModel: Manual sync failed: \(error)")
            
            // Record error in configuration
            if let config = syncConfiguration {
                config.recordSyncError(error.localizedDescription)
                try? modelContext.save()
                
                syncErrorCount = config.syncErrorCount
                syncHealthStatus = config.syncHealthStatus
            }
            
            lastError = error
        }
    }
    
    func updateSyncPreferences() async {
        do {
            guard let config = syncConfiguration else {
                throw SyncSettingsError.configurationNotFound
            }
            
            config.updateSyncPreferences(
                conflictResolution: conflictResolution,
                syncDirection: syncDirection,
                autoSyncEnabled: autoSyncEnabled,
                syncFrequencyMinutes: syncFrequencyMinutes
            )
            
            try modelContext.save()
            
            syncHealthStatus = config.syncHealthStatus
            
            print("✅ SyncSettingsViewModel: Sync preferences updated")
            
        } catch {
            print("❌ SyncSettingsViewModel: Failed to update sync preferences: \(error)")
            lastError = error
        }
    }
    
    func resetSyncErrors() async {
        do {
            guard let config = syncConfiguration else {
                throw SyncSettingsError.configurationNotFound
            }
            
            config.resetSyncErrors()
            try modelContext.save()
            
            syncErrorCount = 0
            lastError = nil
            syncHealthStatus = config.syncHealthStatus
            
            print("✅ SyncSettingsViewModel: Sync errors reset")
            
        } catch {
            print("❌ SyncSettingsViewModel: Failed to reset sync errors: \(error)")
            lastError = error
        }
    }
    
    // MARK: - Troubleshooting Methods
    
    func validateSyncSetup() async {
        do {
            print("🔍 SyncSettingsViewModel: Validating sync setup")
            
            // Check EventKit availability
            try eventKitManager.validateEventKitAvailability()
            
            // Check if TribeBoard calendars exist
            let calendarsExist = try await eventKitManager.areTribeBoardCalendarsSetUp()
            
            if !calendarsExist && isAppleCalendarSyncEnabled {
                print("⚠️ SyncSettingsViewModel: TribeBoard calendars missing, recreating...")
                await recreateCalendars()
            }
            
            // Check sync configuration
            guard let config = syncConfiguration else {
                throw SyncSettingsError.configurationNotFound
            }
            
            if !config.isValid {
                throw SyncSettingsError.invalidConfiguration
            }
            
            // Update health status
            syncHealthStatus = config.syncHealthStatus
            
            print("✅ SyncSettingsViewModel: Sync setup validation completed")
            
        } catch {
            print("❌ SyncSettingsViewModel: Sync setup validation failed: \(error)")
            lastError = error
        }
    }
    
    func recreateCalendars() async {
        do {
            guard eventKitPermissionGranted else {
                throw SyncSettingsError.permissionRequired
            }
            
            print("🏗️ SyncSettingsViewModel: Recreating TribeBoard calendars")
            
            let calendars = try await eventKitManager.setupAllTribeBoardCalendars()
            
            // Update configuration with new calendar identifiers
            guard let config = syncConfiguration else {
                throw SyncSettingsError.configurationNotFound
            }
            
            config.enableAppleCalendarSync(
                calendarIdentifier: calendars.main.calendarIdentifier,
                familyCalendarIdentifier: calendars.family.calendarIdentifier,
                personalCalendarIdentifier: calendars.personal.calendarIdentifier
            )
            
            try modelContext.save()
            
            syncHealthStatus = config.syncHealthStatus
            
            print("✅ SyncSettingsViewModel: TribeBoard calendars recreated successfully")
            
        } catch {
            print("❌ SyncSettingsViewModel: Failed to recreate calendars: \(error)")
            lastError = error
        }
    }
    
    // MARK: - Helper Methods
    
    private func checkEventKitPermissionStatus() async {
        let authStatus = eventKitManager.authorizationStatus
        let hasAccess = authStatus == .fullAccess
        
        if eventKitPermissionGranted != hasAccess {
            eventKitPermissionGranted = hasAccess
            
            // Update configuration
            if let config = syncConfiguration {
                config.updateEventKitPermission(granted: hasAccess)
                try? modelContext.save()
                syncHealthStatus = config.syncHealthStatus
            }
        }
    }
    
    private func getSyncConfiguration() throws -> SyncConfiguration? {
        let descriptor = FetchDescriptor<SyncConfiguration>()
        let allConfigs = try modelContext.fetch(descriptor)
        
        return allConfigs.first { config in
            config.userId == userId
        }
    }
    
    private func getPendingOperationsCount() throws -> Int {
        let descriptor = FetchDescriptor<CalendarEvent>()
        let allEvents = try modelContext.fetch(descriptor)
        
        return allEvents.filter { event in
            event.needsEventKitSync && (event.createdBy == userId || event.privacyLevel == .familyShared)
        }.count
    }
    
    // MARK: - Computed Properties
    
    var syncStatusDescription: String {
        guard let config = syncConfiguration else {
            return "Not configured"
        }
        
        return config.syncStatusString
    }
    
    var syncFrequencyDescription: String {
        if syncFrequencyMinutes < 60 {
            return "\(syncFrequencyMinutes) minutes"
        } else {
            let hours = syncFrequencyMinutes / 60
            return hours == 1 ? "hour" : "\(hours) hours"
        }
    }
}

// MARK: - Sync Settings Errors

enum SyncSettingsError: LocalizedError {
    case configurationNotFound
    case syncNotConfigured
    case permissionRequired
    case invalidConfiguration
    
    var errorDescription: String? {
        switch self {
        case .configurationNotFound:
            return "Sync configuration not found"
        case .syncNotConfigured:
            return "Sync is not properly configured"
        case .permissionRequired:
            return "Calendar permission is required"
        case .invalidConfiguration:
            return "Sync configuration is invalid"
        }
    }
}