import Foundation
import CloudKit
import SwiftData
import Network

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
    
    /// Network path monitor for connectivity detection
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    
    /// Current network connectivity status
    @Published private(set) var isNetworkAvailable = true
    
    /// Current CloudKit availability status
    @Published private(set) var isCloudKitAvailable = true
    
    /// Offline mode flag
    @Published private(set) var isOfflineMode = false
    
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
        
        // Start network monitoring
        startNetworkMonitoring()
    }
    
    deinit {
        networkMonitor.cancel()
    }
    
    // MARK: - Network and Connectivity Management
    
    /// Starts network monitoring for connectivity detection
    private func startNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isNetworkAvailable = path.status == .satisfied
                self?.updateOfflineMode()
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    /// Updates offline mode based on network and CloudKit availability
    private func updateOfflineMode() {
        isOfflineMode = !isNetworkAvailable || !isCloudKitAvailable
    }
    
    /// Checks current network connectivity
    func checkNetworkConnectivity() -> Bool {
        return isNetworkAvailable
    }
    
    /// Checks CloudKit availability with enhanced error handling
    func checkCloudKitAvailability() async -> Bool {
        do {
            let status = try await checkAccountStatus()
            let available = status == .available
            
            await MainActor.run {
                isCloudKitAvailable = available
                updateOfflineMode()
            }
            
            return available
        } catch {
            await MainActor.run {
                isCloudKitAvailable = false
                updateOfflineMode()
            }
            return false
        }
    }
    
    // MARK: - Setup and Configuration
    
    /// Performs initial CloudKit setup including zone creation and subscriptions
    func performInitialSetup() async throws {
        // Check network connectivity first
        guard isNetworkAvailable else {
            throw CloudKitError.networkUnavailable
        }
        
        // Verify CloudKit availability
        guard await checkCloudKitAvailability() else {
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
    
    /// Saves a CloudKit syncable record with enhanced retry logic and fallback
    func save<T: CloudKitSyncable>(_ record: T) async throws {
        // Check if we should fall back to local-only mode
        if shouldFallbackToLocal() {
            markRecordForLaterSync(record)
            handleCloudKitUnavailable(operation: "save")
            throw CloudKitError.networkUnavailable
        }
        
        try await withEnhancedRetry(maxAttempts: maxRetryAttempts, operation: "save") { [self] in
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
    
    /// Fetches records by type with predicate using enhanced retry logic
    func fetch<T: CloudKitSyncable>(_ type: T.Type, predicate: NSPredicate? = nil) async throws -> [CKRecord] {
        // Check if we should fall back to local-only mode
        if shouldFallbackToLocal() {
            handleCloudKitUnavailable(operation: "fetch")
            throw CloudKitError.networkUnavailable
        }
        
        return try await withEnhancedRetry(maxAttempts: maxRetryAttempts, operation: "fetch") { [self] in
            let safePredicate = predicate ?? NSPredicate(value: true)
            
            // Validate predicate before use
            guard validatePredicate(safePredicate) else {
                throw CloudKitError.invalidRecord
            }
            
            let query = CKQuery(recordType: type.recordType, predicate: safePredicate)
            query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            
            let (matchResults, _) = try await privateDatabase.records(matching: query, inZoneWith: customZone.zoneID)
            
            var records: [CKRecord] = []
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    records.append(record)
                case .failure(let error):
                    print("⚠️ CloudKitService: Failed to fetch individual record: \(error)")
                    // Continue processing other records instead of failing completely
                }
            }
            
            return records
        }
    }
    
    /// Fetches a single record by ID with enhanced error handling
    func fetchRecord(withID recordID: String, recordType: String) async throws -> CKRecord? {
        // Check if we should fall back to local-only mode
        if shouldFallbackToLocal() {
            handleCloudKitUnavailable(operation: "fetchRecord")
            throw CloudKitError.networkUnavailable
        }
        
        return try await withEnhancedRetry(maxAttempts: maxRetryAttempts, operation: "fetchRecord") { [self] in
            let ckRecordID = CKRecord.ID(recordName: recordID, zoneID: customZone.zoneID)
            
            do {
                return try await privateDatabase.record(for: ckRecordID)
            } catch let error as CKError where error.code == .unknownItem {
                return nil // Record not found is not an error
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
    
    /// Fetches a family by code with enhanced safety and fallback mechanisms
    func fetchFamily(byCode code: String) async throws -> CKRecord? {
        return try await fetchFamilyWithFallback(byCode: code)
    }
    
    /// Enhanced family fetching with comprehensive error handling and fallback
    func fetchFamilyWithFallback(byCode code: String) async throws -> CKRecord? {
        // Input validation
        guard !code.isEmpty else {
            throw CloudKitError.invalidRecord
        }
        
        // Check if we're in offline mode
        if isOfflineMode {
            print("⚠️ CloudKitService: Operating in offline mode, cannot fetch family by code")
            throw CloudKitError.networkUnavailable
        }
        
        // Check CloudKit availability before attempting operation
        guard await checkCloudKitAvailability() else {
            print("⚠️ CloudKitService: CloudKit unavailable, cannot fetch family")
            throw CloudKitError.containerNotFound
        }
        
        return try await withEnhancedRetry(maxAttempts: maxRetryAttempts, operation: "fetchFamily") { [self] in
            try await performSafeFamilyFetch(byCode: code)
        }
    }
    
    /// Performs safe family fetch with enhanced predicate handling
    private func performSafeFamilyFetch(byCode code: String) async throws -> CKRecord? {
        do {
            // Create safer predicate with explicit field validation
            guard let familyCodeField = CKFieldName.familyCode as String? else {
                throw CloudKitError.invalidRecord
            }
            
            // Use safer predicate construction
            let predicate = NSPredicate(format: "%K == %@", familyCodeField, code as NSString)
            
            // Validate predicate before use
            guard validatePredicate(predicate) else {
                throw CloudKitError.invalidRecord
            }
            
            let records = try await fetchWithSafePredicate(Family.self, predicate: predicate)
            
            // Validate results
            if records.count > 1 {
                print("⚠️ CloudKitService: Multiple families found with same code: \(code)")
                // Return the most recently modified one
                return records.max { record1, record2 in
                    let date1 = record1.modificationDate ?? Date.distantPast
                    let date2 = record2.modificationDate ?? Date.distantPast
                    return date1 < date2
                }
            }
            
            return records.first
            
        } catch let error as CKError {
            // Handle specific CloudKit errors
            switch error.code {
            case .networkUnavailable, .networkFailure:
                await MainActor.run {
                    isCloudKitAvailable = false
                    updateOfflineMode()
                }
                throw CloudKitError.networkUnavailable
            case .serviceUnavailable:
                await MainActor.run {
                    isCloudKitAvailable = false
                    updateOfflineMode()
                }
                throw CloudKitError.syncFailed(error)
            case .unknownItem:
                return nil // Family not found is not an error
            case .invalidArguments:
                throw CloudKitError.invalidRecord
            default:
                throw CloudKitError.syncFailed(error)
            }
        } catch {
            throw CloudKitError.syncFailed(error)
        }
    }
    
    /// Validates predicate safety before CloudKit operations
    private func validatePredicate(_ predicate: NSPredicate) -> Bool {
        // Basic validation to prevent crashes
        let predicateString = predicate.predicateFormat
        
        // Check for potentially problematic patterns
        let dangerousPatterns = ["SUBQUERY", "FUNCTION", "@", "SELF"]
        for pattern in dangerousPatterns {
            if predicateString.contains(pattern) {
                print("⚠️ CloudKitService: Potentially unsafe predicate detected: \(predicateString)")
                return false
            }
        }
        
        return true
    }
    
    /// Safe predicate-based fetch with enhanced error handling
    private func fetchWithSafePredicate<T: CloudKitSyncable>(_ type: T.Type, predicate: NSPredicate) async throws -> [CKRecord] {
        let query = CKQuery(recordType: type.recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        do {
            let (matchResults, _) = try await privateDatabase.records(matching: query, inZoneWith: customZone.zoneID)
            
            var records: [CKRecord] = []
            for (_, result) in matchResults {
                switch result {
                case .success(let record):
                    records.append(record)
                case .failure(let error):
                    print("⚠️ CloudKitService: Failed to fetch individual record: \(error)")
                    // Continue processing other records instead of failing completely
                }
            }
            
            return records
        } catch let error as CKError {
            // Handle zone-related errors by falling back to default zone
            if error.code == .zoneNotFound || error.code == .unknownItem {
                print("🔄 CloudKitService: Custom zone issue, falling back to default zone")
                return try await fetchWithDefaultZone(type, predicate: predicate)
            }
            throw error
        }
    }
    
    /// Fallback fetch using default zone when custom zone fails
    private func fetchWithDefaultZone<T: CloudKitSyncable>(_ type: T.Type, predicate: NSPredicate) async throws -> [CKRecord] {
        let query = CKQuery(recordType: type.recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        
        let (matchResults, _) = try await privateDatabase.records(matching: query)
        
        var records: [CKRecord] = []
        for (_, result) in matchResults {
            switch result {
            case .success(let record):
                records.append(record)
            case .failure(let error):
                print("⚠️ CloudKitService: Failed to fetch record from default zone: \(error)")
            }
        }
        
        return records
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
    
    /// Enhanced retry logic with exponential backoff and jitter
    private func withEnhancedRetry<T>(
        maxAttempts: Int,
        operation: String,
        retryOperation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                // Check connectivity before each attempt
                if !isNetworkAvailable {
                    await MainActor.run {
                        isCloudKitAvailable = false
                        updateOfflineMode()
                    }
                    throw CloudKitError.networkUnavailable
                }
                
                print("🔄 CloudKitService: Attempting \(operation) (attempt \(attempt)/\(maxAttempts))")
                return try await retryOperation()
                
            } catch let error as CKError {
                lastError = error
                
                // Check if error is retryable
                if !isRetryableError(error) {
                    print("❌ CloudKitService: Non-retryable error in \(operation): \(error)")
                    throw CloudKitError.syncFailed(error)
                }
                
                // Update availability status based on error
                await updateAvailabilityFromError(error)
                
                // Don't retry on the last attempt
                if attempt == maxAttempts {
                    print("❌ CloudKitService: Max retry attempts exceeded for \(operation)")
                    throw CloudKitError.retryLimitExceeded
                }
                
                // Calculate delay with exponential backoff and jitter
                let baseDelay = baseRetryDelay * pow(2.0, Double(attempt - 1))
                let jitter = Double.random(in: 0.0...0.1) * baseDelay
                let delay = baseDelay + jitter
                
                print("⏳ CloudKitService: Retrying \(operation) in \(String(format: "%.2f", delay)) seconds")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
            } catch {
                lastError = error
                print("❌ CloudKitService: Unexpected error in \(operation): \(error)")
                throw CloudKitError.syncFailed(error)
            }
        }
        
        // This should never be reached, but provide a fallback
        if let lastError = lastError {
            throw CloudKitError.syncFailed(lastError)
        } else {
            throw CloudKitError.retryLimitExceeded
        }
    }
    
    /// Updates availability status based on CloudKit errors
    private func updateAvailabilityFromError(_ error: CKError) async {
        await MainActor.run {
            switch error.code {
            case .networkUnavailable, .networkFailure:
                isNetworkAvailable = false
                isCloudKitAvailable = false
            case .serviceUnavailable, .zoneBusy:
                isCloudKitAvailable = false
            case .quotaExceeded:
                isCloudKitAvailable = false
            default:
                break
            }
            updateOfflineMode()
        }
    }
    
    /// Executes an operation with exponential backoff retry logic (legacy method for compatibility)
    private func withRetry<T>(maxAttempts: Int, operation: @escaping () async throws -> T) async throws -> T {
        return try await withEnhancedRetry(maxAttempts: maxAttempts, operation: "legacy", retryOperation: operation)
    }
    
    /// Determines if a CloudKit error is retryable with enhanced logic
    private func isRetryableError(_ error: CKError) -> Bool {
        switch error.code {
        // Always retryable - network and service issues
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy:
            return true
            
        // Conditionally retryable - temporary server issues
        case .internalError, .serverRejectedRequest:
            return true
            
        // Retryable with caution - might indicate temporary issues
        case .partialFailure:
            return true
            
        // Never retryable - permanent failures
        case .quotaExceeded, .unknownItem, .invalidArguments, .incompatibleVersion:
            return false
            
        // Account and permission issues - not retryable
        case .notAuthenticated, .permissionFailure, .managedAccountRestricted:
            return false
            
        // Zone issues - might be retryable depending on context
        case .zoneNotFound, .userDeletedZone:
            return false
            
        // Record issues - generally not retryable
        case .serverRecordChanged, .batchRequestFailed:
            return false
            
        // Default to not retryable for unknown errors
        default:
            print("⚠️ CloudKitService: Unknown CloudKit error code: \(error.code.rawValue)")
            return false
        }
    }
    
    // MARK: - Offline Mode and Fallback Operations
    
    /// Checks if operation should fall back to local-only mode
    func shouldFallbackToLocal() -> Bool {
        return isOfflineMode || !isNetworkAvailable || !isCloudKitAvailable
    }
    
    /// Marks records for later sync when CloudKit becomes available
    func markRecordForLaterSync<T: CloudKitSyncable>(_ record: T) {
        // This would typically update a local flag or queue
        // The actual implementation would depend on how the local storage tracks sync status
        print("📝 CloudKitService: Marking record \(record.id) for later sync")
        
        // Post notification for other services to handle local-only storage
        NotificationCenter.default.post(
            name: .recordMarkedForSync,
            object: nil,
            userInfo: ["recordId": record.id.uuidString, "recordType": T.recordType]
        )
    }
    
    /// Handles graceful degradation when CloudKit is unavailable
    func handleCloudKitUnavailable(operation: String) {
        print("⚠️ CloudKitService: CloudKit unavailable for operation: \(operation)")
        print("   Falling back to local-only mode")
        
        // Update status
        Task { @MainActor in
            isCloudKitAvailable = false
            updateOfflineMode()
        }
        
        // Notify observers about offline mode
        NotificationCenter.default.post(
            name: .cloudKitUnavailable,
            object: nil,
            userInfo: ["operation": operation, "timestamp": Date()]
        )
    }
    
    /// Attempts to restore CloudKit connectivity
    func attemptCloudKitReconnection() async -> Bool {
        print("🔄 CloudKitService: Attempting to restore CloudKit connectivity")
        
        // Check network first
        guard isNetworkAvailable else {
            print("❌ CloudKitService: Network still unavailable")
            return false
        }
        
        // Check CloudKit availability
        let available = await checkCloudKitAvailability()
        
        if available {
            print("✅ CloudKitService: CloudKit connectivity restored")
            
            // Notify observers about restored connectivity
            NotificationCenter.default.post(
                name: .cloudKitRestored,
                object: nil,
                userInfo: ["timestamp": Date()]
            )
        } else {
            print("❌ CloudKitService: CloudKit still unavailable")
        }
        
        return available
    }
    
    // MARK: - Account Status
    
    /// Checks CloudKit account status with enhanced error handling
    func checkAccountStatus() async throws -> CKAccountStatus {
        do {
            return try await container.accountStatus()
        } catch {
            print("❌ CloudKitService: Failed to check account status: \(error)")
            throw CloudKitError.syncFailed(error)
        }
    }
    
    /// Verifies CloudKit availability with comprehensive checks
    func verifyCloudKitAvailability() async throws -> Bool {
        // Check network connectivity first
        guard isNetworkAvailable else {
            throw CloudKitError.networkUnavailable
        }
        
        do {
            let status = try await checkAccountStatus()
            let available = status == .available
            
            await MainActor.run {
                isCloudKitAvailable = available
                updateOfflineMode()
            }
            
            return available
        } catch {
            await MainActor.run {
                isCloudKitAvailable = false
                updateOfflineMode()
            }
            throw error
        }
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
    
    // CloudKit availability notifications
    static let cloudKitUnavailable = Notification.Name("cloudKitUnavailable")
    static let cloudKitRestored = Notification.Name("cloudKitRestored")
    static let recordMarkedForSync = Notification.Name("recordMarkedForSync")
    static let networkConnectivityChanged = Notification.Name("networkConnectivityChanged")
}

