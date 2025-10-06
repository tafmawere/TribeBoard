import XCTest
import SwiftUI
@testable import TribeBoard

/// Comprehensive unit tests for JoinFamilyViewModel covering all user flows
@MainActor
class JoinFamilyViewModelTests: TestBase {
    
    // MARK: - Properties
    
    var viewModel: JoinFamilyViewModel!
    var mockDataManager: InMemoryFamilyDataManager!
    var mockAppState: MockAppState!
    var testFamily: InMemoryFamily!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        mockDataManager = InMemoryFamilyDataManager()
        mockAppState = MockAppState()
        
        // Create test family
        testFamily = mockDataManager.createFamily(name: "Test Family", createdByUserId: UUID())
        
        viewModel = JoinFamilyViewModel(dataManager: mockDataManager)
    }
    
    override func tearDown() {
        mockDataManager.clearAllData()
        viewModel = nil
        mockDataManager = nil
        mockAppState = nil
        testFamily = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization_DefaultState() {
        // Then
        XCTAssertEqual(viewModel.familyCode, "")
        XCTAssertFalse(viewModel.isSearching)
        XCTAssertFalse(viewModel.isJoining)
        XCTAssertNil(viewModel.foundFamily)
        XCTAssertFalse(viewModel.showConfirmation)
        XCTAssertNil(viewModel.currentError)
        XCTAssertEqual(viewModel.memberCount, 0)
        XCTAssertFalse(viewModel.isValidCode)
        XCTAssertFalse(viewModel.showErrorAlert)
        XCTAssertFalse(viewModel.showSuccessAlert)
    }
    
    func testInitialization_WithCustomDataManager() {
        // Given
        let customDataManager = InMemoryFamilyDataManager()
        
        // When
        let customViewModel = JoinFamilyViewModel(dataManager: customDataManager)
        
        // Then
        XCTAssertNotNil(customViewModel)
        XCTAssertEqual(customViewModel.familyCode, "")
    }
    
    // MARK: - Family Code Validation Tests
    
    func testFamilyCodeValidation_ValidCodes() {
        // Given
        let validCodes = ["ABC123", "XYZ789", "TEST01", "FAM999"]
        
        // When & Then
        for code in validCodes {
            viewModel.familyCode = code
            
            // Allow time for validation to update
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            
            XCTAssertTrue(viewModel.isValidCode, "Code '\(code)' should be valid")
        }
    }
    
    func testFamilyCodeValidation_InvalidCodes() {
        // Given
        let invalidCodes = ["ABC12", "ABCD123", "ABC-123", "ABC 123", ""]
        
        // When & Then
        for code in invalidCodes {
            viewModel.familyCode = code
            
            // Allow time for validation to update
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
            
            XCTAssertFalse(viewModel.isValidCode, "Code '\(code)' should be invalid")
        }
    }
    
    func testFamilyCodeValidation_RealTimeUpdates() {
        // Given
        viewModel.familyCode = "ABC12" // Invalid
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertFalse(viewModel.isValidCode)
        
        // When
        viewModel.familyCode = "ABC123" // Valid
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        
        // Then
        XCTAssertTrue(viewModel.isValidCode)
    }
    
    // MARK: - Search Family Tests
    
    func testSearchFamily_Success() async {
        // Given
        let familyCode = testFamily.code
        
        // When
        await viewModel.searchFamily(by: familyCode)
        
        // Then
        XCTAssertFalse(viewModel.isSearching)
        XCTAssertNotNil(viewModel.foundFamily)
        XCTAssertEqual(viewModel.foundFamily?.id, testFamily.id)
        XCTAssertEqual(viewModel.foundFamily?.name, testFamily.name)
        XCTAssertTrue(viewModel.showConfirmation)
        XCTAssertNil(viewModel.currentError)
    }
    
    func testSearchFamily_FamilyNotFound() async {
        // Given
        let nonExistentCode = "NOTFND"
        
        // When
        await viewModel.searchFamily(by: nonExistentCode)
        
        // Then
        XCTAssertFalse(viewModel.isSearching)
        XCTAssertNil(viewModel.foundFamily)
        XCTAssertFalse(viewModel.showConfirmation)
        XCTAssertEqual(viewModel.currentError, .familyNotFound)
        XCTAssertTrue(viewModel.showErrorAlert)
    }
    
    func testSearchFamily_EmptyCode() async {
        // Given
        let emptyCode = ""
        
        // When
        await viewModel.searchFamily(by: emptyCode)
        
        // Then
        XCTAssertFalse(viewModel.isSearching)
        XCTAssertNil(viewModel.foundFamily)
        XCTAssertEqual(viewModel.currentError, .emptyCode)
        XCTAssertTrue(viewModel.showErrorAlert)
    }
    
    func testSearchFamily_InvalidCodeFormat() async {
        // Given
        let invalidCode = "ABC12" // Too short
        
        // When
        await viewModel.searchFamily(by: invalidCode)
        
        // Then
        XCTAssertFalse(viewModel.isSearching)
        XCTAssertNil(viewModel.foundFamily)
        XCTAssertEqual(viewModel.currentError, .invalidCode)
        XCTAssertTrue(viewModel.showErrorAlert)
    }
    
    func testSearchFamily_CaseInsensitive() async {
        // Given
        let lowercaseCode = testFamily.code.lowercased()
        
        // When
        await viewModel.searchFamily(by: lowercaseCode)
        
        // Then
        XCTAssertNotNil(viewModel.foundFamily)
        XCTAssertEqual(viewModel.foundFamily?.id, testFamily.id)
    }
    
    func testSearchFamily_WithWhitespace() async {
        // Given
        let codeWithWhitespace = "  \(testFamily.code)  "
        
        // When
        await viewModel.searchFamily(by: codeWithWhitespace)
        
        // Then
        XCTAssertNotNil(viewModel.foundFamily)
        XCTAssertEqual(viewModel.foundFamily?.id, testFamily.id)
    }
    
    func testSearchFamily_LoadingState() async {
        // Given
        let familyCode = testFamily.code
        var loadingStates: [Bool] = []
        
        // Monitor loading state changes
        let cancellable = viewModel.$isSearching.sink { isSearching in
            loadingStates.append(isSearching)
        }
        
        // When
        await viewModel.searchFamily(by: familyCode)
        
        // Then
        XCTAssertTrue(loadingStates.contains(true)) // Should have been loading
        XCTAssertFalse(viewModel.isSearching) // Should be false at the end
        
        cancellable.cancel()
    }
    
    func testSearchFamily_MemberCount() async {
        // Given
        let user1 = mockDataManager.createUser(name: "User 1")
        let user2 = mockDataManager.createUser(name: "User 2")
        _ = mockDataManager.addMemberToFamily(familyId: testFamily.id, user: user1, role: .parent)
        _ = mockDataManager.addMemberToFamily(familyId: testFamily.id, user: user2, role: .child)
        
        // When
        await viewModel.searchFamily(by: testFamily.code)
        
        // Then
        XCTAssertEqual(viewModel.memberCount, 2)
    }
    
    // MARK: - Handle Scanned Code Tests
    
    func testHandleScannedCode_Success() async {
        // Given
        let scannedCode = testFamily.code
        
        // When
        await viewModel.handleScannedCode(scannedCode)
        
        // Then
        XCTAssertEqual(viewModel.familyCode, scannedCode)
        XCTAssertNotNil(viewModel.foundFamily)
        XCTAssertEqual(viewModel.foundFamily?.id, testFamily.id)
    }
    
    func testHandleScannedCode_InvalidCode() async {
        // Given
        let invalidScannedCode = "INVALID"
        
        // When
        await viewModel.handleScannedCode(invalidScannedCode)
        
        // Then
        XCTAssertEqual(viewModel.familyCode, invalidScannedCode)
        XCTAssertNil(viewModel.foundFamily)
        XCTAssertEqual(viewModel.currentError, .familyNotFound)
    }
    
    // MARK: - Join Family Tests
    
    func testJoinFamily_Success() async {
        // Given
        viewModel.foundFamily = testFamily
        mockAppState.currentUser = createTestUser()
        
        // When
        await viewModel.joinFamily(with: mockAppState)
        
        // Then
        XCTAssertFalse(viewModel.isJoining)
        XCTAssertFalse(viewModel.showConfirmation)
        XCTAssertTrue(viewModel.showSuccessAlert)
        XCTAssertNil(viewModel.currentError)
        XCTAssertTrue(mockAppState.familySet)
        XCTAssertEqual(mockAppState.setFamilyValue?.id, testFamily.id)
        
        // Verify user was added to family
        XCTAssertEqual(testFamily.members.count, 1)
        XCTAssertEqual(testFamily.members.first?.userId, mockAppState.currentUser?.id)
    }
    
    func testJoinFamily_NoFoundFamily() async {
        // Given
        viewModel.foundFamily = nil
        mockAppState.currentUser = createTestUser()
        
        // When
        await viewModel.joinFamily(with: mockAppState)
        
        // Then
        XCTAssertFalse(viewModel.isJoining)
        XCTAssertEqual(viewModel.currentError, .familyNotFound)
        XCTAssertTrue(viewModel.showErrorAlert)
        XCTAssertFalse(mockAppState.familySet)
    }
    
    func testJoinFamily_NoCurrentUser() async {
        // Given
        viewModel.foundFamily = testFamily
        mockAppState.currentUser = nil
        
        // When
        await viewModel.joinFamily(with: mockAppState)
        
        // Then
        XCTAssertFalse(viewModel.isJoining)
        XCTAssertEqual(viewModel.currentError, .userNotFound)
        XCTAssertTrue(viewModel.showErrorAlert)
        XCTAssertFalse(mockAppState.familySet)
    }
    
    func testJoinFamily_UserAlreadyMember() async {
        // Given
        let user = createTestUser()
        let inMemoryUser = InMemoryUser(id: user.id, name: user.displayName, createdAt: user.createdAt)
        _ = mockDataManager.addMemberToFamily(familyId: testFamily.id, user: inMemoryUser, role: .parent)
        
        viewModel.foundFamily = testFamily
        mockAppState.currentUser = user
        
        // When
        await viewModel.joinFamily(with: mockAppState)
        
        // Then
        XCTAssertFalse(viewModel.isJoining)
        XCTAssertEqual(viewModel.currentError, .alreadyMember)
        XCTAssertTrue(viewModel.showErrorAlert)
        XCTAssertFalse(mockAppState.familySet)
    }
    
    func testJoinFamily_LoadingState() async {
        // Given
        viewModel.foundFamily = testFamily
        mockAppState.currentUser = createTestUser()
        var loadingStates: [Bool] = []
        
        // Monitor loading state changes
        let cancellable = viewModel.$isJoining.sink { isJoining in
            loadingStates.append(isJoining)
        }
        
        // When
        await viewModel.joinFamily(with: mockAppState)
        
        // Then
        XCTAssertTrue(loadingStates.contains(true)) // Should have been loading
        XCTAssertFalse(viewModel.isJoining) // Should be false at the end
        
        cancellable.cancel()
    }
    
    // MARK: - Cancel Join Tests
    
    func testCancelJoin_Success() {
        // Given
        viewModel.foundFamily = testFamily
        viewModel.showConfirmation = true
        viewModel.memberCount = 5
        viewModel.currentError = .familyNotFound
        
        // When
        viewModel.cancelJoin()
        
        // Then
        XCTAssertFalse(viewModel.showConfirmation)
        XCTAssertNil(viewModel.foundFamily)
        XCTAssertEqual(viewModel.memberCount, 0)
        XCTAssertNil(viewModel.currentError)
    }
    
    // MARK: - Error Handling Tests
    
    func testClearError_Success() {
        // Given
        viewModel.currentError = .familyNotFound
        viewModel.showErrorAlert = true
        
        // When
        viewModel.clearError()
        
        // Then
        XCTAssertNil(viewModel.currentError)
        XCTAssertFalse(viewModel.showErrorAlert)
    }
    
    func testShowError_Success() {
        // Given
        let error = FamilyJoinError.invalidCode
        
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
    
    // MARK: - Reset Tests
    
    func testReset_Success() {
        // Given
        viewModel.familyCode = "ABC123"
        viewModel.foundFamily = testFamily
        viewModel.showConfirmation = true
        viewModel.currentError = .familyNotFound
        viewModel.showErrorAlert = true
        viewModel.showSuccessAlert = true
        viewModel.memberCount = 5
        viewModel.isSearching = true
        viewModel.isJoining = true
        viewModel.isValidCode = true
        
        // When
        viewModel.reset()
        
        // Then
        XCTAssertEqual(viewModel.familyCode, "")
        XCTAssertNil(viewModel.foundFamily)
        XCTAssertFalse(viewModel.showConfirmation)
        XCTAssertNil(viewModel.currentError)
        XCTAssertFalse(viewModel.showErrorAlert)
        XCTAssertFalse(viewModel.showSuccessAlert)
        XCTAssertEqual(viewModel.memberCount, 0)
        XCTAssertFalse(viewModel.isSearching)
        XCTAssertFalse(viewModel.isJoining)
        XCTAssertFalse(viewModel.isValidCode)
    }
    
    // MARK: - Validation Tests
    
    func testCanSearch_ValidConditions() {
        // Given
        viewModel.familyCode = "ABC123"
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        viewModel.isSearching = false
        
        // Then
        XCTAssertTrue(viewModel.canSearch)
    }
    
    func testCanSearch_InvalidConditions() {
        // Test invalid code
        viewModel.familyCode = "ABC12"
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertFalse(viewModel.canSearch)
        
        // Test empty code
        viewModel.familyCode = ""
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        XCTAssertFalse(viewModel.canSearch)
        
        // Test while searching
        viewModel.familyCode = "ABC123"
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        viewModel.isSearching = true
        XCTAssertFalse(viewModel.canSearch)
    }
    
    func testCodeValidationMessage_EmptyCode() {
        // Given
        viewModel.familyCode = ""
        
        // When
        let message = viewModel.codeValidationMessage
        
        // Then
        XCTAssertNil(message)
    }
    
    func testCodeValidationMessage_InvalidCode() {
        // Given
        viewModel.familyCode = "ABC12"
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        
        // When
        let message = viewModel.codeValidationMessage
        
        // Then
        XCTAssertNotNil(message)
        XCTAssertTrue(message!.contains("6 characters"))
    }
    
    func testCodeValidationMessage_ValidCode() {
        // Given
        viewModel.familyCode = "ABC123"
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        
        // When
        let message = viewModel.codeValidationMessage
        
        // Then
        XCTAssertNil(message)
    }
    
    func testErrorMessage_WithError() {
        // Given
        viewModel.currentError = .familyNotFound
        
        // When
        let message = viewModel.errorMessage
        
        // Then
        XCTAssertNotNil(message)
        XCTAssertEqual(message, FamilyJoinError.familyNotFound.localizedDescription)
    }
    
    func testErrorMessage_NoError() {
        // Given
        viewModel.currentError = nil
        
        // When
        let message = viewModel.errorMessage
        
        // Then
        XCTAssertNil(message)
    }
    
    // MARK: - Integration Tests
    
    func testCompleteUserFlow_SearchAndJoinFamily() async {
        // Given
        let familyCode = testFamily.code
        mockAppState.currentUser = createTestUser()
        
        // When - Search for family
        await viewModel.searchFamily(by: familyCode)
        
        // Then - Verify search results
        XCTAssertNotNil(viewModel.foundFamily)
        XCTAssertTrue(viewModel.showConfirmation)
        
        // When - Join family
        await viewModel.joinFamily(with: mockAppState)
        
        // Then - Verify join results
        XCTAssertTrue(viewModel.showSuccessAlert)
        XCTAssertFalse(viewModel.showConfirmation)
        XCTAssertTrue(mockAppState.familySet)
        XCTAssertEqual(testFamily.members.count, 1)
        XCTAssertEqual(testFamily.members.first?.userId, mockAppState.currentUser?.id)
    }
    
    func testCompleteUserFlow_HandleErrorsAndRecovery() async {
        // Given
        let invalidCode = "INVALID"
        
        // When - Search with invalid code
        await viewModel.searchFamily(by: invalidCode)
        
        // Then - Verify error state
        XCTAssertEqual(viewModel.currentError, .familyNotFound)
        XCTAssertTrue(viewModel.showErrorAlert)
        
        // When - Clear error and try valid code
        viewModel.clearError()
        await viewModel.searchFamily(by: testFamily.code)
        
        // Then - Verify recovery
        XCTAssertNil(viewModel.currentError)
        XCTAssertNotNil(viewModel.foundFamily)
        XCTAssertTrue(viewModel.showConfirmation)
    }
    
    func testCompleteUserFlow_CancelAndRetry() async {
        // Given
        mockAppState.currentUser = createTestUser()
        
        // When - Search and find family
        await viewModel.searchFamily(by: testFamily.code)
        XCTAssertTrue(viewModel.showConfirmation)
        
        // When - Cancel join
        viewModel.cancelJoin()
        
        // Then - Verify cancellation
        XCTAssertFalse(viewModel.showConfirmation)
        XCTAssertNil(viewModel.foundFamily)
        
        // When - Search again and join
        await viewModel.searchFamily(by: testFamily.code)
        await viewModel.joinFamily(with: mockAppState)
        
        // Then - Verify successful join
        XCTAssertTrue(viewModel.showSuccessAlert)
        XCTAssertTrue(mockAppState.familySet)
    }
    
    // MARK: - Helper Methods
    
    private func createTestUser() -> UserProfile {
        return UserProfile(
            displayName: "Test User",
            appleUserIdHash: "test_hash_123"
        )
    }
}

// MARK: - Mock AppState Extension

extension MockAppState {
    var familySet = false
    var setFamilyValue: InMemoryFamily?
    
    func setFamily(_ family: InMemoryFamily) {
        familySet = true
        setFamilyValue = family
        currentInMemoryFamily = family
    }
}