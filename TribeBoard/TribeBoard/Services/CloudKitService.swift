import Foundation
import CloudKit
import SwiftData

/// Errors that can occur during CloudKit operations
enum CloudKitError: LocalizedError {
    case containerNotFound
    case networkUnavailable
    case quotaExceeded
    case recordNotFound
    case conflictResolution
    case invalidRecord
    case syncFailed(Error)
    case retryLimitExceeded
    case zoneCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .containerNotFound:
            return "CloudKit container not found"
        case .networkUnavailable:
            return "Network unavailable"
        case .quotaExceeded:
            return "CloudKit quota exceeded"
        case .recordNotFound:
            return "Record not found"
        case .conflictResolution:
            return "Conflict resolution failed"
        case .invalidRecord:
            return "Invalid record format"
        case .syncFailed(let error):
            return "Sync failed: \(error.localizedDescription)"
        case .retryLimitExceeded:
            return "Maximum retry attempts exceeded"
        case .zoneCreationFailed:
            return "Failed to create custom zone"
        }
    }
}

/// Service for managing CloudKit operations with retry logic and conflict resolution
@MainActor
class CloudKitService: ObservableObject {
    
    // MARK: - Properties
    
    private let container: CKContainer
    internal let privateDatabase: CKDatabase
    private let customZone: CKRecordZone
    
    /// Maximum number of retry attempts for failed operations
    private let maxRetryAttempts = 3
    
    /// Base delay for exponential backoff (in seconds)
    private let baseRetryDelay: TimeInterval = 1.0
    
    /// Subscription IDs for tracking active subscriptions
    private let familySubscriptionID = "family-changes"
    private let membershipSubscriptionID = "membership-changes"
    private let userProfileSubscriptionID = "userprofile-changes"
    
    // MARK: - Initialization
    
    init(containerIdentifier: String = "iCloud.net.dataenvy.TribeBoard") {
        self.container = CKContainer(identifier: containerIdentifier)
        self.privateDatabase = container.privateCloudDatabase
        
        // Create custom zone for better organization
        self.customZone = CKRecordZone(zoneName: "TribeBoardZone")
    }
    
    // MARK: - Setup and Configuration
    
    /// Performs initial CloudKit setup including zone creation and subscriptions
    func performInitialSetup() async throws {
        // Verify CloudKit availability
        guard try await verifyCloudKitAvailability() else {
            throw CloudKitError.containerNotFound
        }
        
        // Set up custom zone
        try await setupCustomZone()
        
        // Set up subscriptions for real-time updates
        try await setupSubscriptions()
    }
    
    // MARK: - Zone Management
    
    /// Sets up the custom CloudKit zone
    func setupCustomZone() async throws {
        do {
            // Check if zone already exists
            let zones = try await privateDatabase.allRecordZones()
            if zones.contains(where: { $0.zoneID == customZone.zoneID }) {
                return // Zone already exists
            }
            
            // Create the custom zone
            _ = try await privateDatabase.save(customZone)
        } catch {
            throw CloudKitError.zoneCreationFailed
        }
    }
    
    // MARK: - Subscription Management
    
    /// Sets up CloudKit subscriptions for real-time updates
    func setupSubscriptions() async throws {
        try await setupFamilySubscription()
        try await setupMembershipSubscription()
        try await setupUserProfileSubscription()
    }
    
    /// Creates subscription for Family record changes
    private func setupFamilySubscription() async throws {
        // Check if subscription already exists
        let existingSubscriptions = try await privateDatabase.allSubscriptions()
        if existingSubscriptions.contains(where: { $0.subscriptionID == familySubscriptionID }) {
            return // Subscription already exists
        }
        
        // Create subscription for Family records in custom zone
        let subscription = CKQuerySubscription(
            recordType: CKRecordType.family,
            predicate: NSPredicate(value: true),
            subscriptionID: familySubscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        subscription.zoneID = customZone.zoneID
        
        // Configure notification info
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        notificationInfo.shouldBadge = false
        subscription.notificationInfo = notificationInfo
        
        _ = try await privateDatabase.save(subscription)
    }
    
    /// Creates subscription for Membership record changes
    private func setupMembershipSubscription() async throws {
        // Check if subscription already exists
        let existingSubscriptions = try await privateDatabase.allSubscriptions()
        if existingSubscriptions.contains(where: { $0.subscriptionID == membershipSubscriptionID }) {
            return // Subscription already exists
        }
        
        // Create subscription for Membership records in custom zone
        let subscription = CKQuerySubscription(
            recordType: CKRecordType.membership,
            predicate: NSPredicate(value: true),
            subscriptionID: membershipSubscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        subscription.zoneID = customZone.zoneID
        
        // Configure notification info
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        notificationInfo.shouldBadge = false
        subscription.notificationInfo = notificationInfo
        
        _ = try await privateDatabase.save(subscription)
    }
    
    /// Creates subscription for UserProfile record changes
    private func setupUserProfileSubscription() async throws {
        // Check if subscription already exists
        let existingSubscriptions = try await privateDatabase.allSubscriptions()
        if existingSubscriptions.contains(where: { $0.subscriptionID == userProfileSubscriptionID }) {
            return // Subscription already exists
        }
        
        // Create subscription for UserProfile records in custom zone
        let subscription = CKQuerySubscription(
            recordType: CKRecordType.userProfile,
            predicate: NSPredicate(value: true),
            subscriptionID: userProfileSubscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        subscription.zoneID = customZone.zoneID
        
        // Configure notification info
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        notificationInfo.shouldBadge = false
        subscription.notificationInfo = notificationInfo
        
        _ = try await privateDatabase.save(subscription)
    }
    
    /// Removes all subscriptions (useful for cleanup or reset)
    func removeAllSubscriptions() async throws {
        let subscriptions = try await privateDatabase.allSubscriptions()
        let subscriptionIDs = subscriptions.map { $0.subscriptionID }
        
        if !subscriptionIDs.isEmpty {
            _ = try await privateDatabase.modifySubscriptions(saving: [], deleting: subscriptionIDs)
        }
    }
    
    /// Handles CloudKit remote notifications
    func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) async {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) else {
            return
        }
        
        switch notification.notificationType {
        case .query:
            if let queryNotification = notification as? CKQueryNotification {
                await handleQueryNotification(queryNotification)
            }
        case .database:
            if let databaseNotification = notification as? CKDatabaseNotification {
                await handleDatabaseNotification(databaseNotification)
            }
        default:
            break
        }
    }
    
    /// Handles query notifications for record changes
    private func handleQueryNotification(_ notification: CKQueryNotification) async {
        guard let recordID = notification.recordID else { return }
        
        switch notification.subscriptionID {
        case familySubscriptionID:
            await handleFamilyRecordChange(recordID: recordID, reason: notification.queryNotificationReason)
        case membershipSubscriptionID:
            await handleMembershipRecordChange(recordID: recordID, reason: notification.queryNotificationReason)
        case userProfileSubscriptionID:
            await handleUserProfileRecordChange(recordID: recordID, reason: notification.queryNotificationReason)
        default:
            break
        }
    }
    
    /// Handles database notifications
    private func handleDatabaseNotification(_ notification: CKDatabaseNotification) async {
        // Handle database-level changes if needed
        // This could trigger a full sync or other database-wide operations
    }
    
    /// Handles Family record changes from notifications
    private func handleFamilyRecordChange(recordID: CKRecord.ID, reason: CKQueryNotification.Reason) async {
        switch reason {
        case .recordCreated, .recordUpdated:
            // Fetch the updated record and sync to local storage
            do {
                if let record = try await fetchRecord(withID: recordID.recordName, recordType: CKRecordType.family) {
                    // Notify observers about the change
                    NotificationCenter.default.post(
                        name: .familyRecordChanged,
                        object: nil,
                        userInfo: ["record": record, "reason": reason.rawValue]
                    )
                }
            } catch {
                print("Failed to fetch updated family record: \(error)")
            }
        case .recordDeleted:
            // Handle family deletion
            NotificationCenter.default.post(
                name: .familyRecordDeleted,
                object: nil,
                userInfo: ["recordID": recordID.recordName]
            )
        @unknown default:
            break
        }
    }
    
    /// Handles Membership record changes from notifications
    private func handleMembershipRecordChange(recordID: CKRecord.ID, reason: CKQueryNotification.Reason) async {
        switch reason {
        case .recordCreated, .recordUpdated:
            do {
                if let record = try await fetchRecord(withID: recordID.recordName, recordType: CKRecordType.membership) {
                    NotificationCenter.default.post(
                        name: .membershipRecordChanged,
                        object: nil,
                        userInfo: ["record": record, "reason": reason.rawValue]
                    )
                }
            } catch {
                print("Failed to fetch updated membership record: \(error)")
            }
        case .recordDeleted:
            NotificationCenter.default.post(
                name: .membershipRecordDeleted,
                object: nil,
                userInfo: ["recordID": recordID.recordName]
            )
        @unknown default:
            break
        }
    }
    
    /// Handles UserProfile record changes from notifications
    private func handleUserProfileRecordChange(recordID: CKRecord.ID, reason: CKQueryNotification.Reason) async {
        switch reason {
        case .recordCreated, .recordUpdated:
            do {
                if let record = try await fetchRecord(withID: recordID.recordName, recordType: CKRecordType.userProfile) {
                    NotificationCenter.default.post(
                        name: .userProfileRecordChanged,
                        object: nil,
                        userInfo: ["record": record, "reason": reason.rawValue]
                    )
                }
            } catch {
                print("Failed to fetch updated user profile record: \(error)")
            }
        case .recordDeleted:
            NotificationCenter.default.post(
                name: .userProfileRecordDeleted,
                object: nil,
                userInfo: ["recordID": recordID.recordName]
            )
        @unknown default:
            break
        }
    }
    
    // MARK: - CRUD Operations
    
    /// Saves a CloudKit syncable record with retry logic
    func save<T: CloudKitSyncable>(_ record: T) async throws {
        try await withRetry(maxAttempts: maxRetryAttempts) { [self] in
            var ckRecord = try record.toCKRecord()
            // Create record with custom zone
            let recordID = CKRecord.ID(recordName: record.id.uuidString, zoneID: customZone.zoneID)
            ckRecord = CKRecord(recordType: ckRecord.recordType, recordID: recordID)
            
            // Copy fields from original record
            let originalRecord = try record.toCKRecord()
            for key in originalRecord.allKeys() {
                ckRecord[key] = originalRecord[key]
            }
            
            _ = try await privateDatabase.save(ckRecord)
            
            // Note: The local record sync status should be updated by the caller
            // since we can't mutate the input parameter here
        }
    }
    
    /// Saves multiple records in a batch operation
    func saveRecords<T: CloudKitSyncable>(_ records: [T]) async throws {
        guard !records.isEmpty else { return }
        
        try await withRetry(maxAttempts: maxRetryAttempts) { [self] in
            let ckRecords = try records.map { record in
                let originalRecord = try record.toCKRecord()
                let recordID = CKRecord.ID(recordName: record.id.uuidString, zoneID: customZone.zoneID)
                let ckRecord = CKRecord(recordType: originalRecord.recordType, recordID: recordID)
                
                // Copy fields from original record
                for key in originalRecord.allKeys() {
                    ckRecord[key] = originalRecord[key]
                }
                
                return ckRecord
            }
            
            let operation = CKModifyRecordsOperation(recordsToSave: ckRecords)
            operation.savePolicy = .changedKeys
            operation.qualityOfService = .userInitiated
            
            try await withCheckedThrowingContinuation { continuation in
                operation.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                privateDatabase.add(operation)
            }
        }
    }
    
    /// Fetches records by type with predicate
    func fetch<T: CloudKitSyncable>(_ type: T.Type, predicate: NSPredicate? = nil) async throws -> [CKRecord] {
        return try await withRetry(maxAttempts: maxRetryAttempts) { [self] in
            let query = CKQuery(recordType: type.recordType, predicate: predicate ?? NSPredicate(value: true))
            query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            
            let (matchResults, _) = try await privateDatabase.records(matching: query, inZoneWith: customZone.zoneID)
            
            var records: [CKRecord] = []
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    records.append(record)
                case .failure(let error):
                    print("Failed to fetch record: \(error)")
                }
            }
            
            return records
        }
    }
    
    /// Fetches a single record by ID
    func fetchRecord(withID recordID: String, recordType: String) async throws -> CKRecord? {
        return try await withRetry(maxAttempts: maxRetryAttempts) { [self] in
            let ckRecordID = CKRecord.ID(recordName: recordID, zoneID: customZone.zoneID)
            
            do {
                return try await privateDatabase.record(for: ckRecordID)
            } catch let error as CKError where error.code == .unknownItem {
                return nil
            }
        }
    }
    
    /// Deletes a record by ID
    func deleteRecord(withID recordID: String) async throws {
        try await withRetry(maxAttempts: maxRetryAttempts) { [self] in
            let ckRecordID = CKRecord.ID(recordName: recordID, zoneID: customZone.zoneID)
            _ = try await privateDatabase.deleteRecord(withID: ckRecordID)
        }
    }
    
    // MARK: - Family Operations
    
    /// Fetches a family by code
    func fetchFamily(byCode code: String) async throws -> CKRecord? {
        let predicate = NSPredicate(format: "%K == %@", CKFieldName.familyCode, code)
        let records = try await fetch(Family.self, predicate: predicate)
        return records.first
    }
    
    /// Fetches families created by a specific user
    func fetchFamilies(createdByUserId: String) async throws -> [CKRecord] {
        let predicate = NSPredicate(format: "%K == %@", CKFieldName.familyCreatedByUserId, createdByUserId)
        return try await fetch(Family.self, predicate: predicate)
    }
    
    // MARK: - UserProfile Operations
    
    /// Fetches a user profile by Apple ID hash
    func fetchUserProfile(byAppleUserIdHash hash: String) async throws -> CKRecord? {
        let predicate = NSPredicate(format: "%K == %@", CKFieldName.userAppleUserIdHash, hash)
        let records = try await fetch(UserProfile.self, predicate: predicate)
        return records.first
    }
    
    // MARK: - Membership Operations
    
    /// Fetches memberships for a family
    func fetchMemberships(forFamilyId familyId: String) async throws -> [CKRecord] {
        let familyReference = CKRecord.Reference(
            recordID: CKRecord.ID(recordName: familyId, zoneID: customZone.zoneID),
            action: .none
        )
        let predicate = NSPredicate(format: "%K == %@", CKFieldName.membershipFamilyReference, familyReference)
        return try await fetch(Membership.self, predicate: predicate)
    }
    
    /// Fetches memberships for a user
    func fetchMemberships(forUserId userId: String) async throws -> [CKRecord] {
        let userReference = CKRecord.Reference(
            recordID: CKRecord.ID(recordName: userId, zoneID: customZone.zoneID),
            action: .none
        )
        let predicate = NSPredicate(format: "%K == %@", CKFieldName.membershipUserReference, userReference)
        return try await fetch(Membership.self, predicate: predicate)
    }
    
    /// Fetches active memberships for a family
    func fetchActiveMemberships(forFamilyId familyId: String) async throws -> [CKRecord] {
        let familyReference = CKRecord.Reference(
            recordID: CKRecord.ID(recordName: familyId, zoneID: customZone.zoneID),
            action: .none
        )
        let predicate = NSPredicate(format: "%K == %@ AND %K == %@", 
                                   CKFieldName.membershipFamilyReference, familyReference,
                                   CKFieldName.membershipStatus, MembershipStatus.active.rawValue)
        return try await fetch(Membership.self, predicate: predicate)
    }
    
    // MARK: - Conflict Resolution
    
    /// Resolves conflicts using last-write-wins strategy
    func resolveConflict<T: CloudKitSyncable>(localRecord: T, serverRecord: CKRecord) async throws -> T {
        // Get modification dates
        let localModificationDate = localRecord.lastSyncDate ?? Date.distantPast
        let serverModificationDate = serverRecord.modificationDate ?? Date.distantPast
        
        // Use last-write-wins strategy
        if serverModificationDate > localModificationDate {
            // Server record is newer, update local record
            let updatedRecord = localRecord
            try updatedRecord.updateFromCKRecord(serverRecord)
            return updatedRecord
        } else {
            // Local record is newer or same, keep local changes
            return localRecord
        }
    }
    
    // MARK: - Sync Operations
    
    /// Syncs all pending records to CloudKit
    func syncPendingRecords(from dataService: DataService) async throws {
        // Sync families
        let pendingFamilies = try dataService.fetchRecordsNeedingSync(Family.self)
        for family in pendingFamilies {
            try await save(family)
        }
        
        // Sync user profiles
        let pendingUsers = try dataService.fetchRecordsNeedingSync(UserProfile.self)
        for user in pendingUsers {
            try await save(user)
        }
        
        // Sync memberships
        let pendingMemberships = try dataService.fetchRecordsNeedingSync(Membership.self)
        for membership in pendingMemberships {
            try await save(membership)
        }
    }
    
    /// Performs a full sync from CloudKit to local storage
    func performFullSync(with dataService: DataService) async throws {
        // Fetch all families
        let familyRecords = try await fetch(Family.self)
        for record in familyRecords {
            // Check if local record exists
            if let localFamily = try dataService.fetchFamily(byId: UUID(uuidString: record.recordID.recordName)!) {
                // Resolve conflicts if needed
                let resolvedFamily = try await resolveConflict(localRecord: localFamily, serverRecord: record)
                // Update local record if changed
                if resolvedFamily.lastSyncDate != localFamily.lastSyncDate {
                    try dataService.save()
                }
            } else {
                // Create new local record from CloudKit
                let newFamily = Family(name: "", code: "", createdByUserId: UUID())
                try newFamily.updateFromCKRecord(record)
                // Insert into local storage through dataService
                // Note: This would need to be handled by the calling code since DataService doesn't have a direct insert method
            }
        }
        
        // Similar process for UserProfiles and Memberships...
    }
    
    // MARK: - Retry Logic
    
    /// Executes an operation with exponential backoff retry logic
    private func withRetry<T>(maxAttempts: Int, operation: @escaping () async throws -> T) async throws -> T {
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch let error as CKError {
                // Check if error is retryable
                if !isRetryableError(error) {
                    throw CloudKitError.syncFailed(error)
                }
                
                // Don't retry on the last attempt
                if attempt == maxAttempts {
                    throw CloudKitError.retryLimitExceeded
                }
                
                // Calculate delay with exponential backoff
                let delay = baseRetryDelay * pow(2.0, Double(attempt - 1))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
            } catch {
                throw CloudKitError.syncFailed(error)
            }
        }
        
        throw CloudKitError.retryLimitExceeded
    }
    
    /// Determines if a CloudKit error is retryable
    private func isRetryableError(_ error: CKError) -> Bool {
        switch error.code {
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy:
            return true
        case .quotaExceeded:
            return false
        case .unknownItem:
            return false
        default:
            return false
        }
    }
    
    // MARK: - Account Status
    
    /// Checks CloudKit account status
    func checkAccountStatus() async throws -> CKAccountStatus {
        return try await container.accountStatus()
    }
    
    /// Verifies CloudKit availability
    func verifyCloudKitAvailability() async throws -> Bool {
        let status = try await checkAccountStatus()
        return status == .available
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let familyRecordChanged = Notification.Name("familyRecordChanged")
    static let familyRecordDeleted = Notification.Name("familyRecordDeleted")
    static let membershipRecordChanged = Notification.Name("membershipRecordChanged")
    static let membershipRecordDeleted = Notification.Name("membershipRecordDeleted")
    static let userProfileRecordChanged = Notification.Name("userProfileRecordChanged")
    static let userProfileRecordDeleted = Notification.Name("userProfileRecordDeleted")
}

