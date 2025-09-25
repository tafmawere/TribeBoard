import XCTest
import SwiftData
@testable import TribeBoard

@MainActor
final class JoinFamilyViewModelTests: XCTestCase {
    
    var viewModel: JoinFamilyViewModel!
    var mockDataService: MockDataService!
    var mockCloudKitService: MockCloudKitService!
    var mockQRCodeService: MockQRCodeService!
    var testUser: UserProfile!
    var testFamily: Family!
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockDataService = MockDataService()
        mockCloudKitService = MockCloudKitService()
        mockQRCodeService = MockQRCodeService()
        
        testUser = UserProfile(displayName: "Test User", appleUserIdHash: "test_hash")
        testFamily = Family(name: "Test Family", code: "TEST123", createdByUserId: UUID())
        
        viewModel = JoinFamilyViewModel(
            user: testUser,
            dataService: mockDataService,
            cloudKitService: mockCloudKitService,
            qrCodeService: mockQRCodeService
        )
    }
    
    override func tearDown() async throws {
        viewModel = nil
        mockDataService = nil
        mockCloudKitService = nil
        mockQRCodeService = nil
        testUser = nil
        testFamily = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    @MainActor func testInitialization() {
        XCTAssertEqual(viewModel.familyCode, "")
        XCTAssertFalse(viewModel.isSearching)
        XCTAssertFalse(viewModel.isJoining)
        XCTAssertNil(viewModel.foundFamily)
        XCTAssertFalse(viewModel.showConfirmation)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.joinComplete)
    }
    
    // MARK: - Family Code Validation Tests
    
    @MainActor func testFamilyCodeValidation_Valid() {
        viewModel.familyCode = "TEST123"
        XCTAssertTrue(viewModel.isValidFamilyCode)
        XCTAssertNil(viewModel.familyCodeError)
    }
    
    @MainActor func testFamilyCodeValidation_Empty() {
        viewModel.familyCode = ""
        XCTAssertFalse(viewModel.isValidFamilyCode)
        XCTAssertNotNil(viewModel.familyCodeError)
    }
    
    @MainActor func testFamilyCodeValidation_TooShort() {
        viewModel.familyCode = "ABC12"
        XCTAssertFalse(viewModel.isValidFamilyCode)
        XCTAssertNotNil(viewModel.familyCodeError)
    }
    
    @MainActor func testFamilyCodeValidation_InvalidCharacters() {
        viewModel.familyCode = "ABC-123"
        XCTAssertFalse(viewModel.isValidFamilyCode)
        XCTAssertNotNil(viewModel.familyCodeError)
    }
    
    // MARK: - Search Family Tests
    
    func testSearchFamily_Success() async {
        // Setup
        viewModel.familyCode = "TEST123"
        mockCloudKitService.mockFamily = testFamily
        mockCloudKitService.shouldSucceed = true
        
        // Execute
        await viewModel.searchFamily()
        
        // Verify
        XCTAssertFalse(viewModel.isSearching)
        XCTAssertNotNil(viewModel.foundFamily)
        XCTAssertEqual(viewModel.foundFamily?.code, "TEST123")
        XCTAssertTrue(viewModel.showConfirmation)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testSearchFamily_InvalidCode() async {
        // Setup
        viewModel.familyCode = "ABC12" // Invalid
        
        // Execute
        await viewModel.searchFamily()
        
        // Verify
        XCTAssertFalse(viewModel.isSearching)
        XCTAssertNil(viewModel.foundFamily)
        XCTAssertFalse(viewModel.showConfirmation)
        XCTAssertNotNil(viewModel.errorMessage)
    }
    
    func testSearchFamily_NotFound() async {
        // Setup
        viewModel.familyCode = "NOTFOUND"
        mockCloudKitService.mockFamily = nil
        mockCloudKitService.shouldSucceed = true
        
        // Execute
        await viewModel.searchFamily()
        
        // Verify
        XCTAssertFalse(viewModel.isSearching)
        XCTAssertNil(viewModel.foundFamily)
        XCTAssertFalse(viewModel.showConfirmation)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage?.contains("not found") ?? false)
    }
    
    func testSearchFamily_NetworkError() async {
        // Setup
        viewModel.familyCode = "TEST123"
        mockCloudKitService.shouldSucceed = false
        mockCloudKitService.errorToThrow = CloudKitError.networkUnavailable
        
        // Execute
        await viewModel.searchFamily()
        
        // Verify
        XCTAssertFalse(viewModel.isSearching)
        XCTAssertNil(viewModel.foundFamily)
        XCTAssertFalse(viewModel.showConfirmation)
        XCTAssertNotNil(viewModel.errorMessage)
    }
    
    // MARK: - Join Family Tests
    
    func testJoinFamily_Success() async {
        // Setup
        viewModel.foundFamily = testFamily
        mockDataService.shouldSucceed = true
        mockCloudKitService.shouldSucceed = true
        
        // Execute
        await viewModel.joinFamily()
        
        // Verify
        XCTAssertFalse(viewModel.isJoining)
        XCTAssertTrue(viewModel.joinComplete)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testJoinFamily_NoFamilySelected() async {
        // Setup - no family found
        viewModel.foundFamily = nil
        
        // Execute
        await viewModel.joinFamily()
        
        // Verify
        XCTAssertFalse(viewModel.isJoining)
        XCTAssertFalse(viewModel.joinComplete)
        XCTAssertNotNil(viewModel.errorMessage)
    }
    
    func testJoinFamily_DataServiceFailure() async {
        // Setup
        viewModel.foundFamily = testFamily
        mockDataService.shouldSucceed = false
        mockDataService.errorToThrow = DataServiceError.constraintViolation("Already a member")
        
        // Execute
        await viewModel.joinFamily()
        
        // Verify
        XCTAssertFalse(viewModel.isJoining)
        XCTAssertFalse(viewModel.joinComplete)
        XCTAssertNotNil(viewModel.errorMessage)
    }
    
    func testJoinFamily_CloudKitFailure() async {
        // Setup
        viewModel.foundFamily = testFamily
        mockDataService.shouldSucceed = true
        mockCloudKitService.shouldSucceed = false
        mockCloudKitService.errorToThrow = CloudKitError.networkUnavailable
        
        // Execute
        await viewModel.joinFamily()
        
        // Verify - should succeed locally but show sync warning
        XCTAssertFalse(viewModel.isJoining)
        XCTAssertTrue(viewModel.joinComplete)
        XCTAssertTrue(viewModel.errorMessage?.contains("sync") ?? false)
    }
    
    // MARK: - QR Code Scanning Tests
    
    func testScanQRCode_Success() async {
        // Setup
        mockQRCodeService.mockScannedCode = "SCANNED123"
        mockCloudKitService.mockFamily = testFamily
        mockCloudKitService.shouldSucceed = true
        
        // Execute
        await viewModel.scanQRCode()
        
        // Verify
        XCTAssertEqual(viewModel.familyCode, "SCANNED123")
        XCTAssertNotNil(viewModel.foundFamily)
        XCTAssertTrue(viewModel.showConfirmation)
    }
    
    func testScanQRCode_NoCodeFound() async {
        // Setup
        mockQRCodeService.mockScannedCode = nil
        
        // Execute
        await viewModel.scanQRCode()
        
        // Verify
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage?.contains("QR code") ?? false)
    }
    
    func testScanQRCode_InvalidCode() async {
        // Setup
        mockQRCodeService.mockScannedCode = "INVALID"
        
        // Execute
        await viewModel.scanQRCode()
        
        // Verify
        XCTAssertEqual(viewModel.familyCode, "INVALID")
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage?.contains("invalid") ?? false)
    }
    
    // MARK: - Loading State Tests
    
    func testSearchFamily_LoadingState() async {
        // Setup
        viewModel.familyCode = "TEST123"
        mockCloudKitService.shouldDelay = true
        
        // Start search
        let searchTask = Task {
            await viewModel.searchFamily()
        }
        
        // Check loading state
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        XCTAssertTrue(viewModel.isSearching)
        
        // Wait for completion
        await searchTask.value
        XCTAssertFalse(viewModel.isSearching)
    }
    
    func testJoinFamily_LoadingState() async {
        // Setup
        viewModel.foundFamily = testFamily
        mockDataService.shouldDelay = true
        
        // Start join
        let joinTask = Task {
            await viewModel.joinFamily()
        }
        
        // Check loading state
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        XCTAssertTrue(viewModel.isJoining)
        
        // Wait for completion
        await joinTask.value
        XCTAssertFalse(viewModel.isJoining)
    }
    
    // MARK: - Error Handling Tests
    
    @MainActor func testClearError() {
        viewModel.errorMessage = "Test error"
        XCTAssertNotNil(viewModel.errorMessage)
        
        viewModel.clearError()
        XCTAssertNil(viewModel.errorMessage)
    }
    
    @MainActor func testCancelJoin() {
        viewModel.foundFamily = testFamily
        viewModel.showConfirmation = true
        
        viewModel.cancelJoin()
        
        XCTAssertNil(viewModel.foundFamily)
        XCTAssertFalse(viewModel.showConfirmation)
        XCTAssertEqual(viewModel.familyCode, "")
    }
    
    // MARK: - App State Integration Tests
    
    @MainActor func testSetAppState() {
        let mockAppState = MockAppState()
        viewModel.setAppState(mockAppState)
        
        // Test that app state is updated after joining
        Task {
            viewModel.foundFamily = testFamily
            mockDataService.shouldSucceed = true
            
            await viewModel.joinFamily()
            
            // Verify app state was updated
            XCTAssertTrue(mockAppState.setFamilyCalled)
        }
    }
}

// MARK: - Mock Service Extensions

extension MockCloudKitService {
    var mockFamily: Family?
    var shouldDelay = false
    
    func fetchFamily(byCode code: String) async throws -> Family? {
        if shouldDelay {
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        if !shouldSucceed {
            throw errorToThrow ?? CloudKitError.networkUnavailable
        }
        
        return mockFamily
    }
}

extension MockQRCodeService {
    var mockScannedCode: String?
    
    override func scanQRCode(from image: UIImage) -> String? {
        return mockScannedCode
    }
    
    func scanQRCodeFromCamera() async throws -> String? {
        if shouldFail {
            throw QRCodeError.scanningFailed
        }
        return mockScannedCode
    }
}