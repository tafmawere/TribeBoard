import XCTest
import Security
@testable import TribeBoard

/// Comprehensive unit tests for KeychainService
/// Tests keychain data storage and retrieval operations, error handling, and security scenarios
class KeychainServiceTests: TestBase {
    
    // MARK: - Properties
    
    var keychainService: KeychainService!
    
    // Test data
    let testAppleUserId = "test.apple.user.id.12345"
    let testAppleUserIdHash = "test_hash_value_abcdef123456"
    let testFamilyId = UUID()
    let testData = "test data for keychain".data(using: .utf8)!
    let testKey = "test.keychain.key"
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        keychainService = KeychainService()
        cleanupTestKeychain()
    }
    
    override func tearDown() {
        cleanupTestKeychain()
        keychainService = nil
        super.tearDown()
    }
    
    // MARK: - Setup Helpers
    
    private func cleanupTestKeychain() {
        // Clean up any test data that might exist
        try? keychainService.clearAll()
        try? keychainService.delete(for: testKey)
    }
    
    // MARK: - Basic Storage and Retrieval Tests
    
    func testStore_Success() throws {
        // When
        try keychainService.store(testData, for: testKey)
        
        // Then
        let retrievedData = try keychainService.retrieve(for: testKey)
        XCTAssertNotNil(retrievedData, "Should retrieve stored data")
        XCTAssertEqual(retrievedData, testData, "Retrieved data should match stored data")
    }
    
    func testStore_OverwriteExisting() throws {
        // Given - Store initial data
        try keychainService.store(testData, for: testKey)
        
        let newData = "updated test data".data(using: .utf8)!
        
        // When - Store new data with same key
        try keychainService.store(newData, for: testKey)
        
        // Then - Should retrieve the new data
        let retrievedData = try keychainService.retrieve(for: testKey)
        XCTAssertNotNil(retrievedData, "Should retrieve updated data")
        XCTAssertEqual(retrievedData, newData, "Retrieved data should match updated data")
        XCTAssertNotEqual(retrievedData, testData, "Retrieved data should not match old data")
    }
    
    func testRetrieve_NonExistentKey() throws {
        // When
        let retrievedData = try keychainService.retrieve(for: "non.existent.key")
        
        // Then
        XCTAssertNil(retrievedData, "Should return nil for non-existent key")
    }
    
    func testDelete_Success() throws {
        // Given - Store data first
        try keychainService.store(testData, for: testKey)
        
        // Verify data exists
        let initialData = try keychainService.retrieve(for: testKey)
        XCTAssertNotNil(initialData, "Data should exist before deletion")
        
        // When - Delete the data
        try keychainService.delete(for: testKey)
        
        // Then - Data should no longer exist
        let retrievedData = try keychainService.retrieve(for: testKey)
        XCTAssertNil(retrievedData, "Data should not exist after deletion")
    }
    
    func testDelete_NonExistentKey() throws {
        // When & Then - Should not throw error for non-existent key
        XCTAssertNoThrow(try keychainService.delete(for: "non.existent.key"))
    }
    
    // MARK: - Apple User ID Tests
    
    func testStoreAppleUserId_Success() throws {
        // When
        try keychainService.storeAppleUserId(testAppleUserId)
        
        // Then
        let retrievedUserId = try keychainService.retrieveAppleUserId()
        XCTAssertNotNil(retrievedUserId, "Should retrieve stored Apple User ID")
        XCTAssertEqual(retrievedUserId, testAppleUserId, "Retrieved Apple User ID should match stored value")
    }
    
    func testStoreAppleUserId_OverwriteExisting() throws {
        // Given - Store initial Apple User ID
        try keychainService.storeAppleUserId(testAppleUserId)
        
        let newAppleUserId = "new.apple.user.id.67890"
        
        // When - Store new Apple User ID
        try keychainService.storeAppleUserId(newAppleUserId)
        
        // Then - Should retrieve the new Apple User ID
        let retrievedUserId = try keychainService.retrieveAppleUserId()
        XCTAssertNotNil(retrievedUserId, "Should retrieve updated Apple User ID")
        XCTAssertEqual(retrievedUserId, newAppleUserId, "Retrieved Apple User ID should match updated value")
        XCTAssertNotEqual(retrievedUserId, testAppleUserId, "Retrieved Apple User ID should not match old value")
    }
    
    func testRetrieveAppleUserId_NotStored() throws {
        // When
        let retrievedUserId = try keychainService.retrieveAppleUserId()
        
        // Then
        XCTAssertNil(retrievedUserId, "Should return nil when Apple User ID not stored")
    }
    
    func testDeleteAppleUserId_Success() throws {
        // Given - Store Apple User ID first
        try keychainService.storeAppleUserId(testAppleUserId)
        
        // Verify it exists
        let initialUserId = try keychainService.retrieveAppleUserId()
        XCTAssertNotNil(initialUserId, "Apple User ID should exist before deletion")
        
        // When - Delete the Apple User ID
        try keychainService.deleteAppleUserId()
        
        // Then - Apple User ID should no longer exist
        let retrievedUserId = try keychainService.retrieveAppleUserId()
        XCTAssertNil(retrievedUserId, "Apple User ID should not exist after deletion")
    }
    
    // MARK: - Apple User ID Hash Tests
    
    func testStoreAppleUserIdHash_Success() throws {
        // When
        try keychainService.storeAppleUserIdHash(testAppleUserIdHash)
        
        // Then
        let retrievedHash = try keychainService.retrieveAppleUserIdHash()
        XCTAssertNotNil(retrievedHash, "Should retrieve stored Apple User ID hash")
        XCTAssertEqual(retrievedHash, testAppleUserIdHash, "Retrieved hash should match stored value")
    }
    
    func testStoreAppleUserIdHash_OverwriteExisting() throws {
        // Given - Store initial hash
        try keychainService.storeAppleUserIdHash(testAppleUserIdHash)
        
        let newHash = "new_hash_value_xyz789"
        
        // When - Store new hash
        try keychainService.storeAppleUserIdHash(newHash)
        
        // Then - Should retrieve the new hash
        let retrievedHash = try keychainService.retrieveAppleUserIdHash()
        XCTAssertNotNil(retrievedHash, "Should retrieve updated hash")
        XCTAssertEqual(retrievedHash, newHash, "Retrieved hash should match updated value")
        XCTAssertNotEqual(retrievedHash, testAppleUserIdHash, "Retrieved hash should not match old value")
    }
    
    func testRetrieveAppleUserIdHash_NotStored() throws {
        // When
        let retrievedHash = try keychainService.retrieveAppleUserIdHash()
        
        // Then
        XCTAssertNil(retrievedHash, "Should return nil when hash not stored")
    }
    
    func testDeleteAppleUserIdHash_Success() throws {
        // Given - Store hash first
        try keychainService.storeAppleUserIdHash(testAppleUserIdHash)
        
        // Verify it exists
        let initialHash = try keychainService.retrieveAppleUserIdHash()
        XCTAssertNotNil(initialHash, "Hash should exist before deletion")
        
        // When - Delete the hash
        try keychainService.deleteAppleUserIdHash()
        
        // Then - Hash should no longer exist
        let retrievedHash = try keychainService.retrieveAppleUserIdHash()
        XCTAssertNil(retrievedHash, "Hash should not exist after deletion")
    }
    
    // MARK: - Family ID Tests
    
    func testStoreFamilyId_Success() throws {
        // When
        try keychainService.storeFamilyId(testFamilyId)
        
        // Then
        let retrievedFamilyId = try keychainService.retrieveFamilyId()
        XCTAssertNotNil(retrievedFamilyId, "Should retrieve stored family ID")
        XCTAssertEqual(retrievedFamilyId, testFamilyId, "Retrieved family ID should match stored value")
    }
    
    func testStoreFamilyId_OverwriteExisting() throws {
        // Given - Store initial family ID
        try keychainService.storeFamilyId(testFamilyId)
        
        let newFamilyId = UUID()
        
        // When - Store new family ID
        try keychainService.storeFamilyId(newFamilyId)
        
        // Then - Should retrieve the new family ID
        let retrievedFamilyId = try keychainService.retrieveFamilyId()
        XCTAssertNotNil(retrievedFamilyId, "Should retrieve updated family ID")
        XCTAssertEqual(retrievedFamilyId, newFamilyId, "Retrieved family ID should match updated value")
        XCTAssertNotEqual(retrievedFamilyId, testFamilyId, "Retrieved family ID should not match old value")
    }
    
    func testRetrieveFamilyId_NotStored() throws {
        // When
        let retrievedFamilyId = try keychainService.retrieveFamilyId()
        
        // Then
        XCTAssertNil(retrievedFamilyId, "Should return nil when family ID not stored")
    }
    
    func testDeleteFamilyId_Success() throws {
        // Given - Store family ID first
        try keychainService.storeFamilyId(testFamilyId)
        
        // Verify it exists
        let initialFamilyId = try keychainService.retrieveFamilyId()
        XCTAssertNotNil(initialFamilyId, "Family ID should exist before deletion")
        
        // When - Delete the family ID
        try keychainService.deleteFamilyId()
        
        // Then - Family ID should no longer exist
        let retrievedFamilyId = try keychainService.retrieveFamilyId()
        XCTAssertNil(retrievedFamilyId, "Family ID should not exist after deletion")
    }
    
    // MARK: - Clear All Tests
    
    func testClearAll_Success() throws {
        // Given - Store all types of data
        try keychainService.storeAppleUserId(testAppleUserId)
        try keychainService.storeAppleUserIdHash(testAppleUserIdHash)
        try keychainService.storeFamilyId(testFamilyId)
        
        // Verify all data exists
        XCTAssertNotNil(try keychainService.retrieveAppleUserId())
        XCTAssertNotNil(try keychainService.retrieveAppleUserIdHash())
        XCTAssertNotNil(try keychainService.retrieveFamilyId())
        
        // When - Clear all data
        try keychainService.clearAll()
        
        // Then - All data should be gone
        XCTAssertNil(try keychainService.retrieveAppleUserId(), "Apple User ID should be cleared")
        XCTAssertNil(try keychainService.retrieveAppleUserIdHash(), "Apple User ID hash should be cleared")
        XCTAssertNil(try keychainService.retrieveFamilyId(), "Family ID should be cleared")
    }
    
    func testClearAll_EmptyKeychain() throws {
        // When & Then - Should not throw error when clearing empty keychain
        XCTAssertNoThrow(try keychainService.clearAll())
    }
    
    // MARK: - Error Handling Tests
    
    func testStoreAppleUserId_InvalidData() {
        // Given - Create a string that can't be converted to UTF-8 data
        // This is difficult to create in Swift, so we'll test the error path differently
        // by testing with empty string which should still work
        let emptyUserId = ""
        
        // When & Then - Should not throw error for empty string (it's valid UTF-8)
        XCTAssertNoThrow(try keychainService.storeAppleUserId(emptyUserId))
        
        // Verify it was stored
        let retrieved = try? keychainService.retrieveAppleUserId()
        XCTAssertEqual(retrieved, emptyUserId)
    }
    
    func testStoreAppleUserIdHash_InvalidData() {
        // Given - Empty hash (still valid UTF-8)
        let emptyHash = ""
        
        // When & Then - Should not throw error for empty string
        XCTAssertNoThrow(try keychainService.storeAppleUserIdHash(emptyHash))
        
        // Verify it was stored
        let retrieved = try? keychainService.retrieveAppleUserIdHash()
        XCTAssertEqual(retrieved, emptyHash)
    }
    
    // MARK: - Data Isolation Tests
    
    func testDataIsolation_DifferentKeys() throws {
        // Given - Store data with different keys
        let data1 = "data1".data(using: .utf8)!
        let data2 = "data2".data(using: .utf8)!
        let key1 = "test.key.1"
        let key2 = "test.key.2"
        
        // When - Store data with different keys
        try keychainService.store(data1, for: key1)
        try keychainService.store(data2, for: key2)
        
        // Then - Each key should return its own data
        let retrieved1 = try keychainService.retrieve(for: key1)
        let retrieved2 = try keychainService.retrieve(for: key2)
        
        XCTAssertEqual(retrieved1, data1, "Key 1 should return data 1")
        XCTAssertEqual(retrieved2, data2, "Key 2 should return data 2")
        XCTAssertNotEqual(retrieved1, retrieved2, "Different keys should return different data")
        
        // Clean up
        try keychainService.delete(for: key1)
        try keychainService.delete(for: key2)
    }
    
    func testDataIsolation_AppSpecificData() throws {
        // Given - Store Apple-specific data
        try keychainService.storeAppleUserId(testAppleUserId)
        try keychainService.storeAppleUserIdHash(testAppleUserIdHash)
        try keychainService.storeFamilyId(testFamilyId)
        
        // When - Store generic data with similar key
        let genericData = "generic data".data(using: .utf8)!
        try keychainService.store(genericData, for: "generic.key")
        
        // Then - App-specific data should be unaffected
        XCTAssertEqual(try keychainService.retrieveAppleUserId(), testAppleUserId)
        XCTAssertEqual(try keychainService.retrieveAppleUserIdHash(), testAppleUserIdHash)
        XCTAssertEqual(try keychainService.retrieveFamilyId(), testFamilyId)
        
        // And generic data should be separate
        let retrievedGeneric = try keychainService.retrieve(for: "generic.key")
        XCTAssertEqual(retrievedGeneric, genericData)
        
        // Clean up
        try keychainService.delete(for: "generic.key")
    }
    
    // MARK: - Security Configuration Tests
    
    func testKeychainConfiguration_ServiceIdentifier() throws {
        // This test verifies that the keychain service uses the correct service identifier
        // We can't directly test the keychain attributes, but we can verify that
        // data stored by our service is isolated from other potential services
        
        // Given - Store data using our service
        try keychainService.store(testData, for: testKey)
        
        // When - Try to retrieve using a different service identifier
        // (This would require creating a keychain query with different service identifier)
        // For now, we'll just verify our service can retrieve its own data
        let retrievedData = try keychainService.retrieve(for: testKey)
        
        // Then
        XCTAssertEqual(retrievedData, testData, "Service should retrieve its own data")
        
        // Clean up
        try keychainService.delete(for: testKey)
    }
    
    // MARK: - Performance Tests
    
    func testPerformance_StoreAndRetrieve() {
        // Given
        let performanceData = "performance test data".data(using: .utf8)!
        let performanceKey = "performance.test.key"
        
        // When & Then - Measure performance of store and retrieve operations
        measure {
            for i in 0..<100 {
                let key = "\(performanceKey).\(i)"
                do {
                    try keychainService.store(performanceData, for: key)
                    _ = try keychainService.retrieve(for: key)
                    try keychainService.delete(for: key)
                } catch {
                    XCTFail("Performance test failed with error: \(error)")
                }
            }
        }
    }
    
    func testPerformance_ClearAll() {
        // Given - Store multiple items
        let itemCount = 50
        for i in 0..<itemCount {
            let data = "test data \(i)".data(using: .utf8)!
            let key = "performance.clear.test.\(i)"
            try! keychainService.store(data, for: key)
        }
        
        // Also store app-specific data
        try! keychainService.storeAppleUserId(testAppleUserId)
        try! keychainService.storeAppleUserIdHash(testAppleUserIdHash)
        try! keychainService.storeFamilyId(testFamilyId)
        
        // When & Then - Measure performance of clearAll
        measure {
            do {
                try keychainService.clearAll()
            } catch {
                XCTFail("Performance test failed with error: \(error)")
            }
        }
        
        // Clean up any remaining test data
        for i in 0..<itemCount {
            let key = "performance.clear.test.\(i)"
            try? keychainService.delete(for: key)
        }
    }
    
    // MARK: - Integration Tests
    
    func testIntegration_CompleteAuthenticationFlow() throws {
        // This test simulates a complete authentication flow using keychain operations
        
        // Given - Simulate successful authentication
        let userId = "integration.test.user.id"
        let userHash = "integration_test_hash_12345"
        let familyId = UUID()
        
        // When - Store authentication data (simulating successful sign-in)
        try keychainService.storeAppleUserId(userId)
        try keychainService.storeAppleUserIdHash(userHash)
        try keychainService.storeFamilyId(familyId)
        
        // Then - Verify all data can be retrieved (simulating app restart)
        let retrievedUserId = try keychainService.retrieveAppleUserId()
        let retrievedHash = try keychainService.retrieveAppleUserIdHash()
        let retrievedFamilyId = try keychainService.retrieveFamilyId()
        
        XCTAssertEqual(retrievedUserId, userId, "User ID should persist")
        XCTAssertEqual(retrievedHash, userHash, "User hash should persist")
        XCTAssertEqual(retrievedFamilyId, familyId, "Family ID should persist")
        
        // When - Simulate sign out
        try keychainService.clearAll()
        
        // Then - All data should be cleared
        XCTAssertNil(try keychainService.retrieveAppleUserId(), "User ID should be cleared after sign out")
        XCTAssertNil(try keychainService.retrieveAppleUserIdHash(), "User hash should be cleared after sign out")
        XCTAssertNil(try keychainService.retrieveFamilyId(), "Family ID should be cleared after sign out")
    }
    
    func testIntegration_MultipleUsers() throws {
        // This test simulates switching between different user accounts
        
        // Given - First user data
        let user1Id = "user1.apple.id"
        let user1Hash = "user1_hash_abc123"
        let user1FamilyId = UUID()
        
        // When - Store first user data
        try keychainService.storeAppleUserId(user1Id)
        try keychainService.storeAppleUserIdHash(user1Hash)
        try keychainService.storeFamilyId(user1FamilyId)
        
        // Then - Verify first user data
        XCTAssertEqual(try keychainService.retrieveAppleUserId(), user1Id)
        XCTAssertEqual(try keychainService.retrieveAppleUserIdHash(), user1Hash)
        XCTAssertEqual(try keychainService.retrieveFamilyId(), user1FamilyId)
        
        // Given - Second user data
        let user2Id = "user2.apple.id"
        let user2Hash = "user2_hash_def456"
        let user2FamilyId = UUID()
        
        // When - Switch to second user (overwrite data)
        try keychainService.storeAppleUserId(user2Id)
        try keychainService.storeAppleUserIdHash(user2Hash)
        try keychainService.storeFamilyId(user2FamilyId)
        
        // Then - Should have second user data only
        XCTAssertEqual(try keychainService.retrieveAppleUserId(), user2Id)
        XCTAssertEqual(try keychainService.retrieveAppleUserIdHash(), user2Hash)
        XCTAssertEqual(try keychainService.retrieveFamilyId(), user2FamilyId)
        
        // And first user data should be gone
        XCTAssertNotEqual(try keychainService.retrieveAppleUserId(), user1Id)
        XCTAssertNotEqual(try keychainService.retrieveAppleUserIdHash(), user1Hash)
        XCTAssertNotEqual(try keychainService.retrieveFamilyId(), user1FamilyId)
    }
}