import Foundation
import SwiftData
import CloudKit

/// SwiftData model for managing Apple Calendar sync configuration
@Model
final class SyncConfiguration {
    // Primary identifier
    var id: UUID = UUID()
    
    // User identification
    var userId: UUID = UUID()
    
    // Apple Calendar sync settings
    var isAppleCalendarSyncEnabled: Bool = false
    var tribeBoardCalendarIdentifier: String?
    var tribeBoardFamilyCalendarIdentifier: String?
    var tribeBoardPersonalCalendarIdentifier: String?
    
    // Sync status and metadata
    var lastSyncDate: Date?
    var lastSuccessfulSyncDate: Date?
    var syncErrorCount: Int = 0
    var lastSyncError: String?
    
    // Sync preferences
    var syncConflictResolution: ConflictResolutionStrategy = ConflictResolutionStrategy.lastModifiedWins
    var syncDirection: SyncDirection = SyncDirection.bidirectional
    var autoSyncEnabled: Bool = true
    var syncFrequencyMinutes: Int = 15
    
    // EventKit permissions
    var eventKitPermissionGranted: Bool = false
    var eventKitPermissionRequestDate: Date?
    var eventKitPermissionDeniedDate: Date?
    
    // Sync queue management
    var pendingSyncOperationsCount: Int = 0
    var lastQueueProcessDate: Date?
    
    // CloudKit sync properties
    var ckRecordID: String?
    var lastCloudKitSyncDate: Date?
    var needsSync: Bool = true
    
    // Audit properties
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var version: Int = 1
    
    init(userId: UUID) {
        self.id = UUID()
        self.userId = userId
        self.isAppleCalendarSyncEnabled = false
        self.syncConflictResolution = .lastModifiedWins
        self.syncDirection = .bidirectional
        self.autoSyncEnabled = true
        self.syncFrequencyMinutes = 15
        self.eventKitPermissionGranted = false
        self.syncErrorCount = 0
        self.pendingSyncOperationsCount = 0
        self.createdAt = Date()
        self.updatedAt = Date()
        self.needsSync = true
        self.version = 1
    }
    
    // MARK: - Conflict Resolution Strategy
    
    enum ConflictResolutionStrategy: String, CaseIterable, Codable {
        case lastModifiedWins = "last_modified_wins"
        case tribeBoardWins = "tribeboard_wins"
        case appleCalendarWins = "apple_calendar_wins"
        case askUser = "ask_user"
        
        var displayName: String {
            switch self {
            case .lastModifiedWins:
                return "Last Modified Wins"
            case .tribeBoardWins:
                return "TribeBoard Wins"
            case .appleCalendarWins:
                return "Apple Calendar Wins"
            case .askUser:
                return "Ask User"
            }
        }
        
        var description: String {
            switch self {
            case .lastModifiedWins:
                return "The most recently modified version is kept"
            case .tribeBoardWins:
                return "TribeBoard version always takes priority"
            case .appleCalendarWins:
                return "Apple Calendar version always takes priority"
            case .askUser:
                return "Prompt user to choose which version to keep"
            }
        }
    }
    
    // MARK: - Sync Direction
    
    enum SyncDirection: String, CaseIterable, Codable {
        case bidirectional = "bidirectional"
        case tribeBoardToApple = "tribeboard_to_apple"
        case appleToTribeBoard = "apple_to_tribeboard"
        
        var displayName: String {
            switch self {
            case .bidirectional:
                return "Two-Way Sync"
            case .tribeBoardToApple:
                return "TribeBoard → Apple Calendar"
            case .appleToTribeBoard:
                return "Apple Calendar → TribeBoard"
            }
        }
        
        var description: String {
            switch self {
            case .bidirectional:
                return "Changes sync in both directions"
            case .tribeBoardToApple:
                return "Only sync TribeBoard events to Apple Calendar"
            case .appleToTribeBoard:
                return "Only sync Apple Calendar events to TribeBoard"
            }
        }
    }
    
    // MARK: - Validation
    
    /// Validates the sync configuration
    var isValid: Bool {
        !userId.uuidString.isEmpty &&
        syncFrequencyMinutes > 0 &&
        syncFrequencyMinutes <= 1440 // Max 24 hours
    }
    
    /// Checks if sync is properly configured
    var isSyncConfigured: Bool {
        isAppleCalendarSyncEnabled &&
        eventKitPermissionGranted &&
        tribeBoardCalendarIdentifier != nil
    }
    
    /// Checks if sync is currently healthy
    var isSyncHealthy: Bool {
        isSyncConfigured &&
        syncErrorCount < 5 &&
        (lastSyncError == nil || lastSuccessfulSyncDate ?? Date.distantPast > lastSyncDate ?? Date.distantPast)
    }
    
    /// Returns the time since last successful sync
    var timeSinceLastSync: TimeInterval? {
        guard let lastSync = lastSuccessfulSyncDate else { return nil }
        return Date().timeIntervalSince(lastSync)
    }
    
    /// Checks if sync is overdue based on frequency setting
    var isSyncOverdue: Bool {
        guard autoSyncEnabled, let lastSync = lastSuccessfulSyncDate else { return false }
        let syncInterval = TimeInterval(syncFrequencyMinutes * 60)
        return Date().timeIntervalSince(lastSync) > syncInterval
    }
    
    // MARK: - Configuration Management
    
    /// Enables Apple Calendar sync with the specified calendar identifier
    func enableAppleCalendarSync(
        calendarIdentifier: String,
        familyCalendarIdentifier: String? = nil,
        personalCalendarIdentifier: String? = nil
    ) {
        self.isAppleCalendarSyncEnabled = true
        self.tribeBoardCalendarIdentifier = calendarIdentifier
        self.tribeBoardFamilyCalendarIdentifier = familyCalendarIdentifier
        self.tribeBoardPersonalCalendarIdentifier = personalCalendarIdentifier
        self.updatedAt = Date()
        self.version += 1
        self.needsSync = true
        
        // Reset error count when enabling
        self.syncErrorCount = 0
        self.lastSyncError = nil
    }
    
    /// Disables Apple Calendar sync
    func disableAppleCalendarSync() {
        self.isAppleCalendarSyncEnabled = false
        self.updatedAt = Date()
        self.version += 1
        self.needsSync = true
    }
    
    /// Updates EventKit permission status
    func updateEventKitPermission(granted: Bool) {
        self.eventKitPermissionGranted = granted
        self.eventKitPermissionRequestDate = Date()
        
        if !granted {
            self.eventKitPermissionDeniedDate = Date()
            // Disable sync if permission is denied
            self.isAppleCalendarSyncEnabled = false
        }
        
        self.updatedAt = Date()
        self.version += 1
        self.needsSync = true
    }
    
    /// Updates sync preferences
    func updateSyncPreferences(
        conflictResolution: ConflictResolutionStrategy? = nil,
        syncDirection: SyncDirection? = nil,
        autoSyncEnabled: Bool? = nil,
        syncFrequencyMinutes: Int? = nil
    ) {
        if let conflictResolution = conflictResolution {
            self.syncConflictResolution = conflictResolution
        }
        
        if let syncDirection = syncDirection {
            self.syncDirection = syncDirection
        }
        
        if let autoSyncEnabled = autoSyncEnabled {
            self.autoSyncEnabled = autoSyncEnabled
        }
        
        if let syncFrequencyMinutes = syncFrequencyMinutes,
           syncFrequencyMinutes > 0 && syncFrequencyMinutes <= 1440 {
            self.syncFrequencyMinutes = syncFrequencyMinutes
        }
        
        self.updatedAt = Date()
        self.version += 1
        self.needsSync = true
    }
    
    // MARK: - Sync Status Management
    
    /// Records a successful sync operation
    func recordSuccessfulSync() {
        self.lastSyncDate = Date()
        self.lastSuccessfulSyncDate = Date()
        self.syncErrorCount = 0
        self.lastSyncError = nil
        self.updatedAt = Date()
        self.needsSync = true
    }
    
    /// Records a failed sync operation
    func recordSyncError(_ error: String) {
        self.lastSyncDate = Date()
        self.syncErrorCount += 1
        self.lastSyncError = error
        self.updatedAt = Date()
        self.needsSync = true
        
        // Disable auto-sync if too many consecutive errors
        if syncErrorCount >= 10 {
            self.autoSyncEnabled = false
        }
    }
    
    /// Resets sync error state
    func resetSyncErrors() {
        self.syncErrorCount = 0
        self.lastSyncError = nil
        self.updatedAt = Date()
        self.needsSync = true
    }
    
    /// Updates pending sync operations count
    func updatePendingSyncOperations(count: Int) {
        self.pendingSyncOperationsCount = max(0, count)
        self.lastQueueProcessDate = Date()
        self.updatedAt = Date()
        self.needsSync = true
    }
    
    /// Marks the configuration as synced with CloudKit
    func markAsSynced(recordID: String) {
        self.ckRecordID = recordID
        self.lastCloudKitSyncDate = Date()
        self.needsSync = false
    }
    
    // MARK: - Computed Properties
    
    /// Returns a formatted string for the last sync time
    var lastSyncTimeString: String {
        guard let lastSync = lastSuccessfulSyncDate else {
            return "Never"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastSync, relativeTo: Date())
    }
    
    /// Returns the sync status as a user-friendly string
    var syncStatusString: String {
        if !isAppleCalendarSyncEnabled {
            return "Disabled"
        } else if !eventKitPermissionGranted {
            return "Permission Required"
        } else if !isSyncConfigured {
            return "Not Configured"
        } else if syncErrorCount > 0 {
            return "Error (\(syncErrorCount) failures)"
        } else if pendingSyncOperationsCount > 0 {
            return "Syncing (\(pendingSyncOperationsCount) pending)"
        } else if isSyncOverdue {
            return "Overdue"
        } else {
            return "Active"
        }
    }
    
    /// Returns the sync health status
    var syncHealthStatus: SyncHealthStatus {
        if !isAppleCalendarSyncEnabled {
            return .disabled
        } else if !eventKitPermissionGranted {
            return .permissionRequired
        } else if !isSyncConfigured {
            return .notConfigured
        } else if syncErrorCount >= 5 {
            return .error
        } else if syncErrorCount > 0 {
            return .warning
        } else {
            return .healthy
        }
    }
    
    enum SyncHealthStatus {
        case healthy
        case warning
        case error
        case disabled
        case permissionRequired
        case notConfigured
        
        var color: String {
            switch self {
            case .healthy:
                return "green"
            case .warning:
                return "orange"
            case .error:
                return "red"
            case .disabled:
                return "gray"
            case .permissionRequired:
                return "blue"
            case .notConfigured:
                return "yellow"
            }
        }
        
        var icon: String {
            switch self {
            case .healthy:
                return "checkmark.circle.fill"
            case .warning:
                return "exclamationmark.triangle.fill"
            case .error:
                return "xmark.circle.fill"
            case .disabled:
                return "pause.circle.fill"
            case .permissionRequired:
                return "lock.circle.fill"
            case .notConfigured:
                return "gear.circle.fill"
            }
        }
    }
}

// MARK: - CloudKit Synchronization
extension SyncConfiguration: CloudKitSyncable {
    static var recordType: String { "SyncConfiguration" }
    
    func toCKRecord() throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)
        
        // User identification
        record["userId"] = userId.uuidString
        
        // Sync settings
        record["isAppleCalendarSyncEnabled"] = isAppleCalendarSyncEnabled ? 1 : 0
        record["tribeBoardCalendarIdentifier"] = tribeBoardCalendarIdentifier
        record["tribeBoardFamilyCalendarIdentifier"] = tribeBoardFamilyCalendarIdentifier
        record["tribeBoardPersonalCalendarIdentifier"] = tribeBoardPersonalCalendarIdentifier
        
        // Sync status
        record["lastSyncDate"] = lastSyncDate
        record["lastSuccessfulSyncDate"] = lastSuccessfulSyncDate
        record["syncErrorCount"] = syncErrorCount
        record["lastSyncError"] = lastSyncError
        
        // Preferences
        record["syncConflictResolution"] = syncConflictResolution.rawValue
        record["syncDirection"] = syncDirection.rawValue
        record["autoSyncEnabled"] = autoSyncEnabled ? 1 : 0
        record["syncFrequencyMinutes"] = syncFrequencyMinutes
        
        // Permissions
        record["eventKitPermissionGranted"] = eventKitPermissionGranted ? 1 : 0
        record["eventKitPermissionRequestDate"] = eventKitPermissionRequestDate
        record["eventKitPermissionDeniedDate"] = eventKitPermissionDeniedDate
        
        // Queue management
        record["pendingSyncOperationsCount"] = pendingSyncOperationsCount
        record["lastQueueProcessDate"] = lastQueueProcessDate
        
        // Metadata
        record["createdAt"] = createdAt
        record["updatedAt"] = updatedAt
        record["version"] = version
        
        return record
    }
    
    func updateFromCKRecord(_ record: CKRecord) throws {
        guard let userIdString = record["userId"] as? String,
              let userId = UUID(uuidString: userIdString),
              let isAppleCalendarSyncEnabledInt = record["isAppleCalendarSyncEnabled"] as? Int,
              let syncErrorCount = record["syncErrorCount"] as? Int,
              let conflictResolutionString = record["syncConflictResolution"] as? String,
              let conflictResolution = ConflictResolutionStrategy(rawValue: conflictResolutionString),
              let syncDirectionString = record["syncDirection"] as? String,
              let syncDirection = SyncDirection(rawValue: syncDirectionString),
              let autoSyncEnabledInt = record["autoSyncEnabled"] as? Int,
              let syncFrequencyMinutes = record["syncFrequencyMinutes"] as? Int,
              let eventKitPermissionGrantedInt = record["eventKitPermissionGranted"] as? Int,
              let pendingSyncOperationsCount = record["pendingSyncOperationsCount"] as? Int,
              let createdAt = record["createdAt"] as? Date,
              let updatedAt = record["updatedAt"] as? Date,
              let version = record["version"] as? Int else {
            throw CloudKitSyncError.invalidRecord
        }
        
        self.userId = userId
        self.isAppleCalendarSyncEnabled = isAppleCalendarSyncEnabledInt == 1
        self.syncErrorCount = syncErrorCount
        self.syncConflictResolution = conflictResolution
        self.syncDirection = syncDirection
        self.autoSyncEnabled = autoSyncEnabledInt == 1
        self.syncFrequencyMinutes = syncFrequencyMinutes
        self.eventKitPermissionGranted = eventKitPermissionGrantedInt == 1
        self.pendingSyncOperationsCount = pendingSyncOperationsCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.version = version
        
        // Optional properties
        self.tribeBoardCalendarIdentifier = record["tribeBoardCalendarIdentifier"] as? String
        self.tribeBoardFamilyCalendarIdentifier = record["tribeBoardFamilyCalendarIdentifier"] as? String
        self.tribeBoardPersonalCalendarIdentifier = record["tribeBoardPersonalCalendarIdentifier"] as? String
        self.lastSyncDate = record["lastSyncDate"] as? Date
        self.lastSuccessfulSyncDate = record["lastSuccessfulSyncDate"] as? Date
        self.lastSyncError = record["lastSyncError"] as? String
        self.eventKitPermissionRequestDate = record["eventKitPermissionRequestDate"] as? Date
        self.eventKitPermissionDeniedDate = record["eventKitPermissionDeniedDate"] as? Date
        self.lastQueueProcessDate = record["lastQueueProcessDate"] as? Date
        
        self.ckRecordID = record.recordID.recordName
        self.lastCloudKitSyncDate = Date()
        self.needsSync = false
    }
}

// MARK: - Hashable and Equatable
extension SyncConfiguration: Hashable {
    static func == (lhs: SyncConfiguration, rhs: SyncConfiguration) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}