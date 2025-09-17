import XCTest
import SwiftData
@testable import TribeBoard

@MainActor
final class CreateFamilyViewModelTests: XCTestCase {
    
    var viewModel: CreateFamilyViewModel!
    var mockDataService: CreateFamilyMockDataService!
    var mockCloudKitService: CreateFamilyMockCloudKitService!
    var mockQRCodeService: MockQRCodeService!
    var mockCodeGenerator: MockCodeGenerator!
    var testUser: UserProfile!
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockDataService = CreateFamilyMockDataService()
        mockCloudKitService = CreateFamilyMockCloudKitService()
        mockQRCodeService = MockQRCodeService()
        mockCodeGenerator = MockCodeGenerator()
        
        testUser = UserProfile(displayName: "Test User", appleUserIdHash: "test_hash")
        
        viewModel = CreateFamilyViewModel(
            user: testUser,
            dataService: mockDataService,
            cloudKitService: mockCloudKitService,
            qrCodeService: mockQRCodeService,
            codeGenerator: mockCodeGenerator
        )
    }
    
    override func tearDown() async throws {
        viewModel = nil
        mockDataService = nil
        mockCloudKitService = nil
        mockQRCodeService = nil
        mockCodeGenerator = nil
        testUser = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertEqual(viewModel.familyName, "")
        XCTAssertFalse(viewModel.isCreating)
        XCTAssertNil(viewModel.createdFamily)
        XCTAssertNil(viewModel.qrCodeImage)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.familyCreationComplete)
    }
    
    // MARK: - Family Name Validation Tests
    
    func testFamilyNameValidation_Valid() {
        viewModel.familyName = "Smith Family"
        XCTAssertTrue(viewModel.isValidFamilyName)
        XCTAssertNil(viewModel.familyNameError)
    }
    
    func testFamilyNameValidation_Empty() {
        viewModel.familyName = ""
        XCTAssertFalse(viewModel.isValidFamilyName)
        XCTAssertNotNil(viewModel.familyNameError)
    }
    
    func testFamilyNameValidation_TooShort() {
        viewModel.familyName = "A"
        XCTAssertFalse(viewModel.isValidFamilyName)
        XCTAssertNotNil(viewModel.familyNameError)
    }
    
    func testFamilyNameValidation_TooLong() {
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
    
    func testClearError() {
        viewModel.errorMessage = "Test error"
        XCTAssertNotNil(viewModel.errorMessage)
        
        viewModel.clearError()
        XCTAssertNil(viewModel.errorMessage)
    }
    
    // MARK: - App State Integration Tests
    
    func testSetAppState() {
        let mockAppState = CreateFamilyMockAppState()
        viewModel.setAppState(mockAppState)
        
        // Test that app state is updated after family creation
        Task {
            viewModel.familyName = "Test Family"
            mockCodeGenerator.mockCode = "TEST123"
            mockDataService.shouldSucceed = true
            
            await viewModel.createFamily()
            
            // Verify app state was updated
            XCTAssertTrue(mockAppState.setFamilyCalled)
        }
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
    
    override func generateStyledFamilyQRCode(familyCode: String, size: CGSize = CGSize(width: 300, height: 300)) -> UIImage? {
        if shouldFail {
            return nil
        }
        return mockImage ?? UIImage()
    }
}

class MockCodeGenerator: CodeGenerator {
    var shouldFail = false
    var mockCode = "TEST123"
    var errorToThrow: Error?
    
    override func generateUniqueCode(uniquenessCheck: @escaping (String) async throws -> Bool) async throws -> String {
        if shouldFail {
            throw errorToThrow ?? CodeGenerationError.maxRetriesExceeded
        }
        return mockCode
    }
}

class CreateFamilyMockAppState: AppState {
    var setFamilyCalled = false
    
    override func setFamily(_ family: Family) {
        setFamilyCalled = true
        super.setFamily(family)
    }
}

class CreateFamilyMockDataService: DataService {
    var shouldSucceed = true
    var shouldDelay = false
    var errorToThrow: Error?
    
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
}