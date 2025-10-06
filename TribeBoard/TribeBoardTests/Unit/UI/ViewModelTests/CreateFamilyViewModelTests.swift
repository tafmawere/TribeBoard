import XCTest
import SwiftUI
@testable import TribeBoard

/// Comprehensive unit tests for CreateFamilyViewModel covering all user flows
@MainActor
class CreateFamilyViewModelTests: TestBase {
    
    // MARK: - Properties
    
    var viewModel: CreateFamilyViewModel!
    var mockDataManager: InMemoryFamilyDataManager!
    var mockQRCodeService: MockQRCodeService!
    var mockAppState: MockAppState!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        mockDataManager = InMemoryFamilyDataManager()
        mockQRCodeService = MockQRCodeService()
        mockAppState = MockAppState()
        
        viewModel = CreateFamilyViewModel(
            dataManager: mockDataManager,
            qrCodeService: mockQRCodeService
        )
    }
    
    override func tearDown() {
        mockDataManager.clearAllData()
        viewModel = nil
        mockDataManager = nil
        mockQRCodeService = nil
        mockAppState = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization_DefaultState() {
        // Then
        XCTAssertEqual(viewModel.familyName, "")
        XCTAssertEqual(viewModel.creationState, .idle)
        XCTAssertNil(viewModel.createdFamily)
        XCTAssertNil(viewModel.qrCodeImage)
        XCTAssertNil(viewModel.currentError)
        XCTAssertFalse(viewModel.showErrorAlert)
        XCTAssertFalse(viewModel.showSuccessAlert)
        XCTAssertFalse(viewModel.isValidFamilyName)
        XCTAssertEqual(viewModel.retryCount, 0)
        XCTAssertEqual(viewModel.progress, 0.0)
        XCTAssertEqual(viewModel.statusMessage, "Ready to create family")
    }
    
    func testInitialization_WithCustomDependencies() {
        // Given
        let customDataManager = InMemoryFamilyDataManager()
        let customQRService = MockQRCodeService()
        
        // When
        let customViewModel = CreateFamilyViewModel(
            dataManager: customDataManager,
            qrCodeService: customQRService
        )
        
        // Then
        XCTAssertNotNil(customViewModel)
        XCTAssertEqual(customViewModel.creationState, .idle)
    }
    
    // MARK: - Family Name Validation Tests
    
    func testFamilyNameValidation_ValidNames() {
        // Given
        let validNames = [
            "Smith Family",
            "The Johnsons",
            "AB", // minimum length
            "A".repeated(50) // maximum length
        ]
        
        // When & Then
        for name in validNames {
            viewModel.familyName = name
            
            // Allow time for validation to update
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            
            XCTAssertTrue(viewModel.isValidFamilyName, "Name '\(name)' should be valid")
        }
    }
    
    func testFamilyNameValidation_InvalidNames() {
        // Given
        let invalidNames = [
            "",
            " ",
            "A", // too short
            "A".repeated(51) // too long
        ]
        
        // When & Then
        for name in invalidNames {
            viewModel.familyName = name
            
            // Allow time for validation to update
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            
            XCTAssertFalse(viewModel.isValidFamilyName, "Name '\(name)' should be invalid")
        }
    }
    
    func testFamilyNameValidation_RealTimeUpdates() {
        // Given
        viewModel.familyName = "A" // Invalid
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertFalse(viewModel.isValidFamilyName)
        
        // When
        viewModel.familyName = "Valid Family Name"
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        
        // Then
        XCTAssertTrue(viewModel.isValidFamilyName)
    }
    
    // MARK: - Computed Properties Tests
    
    func testCanCreateFamily_ValidConditions() {
        // Given
        viewModel.familyName = "Valid Family"
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        viewModel.creationState = .idle
        
        // Then
        XCTAssertTrue(viewModel.canCreateFamily)
    }
    
    func testCanCreateFamily_InvalidConditions() {
        // Test invalid family name
        viewModel.familyName = ""
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertFalse(viewModel.canCreateFamily)
        
        // Test non-idle state
        viewModel.familyName = "Valid Family"
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        viewModel.creationState = .validating
        XCTAssertFalse(viewModel.canCreateFamily)
    }
    
    func testIsCreating_States() {
        // Test idle state
        viewModel.creationState = .idle
        XCTAssertFalse(viewModel.isCreating)
        
        // Test active states
        let activeStates: [FamilyCreationState] = [.validating, .generatingCode, .creatingLocally]
        for state in activeStates {
            viewModel.creationState = state
            XCTAssertTrue(viewModel.isCreating, "State \(state) should be considered creating")
        }
        
        // Test completed state
        viewModel.creationState = .completed
        XCTAssertFalse(viewModel.isCreating)
    }
    
    func testIsCompleted_State() {
        // Test non-completed states
        let nonCompletedStates: [FamilyCreationState] = [.idle, .validating, .generatingCode, .creatingLocally, .failed(.userNotFound)]
        for state in nonCompletedStates {
            viewModel.creationState = state
            XCTAssertFalse(viewModel.isCompleted, "State \(state) should not be completed")
        }
        
        // Test completed state
        viewModel.creationState = .completed
        XCTAssertTrue(viewModel.isCompleted)
    }
    
    func testIsFailed_State() {
        // Test non-failed states
        let nonFailedStates: [FamilyCreationState] = [.idle, .validating, .generatingCode, .creatingLocally, .completed]
        for state in nonFailedStates {
            viewModel.creationState = state
            XCTAssertFalse(viewModel.isFailed, "State \(state) should not be failed")
        }
        
        // Test failed state
        viewModel.creationState = .failed(.userNotFound)
        XCTAssertTrue(viewModel.isFailed)
    }
    
    func testCanRetry_Conditions() {
        // Test can retry when failed and under retry limit
        viewModel.creationState = .failed(.userNotFound)
        viewModel.retryCount = 2
        XCTAssertTrue(viewModel.canRetry)
        
        // Test cannot retry when at retry limit
        viewModel.retryCount = 3
        XCTAssertFalse(viewModel.canRetry)
        
        // Test cannot retry when not failed
        viewModel.creationState = .idle
        viewModel.retryCount = 0
        XCTAssertFalse(viewModel.canRetry)
    }
    
    func testCanCancel_Conditions() {
        // Test can cancel when creating
        viewModel.creationState = .validating
        XCTAssertTrue(viewModel.canCancel)
        
        // Test cannot cancel when not creating
        viewModel.creationState = .idle
        XCTAssertFalse(viewModel.canCancel)
    }
    
    // MARK: - Family Creation Tests
    
    func testCreateFamily_Success() async {
        // Given
        viewModel.familyName = "Test Family"
        mockAppState.currentUser = createTestUser()
        mockQRCodeService.mockQRImage = Image(systemName: "qrcode")
        
        // When
        await viewModel.createFamily(with: mockAppState)
        
        // Then
        XCTAssertEqual(viewModel.creationState, .completed)
        XCTAssertNotNil(viewModel.createdFamily)
        XCTAssertEqual(viewModel.createdFamily?.name, "Test Family")
        XCTAssertNotNil(viewModel.qrCodeImage)
        XCTAssertEqual(mockDataManager.families.count, 1)
        XCTAssertTrue(mockAppState.navigationCalled)
    }
    
    func testCreateFamily_UserNotAuthenticated() async {
        // Given
        viewModel.familyName = "Test Family"
        mockAppState.currentUser = nil
        
        // When
        await viewModel.createFamily(with: mockAppState)
        
        // Then
        XCTAssertTrue(viewModel.isFailed)
        XCTAssertEqual(viewModel.currentError, .userNotFound)
        XCTAssertTrue(viewModel.showErrorAlert)
        XCTAssertNil(viewModel.createdFamily)
    }
    
    func testCreateFamily_EmptyFamilyName() async {
        // Given
        viewModel.familyName = ""
        mockAppState.currentUser = createTestUser()
        
        // When
        await viewModel.createFamily(with: mockAppState)
        
        // Then
        XCTAssertTrue(viewModel.isFailed)
        XCTAssertEqual(viewModel.currentError, .emptyFamilyName)
        XCTAssertTrue(viewModel.showErrorAlert)
    }
    
    func testCreateFamily_InvalidFamilyName() async {
        // Given
        viewModel.familyName = "A" // Too short
        mockAppState.currentUser = createTestUser()
        
        // When
        await viewModel.createFamily(with: mockAppState)
        
        // Then
        XCTAssertTrue(viewModel.isFailed)
        XCTAssertEqual(viewModel.currentError, .invalidFamilyName)
        XCTAssertTrue(viewModel.showErrorAlert)
    }
    
    func testCreateFamily_StateProgression() async {
        // Given
        viewModel.familyName = "Test Family"
        mockAppState.currentUser = createTestUser()
        mockQRCodeService.mockQRImage = Image(systemName: "qrcode")
        
        var stateProgression: [FamilyCreationState] = []
        
        // Monitor state changes
        let cancellable = viewModel.$creationState.sink { state in
            stateProgression.append(state)
        }
        
        // When
        await viewModel.createFamily(with: mockAppState)
        
        // Then
        XCTAssertTrue(stateProgression.contains(.idle))
        XCTAssertTrue(stateProgression.contains(.validating))
        XCTAssertTrue(stateProgression.contains(.creatingLocally))
        XCTAssertTrue(stateProgression.contains(.completed))
        
        cancellable.cancel()
    }
    
    func testCreateFamily_ProgressUpdates() async {
        // Given
        viewModel.familyName = "Test Family"
        mockAppState.currentUser = createTestUser()
        mockQRCodeService.mockQRImage = Image(systemName: "qrcode")
        
        var progressValues: [Double] = []
        
        // Monitor progress changes
        let cancellable = viewModel.$progress.sink { progress in
            progressValues.append(progress)
        }
        
        // When
        await viewModel.createFamily(with: mockAppState)
        
        // Then
        XCTAssertTrue(progressValues.contains(0.0)) // Initial
        XCTAssertTrue(progressValues.contains(1.0)) // Completed
        XCTAssertTrue(progressValues.contains { $0 > 0.0 && $0 < 1.0 }) // Intermediate values
        
        cancellable.cancel()
    }
    
    // MARK: - Retry Tests
    
    func testRetryCreation_Success() async {
        // Given
        viewModel.familyName = "Test Family"
        viewModel.creationState = .failed(.userNotFound)
        viewModel.retryCount = 1
        mockAppState.currentUser = createTestUser()
        mockQRCodeService.mockQRImage = Image(systemName: "qrcode")
        
        // When
        await viewModel.retryCreation(with: mockAppState)
        
        // Then
        XCTAssertEqual(viewModel.retryCount, 2)
        XCTAssertEqual(viewModel.creationState, .completed)
        XCTAssertNotNil(viewModel.createdFamily)
    }
    
    func testRetryCreation_CannotRetry() async {
        // Given
        viewModel.familyName = "Test Family"
        viewModel.creationState = .failed(.userNotFound)
        viewModel.retryCount = 3 // At max retry limit
        mockAppState.currentUser = createTestUser()
        
        let initialRetryCount = viewModel.retryCount
        
        // When
        await viewModel.retryCreation(with: mockAppState)
        
        // Then
        XCTAssertEqual(viewModel.retryCount, initialRetryCount) // Should not change
        XCTAssertTrue(viewModel.isFailed) // Should remain failed
    }
    
    // MARK: - Cancel Tests
    
    func testCancelCreation_Success() {
        // Given
        viewModel.creationState = .validating
        
        // When
        viewModel.cancelCreation()
        
        // Then
        XCTAssertTrue(viewModel.isFailed)
        XCTAssertEqual(viewModel.currentError, .operationCancelled)
    }
    
    func testCancelCreation_CannotCancel() {
        // Given
        viewModel.creationState = .idle
        let initialState = viewModel.creationState
        
        // When
        viewModel.cancelCreation()
        
        // Then
        XCTAssertEqual(viewModel.creationState, initialState) // Should not change
    }
    
    // MARK: - Error Handling Tests
    
    func testClearError_Success() {
        // Given
        viewModel.currentError = .userNotFound
        viewModel.showErrorAlert = true
        viewModel.creationState = .failed(.userNotFound)
        
        // When
        viewModel.clearError()
        
        // Then
        XCTAssertNil(viewModel.currentError)
        XCTAssertFalse(viewModel.showErrorAlert)
        XCTAssertEqual(viewModel.creationState, .idle)
    }
    
    func testShowError_Success() {
        // Given
        let error = FamilyCreationError.invalidFamilyName
        
        // When
        viewModel.showError(error)
        
        // Then
        XCTAssertEqual(viewModel.currentError, error)
        XCTAssertTrue(viewModel.showErrorAlert)
    }
    
    func testShowSuccess_Success() {
        // When
        viewModel.showSuccess()
        
        // Then
        XCTAssertTrue(viewModel.showSuccessAlert)
    }
    
    // MARK: - Form Reset Tests
    
    func testResetForm_Success() {
        // Given
        viewModel.familyName = "Test Family"
        viewModel.createdFamily = InMemoryFamily(name: "Test", code: "TEST01")
        viewModel.qrCodeImage = Image(systemName: "qrcode")
        viewModel.creationState = .completed
        viewModel.currentError = .userNotFound
        viewModel.retryCount = 2
        
        // When
        viewModel.resetForm()
        
        // Then
        XCTAssertEqual(viewModel.familyName, "")
        XCTAssertNil(viewModel.createdFamily)
        XCTAssertNil(viewModel.qrCodeImage)
        XCTAssertEqual(viewModel.creationState, .idle)
        XCTAssertNil(viewModel.currentError)
        XCTAssertEqual(viewModel.retryCount, 0)
    }
    
    func testResetCreationState_Success() {
        // Given
        viewModel.creationState = .failed(.userNotFound)
        viewModel.currentError = .invalidFamilyName
        viewModel.retryCount = 2
        viewModel.progress = 0.5
        
        // When
        viewModel.resetCreationState()
        
        // Then
        XCTAssertEqual(viewModel.creationState, .idle)
        XCTAssertNil(viewModel.currentError)
        XCTAssertEqual(viewModel.retryCount, 0)
        XCTAssertEqual(viewModel.progress, 0.0)
        XCTAssertEqual(viewModel.statusMessage, "Ready to create family")
    }
    
    // MARK: - Integration Tests
    
    func testCompleteUserFlow_CreateFamilySuccessfully() async {
        // Given
        let familyName = "Integration Test Family"
        viewModel.familyName = familyName
        mockAppState.currentUser = createTestUser()
        mockQRCodeService.mockQRImage = Image(systemName: "qrcode")
        
        // When - Complete flow
        await viewModel.createFamily(with: mockAppState)
        
        // Then - Verify final state
        XCTAssertEqual(viewModel.creationState, .completed)
        XCTAssertNotNil(viewModel.createdFamily)
        XCTAssertEqual(viewModel.createdFamily?.name, familyName)
        XCTAssertNotNil(viewModel.qrCodeImage)
        XCTAssertEqual(mockDataManager.families.count, 1)
        XCTAssertEqual(mockDataManager.users.count, 1)
        XCTAssertTrue(mockAppState.navigationCalled)
        
        // Verify family has creator as member
        let family = viewModel.createdFamily!
        XCTAssertEqual(family.members.count, 1)
        XCTAssertEqual(family.members.first?.role, .parent)
    }
    
    func testCompleteUserFlow_HandleErrorAndRetry() async {
        // Given
        viewModel.familyName = "Test Family"
        mockAppState.currentUser = nil // This will cause an error
        
        // When - First attempt (should fail)
        await viewModel.createFamily(with: mockAppState)
        
        // Then - Verify error state
        XCTAssertTrue(viewModel.isFailed)
        XCTAssertEqual(viewModel.currentError, .userNotFound)
        
        // Given - Fix the issue
        mockAppState.currentUser = createTestUser()
        mockQRCodeService.mockQRImage = Image(systemName: "qrcode")
        
        // When - Retry
        await viewModel.retryCreation(with: mockAppState)
        
        // Then - Verify success
        XCTAssertEqual(viewModel.creationState, .completed)
        XCTAssertNotNil(viewModel.createdFamily)
        XCTAssertEqual(viewModel.retryCount, 1)
    }
    
    // MARK: - Helper Methods
    
    private func createTestUser() -> UserProfile {
        return UserProfile(
            displayName: "Test User",
            appleUserIdHash: "test_hash_123"
        )
    }
}

// MARK: - Mock Classes

class MockQRCodeService: QRCodeService {
    var mockQRImage: Image?
    var shouldThrowError = false
    
    override func generateQRCode(from text: String) -> Image? {
        if shouldThrowError {
            return nil
        }
        return mockQRImage
    }
}

class MockAppState: AppState {
    var navigationCalled = false
    var lastNavigationTab: NavigationTab?
    var familySet = false
    var setFamilyValue: InMemoryFamily?
    
    func navigateTo(_ tab: NavigationTab) {
        navigationCalled = true
        lastNavigationTab = tab
        selectedNavigationTab = tab
    }
    
    func setFamily(_ family: InMemoryFamily) {
        familySet = true
        setFamilyValue = family
        currentInMemoryFamily = family
    }
}

// MARK: - String Extension for Testing

extension String {
    func repeated(_ count: Int) -> String {
        return String(repeating: self, count: count)
    }
}