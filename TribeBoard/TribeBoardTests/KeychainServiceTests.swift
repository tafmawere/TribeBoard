import XCTest
@testable import TribeBoard

final class KeychainServiceTests: XCTestCase {
    
    var keychainService: KeychainService!
    let testKey = "com.tribeboard.test.key"
    let testData = "test data".data(using: .utf8)!
    
    override func setUp() {
        super.setUp()
        keychainService = KeychainService()
        
        // Clean up any existing test data
        try? keychainService.delete(for: testKey)
        try? keychainService.deleteAppleUserIdHash()
        try? keychainService.deleteFamilyId()
    }
    
    override func tearDown() {
        // Clean up test data
        try? keychainService.delete(for: testKey)
        try? keychainService.deleteAppleUserIdHash()
        try? keychainService.deleteFamilyId()
        
        keychainService = nil
        super.tearDown()
    }
    
    // MARK: - Basic Store/Retrieve/Delete Tests
    
    func testStoreAndRetrieveData() throws {
        // Store data
        try keychainService.store(testData, for: testKey)
        
        // Retrieve data
        let retrievedData = try keychainService.retrieve(for: testKey)
        
        // Verify data matches
        XCTAssertEqual(retrievedData, testData)
    }
    
    func testRetrieveNonExistentData() throws {
        // Try to retrieve data that doesn't exist
        let retrievedData = try keychainService.retrieve(for: "nonexistent.key")
        
        // Should return nil
        XCTAssertNil(retrievedData)
    }
    
    func testDeleteData() throws {
        // Store data first
        try keychainService.store(testData, for: testKey)
        
        // Verify it exists
        let retrievedData = try keychainService.retrieve(for: testKey)
        XCTAssertNotNil(retrievedData)
        
        // Delete the data
        try keychainService.delete(for: testKey)
        
        // Verify it's gone
        let deletedData = try keychainService.retrieve(for: testKey)
        XCTAssertNil(deletedData)
    }
    
    func testDeleteNonExistentData() throws {
        // Deleting non-existent data should not throw
        XCTAssertNoThrow(try keychainService.delete(for: "nonexistent.key"))
    }
    
    func testOverwriteExistingData() throws {
        let newTestData = "new test data".data(using: .utf8)!
        
        // Store initial data
        try keychainService.store(testData, for: testKey)
        
        // Overwrite with new data
        try keychainService.store(newTestData, for: testKey)
        
        // Retrieve and verify new data
        let retrievedData = try keychainService.retrieve(for: testKey)
        XCTAssertEqual(retrievedData, newTestData)
        XCTAssertNotEqual(retrievedData, testData)
    }
    
    // MARK: - Apple User ID Hash Tests
    
    func testStoreAndRetrieveAppleUserIdHash() throws {
        let testHash = "test.apple.user.id.hash"
        
        // Store hash
        try keychainService.storeAppleUserIdHash(testHash)
        
        // Retrieve hash
        let retrievedHash = try keychainService.retrieveAppleUserIdHash()
        
        // Verify hash matches
        XCTAssertEqual(retrievedHash, testHash)
    }
    
    func testRetrieveNonExistentAppleUserIdHash() throws {
        // Try to retrieve hash that doesn't exist
        let retrievedHash = try keychainService.retrieveAppleUserIdHash()
        
        // Should return nil
        XCTAssertNil(retrievedHash)
    }
    
    func testDeleteAppleUserIdHash() throws {
        let testHash = "test.apple.user.id.hash"
        
        // Store hash first
        try keychainService.storeAppleUserIdHash(testHash)
        
        // Verify it exists
        let retrievedHash = try keychainService.retrieveAppleUserIdHash()
        XCTAssertEqual(retrievedHash, testHash)
        
        // Delete the hash
        try keychainService.deleteAppleUserIdHash()
        
        // Verify it's gone
        let deletedHash = try keychainService.retrieveAppleUserIdHash()
        XCTAssertNil(deletedHash)
    }
    
    // MARK: - Family ID Tests
    
    func testStoreAndRetrieveFamilyId() throws {
        let testFamilyId = UUID()
        
        // Store family ID
        try keychainService.storeFamilyId(testFamilyId)
        
        // Retrieve family ID
        let retrievedFamilyId = try keychainService.retrieveFamilyId()
        
        // Verify family ID matches
        XCTAssertEqual(retrievedFamilyId, testFamilyId)
    }
    
    func testRetrieveNonExistentFamilyId() throws {
        // Try to retrieve family ID that doesn't exist
        let retrievedFamilyId = try keychainService.retrieveFamilyId()
        
        // Should return nil
        XCTAssertNil(retrievedFamilyId)
    }
    
    func testDeleteFamilyId() throws {
        let testFamilyId = UUID()
        
        // Store family ID first
        try keychainService.storeFamilyId(testFamilyId)
        
        // Verify it exists
        let retrievedFamilyId = try keychainService.retrieveFamilyId()
        XCTAssertEqual(retrievedFamilyId, testFamilyId)
        
        // Delete the family ID
        try keychainService.deleteFamilyId()
        
        // Verify it's gone
        let deletedFamilyId = try keychainService.retrieveFamilyId()
        XCTAssertNil(deletedFamilyId)
    }
    
    // MARK: - Clear All Tests
    
    func testClearAll() throws {
        let testHash = "test.apple.user.id.hash"
        let testFamilyId = UUID()
        
        // Store both hash and family ID
        try keychainService.storeAppleUserIdHash(testHash)
        try keychainService.storeFamilyId(testFamilyId)
        
        // Verify both exist
        XCTAssertEqual(try keychainService.retrieveAppleUserIdHash(), testHash)
        XCTAssertEqual(try keychainService.retrieveFamilyId(), testFamilyId)
        
        // Clear all
        try keychainService.clearAll()
        
        // Verify both are gone
        XCTAssertNil(try keychainService.retrieveAppleUserIdHash())
        XCTAssertNil(try keychainService.retrieveFamilyId())
    }
    
    // MARK: - Error Handling Tests
    
    @MainActor func testInvalidDataError() {
        // Test storing invalid data should be handled gracefully
        // This test verifies that our convenience methods handle encoding properly
        let testHash = "test.hash"
        XCTAssertNoThrow(try keychainService.storeAppleUserIdHash(testHash))
    }
    
    @MainActor func testKeychainErrorDescriptions() {
        let itemNotFoundError = KeychainService.KeychainError.itemNotFound
        let duplicateItemError = KeychainService.KeychainError.duplicateItem
        let invalidDataError = KeychainService.KeychainError.invalidData
        let unexpectedError = KeychainService.KeychainError.unexpectedError(-1)
        
        XCTAssertEqual(itemNotFoundError.errorDescription, "Item not found in Keychain")
        XCTAssertEqual(duplicateItemError.errorDescription, "Item already exists in Keychain")
        XCTAssertEqual(invalidDataError.errorDescription, "Invalid data format")
        XCTAssertEqual(unexpectedError.errorDescription, "Keychain error: -1")
    }
    
    // MARK: - Performance Tests
    
    func testKeychainPerformance() throws {
        let testData = "performance test data".data(using: .utf8)!
        
        measure {
            do {
                try keychainService.store(testData, for: testKey)
                _ = try keychainService.retrieve(for: testKey)
                try keychainService.delete(for: testKey)
            } catch {
                XCTFail("Performance test failed with error: \(error)")
            }
        }
    }
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentAccess() throws {
        let expectation = XCTestExpectation(description: "Concurrent keychain operations")
        expectation.expectedFulfillmentCount = 10
        
        let queue = DispatchQueue.global(qos: .userInitiated)
        
        for i in 0..<10 {
            queue.async {
                do {
                    let key = "concurrent.test.\(i)"
                    let data = "test data \(i)".data(using: .utf8)!
                    
                    try self.keychainService.store(data, for: key)
                    let retrieved = try self.keychainService.retrieve(for: key)
                    XCTAssertEqual(retrieved, data)
                    try self.keychainService.delete(for: key)
                    
                    expectation.fulfill()
                } catch {
                    XCTFail("Concurrent test failed with error: \(error)")
                }
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
    }
}