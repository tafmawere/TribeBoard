import XCTest
import SwiftData
import Combine
@testable import TribeBoard

/// Integration tests for family creation reliability covering end-to-end flows,
/// network failures, offline mode, CloudKit unavailability, and error recovery
@MainActor
final class FamilyCreationReliabilityIntegrationTests: XCTestCase {
    
    // MARK: - Test Properties
    
    var modelContainer: ModelContainer!
    var dataService: DataService!
    var mockCloudKitService: MockCloudKitService!
    var syncManager: SyncManager!
    var qrCodeService: QRCodeService!
    var codeGenerator: CodeGenerator!
    var createFamilyViewModel: CreateFamilyViewModel!
    var appState: AppState!
    var testUser: UserProfile!
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        print("🧪 Setting up FamilyCreationReliabilityIntegrationTests...")
        
        // Create in-memory container
        modelContainer = try createInMemoryContainer()
        
        // Initialize services
        mockCloudKitService = MockCloudKitService()
        dataService = DataService(
            modelContext: modelContainer.mainContext,
            cloudKitService: mockCloudKitService
        )
        syncManager = SyncManager(
            dataService: dataService,
            cloudKitService: mockCloudKitService
        )
        qrCodeService = QRCodeService()
        codeGenerator = CodeGenerator()
        
        // Initialize view model
        createFamilyViewModel = CreateFamilyViewModel(
            dataService: dataService,
            cloudKitService: mockCloudKitService,
            syncManager: syncManager,
            qrCodeService: qrCodeService,
            codeGenerator: codeGenerator
        )
        
        // Initialize app state
        appState = AppState()
        
        // Create test user
        testUser = try dataService.createUserProfile(
            displayName: "Test User",
            appleUserIdHash: "test_hash_123456789"
        )
        appState.setCurrentUser(testUser)
        
        print("✅ FamilyCreationReliabilityIntegrationTests setup complete")
    }
    
    override func tearDown() async throws {
        // Cancel any ongoing operations
        cancellables.removeAll()
        
        // Clean up
        createFamilyViewModel = nil
        appState = nil
        testUser = nil
        syncManager = nil
        qrCodeService = nil
        codeGenerator = nil
        mockCloudKitService = nil
        dataService = nil
        modelContainer = nil
        
        try await super.tearDown()
        print("✅ FamilyCreationReliabilityIntegrationTests cleanup complete")
    }
    
    // MARK: - Helper Methods
    
    private func createInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([
            Family.self,
            UserProfile.self,
            Membership.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        
        return try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )
    }
    
    private func waitForStateChange(
        to expectedState: FamilyCreationState,
        timeout: TimeInterval = 5.0
    ) async throws {
        let expectation = XCTestExpectation(description: "State change to \(expectedState)")
        
        let cancellable = createFamilyViewModel.$creationState
            .sink { state in
                if state == expectedState {
                    expectation.fulfill()
                }
            }
        
        let result = await XCTWaiter().fulfillment(of: [expectation], timeout: timeout)
        cancellable.cancel()
        
        if result != .completed {
            throw XCTestError(.timeoutWhileWaiting)
        }
    }
    
    private func waitForCompletion(timeout: TimeInterval = 10.0) async throws {
        try await waitForStateChange(to: .completed, timeout: timeout)
    }
    
    private func waitForFailure(timeout: TimeInterval = 5.0) async throws {
        let expectation = XCTestExpectation(description: "State change to failed")
        
        let cancellable = createFamilyViewModel.$creationState
            .sink { state in
                if state.isFailed {
                    expectation.fulfill()
                }
            }
        
        let result = await XCTWaiter().fulfillment(of: [expectation], timeout: timeout)
        cancellable.cancel()
        
        if result != .completed {
            throw XCTestError(.timeoutWhileWaiting)
        }
    }
    
    // MARK: - End-to-End Family Creation Flow Tests
    
    /// Tests the complete family creation flow from start to finish
    /// Requirements: 1.1, 1.2
    func testCompleteEndToEndFamilyCreationFlow() async throws {
        print("🧪 Testing complete end-to-end family creation flow...")
        
        // Set up successful scenario
        mockCloudKitService.shouldFailOperations = false
        mockCloudKitService.networkDelay = 0.1 // Small delay to simulate real network
        
        // Set family name
        createFamilyViewModel.familyName = "Integration Test Family"
        
        // Verify initial state
        XCTAssertEqual(createFamilyViewModel.creationState, .idle)
        XCTAssertTrue(createFamilyViewModel.canCreateFamily)
        
        // Start family creation
        let creationTask = Task {
            await createFamilyViewModel.createFamily(with: appState)
        }
        
        // Wait for validation state
        try await waitForStateChange(to: .validating, timeout: 2.0)
        XCTAssertEqual(createFamilyViewModel.creationState, .validating)
        
        // Wait for code generation state
        try await waitForStateChange(to: .generatingCode, timeout: 2.0)
        XCTAssertEqual(createFamilyViewModel.creationState, .generatingCode)
        
        // Wait for local creation state
        try await waitForStateChange(to: .creatingLocally, timeout: 2.0)
        XCTAssertEqual(createFamilyViewModel.creationState, .creatingLocally)
        
        // Wait for CloudKit sync state
        try await waitForStateChange(to: .syncingToCloudKit, timeout: 2.0)
        XCTAssertEqual(createFamilyViewModel.creationState, .syncingToCloudKit)
        
        // Wait for completion
        try await waitForCompletion(timeout: 5.0)
        
        await creationTask.value
        
        // Verify final state
        XCTAssertEqual(createFamilyViewModel.creationState, .completed)
        XCTAssertNotNil(createFamilyViewModel.createdFamily)
        XCTAssertNotNil(createFamilyViewModel.qrCodeImage)
        XCTAssertNil(createFamilyViewModel.currentError)
        
        // Verify family was created correctly
        let createdFamily = createFamilyViewModel.createdFamily!
        XCTAssertEqual(createdFamily.name, "Integration Test Family")
        XCTAssertFalse(createdFamily.code.isEmpty)
        XCTAssertEqual(createdFamily.createdByUserId, testUser.id)
        XCTAssertFalse(createdFamily.needsSync) // Should be synced to CloudKit
        
        // Verify membership was created
        let memberships = try dataService.fetchMemberships(forUser: testUser)
        XCTAssertEqual(memberships.count, 1)
        XCTAssertEqual(memberships.first?.role, .parentAdmin)
        XCTAssertEqual(memberships.first?.family?.id, createdFamily.id)
        
        // Verify CloudKit operations were called
        XCTAssertGreaterThan(mockCloudKitService.getOperationCallCount("save"), 0)
        
        // Verify app state was updated
        XCTAssertEqual(appState.currentFamily?.id, createdFamily.id)
        XCTAssertEqual(appState.currentMembership?.role, .parentAdmin)
        
        print("✅ Complete end-to-end family creation flow test passed")
    }
    
    /// Tests family creation with validation errors
    /// Requirements: 1.1
    func testEndToEndFlowWithValidationErrors() async throws {
        print("🧪 Testing end-to-end flow with validation errors...")
        
        // Test empty family name
        createFamilyViewModel.familyName = ""
        XCTAssertFalse(createFamilyViewModel.canCreateFamily)
        
        // Test family name too short
        createFamilyViewModel.familyName = "A"
        XCTAssertFalse(createFamilyViewModel.isValidFamilyName)
        
        // Test family name too long
        createFamilyViewModel.familyName = String(repeating: "A", count: 51)
        XCTAssertFalse(createFamilyViewModel.isValidFamilyName)
        
        // Test valid family name
        createFamilyViewModel.familyName = "Valid Family Name"
        XCTAssertTrue(createFamilyViewModel.isValidFamilyName)
        XCTAssertTrue(createFamilyViewModel.canCreateFamily)
        
        print("✅ End-to-end flow validation error test passed")
    }
    
    // MARK: - Network Failure Scenarios Tests
    
    /// Tests family creation behavior during network failures
    /// Requirements: 4.1, 4.2
    func testNetworkFailureScenarios() async throws {
        print("🧪 Testing network failure scenarios...")
        
        // Set up network failure
        mockCloudKitService.simulateNetworkError()
        
        // Set family name
        createFamilyViewModel.familyName = "Network Test Family"
        
        // Start family creation
        let creationTask = Task {
            await createFamilyViewModel.createFamily(with: appState)
        }
        
        // Wait for completion (should fallback to local-only)
        try await waitForCompletion(timeout: 10.0)
        
        await creationTask.value
        
        // Verify family was created locally despite network failure
        XCTAssertEqual(createFamilyViewModel.creationState, .completed)
        XCTAssertNotNil(createFamilyViewModel.createdFamily)
        
        let createdFamily = createFamilyViewModel.createdFamily!
        XCTAssertEqual(createdFamily.name, "Network Test Family")
        XCTAssertTrue(createdFamily.needsSync) // Should be marked for sync
        
        // Verify membership was created locally
        let memberships = try dataService.fetchMemberships(forUser: testUser)
        XCTAssertEqual(memberships.count, 1)
        XCTAssertTrue(memberships.first?.needsSync ?? false)
        
        print("✅ Network failure scenario test passed")
    }
    
    /// Tests connection timeout handling
    /// Requirements: 4.1
    func testConnectionTimeoutHandling() async throws {
        print("🧪 Testing connection timeout handling...")
        
        // Set up long network delay to simulate timeout
        mockCloudKitService.simulateNetworkDelay(10.0) // Very long delay
        mockCloudKitService.setCustomError(FamilyCreationError.connectionTimeout)
        
        createFamilyViewModel.familyName = "Timeout Test Family"
        
        let creationTask = Task {
            await createFamilyViewModel.createFamily(with: appState)
        }
        
        // Should complete with local fallback
        try await waitForCompletion(timeout: 15.0)
        
        await creationTask.value
        
        // Verify family was created locally
        XCTAssertEqual(createFamilyViewModel.creationState, .completed)
        XCTAssertNotNil(createFamilyViewModel.createdFamily)
        XCTAssertTrue(createFamilyViewModel.createdFamily?.needsSync ?? false)
        
        print("✅ Connection timeout handling test passed")
    }
    
    // MARK: - Offline Mode Behavior Tests
    
    /// Tests family creation in offline mode
    /// Requirements: 4.1, 4.2, 4.3
    func testOfflineModeBehavior() async throws {
        print("🧪 Testing offline mode behavior...")
        
        // Simulate offline mode
        syncManager.setOfflineMode(true)
        
        createFamilyViewModel.familyName = "Offline Test Family"
        
        // Verify offline mode is detected
        XCTAssertTrue(createFamilyViewModel.isOfflineMode)
        
        let creationTask = Task {
            await createFamilyViewModel.createFamily(with: appState)
        }
        
        try await waitForCompletion(timeout: 5.0)
        
        await creationTask.value
        
        // Verify family was created in offline mode
        XCTAssertEqual(createFamilyViewModel.creationState, .completed)
        XCTAssertNotNil(createFamilyViewModel.createdFamily)
        
        let createdFamily = createFamilyViewModel.createdFamily!
        XCTAssertTrue(createdFamily.needsSync) // Should be marked for sync
        XCTAssertNil(createdFamily.lastSyncDate) // Should not have sync date
        
        // Verify CloudKit operations were not attempted
        XCTAssertEqual(mockCloudKitService.getOperationCallCount("save"), 0)
        
        print("✅ Offline mode behavior test passed")
    }
    
    /// Tests sync when connectivity is restored
    /// Requirements: 4.4
    func testSyncWhenConnectivityRestored() async throws {
        print("🧪 Testing sync when connectivity is restored...")
        
        // Start in offline mode
        syncManager.setOfflineMode(true)
        
        createFamilyViewModel.familyName = "Sync Test Family"
        
        // Create family offline
        await createFamilyViewModel.createFamily(with: appState)
        
        // Verify family was created offline
        XCTAssertNotNil(createFamilyViewModel.createdFamily)
        let family = createFamilyViewModel.createdFamily!
        XCTAssertTrue(family.needsSync)
        
        // Restore connectivity
        syncManager.setOfflineMode(false)
        mockCloudKitService.shouldFailOperations = false
        
        // Trigger sync
        try await syncManager.syncPendingRecords()
        
        // Verify family was synced
        let syncedFamily = try dataService.fetchFamily(byId: family.id)
        XCTAssertNotNil(syncedFamily)
        XCTAssertFalse(syncedFamily?.needsSync ?? true)
        XCTAssertNotNil(syncedFamily?.lastSyncDate)
        
        print("✅ Sync when connectivity restored test passed")
    }
    
    // MARK: - CloudKit Unavailability and Fallback Tests
    
    /// Tests CloudKit unavailability scenarios
    /// Requirements: 4.1, 4.2
    func testCloudKitUnavailabilityFallback() async throws {
        print("🧪 Testing CloudKit unavailability fallback...")
        
        // Simulate CloudKit unavailable
        mockCloudKitService.mockAccountStatus = .noAccount
        mockCloudKitService.setCustomError(FamilyCreationError.cloudKitUnavailable)
        
        createFamilyViewModel.familyName = "CloudKit Unavailable Test"
        
        let creationTask = Task {
            await createFamilyViewModel.createFamily(with: appState)
        }
        
        try await waitForCompletion(timeout: 5.0)
        
        await creationTask.value
        
        // Verify family was created with local fallback
        XCTAssertEqual(createFamilyViewModel.creationState, .completed)
        XCTAssertNotNil(createFamilyViewModel.createdFamily)
        
        let family = createFamilyViewModel.createdFamily!
        XCTAssertTrue(family.needsSync) // Should be marked for later sync
        
        print("✅ CloudKit unavailability fallback test passed")
    }
    
    /// Tests CloudKit quota exceeded scenario
    /// Requirements: 4.2
    func testCloudKitQuotaExceededFallback() async throws {
        print("🧪 Testing CloudKit quota exceeded fallback...")
        
        mockCloudKitService.simulateQuotaExceeded()
        
        createFamilyViewModel.familyName = "Quota Test Family"
        
        let creationTask = Task {
            await createFamilyViewModel.createFamily(with: appState)
        }
        
        try await waitForCompletion(timeout: 5.0)
        
        await creationTask.value
        
        // Should complete with local fallback
        XCTAssertEqual(createFamilyViewModel.creationState, .completed)
        XCTAssertNotNil(createFamilyViewModel.createdFamily)
        XCTAssertTrue(createFamilyViewModel.createdFamily?.needsSync ?? false)
        
        print("✅ CloudKit quota exceeded fallback test passed")
    }
    
    // MARK: - Concurrent Family Creation and Code Collision Tests
    
    /// Tests concurrent family creation scenarios
    /// Requirements: 2.1, 2.2
    func testConcurrentFamilyCreation() async throws {
        print("🧪 Testing concurrent family creation...")
        
        // Create second user and view model
        let secondUser = try dataService.createUserProfile(
            displayName: "Second User",
            appleUserIdHash: "second_hash_123456789"
        )
        
        let secondAppState = AppState()
        secondAppState.setCurrentUser(secondUser)
        
        let secondViewModel = CreateFamilyViewModel(
            dataService: dataService,
            cloudKitService: mockCloudKitService,
            syncManager: syncManager,
            qrCodeService: qrCodeService,
            codeGenerator: codeGenerator
        )
        
        // Set up both view models
        createFamilyViewModel.familyName = "Concurrent Family 1"
        secondViewModel.familyName = "Concurrent Family 2"
        
        // Start both creations simultaneously
        let task1 = Task {
            await createFamilyViewModel.createFamily(with: appState)
        }
        
        let task2 = Task {
            await secondViewModel.createFamily(with: secondAppState)
        }
        
        // Wait for both to complete
        await task1.value
        await task2.value
        
        // Both should succeed with different codes
        XCTAssertEqual(createFamilyViewModel.creationState, .completed)
        XCTAssertEqual(secondViewModel.creationState, .completed)
        
        XCTAssertNotNil(createFamilyViewModel.createdFamily)
        XCTAssertNotNil(secondViewModel.createdFamily)
        
        // Verify different family codes
        let family1Code = createFamilyViewModel.createdFamily?.code
        let family2Code = secondViewModel.createdFamily?.code
        XCTAssertNotEqual(family1Code, family2Code)
        
        print("✅ Concurrent family creation test passed")
    }
    
    /// Tests code collision detection and resolution
    /// Requirements: 2.1, 2.2
    func testCodeCollisionHandling() async throws {
        print("🧪 Testing code collision handling...")
        
        // Pre-create a family with a specific code
        let existingFamily = try dataService.createFamily(
            name: "Existing Family",
            code: "COLLISION",
            createdByUserId: testUser.id
        )
        
        // Mock the code generator to initially return the colliding code
        var callCount = 0
        let originalGenerator = codeGenerator
        
        // Create a custom code generator that returns collision first, then unique
        let testCodeGenerator = TestCodeGenerator { code in
            callCount += 1
            if callCount == 1 {
                return "COLLISION" // First attempt collides
            } else {
                return "UNIQUE\(callCount)" // Subsequent attempts are unique
            }
        }
        
        // Replace the code generator temporarily
        createFamilyViewModel = CreateFamilyViewModel(
            dataService: dataService,
            cloudKitService: mockCloudKitService,
            syncManager: syncManager,
            qrCodeService: qrCodeService,
            codeGenerator: testCodeGenerator
        )
        
        createFamilyViewModel.familyName = "Collision Test Family"
        
        let creationTask = Task {
            await createFamilyViewModel.createFamily(with: appState)
        }
        
        try await waitForCompletion(timeout: 5.0)
        
        await creationTask.value
        
        // Should succeed with a different code
        XCTAssertEqual(createFamilyViewModel.creationState, .completed)
        XCTAssertNotNil(createFamilyViewModel.createdFamily)
        
        let newFamily = createFamilyViewModel.createdFamily!
        XCTAssertNotEqual(newFamily.code, "COLLISION")
        XCTAssertTrue(newFamily.code.hasPrefix("UNIQUE"))
        
        // Verify collision was handled (multiple generation attempts)
        XCTAssertGreaterThan(callCount, 1)
        
        print("✅ Code collision handling test passed")
    }
    
    // MARK: - Error Recovery and Retry Mechanism Tests
    
    /// Tests automatic retry mechanisms
    /// Requirements: 1.1, 1.2
    func testAutomaticRetryMechanisms() async throws {
        print("🧪 Testing automatic retry mechanisms...")
        
        // Set up transient failure that succeeds on retry
        mockCloudKitService.shouldFailOperations = true
        mockCloudKitService.setCustomError(FamilyCreationError.networkUnavailable)
        
        // Set up the mock to fail first few attempts then succeed
        mockCloudKitService.failOnRecordIndex = 0 // Fail on first attempt
        
        createFamilyViewModel.familyName = "Retry Test Family"
        
        let creationTask = Task {
            await createFamilyViewModel.createFamily(with: appState)
        }
        
        // Should eventually succeed with fallback to local-only
        try await waitForCompletion(timeout: 15.0)
        
        await creationTask.value
        
        // Verify success (should complete with local fallback)
        XCTAssertEqual(createFamilyViewModel.creationState, .completed)
        XCTAssertNotNil(createFamilyViewModel.createdFamily)
        
        // Should be marked for sync due to CloudKit failure
        XCTAssertTrue(createFamilyViewModel.createdFamily?.needsSync ?? false)
        
        print("✅ Automatic retry mechanisms test passed")
    }
    
    /// Tests manual retry functionality
    /// Requirements: 1.1, 1.2
    func testManualRetryFunctionality() async throws {
        print("🧪 Testing manual retry functionality...")
        
        // Set up failure scenario
        mockCloudKitService.setCustomError(FamilyCreationError.networkUnavailable)
        
        createFamilyViewModel.familyName = "Manual Retry Test"
        
        // First attempt should fail
        await createFamilyViewModel.createFamily(with: appState)
        
        try await waitForFailure(timeout: 5.0)
        
        // Verify failure state
        XCTAssertTrue(createFamilyViewModel.isFailed)
        XCTAssertTrue(createFamilyViewModel.canRetry)
        
        // Fix the issue and retry manually
        mockCloudKitService.shouldFailOperations = false
        
        let retryTask = Task {
            await createFamilyViewModel.retryCreation(with: appState)
        }
        
        try await waitForCompletion(timeout: 5.0)
        
        await retryTask.value
        
        // Should succeed on retry
        XCTAssertEqual(createFamilyViewModel.creationState, .completed)
        XCTAssertNotNil(createFamilyViewModel.createdFamily)
        
        print("✅ Manual retry functionality test passed")
    }
    
    /// Tests error recovery strategies
    /// Requirements: 1.1, 1.2
    func testErrorRecoveryStrategies() async throws {
        print("🧪 Testing error recovery strategies...")
        
        // Test different error types and their recovery strategies
        let errorScenarios: [(FamilyCreationError, Bool)] = [
            (.networkUnavailable, true), // Should be retryable
            (.cloudKitUnavailable, true), // Should be retryable
            (.validationFailed("Test error"), false), // Should not be retryable
            (.maxRetriesExceeded, false), // Should not be retryable
            (.codeCollisionDetected, true) // Should be retryable
        ]
        
        for (error, shouldBeRetryable) in errorScenarios {
            // Reset state
            createFamilyViewModel.resetCreationState()
            
            // Simulate the error
            createFamilyViewModel.familyName = "Recovery Test"
            
            // Manually set the error state
            createFamilyViewModel.creationState = .failed(error)
            
            // Check retry capability
            XCTAssertEqual(createFamilyViewModel.canRetry, shouldBeRetryable, 
                          "Error \(error) should have retryable=\(shouldBeRetryable)")
            
            // Check recovery strategy
            let strategy = error.recoveryStrategy
            switch strategy {
            case .automaticRetry:
                XCTAssertTrue(shouldBeRetryable)
            case .fallbackToLocal:
                // Should allow fallback
                break
            case .userIntervention:
                XCTAssertFalse(shouldBeRetryable)
            case .noRecovery:
                XCTAssertFalse(shouldBeRetryable)
            }
        }
        
        print("✅ Error recovery strategies test passed")
    }
    
    /// Tests maximum retry limit enforcement
    /// Requirements: 1.1
    func testMaximumRetryLimitEnforcement() async throws {
        print("🧪 Testing maximum retry limit enforcement...")
        
        // Set up persistent failure
        mockCloudKitService.setCustomError(FamilyCreationError.networkUnavailable)
        
        createFamilyViewModel.familyName = "Max Retry Test"
        
        // Attempt creation multiple times
        for attempt in 1...5 {
            await createFamilyViewModel.createFamily(with: appState)
            
            if attempt <= 3 {
                // Should allow retry for first 3 attempts
                XCTAssertTrue(createFamilyViewModel.canRetry, "Should allow retry on attempt \(attempt)")
                
                // Reset for next attempt
                createFamilyViewModel.resetCreationState()
            } else {
                // Should not allow retry after max attempts
                XCTAssertFalse(createFamilyViewModel.canRetry, "Should not allow retry after max attempts")
                break
            }
        }
        
        print("✅ Maximum retry limit enforcement test passed")
    }
    
    // MARK: - Complex Integration Scenarios
    
    /// Tests complex scenario with multiple failure types
    /// Requirements: 1.1, 1.2, 2.1, 2.2, 4.1, 4.2
    func testComplexFailureRecoveryScenario() async throws {
        print("🧪 Testing complex failure recovery scenario...")
        
        var operationCount = 0
        
        // Set up complex failure sequence:
        // 1. Code collision
        // 2. Network failure
        // 3. Success
        
        let testCodeGenerator = TestCodeGenerator { code in
            operationCount += 1
            if operationCount == 1 {
                return "COLLISION" // First code collides
            } else {
                return "UNIQUE\(operationCount)" // Subsequent codes are unique
            }
        }
        
        // Pre-create colliding family
        _ = try dataService.createFamily(
            name: "Existing",
            code: "COLLISION",
            createdByUserId: testUser.id
        )
        
        // Set up network failure for first sync attempt
        mockCloudKitService.shouldFailOperations = true
        mockCloudKitService.setCustomError(FamilyCreationError.networkUnavailable)
        mockCloudKitService.failOnRecordIndex = 0 // Fail on first attempt
        
        // Use test code generator
        createFamilyViewModel = CreateFamilyViewModel(
            dataService: dataService,
            cloudKitService: mockCloudKitService,
            syncManager: syncManager,
            qrCodeService: qrCodeService,
            codeGenerator: testCodeGenerator
        )
        
        createFamilyViewModel.familyName = "Complex Scenario Test"
        
        let creationTask = Task {
            await createFamilyViewModel.createFamily(with: appState)
        }
        
        // Should eventually succeed despite multiple failures
        try await waitForCompletion(timeout: 15.0)
        
        await creationTask.value
        
        // Verify final success
        XCTAssertEqual(createFamilyViewModel.creationState, .completed)
        XCTAssertNotNil(createFamilyViewModel.createdFamily)
        
        let family = createFamilyViewModel.createdFamily!
        XCTAssertNotEqual(family.code, "COLLISION") // Should have resolved collision
        XCTAssertFalse(family.needsSync) // Should have eventually synced
        
        // Verify multiple operations occurred
        XCTAssertGreaterThan(operationCount, 1) // Code generation retried
        // Note: Sync will fallback to local-only due to network failure
        
        print("✅ Complex failure recovery scenario test passed")
    }
}

// MARK: - Test Helper Classes

/// Test code generator that allows custom code generation logic
class TestCodeGenerator: CodeGenerator {
    private let codeProvider: (String) -> String
    
    init(codeProvider: @escaping (String) -> String) {
        self.codeProvider = codeProvider
        super.init()
    }
    
    override func generateUniqueCodeSafely(
        checkLocal: @escaping (String) throws -> Bool,
        checkRemote: @escaping (String) async throws -> Bool
    ) async throws -> String {
        let baseCode = "TEST"
        let generatedCode = codeProvider(baseCode)
        
        // Check uniqueness
        let isLocallyUnique = try checkLocal(generatedCode)
        let isRemotelyUnique = try await checkRemote(generatedCode)
        
        if isLocallyUnique && isRemotelyUnique {
            return generatedCode
        } else {
            // Retry with different code
            let retryCode = codeProvider(baseCode + "_RETRY")
            return retryCode
        }
    }
}