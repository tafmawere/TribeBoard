import Foundation
import CloudKit
@testable import TribeBoard

/// Mock CloudKit service for controllable testing scenarios
@MainActor
class MockCloudKitService: CloudKitService {
    
    // MARK: - Test Control Properties
    
    /// Controls whether operations should fail
    var shouldFailOperations = false
    
    /// Network delay to simulate in operations
    var networkDelay: TimeInterval = 0
    
    /// Current conflict scenario to simulate
    var conflictScenario: ConflictScenario = .none
    
    /// In-memory storage for CloudKit records
    var recordStorage: [String: CKRecord] = [:]
    
    /// Subscription storage for testing
    var subscriptionStorage: [String: CKSubscription] = [:]
    
    /// Error to throw when operations fail
    var errorToThrow: Error = CloudKitError.networkUnavailable
    
    /// Counter for operation calls
    var operationCallCount: [String: Int] = [:]
    
    /// Flag to track if initial setup was called
    var initialSetupCalled = false
    
    /// Flag to track if subscriptions were set up
    var subscriptionsSetUp = false
    
    /// Account status to return
    var mockAccountStatus: CKAccountStatus = .available
    
    /// Index at which to fail operations (for partial migration testing)
    var failOnRecordIndex: Int?
    
    /// Current operation index counter
    private var currentOperationIndex = 0
    
    // MARK: - Initialization
    
    override init(containerIdentifier: String = "iCloud.net.dataenvy.TribeBoard.Test") {
        super.init(containerIdentifier: containerIdentifier)
        reset()
    }
    
    // MARK: - Test Control Methods
    
    /// Resets the mock service to clean state
    func reset() {
        shouldFailOperations = false
        networkDelay = 0
        conflictScenario = .none
        recordStorage.removeAll()
        subscriptionStorage.removeAll()
        errorToThrow = CloudKitError.networkUnavailable
        operationCallCount.removeAll()
        initialSetupCalled = false
        subscriptionsSetUp = false
        mockAccountStatus = .available
        failOnRecordIndex = nil
        currentOperationIndex = 0
    }
    
    /// Simulates network error for next operations
    func simulateNetworkError() {
        shouldFailOperations = true
        errorToThrow = CloudKitError.networkUnavailable
    }
    
    /// Simulates CloudKit quota exceeded error
    func simulateQuotaExceeded() {
        shouldFailOperations = true
        errorToThrow = CloudKitError.quotaExceeded
    }
    
    /// Simulates record not found error
    func simulateRecordNotFound() {
        shouldFailOperations = true
        errorToThrow = CloudKitError.recordNotFound
    }
    
    /// Simulates conflict scenario
    func simulateConflict(scenario: ConflictScenario) {
        conflictScenario = scenario
    }
    
    /// Simulates network delay
    func simulateNetworkDelay(_ delay: TimeInterval) {
        networkDelay = delay
    }
    
    /// Sets custom error to throw
    func setCustomError(_ error: Error) {
        shouldFailOperations = true
        errorToThrow = error
    }
    
    /// Gets the number of times an operation was called
    func getOperationCallCount(_ operation: String) -> Int {
        return operationCallCount[operation] ?? 0
    }
    
    // MARK: - Helper Methods
    
    private func incrementCallCount(_ operation: String) {
        operationCallCount[operation, default: 0] += 1
    }
    
    private func simulateDelay() async throws {
        if networkDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(networkDelay * 1_000_000_000))
        }
    }
    
    private func checkForFailure() throws {
        if shouldFailOperations {
            throw errorToThrow
        }
        
        // Check for index-based failure
        if let failIndex = failOnRecordIndex, currentOperationIndex == failIndex {
            currentOperationIndex += 1
            throw errorToThrow
        }
        
        currentOperationIndex += 1
    }
    
    // MARK: - Setup and Configuration Overrides
    
    override func performInitialSetup() async throws {
        incrementCallCount("performInitialSetup")
        try await simulateDelay()
        try checkForFailure()
        
        initialSetupCalled = true
        subscriptionsSetUp = true
    }
    
    override func setupCustomZone() async throws {
        incrementCallCount("setupCustomZone")
        try await simulateDelay()
        try checkForFailure()
    }
    
    override func setupSubscriptions() async throws {
        incrementCallCount("setupSubscriptions")
        try await simulateDelay()
        try checkForFailure()
        
        // Simulate creating subscriptions
        let familySubscription = CKQuerySubscription(
            recordType: CKRecordType.family,
            predicate: NSPredicate(value: true),
            subscriptionID: "family-changes"
        )
        subscriptionStorage["family-changes"] = familySubscription
        
        let membershipSubscription = CKQuerySubscription(
            recordType: CKRecordType.membership,
            predicate: NSPredicate(value: true),
            subscriptionID: "membership-changes"
        )
        subscriptionStorage["membership-changes"] = membershipSubscription
        
        let userProfileSubscription = CKQuerySubscription(
            recordType: CKRecordType.userProfile,
            predicate: NSPredicate(value: true),
            subscriptionID: "userprofile-changes"
        )
        subscriptionStorage["userprofile-changes"] = userProfileSubscription
        
        subscriptionsSetUp = true
    }
    
    override func removeAllSubscriptions() async throws {
        incrementCallCount("removeAllSubscriptions")
        try await simulateDelay()
        try checkForFailure()
        
        subscriptionStorage.removeAll()
        subscriptionsSetUp = false
    }
    
    // MARK: - CRUD Operations Overrides
    
    override func save<T: CloudKitSyncable>(_ record: T) async throws {
        incrementCallCount("save")
        try await simulateDelay()
        try checkForFailure()
        
        let ckRecord = try record.toCKRecord()
        let recordID = record.id.uuidString
        
        // Store the record
        recordStorage[recordID] = ckRecord
    }
    
    override func saveRecords<T: CloudKitSyncable>(_ records: [T]) async throws {
        incrementCallCount("saveRecords")
        try await simulateDelay()
        try checkForFailure()
        
        for record in records {
            let ckRecord = try record.toCKRecord()
            let recordID = record.id.uuidString
            recordStorage[recordID] = ckRecord
        }
    }
    
    override func fetch<T: CloudKitSyncable>(_ type: T.Type, predicate: NSPredicate? = nil) async throws -> [CKRecord] {
        incrementCallCount("fetch")
        try await simulateDelay()
        try checkForFailure()
        
        let recordType = type.recordType
        let matchingRecords = recordStorage.values.filter { record in
            guard record.recordType == recordType else { return false }
            
            if let predicate = predicate {
                // Simple predicate evaluation for testing
                return evaluatePredicate(predicate, against: record)
            }
            
            return true
        }
        
        return Array(matchingRecords)
    }
    
    override func fetchRecord(withID recordID: String, recordType: String) async throws -> CKRecord? {
        incrementCallCount("fetchRecord")
        try await simulateDelay()
        try checkForFailure()
        
        return recordStorage[recordID]
    }
    
    override func deleteRecord(withID recordID: String) async throws {
        incrementCallCount("deleteRecord")
        try await simulateDelay()
        try checkForFailure()
        
        recordStorage.removeValue(forKey: recordID)
    }
    
    // MARK: - Family Operations Overrides
    
    override func fetchFamily(byCode code: String) async throws -> CKRecord? {
        incrementCallCount("fetchFamily")
        try await simulateDelay()
        try checkForFailure()
        
        return recordStorage.values.first { record in
            record.recordType == CKRecordType.family &&
            record[CKFieldName.familyCode] as? String == code
        }
    }
    
    override func fetchFamilies(createdByUserId: String) async throws -> [CKRecord] {
        incrementCallCount("fetchFamilies")
        try await simulateDelay()
        try checkForFailure()
        
        return recordStorage.values.filter { record in
            record.recordType == CKRecordType.family &&
            record[CKFieldName.familyCreatedByUserId] as? String == createdByUserId
        }
    }
    
    // MARK: - UserProfile Operations Overrides
    
    override func fetchUserProfile(byAppleUserIdHash hash: String) async throws -> CKRecord? {
        incrementCallCount("fetchUserProfile")
        try await simulateDelay()
        try checkForFailure()
        
        return recordStorage.values.first { record in
            record.recordType == CKRecordType.userProfile &&
            record[CKFieldName.userAppleUserIdHash] as? String == hash
        }
    }
    
    // MARK: - Membership Operations Overrides
    
    override func fetchMemberships(forFamilyId familyId: String) async throws -> [CKRecord] {
        incrementCallCount("fetchMemberships")
        try await simulateDelay()
        try checkForFailure()
        
        return recordStorage.values.filter { record in
            record.recordType == CKRecordType.membership &&
            (record[CKFieldName.membershipFamilyReference] as? CKRecord.Reference)?.recordID.recordName == familyId
        }
    }
    
    override func fetchMemberships(forUserId userId: String) async throws -> [CKRecord] {
        incrementCallCount("fetchMemberships")
        try await simulateDelay()
        try checkForFailure()
        
        return recordStorage.values.filter { record in
            record.recordType == CKRecordType.membership &&
            (record[CKFieldName.membershipUserReference] as? CKRecord.Reference)?.recordID.recordName == userId
        }
    }
    
    override func fetchActiveMemberships(forFamilyId familyId: String) async throws -> [CKRecord] {
        incrementCallCount("fetchActiveMemberships")
        try await simulateDelay()
        try checkForFailure()
        
        return recordStorage.values.filter { record in
            record.recordType == CKRecordType.membership &&
            (record[CKFieldName.membershipFamilyReference] as? CKRecord.Reference)?.recordID.recordName == familyId &&
            record[CKFieldName.membershipStatus] as? String == MembershipStatus.active.rawValue
        }
    }
    
    // MARK: - Conflict Resolution Override
    
    override func resolveConflict<T: CloudKitSyncable>(localRecord: T, serverRecord: CKRecord) async throws -> T {
        incrementCallCount("resolveConflict")
        try await simulateDelay()
        try checkForFailure()
        
        switch conflictScenario {
        case .none:
            return try await super.resolveConflict(localRecord: localRecord, serverRecord: serverRecord)
            
        case .localNewer:
            // Simulate local record being newer
            return localRecord
            
        case .serverNewer:
            // Simulate server record being newer
            let updatedRecord = localRecord
            try updatedRecord.updateFromCKRecord(serverRecord)
            return updatedRecord
            
        case .simultaneousUpdate:
            // Simulate simultaneous update conflict
            throw CloudKitError.conflictResolution
        }
    }
    
    // MARK: - Account Status Override
    
    override func checkAccountStatus() async throws -> CKAccountStatus {
        incrementCallCount("checkAccountStatus")
        try await simulateDelay()
        try checkForFailure()
        
        return mockAccountStatus
    }
    
    override func verifyCloudKitAvailability() async throws -> Bool {
        incrementCallCount("verifyCloudKitAvailability")
        try await simulateDelay()
        try checkForFailure()
        
        return mockAccountStatus == .available
    }
    
    // MARK: - Notification Handling
    
    override func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) async {
        incrementCallCount("handleRemoteNotification")
        // Simulate handling notification
        await super.handleRemoteNotification(userInfo)
    }
    
    // MARK: - Helper Methods for Testing
    
    /// Simple predicate evaluation for testing purposes
    private func evaluatePredicate(_ predicate: NSPredicate, against record: CKRecord) -> Bool {
        // This is a simplified implementation for testing
        // In a real scenario, you might want more sophisticated predicate evaluation
        
        let predicateString = predicate.predicateFormat
        
        // Handle family code predicates
        if predicateString.contains("code == ") {
            if let range = predicateString.range(of: "\"([^\"]+)\"", options: .regularExpression) {
                let code = String(predicateString[range]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                return record[CKFieldName.familyCode] as? String == code
            }
        }
        
        // Handle Apple ID hash predicates
        if predicateString.contains("appleUserIdHash == ") {
            if let range = predicateString.range(of: "\"([^\"]+)\"", options: .regularExpression) {
                let hash = String(predicateString[range]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                return record[CKFieldName.userAppleUserIdHash] as? String == hash
            }
        }
        
        // Handle membership status predicates
        if predicateString.contains("status == ") {
            if let range = predicateString.range(of: "\"([^\"]+)\"", options: .regularExpression) {
                let status = String(predicateString[range]).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                return record[CKFieldName.membershipStatus] as? String == status
            }
        }
        
        // Default to true for simple predicates
        return true
    }
    
    /// Creates a test CKRecord for the given type and data
    func createTestRecord(recordType: String, recordID: String, fields: [String: Any]) -> CKRecord {
        let record = CKRecord(recordType: recordType, recordID: CKRecord.ID(recordName: recordID))
        
        for (key, value) in fields {
            record[key] = value as? CKRecordValue
        }
        
        recordStorage[recordID] = record
        return record
    }
    
    /// Gets all stored records of a specific type
    func getStoredRecords(ofType recordType: String) -> [CKRecord] {
        return recordStorage.values.filter { $0.recordType == recordType }
    }
    
    /// Checks if a subscription exists
    func hasSubscription(withID subscriptionID: String) -> Bool {
        return subscriptionStorage[subscriptionID] != nil
    }
}

// MARK: - Conflict Scenarios

/// Enumeration of conflict scenarios for testing
enum ConflictScenario {
    case none
    case localNewer
    case serverNewer
    case simultaneousUpdate
}