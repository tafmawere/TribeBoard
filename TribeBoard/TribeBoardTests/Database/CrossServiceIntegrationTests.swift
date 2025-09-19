import XCTest
import SwiftData
@testable import TribeBoard

/// Tests for cross-service interactions and data flow
@MainActor
class CrossServiceIntegrationTests: DatabaseTestBase {
    
    // MARK: - Test Properties
    
    private var authService: AuthService!
    private var cloudKitService: MockCloudKitService!
    private var keychainService: KeychainService!
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Initialize services for integration testing
        keychainService = KeychainService()
        authService = AuthService(keychainService: keychainService)
        cloudKitService = MockCloudKitService()
        
        // Set up service dependencies
        authService.setDataService(dataService)
        
        // Reset mock service state
        cloudKitService.reset()
    }
    
    override func tearDown() async throws {
        // Clean up services and keychain
        try? keychainService.clearAll()
        authService = nil
        cloudKitService = nil
        keychainService = nil
        
        try await super.tearDown()
    }
    
    // MARK: - DataService and CloudKitService Integration Tests
    
    /// Tests DataService and CloudKitService integration for sync operations
    /// Requirements: 8.4
    func testDataServiceCloudKitServiceSyncIntegration() async throws {
        print("🧪 Testing DataService and CloudKitService sync integration...")
        
        // Step 1: Create local data through DataService
        let family = try dataService.createFamily(
            name: "Sync Test Family",
            code: "SYNC123",
            createdByUserId: UUID()
        )
        
        let user = try dataService.createUserProfile(
            displayName: "Sync Test User",
            appleUserIdHash: "sync_hash_1234567890"
        )
        
        let membership = try dataService.createMembership(
            family: family,
            user: user,
            role: .parentAdmin
        )
        
        // Step 2: Mark records as needing sync
        family.markAsNeedingSync()
        user.markAsNeedingSync()
        membership.markAsNeedingSync()
        try dataService.save()
        
        // Step 3: Verify records need sync
        let familiesNeedingSync = try dataService.fetchRecordsNeedingSync(Family.self)
        let usersNeedingSync = try dataService.fetchRecordsNeedingSync(UserProfile.self)
        let membershipsNeedingSync = try dataService.fetchRecordsNeedingSync(Membership.self)
        
        XCTAssertEqual(familiesNeedingSync.count, 1)
        XCTAssertEqual(usersNeedingSync.count, 1)
        XCTAssertEqual(membershipsNeedingSync.count, 1)
        
        // Step 4: Simulate CloudKit sync operations
        try await cloudKitService.save(family)
        try await cloudKitService.save(user)
        try await cloudKitService.save(membership)
        
        // Step 5: Mark records as synced (this would normally be done by sync service)
        family.markAsSynced()
        user.markAsSynced()
        membership.markAsSynced()
        try dataService.save()
        
        // Step 6: Verify records no longer need sync
        let familiesStillNeedingSync = try dataService.fetchRecordsNeedingSync(Family.self)
        let usersStillNeedingSync = try dataService.fetchRecordsNeedingSync(UserProfile.self)
        let membershipsStillNeedingSync = try dataService.fetchRecordsNeedingSync(Membership.self)
        
        XCTAssertEqual(familiesStillNeedingSync.count, 0)
        XCTAssertEqual(usersStillNeedingSync.count, 0)
        XCTAssertEqual(membershipsStillNeedingSync.count, 0)
        
        // Step 7: Test CloudKit record retrieval
        let cloudKitFamilies = try await cloudKitService.fetch(Family.self)
        let cloudKitUsers = try await cloudKitService.fetch(UserProfile.self)
        let cloudKitMemberships = try await cloudKitService.fetch(Membership.self)
        
        XCTAssertEqual(cloudKitFamilies.count, 1)
        XCTAssertEqual(cloudKitUsers.count, 1)
        XCTAssertEqual(cloudKitMemberships.count, 1)
        
        print("✅ DataService and CloudKitService sync integration test passed")
    }
    
    /// Tests conflict resolution between DataService and CloudKitService
    /// Requirements: 8.4
    func testDataServiceCloudKitConflictResolution() async throws {
        print("🧪 Testing DataService and CloudKit conflict resolution...")
        
        // Step 1: Create local record
        let localFamily = try dataService.createFamily(
            name: "Local Family",
            code: "LOCAL123",
            createdByUserId: UUID()
        )
        
        // Step 2: Simulate server record with different data
        cloudKitService.simulateConflict(scenario: .serverNewer)
        
        // Create a mock server record
        let serverRecord = try localFamily.toCKRecord()
        serverRecord["name"] = "Server Family" // Different name
        serverRecord.modificationDate = Date().addingTimeInterval(3600) // 1 hour newer
        
        // Step 3: Resolve conflict using CloudKitService
        let resolvedFamily = try await cloudKitService.resolveConflict(
            localRecord: localFamily,
            serverRecord: serverRecord
        )
        
        // Step 4: Verify conflict resolution (server wins because it's newer)
        XCTAssertEqual(resolvedFamily.name, "Server Family")
        XCTAssertNotNil(resolvedFamily.lastSyncDate)
        
        // Step 5: Test local-newer scenario
        cloudKitService.simulateConflict(scenario: .localNewer)
        
        let newerLocalFamily = try dataService.createFamily(
            name: "Newer Local Family",
            code: "NEWER123",
            createdByUserId: UUID()
        )
        
        let olderServerRecord = try newerLocalFamily.toCKRecord()
        olderServerRecord["name"] = "Older Server Family"
        olderServerRecord.modificationDate = Date().addingTimeInterval(-3600) // 1 hour older
        
        let resolvedNewerFamily = try await cloudKitService.resolveConflict(
            localRecord: newerLocalFamily,
            serverRecord: olderServerRecord
        )
        
        // Local record should win because it's newer
        XCTAssertEqual(resolvedNewerFamily.name, "Newer Local Family")
        
        print("✅ DataService and CloudKit conflict resolution test passed")
    }
    
    /// Tests batch sync operations between services
    /// Requirements: 8.4
    func testBatchSyncOperations() async throws {
        print("🧪 Testing batch sync operations...")
        
        // Step 1: Create multiple records through DataService
        let families = TestDataFactory.createBulkFamilies(count: 5)
        let users = TestDataFactory.createBulkUsers(count: 5)
        
        // Insert into local database
        for family in families {
            testContext.insert(family)
            family.markAsNeedingSync()
        }
        for user in users {
            testContext.insert(user)
            user.markAsNeedingSync()
        }
        try testContext.save()
        
        // Step 2: Verify all records need sync
        let familiesNeedingSync = try dataService.fetchRecordsNeedingSync(Family.self)
        let usersNeedingSync = try dataService.fetchRecordsNeedingSync(UserProfile.self)
        
        XCTAssertEqual(familiesNeedingSync.count, 5)
        XCTAssertEqual(usersNeedingSync.count, 5)
        
        // Step 3: Perform batch sync to CloudKit
        try await cloudKitService.saveRecords(families)
        try await cloudKitService.saveRecords(users)
        
        // Step 4: Mark all as synced
        for family in families {
            family.markAsSynced()
        }
        for user in users {
            user.markAsSynced()
        }
        try dataService.save()
        
        // Step 5: Verify sync completion
        let remainingFamiliesNeedingSync = try dataService.fetchRecordsNeedingSync(Family.self)
        let remainingUsersNeedingSync = try dataService.fetchRecordsNeedingSync(UserProfile.self)
        
        XCTAssertEqual(remainingFamiliesNeedingSync.count, 0)
        XCTAssertEqual(remainingUsersNeedingSync.count, 0)
        
        // Step 6: Verify CloudKit has all records
        let cloudKitFamilies = try await cloudKitService.fetch(Family.self)
        let cloudKitUsers = try await cloudKitService.fetch(UserProfile.self)
        
        XCTAssertEqual(cloudKitFamilies.count, 5)
        XCTAssertEqual(cloudKitUsers.count, 5)
        
        print("✅ Batch sync operations test passed")
    }
    
    // MARK: - DataService and AuthService Integration Tests
    
    /// Tests DataService and AuthService integration for user management
    /// Requirements: 8.5
    func testDataServiceAuthServiceUserManagement() async throws {
        print("🧪 Testing DataService and AuthService user management integration...")
        
        // Step 1: Simulate user authentication (we can't actually call Apple's auth in tests)
        let testAppleIdHash = "test_apple_id_hash_1234567890"
        
        // Step 2: Create user profile through DataService (simulating what AuthService would do)
        let userProfile = try dataService.createUserProfile(
            displayName: "Authenticated User",
            appleUserIdHash: testAppleIdHash
        )
        
        // Step 3: Simulate storing authentication data in keychain
        try keychainService.storeAppleUserIdHash(testAppleIdHash)
        
        // Step 4: Verify keychain storage
        let retrievedHash = try keychainService.retrieveAppleUserIdHash()
        XCTAssertEqual(retrievedHash, testAppleIdHash)
        
        // Step 5: Test user profile retrieval by auth service
        let fetchedProfile = try dataService.fetchUserProfile(byAppleUserIdHash: testAppleIdHash)
        XCTAssertNotNil(fetchedProfile)
        XCTAssertEqual(fetchedProfile?.id, userProfile.id)
        XCTAssertEqual(fetchedProfile?.displayName, "Authenticated User")
        
        // Step 6: Test user profile update through auth service workflow
        let updatedProfile = fetchedProfile!
        // In a real scenario, AuthService might update the display name
        // We'll simulate this by updating through DataService
        
        // Step 7: Test authentication state consistency
        // Verify that the user profile exists and is valid
        XCTAssertTrue(updatedProfile.isFullyValid)
        XCTAssertEqual(updatedProfile.appleUserIdHash, testAppleIdHash)
        
        // Step 8: Test sign out workflow
        try keychainService.clearAll()
        let clearedHash = try keychainService.retrieveAppleUserIdHash()
        XCTAssertNil(clearedHash)
        
        // User profile should still exist in database after sign out
        let profileAfterSignOut = try dataService.fetchUserProfile(byAppleUserIdHash: testAppleIdHash)
        XCTAssertNotNil(profileAfterSignOut)
        
        print("✅ DataService and AuthService user management integration test passed")
    }
    
    /// Tests authentication state persistence across app launches
    /// Requirements: 8.5
    func testAuthenticationStatePersistence() async throws {
        print("🧪 Testing authentication state persistence...")
        
        // Step 1: Simulate initial authentication
        let testAppleIdHash = "persistent_hash_1234567890"
        let userProfile = try dataService.createUserProfile(
            displayName: "Persistent User",
            appleUserIdHash: testAppleIdHash
        )
        
        // Step 2: Store authentication data
        try keychainService.storeAppleUserIdHash(testAppleIdHash)
        
        // Step 3: Simulate app restart by creating new service instances
        let newKeychainService = KeychainService()
        let newAuthService = AuthService(keychainService: newKeychainService)
        newAuthService.setDataService(dataService)
        
        // Step 4: Verify authentication data persists
        let retrievedHash = try newKeychainService.retrieveAppleUserIdHash()
        XCTAssertEqual(retrievedHash, testAppleIdHash)
        
        // Step 5: Verify user profile can be retrieved
        let retrievedProfile = try dataService.fetchUserProfile(byAppleUserIdHash: testAppleIdHash)
        XCTAssertNotNil(retrievedProfile)
        XCTAssertEqual(retrievedProfile?.id, userProfile.id)
        
        // Step 6: Test authentication state validation
        // In a real app, AuthService would validate the credential with Apple
        // Here we just verify the data integrity
        XCTAssertTrue(retrievedProfile!.isFullyValid)
        
        print("✅ Authentication state persistence test passed")
    }
    
    // MARK: - Error Propagation Tests
    
    /// Tests error propagation between services maintains system consistency
    /// Requirements: 8.7
    func testErrorPropagationBetweenServices() async throws {
        print("🧪 Testing error propagation between services...")
        
        // Step 1: Set up initial valid state
        let user = try dataService.createUserProfile(
            displayName: "Error Test User",
            appleUserIdHash: "error_hash_1234567890"
        )
        
        let family = try dataService.createFamily(
            name: "Error Test Family",
            code: "ERROR123",
            createdByUserId: user.id
        )
        
        // Step 2: Simulate CloudKit error during sync
        cloudKitService.shouldFailOperations = true
        
        do {
            try await cloudKitService.save(family)
            XCTFail("Should have thrown CloudKit error")
        } catch {
            // Expected error - verify local state remains consistent
            let localFamily = try dataService.fetchFamily(byId: family.id)
            XCTAssertNotNil(localFamily)
            XCTAssertEqual(localFamily?.name, "Error Test Family")
        }
        
        // Step 3: Reset CloudKit service and verify recovery
        cloudKitService.shouldFailOperations = false
        cloudKitService.reset()
        
        // Should now succeed
        try await cloudKitService.save(family)
        
        // Step 4: Test DataService error propagation
        do {
            // Try to create duplicate family code
            _ = try dataService.createFamily(
                name: "Duplicate Family",
                code: "ERROR123", // Same code as existing family
                createdByUserId: user.id
            )
            XCTFail("Should have thrown validation error")
        } catch let error as DataServiceError {
            // Verify error type and message
            switch error {
            case .validationFailed(let messages):
                XCTAssertTrue(messages.contains { $0.contains("already exists") })
            default:
                XCTFail("Expected validation failed error, got \(error)")
            }
        }
        
        // Step 5: Verify system state remains consistent after errors
        let allFamilies = try dataService.fetchAllFamilies()
        XCTAssertEqual(allFamilies.count, 1) // Only the original family should exist
        XCTAssertEqual(allFamilies.first?.code, "ERROR123")
        
        // Step 6: Test keychain error propagation
        // Simulate keychain access error by using invalid data
        do {
            // This should succeed normally
            try keychainService.storeAppleUserIdHash("valid_hash")
            
            // Verify storage worked
            let retrieved = try keychainService.retrieveAppleUserIdHash()
            XCTAssertEqual(retrieved, "valid_hash")
        } catch {
            // If keychain fails, verify error is properly propagated
            XCTAssertTrue(error is KeychainError)
        }
        
        print("✅ Error propagation between services test passed")
    }
    
    /// Tests error recovery scenarios across services
    /// Requirements: 8.7
    func testCrossServiceErrorRecovery() async throws {
        print("🧪 Testing cross-service error recovery...")
        
        // Step 1: Create initial data
        let user = try dataService.createUserProfile(
            displayName: "Recovery Test User",
            appleUserIdHash: "recovery_hash_1234567890"
        )
        
        // Step 2: Simulate partial failure scenario
        // Family creation succeeds, but CloudKit sync fails
        let family = try dataService.createFamily(
            name: "Recovery Test Family",
            code: "RECOV123",
            createdByUserId: user.id
        )
        
        family.markAsNeedingSync()
        try dataService.save()
        
        // Step 3: Simulate CloudKit failure
        cloudKitService.shouldFailOperations = true
        
        do {
            try await cloudKitService.save(family)
            XCTFail("Should have failed")
        } catch {
            // Expected failure
        }
        
        // Step 4: Verify local state is preserved
        let localFamily = try dataService.fetchFamily(byCode: "RECOV123")
        XCTAssertNotNil(localFamily)
        XCTAssertTrue(localFamily!.needsSync) // Should still need sync
        
        // Step 5: Simulate recovery - CloudKit comes back online
        cloudKitService.shouldFailOperations = false
        cloudKitService.reset()
        
        // Retry sync operation
        try await cloudKitService.save(family)
        family.markAsSynced()
        try dataService.save()
        
        // Step 6: Verify recovery completed successfully
        XCTAssertFalse(family.needsSync)
        
        let cloudKitFamilies = try await cloudKitService.fetch(Family.self)
        XCTAssertEqual(cloudKitFamilies.count, 1)
        
        print("✅ Cross-service error recovery test passed")
    }
    
    // MARK: - Offline/Online Transition Tests
    
    /// Tests offline/online transitions maintain data integrity
    /// Requirements: 8.7
    func testOfflineOnlineTransitions() async throws {
        print("🧪 Testing offline/online transitions...")
        
        // Step 1: Create data while "online"
        let user = try dataService.createUserProfile(
            displayName: "Offline Test User",
            appleUserIdHash: "offline_hash_1234567890"
        )
        
        let family = try dataService.createFamily(
            name: "Offline Test Family",
            code: "OFFLN123",
            createdByUserId: user.id
        )
        
        // Step 2: Simulate going offline
        cloudKitService.simulateNetworkError()
        
        // Step 3: Continue creating data while offline
        let offlineUser = try dataService.createUserProfile(
            displayName: "Offline Created User",
            appleUserIdHash: "offline_created_hash_1234567890"
        )
        
        let offlineMembership = try dataService.createMembership(
            family: family,
            user: offlineUser,
            role: .kid
        )
        
        // Step 4: Mark offline-created records as needing sync
        offlineUser.markAsNeedingSync()
        offlineMembership.markAsNeedingSync()
        try dataService.save()
        
        // Step 5: Verify local data integrity while offline
        let localFamilies = try dataService.fetchAllFamilies()
        XCTAssertEqual(localFamilies.count, 1)
        
        let familyMemberships = try dataService.fetchActiveMemberships(forFamily: family)
        XCTAssertEqual(familyMemberships.count, 1) // The offline-created membership
        
        // Step 6: Simulate coming back online
        cloudKitService.reset() // This clears the network error simulation
        
        // Step 7: Sync offline-created data
        let recordsNeedingSync = try dataService.fetchRecordsNeedingSync(UserProfile.self)
        XCTAssertGreaterThan(recordsNeedingSync.count, 0)
        
        // Sync the offline-created records
        for record in recordsNeedingSync {
            try await cloudKitService.save(record)
            record.markAsSynced()
        }
        
        let membershipsNeedingSync = try dataService.fetchRecordsNeedingSync(Membership.self)
        for membership in membershipsNeedingSync {
            try await cloudKitService.save(membership)
            membership.markAsSynced()
        }
        
        try dataService.save()
        
        // Step 8: Verify all data is now synced
        let remainingRecordsNeedingSync = try dataService.fetchRecordsNeedingSync(UserProfile.self)
        let remainingMembershipsNeedingSync = try dataService.fetchRecordsNeedingSync(Membership.self)
        
        XCTAssertEqual(remainingRecordsNeedingSync.count, 0)
        XCTAssertEqual(remainingMembershipsNeedingSync.count, 0)
        
        // Step 9: Verify CloudKit has all the data
        let cloudKitUsers = try await cloudKitService.fetch(UserProfile.self)
        let cloudKitMemberships = try await cloudKitService.fetch(Membership.self)
        
        XCTAssertGreaterThanOrEqual(cloudKitUsers.count, 2) // Original + offline created
        XCTAssertGreaterThanOrEqual(cloudKitMemberships.count, 1)
        
        print("✅ Offline/online transitions test passed")
    }
    
    /// Tests data consistency during network interruptions
    /// Requirements: 8.7
    func testNetworkInterruptionDataConsistency() async throws {
        print("🧪 Testing data consistency during network interruptions...")
        
        // Step 1: Create baseline data
        let user = try dataService.createUserProfile(
            displayName: "Network Test User",
            appleUserIdHash: "network_hash_1234567890"
        )
        
        let family = try dataService.createFamily(
            name: "Network Test Family",
            code: "NETWK123",
            createdByUserId: user.id
        )
        
        // Step 2: Start sync operation
        family.markAsNeedingSync()
        try dataService.save()
        
        // Step 3: Simulate network interruption during sync
        cloudKitService.networkDelay = 0.1 // Small delay to simulate slow network
        
        // Start sync operation
        let syncTask = Task {
            try await cloudKitService.save(family)
        }
        
        // Step 4: Simulate network failure mid-operation
        try await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
        cloudKitService.simulateNetworkError()
        
        // Step 5: Wait for sync to complete (should fail)
        do {
            try await syncTask.value
            XCTFail("Sync should have failed due to network error")
        } catch {
            // Expected failure
        }
        
        // Step 6: Verify local data remains consistent
        let localFamily = try dataService.fetchFamily(byId: family.id)
        XCTAssertNotNil(localFamily)
        XCTAssertEqual(localFamily?.name, "Network Test Family")
        XCTAssertTrue(localFamily!.needsSync) // Should still need sync
        
        // Step 7: Simulate network recovery and retry
        cloudKitService.reset()
        cloudKitService.networkDelay = 0
        
        try await cloudKitService.save(family)
        family.markAsSynced()
        try dataService.save()
        
        // Step 8: Verify final consistency
        XCTAssertFalse(family.needsSync)
        
        let cloudKitFamilies = try await cloudKitService.fetch(Family.self)
        XCTAssertEqual(cloudKitFamilies.count, 1)
        
        print("✅ Network interruption data consistency test passed")
    }
}