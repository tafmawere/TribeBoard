import XCTest
@testable import TribeBoard

class MockKeychainServiceTests: XCTestCase {
    
    var mockKeychain: MockKeychainService!
    
    override func setUp() {
        super.setUp()
        mockKeychain = MockKeychainService()
    }
    
    override func tearDown() {
        mockKeychain = nil
        super.tearDown()
    }
    
    // MARK: - Basic Storage Tests
    
    func testStoreAndRetrieveData() throws {
        // Given
        let testData = "test data".data(using: .utf8)!
        let testKey = "test_key"
        
        // When
        try mockKeychain.store(testData, for: testKey)
        let retrievedData = try mockKeychain.retrieve(for: testKey)
        
        // Then
        XCTAssertEqual(retrievedData, testData)
        XCTAssertEqual(mockKeychain.storeCallCount, 1)
        XCTAssertEqual(mockKeychain.retrieveCallCount, 1)
    }
    
    func testRetrieveNonExistentData() throws {
        // Given
        let testKey = "non_existent_key"
        
        // When
        let retrievedData = try mockKeychain.retrieve(for: testKey)
        
        // Then
        XCTAssertNil(retrievedData)
        XCTAssertEqual(mockKeychain.retrieveCallCount, 1)
    }
    
    func testDeleteData() throws {
        // Given
        let testData = "test data".data(using: .utf8)!
        let testKey = "test_key"
        try mockKeychain.store(testData, for: testKey)
        
        // When
        try mockKeychain.delete(for: testKey)
        let retrievedData = try mockKeychain.retrieve(for: testKey)
        
        // Then
        XCTAssertNil(retrievedData)
        XCTAssertEqual(mockKeychain.deleteCallCount, 1)
    }
    
    // MARK: - Apple User ID Tests
    
    func testStoreAndRetrieveAppleUserId() throws {
        // Given
        let testUserId = "test.apple.user.id"
        
        // When
        try mockKeychain.storeAppleUserId(testUserId)
        let retrievedUserId = try mockKeychain.retrieveAppleUserId()
        
        // Then
        XCTAssertEqual(retrievedUserId, testUserId)
        XCTAssertTrue(mockKeychain.hasData(for: KeychainService.appleUserIdKey))
    }
    
    func testStoreAndRetrieveAppleUserIdHash() throws {
        // Given
        let testHash = "test_hash_value"
        
        // When
        try mockKeychain.storeAppleUserIdHash(testHash)
        let retrievedHash = try mockKeychain.retrieveAppleUserIdHash()
        
        // Then
        XCTAssertEqual(retrievedHash, testHash)
        XCTAssertTrue(mockKeychain.hasData(for: KeychainService.appleUserIdHashKey))
    }
    
    func testDeleteAppleUserId() throws {
        // Given
        let testUserId = "test.apple.user.id"
        try mockKeychain.storeAppleUserId(testUserId)
        
        // When
        try mockKeychain.deleteAppleUserId()
        let retrievedUserId = try mockKeychain.retrieveAppleUserId()
        
        // Then
        XCTAssertNil(retrievedUserId)
        XCTAssertFalse(mockKeychain.hasData(for: KeychainService.appleUserIdKey))
    }
    
    // MARK: - Family ID Tests
    
    func testStoreAndRetrieveFamilyId() throws {
        // Given
        let testFamilyId = UUID()
        
        // When
        try mockKeychain.storeFamilyId(testFamilyId)
        let retrievedFamilyId = try mockKeychain.retrieveFamilyId()
        
        // Then
        XCTAssertEqual(retrievedFamilyId, testFamilyId)
        XCTAssertTrue(mockKeychain.hasData(for: KeychainService.familyIdKey))
    }
    
    func testDeleteFamilyId() throws {
        // Given
        let testFamilyId = UUID()
        try mockKeychain.storeFamilyId(testFamilyId)
        
        // When
        try mockKeychain.deleteFamilyId()
        let retrievedFamilyId = try mockKeychain.retrieveFamilyId()
        
        // Then
        XCTAssertNil(retrievedFamilyId)
        XCTAssertFalse(mockKeychain.hasData(for: KeychainService.familyIdKey))
    }
    
    // MARK: - Clear All Tests
    
    func testClearAll() throws {
        // Given
        let testUserId = "test.apple.user.id"
        let testHash = "test_hash"
        let testFamilyId = UUID()
        
        try mockKeychain.storeAppleUserId(testUserId)
        try mockKeychain.storeAppleUserIdHash(testHash)
        try mockKeychain.storeFamilyId(testFamilyId)
        
        // When
        try mockKeychain.clearAll()
        
        // Then
        XCTAssertNil(try mockKeychain.retrieveAppleUserId())
        XCTAssertNil(try mockKeychain.retrieveAppleUserIdHash())
        XCTAssertNil(try mockKeychain.retrieveFamilyId())
        XCTAssertEqual(mockKeychain.getStoredItemCount(), 0)
    }
    
    // MARK: - Error Configuration Tests
    
    func testConfigureForFailure() throws {
        // Given
        let testError = KeychainService.KeychainError.itemNotFound
        mockKeychain.setError(testError)
        mockKeychain.shouldSucceed = false
        
        // When/Then
        XCTAssertThrowsError(try mockKeychain.store("test".data(using: .utf8)!, for: "key")) { error in
            XCTAssertEqual(error as? KeychainService.KeychainError, testError)
        }
    }
    
    func testConfigureSpecificOperationFailure() throws {
        // Given
        mockKeychain.setFailingOperations([.store])
        mockKeychain.setError(.duplicateItem)
        
        // When/Then
        XCTAssertThrowsError(try mockKeychain.store("test".data(using: .utf8)!, for: "key")) { error in
            XCTAssertEqual(error as? KeychainService.KeychainError, .duplicateItem)
        }
        
        // But retrieve should still work
        XCTAssertNoThrow(try mockKeychain.retrieve(for: "key"))
    }
    
    func testConfigureAppleUserIdOperationFailure() throws {
        // Given
        mockKeychain.setFailingOperations([.storeAppleUserId])
        mockKeychain.setError(.duplicateItem)
        
        // When/Then
        XCTAssertThrowsError(try mockKeychain.storeAppleUserId("test.user.id")) { error in
            XCTAssertEqual(error as? KeychainService.KeychainError, .duplicateItem)
        }
    }
    
    // MARK: - Test Utility Tests
    
    func testReset() throws {
        // Given
        try mockKeychain.store("test".data(using: .utf8)!, for: "key")
        mockKeychain.shouldSucceed = false
        mockKeychain.setError(.itemNotFound)
        mockKeychain.setFailingOperations([.store])
        
        // When
        mockKeychain.reset()
        
        // Then
        XCTAssertEqual(mockKeychain.getStoredItemCount(), 0)
        XCTAssertTrue(mockKeychain.shouldSucceed)
        XCTAssertEqual(mockKeychain.storeCallCount, 0)
        XCTAssertEqual(mockKeychain.retrieveCallCount, 0)
        XCTAssertEqual(mockKeychain.deleteCallCount, 0)
        
        // Should be able to store successfully after reset
        XCTAssertNoThrow(try mockKeychain.store("test".data(using: .utf8)!, for: "key"))
    }
    
    func testPrePopulate() {
        // Given
        let testData = "pre-populated data".data(using: .utf8)!
        let testKey = "pre_populated_key"
        
        // When
        mockKeychain.prePopulate(data: testData, for: testKey)
        
        // Then
        XCTAssertTrue(mockKeychain.hasData(for: testKey))
        XCTAssertEqual(mockKeychain.getAllStoredData()[testKey], testData)
    }
    
    func testGetAllStoredData() throws {
        // Given
        let testData1 = "data1".data(using: .utf8)!
        let testData2 = "data2".data(using: .utf8)!
        try mockKeychain.store(testData1, for: "key1")
        try mockKeychain.store(testData2, for: "key2")
        
        // When
        let allData = mockKeychain.getAllStoredData()
        
        // Then
        XCTAssertEqual(allData.count, 2)
        XCTAssertEqual(allData["key1"], testData1)
        XCTAssertEqual(allData["key2"], testData2)
    }
    
    // MARK: - Call Tracking Tests
    
    func testCallTracking() throws {
        // Given
        let testData = "test".data(using: .utf8)!
        
        // When
        try mockKeychain.store(testData, for: "key1")
        try mockKeychain.store(testData, for: "key2")
        _ = try mockKeychain.retrieve(for: "key1")
        _ = try mockKeychain.retrieve(for: "key2")
        _ = try mockKeychain.retrieve(for: "key3")
        try mockKeychain.delete(for: "key1")
        
        // Then
        XCTAssertEqual(mockKeychain.storeCallCount, 2)
        XCTAssertEqual(mockKeychain.retrieveCallCount, 3)
        XCTAssertEqual(mockKeychain.deleteCallCount, 1)
    }
}

// MARK: - KeychainService.KeychainError Extension for Testing

extension KeychainService.KeychainError: Equatable {
    public static func == (lhs: KeychainService.KeychainError, rhs: KeychainService.KeychainError) -> Bool {
        switch (lhs, rhs) {
        case (.itemNotFound, .itemNotFound),
             (.duplicateItem, .duplicateItem),
             (.invalidData, .invalidData):
            return true
        case (.unexpectedError(let lhsStatus), .unexpectedError(let rhsStatus)):
            return lhsStatus == rhsStatus
        default:
            return false
        }
    }
}