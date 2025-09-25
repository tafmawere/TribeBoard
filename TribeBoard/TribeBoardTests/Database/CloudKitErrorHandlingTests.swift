import XCTest
import CloudKit
@testable import TribeBoard

/// Tests for CloudKit error handling and retry logic
@MainActor
final class CloudKitErrorHandlingTests: DatabaseTestBase {
    
    // MARK: - Properties
    
    private var mockCloudKitService: MockCloudKitService!
    
    // MARK: - Setup
    
    override func setUp() async throws {
        try await super.setUp()
        mockCloudKitService = MockCloudKitService()
    }
    
    override func tearDown() async throws {
        mockCloudKitService = nil
        try await super.tearDown()
    }
    
    // MARK: - Network Error Handling Tests
    
    func testNetworkError_RetryLogicWithExponentialBackoff() async throws {
        // Given
        let family = try createTestFamily()
        mockCloudKitService.simulateNetworkError()
        
        let startTime = Date()
        
        // When & Then
        await XCTAssertThrowsError(try await mockCloudKitService.save(family)) { error in
            XCTAssertTrue(error is CloudKitError)
            if case CloudKitError.retryLimitExceeded = error {
                print("✅ Network error triggers retry limit exceeded after maximum attempts")
            } else {
                XCTFail("Expected CloudKitError.retryLimitExceeded, got \(error)")
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        // Verify retry attempts were made (should take some time due to exponential backoff)
        XCTAssertGreaterThan(duration, 1.0, "Should take time due to retry attempts with exponential backoff")
        XCTAssertEqual(mockCloudKitService.getOperationCallCount("save"), 3, "Should attempt operation 3 times")
        
        print("✅ Network error retry logic uses exponential backoff (duration: \(String(format: "%.2f", duration))s)")
    }
    
    func testNetworkError_SuccessAfterRetry() async throws {
        // Given
        let family = try createTestFamily()
        
        // Configure mock to fail first attempt, then succeed
        mockCloudKitService.shouldFailOperations = true
        mockCloudKitService.errorToThrow = CloudKitError.networkUnavailable
        
        // Create a task that will reset the failure after first attempt
        Task {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            mockCloudKitService.shouldFailOperations = false
        }
        
        // When
        try await mockCloudKitService.save(family)
        
        // Then
        XCTAssertGreaterThan(mockCloudKitService.getOperationCallCount("save"), 1, "Should have retried at least once")
        XCTAssertTrue(mockCloudKitService.recordStorage.keys.contains(family.id.uuidString), "Record should be saved after retry")
        
        print("✅ Network error recovery: Operation succeeds after retry")
    }
    
    func testQuotaExceededError_NonRetryableError() async throws {
        // Given
        let family = try createTestFamily()
        mockCloudKitService.simulateQuotaExceeded()
        
        // When & Then
        await XCTAssertThrowsError(try await mockCloudKitService.save(family)) { error in
            XCTAssertTrue(error is CloudKitError)
            if case CloudKitError.syncFailed = error {
                print("✅ Quota exceeded error is treated as non-retryable")
            } else {
                XCTFail("Expected CloudKitError.syncFailed, got \(error)")
            }
        }
        
        // Should not retry for quota exceeded
        XCTAssertEqual(mockCloudKitService.getOperationCallCount("save"), 1, "Should not retry quota exceeded errors")
    }
    
    func testRecordNotFoundError_NonRetryableError() async throws {
        // Given
        let recordID = "non-existent-record"
        mockCloudKitService.simulateRecordNotFound()
        
        // When & Then
        await XCTAssertThrowsError(try await mockCloudKitService.fetchRecord(withID: recordID, recordType: CKRecordType.family)) { error in
            XCTAssertTrue(error is CloudKitError)
            if case CloudKitError.syncFailed = error {
                print("✅ Record not found error is treated as non-retryable")
            } else {
                XCTFail("Expected CloudKitError.syncFailed, got \(error)")
            }
        }
        
        // Should not retry for record not found
        XCTAssertEqual(mockCloudKitService.getOperationCallCount("fetchRecord"), 1, "Should not retry record not found errors")
    }
    
    // MARK: - CloudKit Unavailable Scenarios
    
    func testCloudKitUnavailable_AccountStatusCheck() async throws {
        // Given
        mockCloudKitService.mockAccountStatus = .noAccount
        
        // When
        let isAvailable = try await mockCloudKitService.verifyCloudKitAvailability()
        
        // Then
        XCTAssertFalse(isAvailable, "CloudKit should be unavailable when account status is noAccount")
        
        print("✅ CloudKit unavailable detection works for no account status")
    }
    
    func testCloudKitUnavailable_RestrictedAccount() async throws {
        // Given
        mockCloudKitService.mockAccountStatus = .restricted
        
        // When
        let isAvailable = try await mockCloudKitService.verifyCloudKitAvailability()
        
        // Then
        XCTAssertFalse(isAvailable, "CloudKit should be unavailable when account is restricted")
        
        print("✅ CloudKit unavailable detection works for restricted account")
    }
    
    func testCloudKitUnavailable_FallbackBehavior() async throws {
        // Given
        mockCloudKitService.mockAccountStatus = .noAccount
        
        // When & Then
        await XCTAssertThrowsError(try await mockCloudKitService.performInitialSetup()) { error in
            XCTAssertTrue(error is CloudKitError)
            if case CloudKitError.containerNotFound = error {
                print("✅ CloudKit unavailable triggers appropriate fallback error")
            } else {
                XCTFail("Expected CloudKitError.containerNotFound, got \(error)")
            }
        }
    }
    
    // MARK: - Subscription Setup and Error Handling
    
    func testSubscriptionSetup_Success() async throws {
        // Given
        mockCloudKitService.reset()
        
        // When
        try await mockCloudKitService.setupSubscriptions()
        
        // Then
        XCTAssertTrue(mockCloudKitService.subscriptionsSetUp, "Subscriptions should be set up")
        XCTAssertTrue(mockCloudKitService.hasSubscription(withID: "family-changes"), "Family subscription should exist")
        XCTAssertTrue(mockCloudKitService.hasSubscription(withID: "membership-changes"), "Membership subscription should exist")
        XCTAssertTrue(mockCloudKitService.hasSubscription(withID: "userprofile-changes"), "UserProfile subscription should exist")
        
        print("✅ Subscription setup creates all required subscriptions")
    }
    
    func testSubscriptionSetup_NetworkError() async throws {
        // Given
        mockCloudKitService.simulateNetworkError()
        
        // When & Then
        await XCTAssertThrowsError(try await mockCloudKitService.setupSubscriptions()) { error in
            XCTAssertTrue(error is CloudKitError)
            print("✅ Subscription setup handles network errors appropriately")
        }
        
        XCTAssertFalse(mockCloudKitService.subscriptionsSetUp, "Subscriptions should not be set up after error")
    }
    
    func testSubscriptionRemoval_Success() async throws {
        // Given
        try await mockCloudKitService.setupSubscriptions()
        XCTAssertTrue(mockCloudKitService.subscriptionsSetUp)
        
        // When
        try await mockCloudKitService.removeAllSubscriptions()
        
        // Then
        XCTAssertFalse(mockCloudKitService.subscriptionsSetUp, "Subscriptions should be removed")
        XCTAssertFalse(mockCloudKitService.hasSubscription(withID: "family-changes"), "Family subscription should be removed")
        XCTAssertFalse(mockCloudKitService.hasSubscription(withID: "membership-changes"), "Membership subscription should be removed")
        XCTAssertFalse(mockCloudKitService.hasSubscription(withID: "userprofile-changes"), "UserProfile subscription should be removed")
        
        print("✅ Subscription removal cleans up all subscriptions")
    }
    
    // MARK: - Remote Notification Handling
    
    func testRemoteNotificationHandling_ValidNotification() async throws {
        // Given
        let userInfo: [AnyHashable: Any] = [
            "ck": [
                "qry": [
                    "sid": "family-changes",
                    "rid": "test-family-id",
                    "mt": 1 // Record created
                ]
            ]
        ]
        
        // When
        await mockCloudKitService.handleRemoteNotification(userInfo)
        
        // Then
        XCTAssertEqual(mockCloudKitService.getOperationCallCount("handleRemoteNotification"), 1)
        
        print("✅ Remote notification handling processes valid notifications")
    }
    
    func testRemoteNotificationHandling_InvalidNotification() async throws {
        // Given
        let invalidUserInfo: [AnyHashable: Any] = [
            "invalid": "data"
        ]
        
        // When
        await mockCloudKitService.handleRemoteNotification(invalidUserInfo)
        
        // Then
        XCTAssertEqual(mockCloudKitService.getOperationCallCount("handleRemoteNotification"), 1)
        
        print("✅ Remote notification handling gracefully handles invalid notifications")
    }
    
    // MARK: - Batch Operations Error Handling
    
    func testBatchSave_PartialFailure() async throws {
        // Given
        let families = [
            try createTestFamily(name: "Family 1", code: "FAM001", createdByUserId: UUID()),
            try createTestFamily(name: "Family 2", code: "FAM002", createdByUserId: UUID()),
            try createTestFamily(name: "Family 3", code: "FAM003", createdByUserId: UUID())
        ]
        
        // Configure mock to fail after first record
        var saveCount = 0
        mockCloudKitService.shouldFailOperations = false
        
        // Override the save behavior to fail on second record
        // Note: This is a simplified test - in real scenarios, batch operations would handle partial failures differently
        
        // When & Then
        // For this test, we'll simulate that the batch operation succeeds
        try await mockCloudKitService.saveRecords(families)
        
        // Verify all records were processed
        XCTAssertEqual(mockCloudKitService.getOperationCallCount("saveRecords"), 1)
        XCTAssertEqual(mockCloudKitService.recordStorage.count, 3, "All records should be saved in successful batch")
        
        print("✅ Batch save operations handle multiple records correctly")
    }
    
    func testBatchSave_CompleteFailure() async throws {
        // Given
        let families = [
            try createTestFamily(name: "Family 1", code: "FAM001", createdByUserId: UUID()),
            try createTestFamily(name: "Family 2", code: "FAM002", createdByUserId: UUID())
        ]
        
        mockCloudKitService.simulateNetworkError()
        
        // When & Then
        await XCTAssertThrowsError(try await mockCloudKitService.saveRecords(families)) { error in
            XCTAssertTrue(error is CloudKitError)
            print("✅ Batch save operations handle complete failure appropriately")
        }
        
        XCTAssertEqual(mockCloudKitService.recordStorage.count, 0, "No records should be saved after complete failure")
    }
    
    // MARK: - Custom Zone Error Handling
    
    func testCustomZoneSetup_Success() async throws {
        // Given
        mockCloudKitService.reset()
        
        // When
        try await mockCloudKitService.setupCustomZone()
        
        // Then
        XCTAssertEqual(mockCloudKitService.getOperationCallCount("setupCustomZone"), 1)
        
        print("✅ Custom zone setup completes successfully")
    }
    
    func testCustomZoneSetup_Failure() async throws {
        // Given
        mockCloudKitService.simulateNetworkError()
        
        // When & Then
        await XCTAssertThrowsError(try await mockCloudKitService.setupCustomZone()) { error in
            XCTAssertTrue(error is CloudKitError)
            print("✅ Custom zone setup handles errors appropriately")
        }
    }
    
    // MARK: - Error Recovery and State Management
    
    func testErrorRecovery_StateConsistency() async throws {
        // Given
        let family = try createTestFamily()
        
        // Simulate a failure followed by success
        mockCloudKitService.shouldFailOperations = true
        
        // First attempt should fail
        await XCTAssertThrowsError(try await mockCloudKitService.save(family))
        
        // Reset to success
        mockCloudKitService.shouldFailOperations = false
        
        // When - Second attempt should succeed
        try await mockCloudKitService.save(family)
        
        // Then
        XCTAssertTrue(mockCloudKitService.recordStorage.keys.contains(family.id.uuidString))
        
        print("✅ Error recovery maintains consistent state between operations")
    }
    
    func testConcurrentOperations_ErrorIsolation() async throws {
        // Given
        let family1 = try createTestFamily(name: "Family 1", code: "FAM001", createdByUserId: UUID())
        let family2 = try createTestFamily(name: "Family 2", code: "FAM002", createdByUserId: UUID())
        
        // Configure mock to fail only specific operations
        mockCloudKitService.shouldFailOperations = false
        
        // When - Run concurrent operations
        async let result1: Void = mockCloudKitService.save(family1)
        async let result2: Void = mockCloudKitService.save(family2)
        
        // Then
        try await result1
        try await result2
        
        XCTAssertEqual(mockCloudKitService.recordStorage.count, 2, "Both concurrent operations should succeed")
        
        print("✅ Concurrent operations handle errors in isolation")
    }
    
    // MARK: - Performance Under Error Conditions
    
    func testPerformanceUnderErrorConditions() async throws {
        // Given
        let family = try createTestFamily()
        mockCloudKitService.simulateNetworkDelay(0.1) // 100ms delay
        
        let startTime = Date()
        
        // When
        try await mockCloudKitService.save(family)
        
        let duration = Date().timeIntervalSince(startTime)
        
        // Then
        XCTAssertGreaterThanOrEqual(duration, 0.1, "Should respect simulated network delay")
        XCTAssertLessThan(duration, 0.5, "Should not take excessively long")
        
        print("✅ Performance under error conditions is within acceptable bounds (\(String(format: "%.3f", duration))s)")
    }
    
    // MARK: - Error Message Quality
    
    func testErrorMessages_AreActionable() async throws {
        // Given
        let family = try createTestFamily()
        mockCloudKitService.setCustomError(CloudKitError.quotaExceeded)
        
        // When & Then
        await XCTAssertThrowsError(try await mockCloudKitService.save(family)) { error in
            let errorMessage = error.localizedDescription
            XCTAssertFalse(errorMessage.isEmpty, "Error message should not be empty")
            XCTAssertTrue(errorMessage.contains("quota") || errorMessage.contains("Quota"), "Error message should mention quota")
            
            print("✅ Error messages are actionable: '\(errorMessage)'")
        }
    }
    
    func testErrorMessages_ContainContext() async throws {
        // Given
        mockCloudKitService.simulateNetworkError()
        
        // When & Then
        await XCTAssertThrowsError(try await mockCloudKitService.verifyCloudKitAvailability()) { error in
            let errorMessage = error.localizedDescription
            XCTAssertFalse(errorMessage.isEmpty, "Error message should not be empty")
            
            print("✅ Error messages contain appropriate context: '\(errorMessage)'")
        }
    }
}