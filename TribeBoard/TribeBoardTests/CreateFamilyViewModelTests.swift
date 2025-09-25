import XCTest
import SwiftData
@testable import TribeBoard

@MainActor
final class CreateFamilyViewModelTests: XCTestCase {
    
    var viewModel: CreateFamilyViewModel!
    var mockDataService: CreateFamilyMockDataService!
    var mockCloudKitService: CreateFamilyMockCloudKitService!
    var mockSyncManager: MockSyncManager!
    var mockQRCodeService: MockQRCodeService!
    var mockCodeGenerator: MockCodeGenerator!
    var mockAppState: CreateFamilyMockAppState!
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockDataService = CreateFamilyMockDataService()
        mockCloudKitService = CreateFamilyMockCloudKitService()
        mockSyncManager = MockSyncManager(dataService: mockDataService, cloudKitService: mockCloudKitService)
        mockQRCodeService = MockQRCodeService()
        mockCodeGenerator = MockCodeGenerator()
        mockAppState = CreateFamilyMockAppState()
        
        viewModel = CreateFamilyViewModel(
            dataService: mockDataService,
            cloudKitService: mockCloudKitService,
            syncManager: mockSyncManager,
            qrCodeService: mockQRCodeService,
            codeGenerator: mockCodeGenerator
        )
    }
    
    override func tearDown() async throws {
        viewModel = nil
        mockDataService = nil
        mockCloudKitService = nil
        mockSyncManager = nil
        mockQRCodeService = nil
        mockCodeGenerator = nil
        mockAppState = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    @MainActor func testInitialization() {
        XCTAssertEqual(viewModel.familyName, "")
        XCTAssertFalse(viewModel.isCreating)
        XCTAssertNil(viewModel.createdFamily)
        XCTAssertNil(viewModel.qrCodeImage)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.familyCreationComplete)
    }
    
    // MARK: - Family Name Validation Tests
    
    @MainActor func testFamilyNameValidation_Valid() {
        viewModel.familyName = "Smith Family"
        XCTAssertTrue(viewModel.isValidFamilyName)
        XCTAssertNil(viewModel.familyNameError)
    }
    
    @MainActor func testFamilyNameValidation_Empty() {
        viewModel.familyName = ""
        XCTAssertFalse(viewModel.isValidFamilyName)
        XCTAssertNotNil(viewModel.familyNameError)
    }
    
    @MainActor func testFamilyNameValidation_TooShort() {
        viewModel.familyName = "A"
        XCTAssertFalse(viewModel.isValidFamilyName)
        XCTAssertNotNil(viewModel.familyNameError)
    }
    
    @MainActor func testFamilyNameValidation_TooLong() {
        viewModel.familyName = String(repeating: "A", count: 51)
        XCTAssertFalse(viewModel.isValidFamilyName)
        XCTAssertNotNil(viewModel.familyNameError)
    }
    
    // MARK: - Family Creation Tests
    
    func testCreateFamily_Success() async {
        // Setup
        viewModel.familyName = "Test Family"
        mockCodeGenerator.mockCode = "TEST123"
        mockDataService.shouldSucceed = true
        mockCloudKitService.shouldSucceed = true
        mockQRCodeService.mockImage = UIImage()
        
        // Execute
        await viewModel.createFamily()
        
        // Verify
        XCTAssertFalse(viewModel.isCreating)
        XCTAssertNotNil(viewModel.createdFamily)
        XCTAssertEqual(viewModel.createdFamily?.name, "Test Family")
        XCTAssertEqual(viewModel.createdFamily?.code, "TEST123")
        XCTAssertNotNil(viewModel.qrCodeImage)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.familyCreationComplete)
    }
    
    func testCreateFamily_InvalidName() async {
        // Setup
        viewModel.familyName = ""
        
        // Execute
        await viewModel.createFamily()
        
        // Verify
        XCTAssertFalse(viewModel.isCreating)
        XCTAssertNil(viewModel.createdFamily)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.familyCreationComplete)
    }
    
    func testCreateFamily_DataServiceFailure() async {
        // Setup
        viewModel.familyName = "Test Family"
        mockCodeGenerator.mockCode = "TEST123"
        mockDataService.shouldSucceed = false
        mockDataService.errorToThrow = DataServiceError.validationFailed(["Test error"])
        
        // Execute
        await viewModel.createFamily()
        
        // Verify
        XCTAssertFalse(viewModel.isCreating)
        XCTAssertNil(viewModel.createdFamily)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.familyCreationComplete)
    }
    
    func testCreateFamily_CloudKitFailure() async {
        // Setup
        viewModel.familyName = "Test Family"
        mockCodeGenerator.mockCode = "TEST123"
        mockDataService.shouldSucceed = true
        mockCloudKitService.shouldSucceed = false
        mockCloudKitService.errorToThrow = CloudKitError.networkUnavailable
        
        // Execute
        await viewModel.createFamily()
        
        // Verify - should succeed locally but show sync warning
        XCTAssertFalse(viewModel.isCreating)
        XCTAssertNotNil(viewModel.createdFamily)
        XCTAssertTrue(viewModel.familyCreationComplete)
        // Error message should indicate sync issue, not creation failure
        XCTAssertTrue(viewModel.errorMessage?.contains("sync") ?? false)
    }
    
    func testCreateFamily_CodeGenerationFailure() async {
        // Setup
        viewModel.familyName = "Test Family"
        mockCodeGenerator.shouldFail = true
        mockCodeGenerator.errorToThrow = CodeGenerationError.maxRetriesExceeded
        
        // Execute
        await viewModel.createFamily()
        
        // Verify
        XCTAssertFalse(viewModel.isCreating)
        XCTAssertNil(viewModel.createdFamily)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.familyCreationComplete)
    }
    
    func testCreateFamily_QRCodeGenerationFailure() async {
        // Setup
        viewModel.familyName = "Test Family"
        mockCodeGenerator.mockCode = "TEST123"
        mockDataService.shouldSucceed = true
        mockCloudKitService.shouldSucceed = true
        mockQRCodeService.shouldFail = true
        
        // Execute
        await viewModel.createFamily()
        
        // Verify - should still succeed even if QR code fails
        XCTAssertFalse(viewModel.isCreating)
        XCTAssertNotNil(viewModel.createdFamily)
        XCTAssertNil(viewModel.qrCodeImage)
        XCTAssertTrue(viewModel.familyCreationComplete)
    }
    
    // MARK: - Loading State Tests
    
    func testCreateFamily_LoadingState() async {
        // Setup
        viewModel.familyName = "Test Family"
        mockDataService.shouldDelay = true
        
        // Start creation
        let createTask = Task {
            await viewModel.createFamily()
        }
        
        // Check loading state
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        XCTAssertTrue(viewModel.isCreating)
        
        // Wait for completion
        await createTask.value
        XCTAssertFalse(viewModel.isCreating)
    }
    
    // MARK: - Error Handling Tests
    
    @MainActor func testClearError() {
        viewModel.errorMessage = "Test error"
        XCTAssertNotNil(viewModel.errorMessage)
        
        viewModel.clearError()
        XCTAssertNil(viewModel.errorMessage)
    }
    
    // MARK: - Enhanced State Machine Tests
    
    func testStateTransitions_SuccessfulFlow() async {
        viewModel.familyName = "Test Family"
        mockCodeGenerator.mockCode = "TEST123"
        mockDataService.shouldSucceed = true
        mockCloudKitService.shouldSucceed = true
        
        // Track state changes
        var stateHistory: [FamilyCreationState] = []
        let expectation = XCTestExpectation(description: "State transitions")
        
        // Monitor state changes
        let cancellable = viewModel.$creationState.sink { state in
            stateHistory.append(state)
            if state.isCompleted {
                expectation.fulfill()
            }
        }
        
        await viewModel.createFamily(with: mockAppState)
        
        await fulfillment(of: [expectation], timeout: 2.0)
        cancellable.cancel()
        
        // Verify state progression
        XCTAssertTrue(stateHistory.contains(.idle))
        XCTAssertTrue(stateHistory.contains(.validating))
        XCTAssertTrue(stateHistory.contains(.generatingCode))
        XCTAssertTrue(stateHistory.contains(.creatingLocally))
        XCTAssertTrue(stateHistory.contains(.completed))
        
        XCTAssertTrue(viewModel.isCompleted)
        XCTAssertFalse(viewModel.isCreating)
    }
    
    func testStateTransitions_ValidationFailure() async {
        viewModel.familyName = "" // Invalid name
        
        let expectation = XCTestExpectation(description: "Validation failure")
        
        let cancellable = viewModel.$creationState.sink { state in
            if case .failed(let error) = state {
                if case .invalidFamilyName = error {
                    expectation.fulfill()
                }
            }
        }
        
        await viewModel.createFamily(with: mockAppState)
        
        await fulfillment(of: [expectation], timeout: 1.0)
        cancellable.cancel()
        
        XCTAssertTrue(viewModel.isFailed)
        XCTAssertNotNil(viewModel.currentError)
    }
    
    func testStateTransitions_CodeGenerationFailure() async {
        viewModel.familyName = "Test Family"
        mockCodeGenerator.shouldFail = true
        mockCodeGenerator.errorToThrow = FamilyCodeGenerationError.maxAttemptsExceeded
        
        let expectation = XCTestExpectation(description: "Code generation failure")
        
        let cancellable = viewModel.$creationState.sink { state in
            if case .failed(let error) = state {
                if case .codeGenerationFailed = error {
                    expectation.fulfill()
                }
            }
        }
        
        await viewModel.createFamily(with: mockAppState)
        
        await fulfillment(of: [expectation], timeout: 1.0)
        cancellable.cancel()
        
        XCTAssertTrue(viewModel.isFailed)
        XCTAssertTrue(viewModel.currentError?.category == .codeGeneration)
    }
    
    func testStateTransitions_LocalCreationFailure() async {
        viewModel.familyName = "Test Family"
        mockCodeGenerator.mockCode = "TEST123"
        mockDataService.shouldSucceed = false
        mockDataService.errorToThrow = DataServiceError.constraintViolation("Duplicate code")
        
        let expectation = XCTestExpectation(description: "Local creation failure")
        
        let cancellable = viewModel.$creationState.sink { state in
            if case .failed(let error) = state {
                if case .localCreationFailed = error {
                    expectation.fulfill()
                }
            }
        }
        
        await viewModel.createFamily(with: mockAppState)
        
        await fulfillment(of: [expectation], timeout: 1.0)
        cancellable.cancel()
        
        XCTAssertTrue(viewModel.isFailed)
        XCTAssertTrue(viewModel.currentError?.category == .localDatabase)
    }
    
    func testStateTransitions_CloudKitSyncFailure() async {
        viewModel.familyName = "Test Family"
        mockCodeGenerator.mockCode = "TEST123"
        mockDataService.shouldSucceed = true
        mockCloudKitService.shouldSucceed = false
        mockCloudKitService.errorToThrow = CloudKitError.networkUnavailable
        
        await viewModel.createFamily(with: mockAppState)
        
        // Should complete successfully with local fallback
        XCTAssertTrue(viewModel.isCompleted)
        XCTAssertNotNil(viewModel.createdFamily)
        
        // Should indicate sync issue
        XCTAssertTrue(viewModel.createdFamily?.needsSync ?? false)
    }
    
    // MARK: - Enhanced Error Handling Tests
    
    func testRetryMechanism_RetryableError() async {
        viewModel.familyName = "Test Family"
        mockCodeGenerator.mockCode = "TEST123"
        mockDataService.shouldSucceed = false
        mockDataService.errorToThrow = DataServiceError.invalidData("Temporary error")
        
        // First attempt should fail
        await viewModel.createFamily(with: mockAppState)
        XCTAssertTrue(viewModel.isFailed)
        XCTAssertTrue(viewModel.canRetry)
        
        // Fix the service for retry
        mockDataService.shouldSucceed = true
        
        // Retry should succeed
        await viewModel.retryCreation(with: mockAppState)
        XCTAssertTrue(viewModel.isCompleted)
        XCTAssertNotNil(viewModel.createdFamily)
    }
    
    func testRetryMechanism_NonRetryableError() async {
        viewModel.familyName = "Test Family"
        mockCodeGenerator.shouldFail = true
        mockCodeGenerator.errorToThrow = FamilyCodeGenerationError.formatValidationFailed("Invalid format")
        
        await viewModel.createFamily(with: mockAppState)
        
        XCTAssertTrue(viewModel.isFailed)
        XCTAssertFalse(viewModel.canRetry) // Non-retryable error
    }
    
    func testRetryMechanism_MaxRetriesExceeded() async {
        viewModel.familyName = "Test Family"
        mockCodeGenerator.shouldFail = true
        mockCodeGenerator.errorToThrow = FamilyCodeGenerationError.uniquenessCheckFailed
        
        // Exhaust retry attempts
        for _ in 0..<3 {
            await viewModel.createFamily(with: mockAppState)
            if viewModel.canRetry {
                await viewModel.retryCreation(with: mockAppState)
            }
        }
        
        XCTAssertFalse(viewModel.canRetry)
        XCTAssertEqual(viewModel.retryCount, 3)
    }
    
    func testCancellation() async {
        viewModel.familyName = "Test Family"
        mockDataService.shouldDelay = true
        
        // Start creation
        let createTask = Task {
            await viewModel.createFamily(with: mockAppState)
        }
        
        // Cancel while in progress
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        viewModel.cancelCreation()
        
        await createTask.value
        
        XCTAssertTrue(viewModel.isFailed)
        if case .operationCancelled = viewModel.currentError {
            XCTAssertTrue(true)
        } else {
            XCTFail("Expected operation cancelled error")
        }
    }
    
    func testOfflineMode_LocalOnlyCreation() async {
        viewModel.familyName = "Test Family"
        mockCodeGenerator.mockCode = "TEST123"
        mockDataService.shouldSucceed = true
        mockSyncManager.isOfflineMode = true
        
        await viewModel.createFamily(with: mockAppState)
        
        XCTAssertTrue(viewModel.isCompleted)
        XCTAssertNotNil(viewModel.createdFamily)
        XCTAssertTrue(viewModel.createdFamily?.needsSync ?? false)
    }
    
    func testProgressTracking() async {
        viewModel.familyName = "Test Family"
        mockCodeGenerator.mockCode = "TEST123"
        mockDataService.shouldSucceed = true
        mockCloudKitService.shouldSucceed = true
        
        var progressValues: [Double] = []
        let expectation = XCTestExpectation(description: "Progress tracking")
        
        let cancellable = viewModel.$progress.sink { progress in
            progressValues.append(progress)
            if progress >= 1.0 {
                expectation.fulfill()
            }
        }
        
        await viewModel.createFamily(with: mockAppState)
        
        await fulfillment(of: [expectation], timeout: 2.0)
        cancellable.cancel()
        
        // Should have progressed from 0 to 1
        XCTAssertTrue(progressValues.contains(0.0))
        XCTAssertTrue(progressValues.contains(1.0))
        XCTAssertTrue(progressValues.count > 2) // Should have intermediate values
    }
    
    func testStatusMessages() async {
        viewModel.familyName = "Test Family"
        mockCodeGenerator.mockCode = "TEST123"
        mockDataService.shouldSucceed = true
        mockCloudKitService.shouldSucceed = true
        
        var statusMessages: [String] = []
        let expectation = XCTestExpectation(description: "Status messages")
        
        let cancellable = viewModel.$statusMessage.sink { message in
            statusMessages.append(message)
            if message.contains("successfully") {
                expectation.fulfill()
            }
        }
        
        await viewModel.createFamily(with: mockAppState)
        
        await fulfillment(of: [expectation], timeout: 2.0)
        cancellable.cancel()
        
        // Should have meaningful status messages
        XCTAssertTrue(statusMessages.contains { $0.contains("Ready") })
        XCTAssertTrue(statusMessages.contains { $0.contains("Validating") })
        XCTAssertTrue(statusMessages.contains { $0.contains("Generating") })
        XCTAssertTrue(statusMessages.contains { $0.contains("Creating") })
        XCTAssertTrue(statusMessages.contains { $0.contains("successfully") })
    }
    
    // MARK: - Edge Case Tests
    
    @MainActor func testFormReset() {
        viewModel.familyName = "Test Family"
        viewModel.createdFamily = Family(name: "Test", code: "TEST123", createdByUserId: UUID())
        viewModel.qrCodeImage = Image(systemName: "qrcode")
        
        viewModel.resetForm()
        
        XCTAssertEqual(viewModel.familyName, "")
        XCTAssertNil(viewModel.createdFamily)
        XCTAssertNil(viewModel.qrCodeImage)
        XCTAssertEqual(viewModel.creationState, .idle)
    }
    
    @MainActor func testClearError() {
        viewModel.currentError = FamilyCreationError.networkUnavailable
        
        viewModel.clearError()
        
        XCTAssertNil(viewModel.currentError)
        if viewModel.creationState.isFailed {
            XCTAssertEqual(viewModel.creationState, .idle)
        }
    }
    
    @MainActor func testValidationStateUpdates() {
        // Test real-time validation
        viewModel.familyName = ""
        XCTAssertFalse(viewModel.isValidFamilyName)
        XCTAssertFalse(viewModel.canCreateFamily)
        
        viewModel.familyName = "A"
        XCTAssertFalse(viewModel.isValidFamilyName)
        XCTAssertFalse(viewModel.canCreateFamily)
        
        viewModel.familyName = "Valid Family"
        XCTAssertTrue(viewModel.isValidFamilyName)
        XCTAssertTrue(viewModel.canCreateFamily)
        
        viewModel.familyName = String(repeating: "A", count: 51)
        XCTAssertFalse(viewModel.isValidFamilyName)
        XCTAssertFalse(viewModel.canCreateFamily)
    }
    
    func testConcurrentOperations() async {
        viewModel.familyName = "Test Family"
        mockCodeGenerator.mockCode = "TEST123"
        mockDataService.shouldSucceed = true
        
        // Try to start multiple creation operations
        let task1 = Task { await viewModel.createFamily(with: mockAppState) }
        let task2 = Task { await viewModel.createFamily(with: mockAppState) }
        
        await task1.value
        await task2.value
        
        // Should handle concurrent operations gracefully
        XCTAssertTrue(viewModel.isCompleted || viewModel.isFailed)
    }
    
    // MARK: - App State Integration Tests
    
    func testAppStateIntegration() async {
        viewModel.familyName = "Test Family"
        mockCodeGenerator.mockCode = "TEST123"
        mockDataService.shouldSucceed = true
        mockCloudKitService.shouldSucceed = true
        
        await viewModel.createFamily(with: mockAppState)
        
        XCTAssertTrue(mockAppState.setFamilyCalled)
        XCTAssertNotNil(mockAppState.currentFamily)
        XCTAssertEqual(mockAppState.currentFamily?.name, "Test Family")
    }
}

// MARK: - Mock Services

class CreateFamilyMockCloudKitService: CloudKitService {
    var shouldSucceed = true
    var errorToThrow: Error?
    
    override init() {
        super.init(containerIdentifier: "test")
    }
    
    override func save<T: CloudKitSyncable>(_ record: T) async throws {
        if !shouldSucceed {
            throw errorToThrow ?? CloudKitError.networkUnavailable
        }
    }
}

class MockQRCodeService: QRCodeService {
    var shouldFail = false
    var mockImage: UIImage?
    
    override func generateQRCode(from text: String) -> Image? {
        if shouldFail {
            return nil
        }
        return mockImage != nil ? Image(uiImage: mockImage!) : Image(systemName: "qrcode")
    }
}

class MockCodeGenerator: CodeGenerator {
    var shouldFail = false
    var mockCode = "TEST123"
    var errorToThrow: Error?
    
    override func generateUniqueCodeSafely(
        checkLocal: @escaping (String) async throws -> Bool,
        checkRemote: @escaping (String) async throws -> Bool
    ) async throws -> String {
        if shouldFail {
            throw errorToThrow ?? FamilyCodeGenerationError.maxAttemptsExceeded
        }
        return mockCode
    }
    
    override func generateUniqueCode(checkUniqueness: @escaping (String) async throws -> Bool) async throws -> String {
        if shouldFail {
            throw errorToThrow ?? CodeGenerationError.maxRetriesExceeded
        }
        return mockCode
    }
}

class CreateFamilyMockAppState: AppState {
    var setFamilyCalled = false
    var currentFamily: Family?
    var currentUser: UserProfile?
    
    override init() {
        super.init()
        // Set up a mock user
        currentUser = UserProfile(displayName: "Test User", appleUserIdHash: "test_hash")
    }
    
    override func setFamily(_ family: Family, membership: Membership) {
        setFamilyCalled = true
        currentFamily = family
        super.setFamily(family, membership: membership)
    }
}

class CreateFamilyMockDataService: DataService {
    var shouldSucceed = true
    var shouldDelay = false
    var errorToThrow: Error?
    
    init() {
        // Create a mock model container for testing
        let container = try! ModelContainerConfiguration.createInMemory()
        super.init(modelContext: container.mainContext)
    }
    
    override func createFamily(name: String, code: String, createdByUserId: UUID) throws -> Family {
        if shouldDelay {
            // Simulate delay in async context
            Task {
                do {
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                } catch {
                    // Handle sleep interruption
                }
            }
        }
        
        if !shouldSucceed {
            throw errorToThrow ?? DataServiceError.validationFailed(["Mock error"])
        }
        
        return Family(name: name, code: code, createdByUserId: createdByUserId)
    }
    
    override func createMembership(family: Family, user: UserProfile, role: Role) throws -> Membership {
        if !shouldSucceed {
            throw errorToThrow ?? DataServiceError.validationFailed(["Mock error"])
        }
        
        return Membership(family: family, user: user, role: role)
    }
    
    override func save() throws {
        if !shouldSucceed {
            throw errorToThrow ?? DataServiceError.invalidData("Save failed")
        }
    }
}

class MockSyncManager: SyncManager {
    var isOfflineMode = false
    
    override init(dataService: DataService, cloudKitService: CloudKitService) {
        super.init(dataService: dataService, cloudKitService: cloudKitService)
    }
    
    override func markRecordForSync<T: CloudKitSyncable>(_ record: T) {
        // Mock implementation
    }
}