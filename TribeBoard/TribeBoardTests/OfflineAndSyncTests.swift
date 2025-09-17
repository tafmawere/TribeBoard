import XCTest
import SwiftData
import CloudKit
@testable import TribeBoard

/// Tests for offline functionality and sync scenarios
@MainActor
final class OfflineAndSyncTests: XCTestCase {
    
    var modelContainer: ModelContainer!
    var dataService: DataService!
    var cloudKitService: CloudKitService!
    var mockCloudKitService: MockCloudKitService!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create in-memory container for testing
        modelContainer = try ModelContainerConfiguration.createInMemory()
        dataService = DataService(modelContext: modelContainer.mainContext)
        cloudKitService = CloudKitService(containerIdentifier: "iCloud.net.dataenvy.TribeBoard.test")
        mockCloudKitService = MockCloudKitService()
    }
    
    override func tearDown() async throws {
        modelContainer = nil
        dataService = nil
        cloudKitService = nil
        mockCloudKitService = nil
        try await super.tearDown()
    }
    
    // MARK: - Offline Data Creation Tests
    
    func testOfflineFamilyCreation() throws {
        // Create family while "offline" (no CloudKit sync)
        let user = try dataService.createUserProfile(
            displayName: "Offline User",
            appleUserIdHash: "offline_hash"
        )
        
        let family = try dataService.createFamily(
            name: "Offline Family",
            code: "OFFLINE1",
            createdByUserId: user.id
        )
        
        let membership = try dataService.createMembership(
            family: family,
            user: user,
            role: .parentAdmin
        )
        
        // Verify data is stored locally
        XCTAssertEqual(family.name, "Offline Family")
        XCTAssertEqual(membership.role, .parentAdmin)
        
        // Verify sync flags
        XCTAssertTrue(family.needsSync)
        XCTAssertTrue(membership.needsSync)
        XCTAssertNil(family.ckRecordID)
        XCTAssertNil(membership.ckRecordID)
    }
    
    func testOfflineDataModification() throws {
        // Create initial data
        let user = try dataService.createUserProfile(
            displayName: "Test User",
            appleUserIdHash: "test_hash"
        )
        
        let family = try dataService.createFamily(
            name: "Test Family",
            code: "TEST123",
            createdByUserId: user.id
        )
        
        let membership = try dataService.createMembership(
            family: family,
            user: user,
            role: .adult
        )
        
        // Simulate sync completion
        family.markAsSynced(recordID: "family_record_id")
        membership.markAsSynced(recordID: "membership_record_id")
        
        XCTAssertFalse(family.needsSync)
        XCTAssertFalse(membership.needsSync)
        
        // Modify data while offline
        try dataService.updateMembershipRole(membership, to: .parentAdmin)
        
        // Verify sync flag is set
        XCTAssertTrue(membership.needsSync)
        XCTAssertEqual(membership.role, .parentAdmin)
    }
    
    // MARK: - Sync Queue Tests
    
    func testSyncQueueManagement() async throws {
        // Create multiple items that need sync
        let user1 = try dataService.createUserProfile(
            displayName: "User 1",
            appleUserIdHash: "hash1"
        )
        
        let user2 = try dataService.createUserProfile(
            displayName: "User 2",
            appleUserIdHash: "hash2"
        )
        
        let family = try dataService.createFamily(
            name: "Sync Family",
            code: "SYNC123",
            createdByUserId: user1.id
        )
        
        let membership1 = try dataService.createMembership(
            family: family,
            user: user1,
            role: .parentAdmin
        )
        
        let membership2 = try dataService.createMembership(
            family: family,
            user: user2,
            role: .adult
        )
        
        // Verify all items need sync
        XCTAssertTrue(family.needsSync)
        XCTAssertTrue(membership1.needsSync)
        XCTAssertTrue(membership2.needsSync)
        
        // Simulate successful sync for some items
        family.markAsSynced(recordID: "family_synced")
        membership1.markAsSynced(recordID: "membership1_synced")
        
        // Verify sync states
        XCTAssertFalse(family.needsSync)
        XCTAssertFalse(membership1.needsSync)
        XCTAssertTrue(membership2.needsSync) // Still needs sync
    }
    
    // MARK: - Conflict Resolution Tests
    
    func testConflictResolution_LastWriteWins() async throws {
        // Create local family
        let user = try dataService.createUserProfile(
            displayName: "Test User",
            appleUserIdHash: "test_hash"
        )
        
        let localFamily = try dataService.createFamily(
            name: "Local Family",
            code: "LOCAL123",
            createdByUserId: user.id
        )
        
        // Simulate local modification
        localFamily.name = "Modified Local Family"
        localFamily.lastSyncDate = Date(timeIntervalSinceNow: -3600) // 1 hour ago
        
        // Create server record (newer)
        let serverRecord = try localFamily.toCKRecord()
        serverRecord[CKFieldName.familyName] = "Server Family"
        // Note: In real CloudKit, modificationDate would be set automatically
        
        // Test conflict resolution
        let resolvedFamily = try await cloudKitService.resolveConflict(
            localRecord: localFamily,
            serverRecord: serverRecord
        )
        
        // Server should win (assuming it's newer)
        XCTAssertEqual(resolvedFamily.name, "Server Family")
    }
    
    func testConflictResolution_MembershipRoleChange() async throws {
        // Create membership
        let user = try dataService.createUserProfile(
            displayName: "Test User",
            appleUserIdHash: "test_hash"
        )
        
        let family = try dataService.createFamily(
            name: "Test Family",
            code: "TEST123",
            createdByUserId: user.id
        )
        
        let membership = try dataService.createMembership(
            family: family,
            user: user,
            role: .adult
        )
        
        // Simulate local change
        membership.role = .kid
        membership.lastSyncDate = Date(timeIntervalSinceNow: -1800) // 30 minutes ago
        
        // Create server record with different role (newer)
        let serverRecord = try membership.toCKRecord()
        serverRecord[CKFieldName.membershipRole] = Role.visitor.rawValue
        
        // Test conflict resolution
        let resolvedMembership = try await cloudKitService.resolveConflict(
            localRecord: membership,
            serverRecord: serverRecord
        )
        
        // Server should win
        XCTAssertEqual(resolvedMembership.role, .visitor)
    }
    
    // MARK: - Network Failure Simulation Tests
    
    func testNetworkFailureHandling() async {
        // Setup mock service to simulate network failure
        mockCloudKitService.shouldSucceed = false
        mockCloudKitService.errorToThrow = CloudKitError.networkUnavailable
        
        // Create data that would normally sync
        do {
            let user = try dataService.createUserProfile(
                displayName: "Network Test User",
                appleUserIdHash: "network_hash"
            )
            
            let family = try dataService.createFamily(
                name: "Network Test Family",
                code: "NET123",
                createdByUserId: user.id
            )
            
            // Attempt to sync (should fail gracefully)
            do {
                try await mockCloudKitService.save(family)
                XCTFail("Expected network error")
            } catch CloudKitError.networkUnavailable {
                // Expected error - data should remain in local storage
                XCTAssertTrue(family.needsSync)
                XCTAssertNil(family.ckRecordID)
            }
            
        } catch {
            XCTFail("Local data creation should succeed even with network issues")
        }
    }
    
    func testRetryLogicWithExponentialBackoff() async {
        // This test would verify retry logic in a real implementation
        // For now, we test the concept
        
        var attemptCount = 0
        let maxRetries = 3
        
        func simulateRetryableOperation() async throws {
            attemptCount += 1
            
            if attemptCount < maxRetries {
                throw CloudKitError.networkUnavailable
            }
            
            // Success on final attempt
        }
        
        // Simulate retry logic
        for attempt in 1...maxRetries {
            do {
                try await simulateRetryableOperation()
                break // Success
            } catch {
                if attempt == maxRetries {
                    XCTFail("All retries exhausted")
                }
                // In real implementation, would wait with exponential backoff
                try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 10_000_000)) // 0.01s * 2^attempt
            }
        }
        
        XCTAssertEqual(attemptCount, maxRetries)
    }
    
    // MARK: - Data Consistency Tests
    
    func testDataConsistencyAfterSync() throws {
        // Create family with members
        let parent = try dataService.createUserProfile(
            displayName: "Parent",
            appleUserIdHash: "parent_hash"
        )
        
        let child = try dataService.createUserProfile(
            displayName: "Child",
            appleUserIdHash: "child_hash"
        )
        
        let family = try dataService.createFamily(
            name: "Consistency Family",
            code: "CONSIST1",
            createdByUserId: parent.id
        )
        
        let parentMembership = try dataService.createMembership(
            family: family,
            user: parent,
            role: .parentAdmin
        )
        
        let childMembership = try dataService.createMembership(
            family: family,
            user: child,
            role: .kid
        )
        
        // Simulate partial sync (only family synced)
        family.markAsSynced(recordID: "family_synced")
        
        // Verify consistency
        let activeMembers = try dataService.fetchActiveMembers(forFamily: family)
        XCTAssertEqual(activeMembers.count, 2)
        
        // Verify parent admin constraint is maintained
        XCTAssertTrue(try dataService.familyHasParentAdmin(family))
        
        let parentAdmins = activeMembers.filter { $0.role == .parentAdmin }
        XCTAssertEqual(parentAdmins.count, 1)
        XCTAssertEqual(parentAdmins.first?.user?.id, parent.id)
    }
    
    // MARK: - Offline Search and Filtering Tests
    
    func testOfflineDataFiltering() throws {
        // Create test data
        let user1 = try dataService.createUserProfile(
            displayName: "User One",
            appleUserIdHash: "hash1"
        )
        
        let user2 = try dataService.createUserProfile(
            displayName: "User Two",
            appleUserIdHash: "hash2"
        )
        
        let family1 = try dataService.createFamily(
            name: "Family Alpha",
            code: "ALPHA1",
            createdByUserId: user1.id
        )
        
        let family2 = try dataService.createFamily(
            name: "Family Beta",
            code: "BETA22",
            createdByUserId: user2.id
        )
        
        let membership1 = try dataService.createMembership(
            family: family1,
            user: user1,
            role: .parentAdmin
        )
        
        let membership2 = try dataService.createMembership(
            family: family2,
            user: user2,
            role: .parentAdmin
        )
        
        let membership3 = try dataService.createMembership(
            family: family1,
            user: user2,
            role: .adult
        )
        
        // Test filtering active members
        let family1Members = try dataService.fetchActiveMembers(forFamily: family1)
        XCTAssertEqual(family1Members.count, 2)
        
        let family2Members = try dataService.fetchActiveMembers(forFamily: family2)
        XCTAssertEqual(family2Members.count, 1)
        
        // Test role filtering
        let parentAdmins = family1Members.filter { $0.role == .parentAdmin }
        XCTAssertEqual(parentAdmins.count, 1)
        
        let adults = family1Members.filter { $0.role == .adult }
        XCTAssertEqual(adults.count, 1)
    }
    
    // MARK: - Sync State Recovery Tests
    
    func testSyncStateRecovery() throws {
        // Create data with mixed sync states
        let user = try dataService.createUserProfile(
            displayName: "Recovery User",
            appleUserIdHash: "recovery_hash"
        )
        
        let family = try dataService.createFamily(
            name: "Recovery Family",
            code: "RECOVER1",
            createdByUserId: user.id
        )
        
        let membership = try dataService.createMembership(
            family: family,
            user: user,
            role: .parentAdmin
        )
        
        // Simulate partial sync failure
        family.markAsSynced(recordID: "family_record")
        // membership remains unsynced
        
        // Verify recovery state
        XCTAssertFalse(family.needsSync)
        XCTAssertTrue(membership.needsSync)
        XCTAssertNotNil(family.ckRecordID)
        XCTAssertNil(membership.ckRecordID)
        
        // Simulate recovery sync
        membership.markAsSynced(recordID: "membership_record")
        
        // Verify full sync state
        XCTAssertFalse(family.needsSync)
        XCTAssertFalse(membership.needsSync)
        XCTAssertNotNil(family.ckRecordID)
        XCTAssertNotNil(membership.ckRecordID)
    }
    
    // MARK: - Performance Under Sync Load Tests
    
    func testPerformanceUnderSyncLoad() throws {
        measure {
            do {
                // Create multiple families and members
                for i in 0..<50 {
                    let user = try dataService.createUserProfile(
                        displayName: "User \(i)",
                        appleUserIdHash: "hash_\(i)"
                    )
                    
                    let family = try dataService.createFamily(
                        name: "Family \(i)",
                        code: "FAM\(String(format: "%03d", i))",
                        createdByUserId: user.id
                    )
                    
                    _ = try dataService.createMembership(
                        family: family,
                        user: user,
                        role: .parentAdmin
                    )
                    
                    // Simulate some items being synced
                    if i % 3 == 0 {
                        family.markAsSynced(recordID: "family_\(i)")
                    }
                }
                
                // Query performance with mixed sync states
                let descriptor = FetchDescriptor<Family>()
                let allFamilies = try modelContainer.mainContext.fetch(descriptor)
                XCTAssertEqual(allFamilies.count, 50)
                
                let unsyncedFamilies = allFamilies.filter { $0.needsSync }
                XCTAssertTrue(unsyncedFamilies.count > 0)
                
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
        }
    }
}

// MARK: - Mock CloudKit Service for Offline Testing

class MockCloudKitService: CloudKitService {
    var shouldSucceed = true
    var errorToThrow: Error?
    var simulateDelay = false
    
    override init() {
        super.init(containerIdentifier: "test")
    }
    
    override func save<T: CloudKitSyncable>(_ record: T) async throws {
        if simulateDelay {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        if !shouldSucceed {
            throw errorToThrow ?? CloudKitError.networkUnavailable
        }
        
        // Simulate successful sync
        record.markAsSynced(recordID: "mock_record_\(UUID().uuidString)")
    }
    
    override func fetch<T: CloudKitSyncable>(_ type: T.Type, predicate: NSPredicate) async throws -> [T] {
        if !shouldSucceed {
            throw errorToThrow ?? CloudKitError.networkUnavailable
        }
        
        return [] // Return empty for mock
    }
}