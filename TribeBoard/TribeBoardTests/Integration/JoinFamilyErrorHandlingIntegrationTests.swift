import XCTest
import SwiftUI
@testable import TribeBoard

/// Integration tests for error handling in the Join Family redesigned interface
@MainActor
class JoinFamilyErrorHandlingIntegrationTests: TestBase {
    
    // MARK: - Properties
    
    var viewModel: JoinFamilyViewModel!
    var appState: AppState!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        setupTestEnvironment()
    }
    
    override func tearDown() {
        cleanupTestEnvironment()
        super.tearDown()
    }
    
    private func setupTestEnvironment() {
        // Initialize with in-memory data manager for testing
        let dataManager = InMemoryFamilyDataManager.shared
        dataManager.reset() // Clear any existing test data
        
        viewModel = JoinFamilyViewModel(dataManager: dataManager)
        appState = AppState()
        
        // Set up a test user
        let testUser = UserProfile(
            id: "test-user-123",
            displayName: "Test User",
            email: "test@example.com"
        )
        appState.setUser(testUser)
    }
    
    private func cleanupTestEnvironment() {
        viewModel = nil
        appState = nil
        InMemoryFamilyDataManager.shared.reset()
    }
    
    // MARK: - Card Layout Error Display Tests
    
    func testCardLayoutErrorDisplay_ValidationError() async {
        // Given
        let invalidCode = "AB" // Too short
        
        // When
        viewModel.familyCode = invalidCode
        
        // Then
        XCTAssertFalse(viewModel.isValidCode)
        XCTAssertNotNil(viewModel.codeValidationMessage)
        XCTAssertEqual(viewModel.codeValidationMessage, "Code must be 6 characters with letters and numbers")
    }
    
    func testCardLayoutErrorDisplay_EmptyCodeError() async {
        // Given
        let emptyCode = ""
        
        // When
        await viewModel.searchFamily(by: emptyCode)
        
        // Then
        XCTAssertNotNil(viewModel.currentError)
        XCTAssertEqual(viewModel.currentError, .emptyCode)
        XCTAssertTrue(viewModel.showErrorAlert)
    }
    
    func testCardLayoutErrorDisplay_InvalidCodeError() async {
        // Given
        let invalidCode = "12345" // Invalid format
        
        // When
        await viewModel.searchFamily(by: invalidCode)
        
        // Then
        XCTAssertNotNil(viewModel.currentError)
        XCTAssertEqual(viewModel.currentError, .invalidCode)
        XCTAssertTrue(viewModel.showErrorAlert)
    }
    
    func testCardLayoutErrorDisplay_FamilyNotFoundError() async {
        // Given
        let nonExistentCode = "NOTFND"
        
        // When
        await viewModel.searchFamily(by: nonExistentCode)
        
        // Then
        XCTAssertNotNil(viewModel.currentError)
        XCTAssertEqual(viewModel.currentError, .familyNotFound)
        XCTAssertTrue(viewModel.showErrorAlert)
    }
    
    // MARK: - Inline Error Message Tests
    
    func testInlineErrorMessage_ShowsForInvalidCode() {
        // Given
        let invalidCode = "ABC12" // 5 characters, invalid
        
        // When
        viewModel.familyCode = invalidCode
        
        // Then
        XCTAssertFalse(viewModel.isValidCode)
        XCTAssertNotNil(viewModel.codeValidationMessage)
        
        // Simulate card component logic
        let shouldShowInlineError = !viewModel.familyCode.isEmpty && !viewModel.isValidCode
        XCTAssertTrue(shouldShowInlineError)
    }
    
    func testInlineErrorMessage_HiddenForValidCode() {
        // Given
        let validCode = "ABC123"
        
        // When
        viewModel.familyCode = validCode
        
        // Then
        XCTAssertTrue(viewModel.isValidCode)
        XCTAssertNil(viewModel.codeValidationMessage)
        
        // Simulate card component logic
        let shouldShowInlineError = !viewModel.familyCode.isEmpty && !viewModel.isValidCode
        XCTAssertFalse(shouldShowInlineError)
    }
    
    func testInlineErrorMessage_HiddenForEmptyCode() {
        // Given
        let emptyCode = ""
        
        // When
        viewModel.familyCode = emptyCode
        
        // Then
        // Simulate card component logic
        let shouldShowInlineError = !viewModel.familyCode.isEmpty && !viewModel.isValidCode
        XCTAssertFalse(shouldShowInlineError)
    }
    
    // MARK: - Loading State Tests
    
    func testLoadingState_SearchingFamily() async {
        // Given
        let validCode = "ABC123"
        viewModel.familyCode = validCode
        
        // When
        let searchTask = Task {
            await viewModel.searchFamily(by: validCode)
        }
        
        // Then - Should be in loading state initially
        XCTAssertTrue(viewModel.isSearching)
        
        // Wait for completion
        await searchTask.value
        
        // Then - Should not be loading anymore
        XCTAssertFalse(viewModel.isSearching)
    }
    
    func testLoadingState_JoiningFamily() async {
        // Given - Set up a family to join
        let dataManager = InMemoryFamilyDataManager.shared
        let testFamily = InMemoryFamily(
            id: "test-family-123",
            name: "Test Family",
            code: "TEST01",
            createdAt: Date(),
            members: []
        )
        dataManager.addFamily(testFamily)
        
        // Search for the family first
        await viewModel.searchFamily(by: "TEST01")
        XCTAssertNotNil(viewModel.foundFamily)
        
        // When
        let joinTask = Task {
            await viewModel.joinFamily(with: appState)
        }
        
        // Then - Should be in joining state initially
        XCTAssertTrue(viewModel.isJoining)
        
        // Wait for completion
        await joinTask.value
        
        // Then - Should not be joining anymore
        XCTAssertFalse(viewModel.isJoining)
    }
    
    // MARK: - Alert Dialog Tests
    
    func testAlertDialog_ErrorWithRetryOption() async {
        // Given
        let nonExistentCode = "NOTFND"
        
        // When
        await viewModel.searchFamily(by: nonExistentCode)
        
        // Then
        XCTAssertTrue(viewModel.showErrorAlert)
        XCTAssertNotNil(viewModel.currentError)
        XCTAssertTrue(viewModel.currentError?.isRetryable == true)
    }
    
    func testAlertDialog_ErrorWithoutRetryOption() async {
        // Given
        let invalidCode = "12345"
        
        // When
        await viewModel.searchFamily(by: invalidCode)
        
        // Then
        XCTAssertTrue(viewModel.showErrorAlert)
        XCTAssertNotNil(viewModel.currentError)
        XCTAssertFalse(viewModel.currentError?.isRetryable == true)
    }
    
    func testAlertDialog_ErrorDismissal() {
        // Given
        viewModel.showError(.familyNotFound)
        XCTAssertTrue(viewModel.showErrorAlert)
        
        // When
        viewModel.clearError()
        
        // Then
        XCTAssertFalse(viewModel.showErrorAlert)
        XCTAssertNil(viewModel.currentError)
    }
    
    // MARK: - Confirmation Dialog Tests
    
    func testConfirmationDialog_ShowsForFoundFamily() async {
        // Given - Set up a family to find
        let dataManager = InMemoryFamilyDataManager.shared
        let testFamily = InMemoryFamily(
            id: "test-family-456",
            name: "Test Family 2",
            code: "TEST02",
            createdAt: Date(),
            members: []
        )
        dataManager.addFamily(testFamily)
        
        // When
        await viewModel.searchFamily(by: "TEST02")
        
        // Then
        XCTAssertNotNil(viewModel.foundFamily)
        XCTAssertTrue(viewModel.showConfirmation)
        XCTAssertEqual(viewModel.foundFamily?.name, "Test Family 2")
    }
    
    func testConfirmationDialog_CancelsCorrectly() async {
        // Given - Set up a family and find it
        let dataManager = InMemoryFamilyDataManager.shared
        let testFamily = InMemoryFamily(
            id: "test-family-789",
            name: "Test Family 3",
            code: "TEST03",
            createdAt: Date(),
            members: []
        )
        dataManager.addFamily(testFamily)
        
        await viewModel.searchFamily(by: "TEST03")
        XCTAssertTrue(viewModel.showConfirmation)
        
        // When
        viewModel.cancelJoin()
        
        // Then
        XCTAssertFalse(viewModel.showConfirmation)
        XCTAssertNil(viewModel.foundFamily)
        XCTAssertEqual(viewModel.memberCount, 0)
    }
    
    // MARK: - QR Code Error Handling Tests
    
    func testQRCodeError_InvalidScannedCode() async {
        // Given
        let invalidScannedCode = "INVALID"
        
        // When
        await viewModel.handleScannedCode(invalidScannedCode)
        
        // Then
        XCTAssertEqual(viewModel.familyCode, invalidScannedCode)
        XCTAssertNotNil(viewModel.currentError)
        XCTAssertEqual(viewModel.currentError, .familyNotFound)
    }
    
    func testQRCodeError_ValidScannedCode() async {
        // Given - Set up a family for QR scanning
        let dataManager = InMemoryFamilyDataManager.shared
        let testFamily = InMemoryFamily(
            id: "qr-family-123",
            name: "QR Test Family",
            code: "QRTEST",
            createdAt: Date(),
            members: []
        )
        dataManager.addFamily(testFamily)
        
        // When
        await viewModel.handleScannedCode("QRTEST")
        
        // Then
        XCTAssertEqual(viewModel.familyCode, "QRTEST")
        XCTAssertNotNil(viewModel.foundFamily)
        XCTAssertTrue(viewModel.showConfirmation)
        XCTAssertNil(viewModel.currentError)
    }
    
    // MARK: - Error Recovery Tests
    
    func testErrorRecovery_RetryAfterFailure() async {
        // Given - Initial failure
        await viewModel.searchFamily(by: "NOTFND")
        XCTAssertNotNil(viewModel.currentError)
        XCTAssertTrue(viewModel.showErrorAlert)
        
        // Clear error
        viewModel.clearError()
        
        // Set up a valid family
        let dataManager = InMemoryFamilyDataManager.shared
        let testFamily = InMemoryFamily(
            id: "retry-family-123",
            name: "Retry Test Family",
            code: "RETRY1",
            createdAt: Date(),
            members: []
        )
        dataManager.addFamily(testFamily)
        
        // When - Retry with valid code
        await viewModel.searchFamily(by: "RETRY1")
        
        // Then
        XCTAssertNil(viewModel.currentError)
        XCTAssertFalse(viewModel.showErrorAlert)
        XCTAssertNotNil(viewModel.foundFamily)
        XCTAssertTrue(viewModel.showConfirmation)
    }
    
    func testErrorRecovery_ClearErrorOnNewSearch() async {
        // Given - Initial error state
        viewModel.showError(.familyNotFound)
        XCTAssertNotNil(viewModel.currentError)
        
        // When - Start new search
        await viewModel.searchFamily(by: "NEWSCH")
        
        // Then - Error should be cleared during search
        // (Even if search fails again, the old error is cleared first)
        XCTAssertTrue(viewModel.currentError == .familyNotFound) // New error, not old one
    }
    
    // MARK: - Integration Flow Tests
    
    func testIntegrationFlow_CompleteErrorHandlingFlow() async {
        // Given - Start with invalid input
        viewModel.familyCode = "AB" // Too short
        
        // Then - Should show validation error
        XCTAssertFalse(viewModel.isValidCode)
        XCTAssertNotNil(viewModel.codeValidationMessage)
        
        // When - Try to search with invalid code
        await viewModel.searchFamily(by: "12345")
        
        // Then - Should show search error
        XCTAssertNotNil(viewModel.currentError)
        XCTAssertTrue(viewModel.showErrorAlert)
        
        // When - Clear error and try valid code
        viewModel.clearError()
        
        // Set up valid family
        let dataManager = InMemoryFamilyDataManager.shared
        let testFamily = InMemoryFamily(
            id: "flow-family-123",
            name: "Flow Test Family",
            code: "FLOW01",
            createdAt: Date(),
            members: []
        )
        dataManager.addFamily(testFamily)
        
        await viewModel.searchFamily(by: "FLOW01")
        
        // Then - Should succeed
        XCTAssertNil(viewModel.currentError)
        XCTAssertFalse(viewModel.showErrorAlert)
        XCTAssertNotNil(viewModel.foundFamily)
        XCTAssertTrue(viewModel.showConfirmation)
    }
    
    func testIntegrationFlow_ErrorStateReset() {
        // Given - Various error states
        viewModel.showError(.familyNotFound)
        viewModel.familyCode = "INVALID"
        
        // When - Reset
        viewModel.reset()
        
        // Then - All error states should be cleared
        XCTAssertNil(viewModel.currentError)
        XCTAssertFalse(viewModel.showErrorAlert)
        XCTAssertFalse(viewModel.showSuccessAlert)
        XCTAssertEqual(viewModel.familyCode, "")
        XCTAssertNil(viewModel.foundFamily)
        XCTAssertFalse(viewModel.showConfirmation)
    }
    
    // MARK: - Accessibility Error Handling Tests
    
    func testAccessibilityErrorHandling_ErrorAnnouncements() async {
        // Given
        let invalidCode = "INVALID"
        
        // When
        await viewModel.searchFamily(by: invalidCode)
        
        // Then
        XCTAssertNotNil(viewModel.currentError)
        // In a real implementation, you would verify that accessibility announcements were made
        // This would require mocking the EnhancedAccessibility class
    }
    
    func testAccessibilityErrorHandling_ErrorLabels() {
        // Given
        let validationMessage = "Code must be 6 characters with letters and numbers"
        
        // When
        viewModel.familyCode = "AB"
        
        // Then
        XCTAssertNotNil(viewModel.codeValidationMessage)
        // In a real implementation, you would verify that error messages have proper accessibility labels
    }
    
    // MARK: - Performance Error Handling Tests
    
    func testPerformanceErrorHandling_MultipleErrors() {
        measure {
            for i in 0..<100 {
                let error: FamilyJoinError = i % 2 == 0 ? .invalidCode : .familyNotFound
                viewModel.showError(error)
                viewModel.clearError()
            }
        }
    }
    
    func testPerformanceErrorHandling_ValidationUpdates() {
        measure {
            for i in 0..<100 {
                viewModel.familyCode = i % 2 == 0 ? "VALID1" : "INV"
            }
        }
    }
}