import XCTest
import SwiftUI
@testable import TribeBoard

/// Comprehensive unit tests for RoleSelectionViewModel covering all user flows
@MainActor
class RoleSelectionViewModelTests: TestBase {
    
    // MARK: - Properties
    
    var viewModel: RoleSelectionViewModel!
    var mockDataManager: InMemoryFamilyDataManager!
    var mockAppState: MockAppState!
    var testFamily: InMemoryFamily!
    var testUser: InMemoryUser!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        mockDataManager = InMemoryFamilyDataManager()
        mockAppState = MockAppState()
        
        // Create test family and user
        testFamily = mockDataManager.createFamily(name: "Test Family", createdByUserId: UUID())
        testUser = mockDataManager.createUser(name: "Test User")
        
        viewModel = RoleSelectionViewModel(
            family: testFamily,
            user: testUser,
            dataManager: mockDataManager
        )
        viewModel.setAppState(mockAppState)
    }
    
    override func tearDown() {
        mockDataManager.clearAllData()
        viewModel = nil
        mockDataManager = nil
        mockAppState = nil
        testFamily = nil
        testUser = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization_DefaultState() {
        // Then
        XCTAssertEqual(viewModel.selectedRole, .parent)
        XCTAssertFalse(viewModel.isUpdating)
        XCTAssertNil(viewModel.currentError)
        XCTAssertTrue(viewModel.canSelectParent)
        XCTAssertFalse(viewModel.roleSelectionComplete)
        XCTAssertFalse(viewModel.showErrorAlert)
        XCTAssertFalse(viewModel.showSuccessAlert)
    }
    
    func testInitialization_WithCustomDataManager() {
        // Given
        let customDataManager = InMemoryFamilyDataManager()
        let customFamily = customDataManager.createFamily(name: "Custom Family", createdByUserId: UUID())
        let customUser = customDataManager.createUser(name: "Custom User")
        
        // When
        let customViewModel = RoleSelectionViewModel(
            family: customFamily,
            user: customUser,
            dataManager: customDataManager
        )
        
        // Then
        XCTAssertNotNil(customViewModel)
        XCTAssertEqual(customViewModel.selectedRole, .parent)
    }
    
    // MARK: - Role Selection Tests
    
    func testSetRole_ValidRole() async {
        // Given
        let newRole = InMemoryRole.child
        
        // When
        await viewModel.setRole(newRole)
        
        // Then
        XCTAssertEqual(viewModel.selectedRole, newRole)
        XCTAssertTrue(viewModel.roleSelectionComplete)
        XCTAssertTrue(viewModel.showSuccessAlert)
        XCTAssertNil(viewModel.currentError)
        XCTAssertTrue(mockAppState.familySet)
    }
    
    func testSetRole_ParentWhenNotAvailable() async {
        // Given - Add another parent to make parent role unavailable
        let existingParent = mockDataManager.createUser(name: "Existing Parent")
        _ = mockDataManager.addMemberToFamily(familyId: testFamily.id, user: existingParent, role: .parent)
        
        // Refresh parent availability
        await viewModel.checkParentAvailability()
        
        // When
        await viewModel.setRole(.parent)
        
        // Then
        XCTAssertEqual(viewModel.selectedRole, .helper) // Should fallback to helper
        XCTAssertNotNil(viewModel.currentError)
        XCTAssertTrue(viewModel.showErrorAlert)
    }
    
    func testSetRole_ClearsErrorBeforeUpdate() async {
        // Given
        viewModel.currentError = .familyNotFound
        viewModel.showErrorAlert = true
        
        // When
        await viewModel.setRole(.child)
        
        // Then
        XCTAssertNil(viewModel.currentError)
        XCTAssertFalse(viewModel.showErrorAlert)
    }
    
    // MARK: - Role Update Tests
    
    func testUpdateRole_NewMember() async {
        // Given
        let role = InMemoryRole.guardian
        
        // When
        await viewModel.updateRole(role)
        
        // Then
        XCTAssertFalse(viewModel.isUpdating)
        XCTAssertTrue(viewModel.roleSelectionComplete)
        XCTAssertTrue(viewModel.showSuccessAlert)
        XCTAssertTrue(mockAppState.familySet)
        
        // Verify user was added to family
        let member = testFamily.member(withUserId: testUser.id)
        XCTAssertNotNil(member)
        XCTAssertEqual(member?.role, role)
    }
    
    func testUpdateRole_ExistingMember() async {
        // Given - Add user as existing member
        _ = mockDataManager.addMemberToFamily(familyId: testFamily.id, user: testUser, role: .parent)
        let newRole = InMemoryRole.helper
        
        // When
        await viewModel.updateRole(newRole)
        
        // Then
        XCTAssertTrue(viewModel.roleSelectionComplete)
        XCTAssertTrue(viewModel.showSuccessAlert)
        
        // Verify role was updated
        let member = testFamily.member(withUserId: testUser.id)
        XCTAssertNotNil(member)
        XCTAssertEqual(member?.role, newRole)
    }
    
    func testUpdateRole_LoadingState() async {
        // Given
        var loadingStates: [Bool] = []
        
        // Monitor loading state changes
        let cancellable = viewModel.$isUpdating.sink { isUpdating in
            loadingStates.append(isUpdating)
        }
        
        // When
        await viewModel.updateRole(.child)
        
        // Then
        XCTAssertTrue(loadingStates.contains(true)) // Should have been loading
        XCTAssertFalse(viewModel.isUpdating) // Should be false at the end
        
        cancellable.cancel()
    }
    
    func testUpdateRole_ClearsErrorBeforeUpdate() async {
        // Given
        viewModel.currentError = .familyNotFound
        viewModel.showErrorAlert = true
        
        // When
        await viewModel.updateRole(.child)
        
        // Then
        XCTAssertNil(viewModel.currentError)
        XCTAssertFalse(viewModel.showErrorAlert)
    }
    
    // MARK: - Parent Availability Tests
    
    func testCheckParentAvailability_NoExistingParent() async {
        // When
        await viewModel.checkParentAvailability()
        
        // Then
        XCTAssertTrue(viewModel.canSelectParent)
        XCTAssertEqual(viewModel.selectedRole, .parent) // Should remain parent
    }
    
    func testCheckParentAvailability_ExistingParent() async {
        // Given - Add existing parent
        let existingParent = mockDataManager.createUser(name: "Existing Parent")
        _ = mockDataManager.addMemberToFamily(familyId: testFamily.id, user: existingParent, role: .parent)
        
        // When
        await viewModel.checkParentAvailability()
        
        // Then
        XCTAssertFalse(viewModel.canSelectParent)
        XCTAssertEqual(viewModel.selectedRole, .helper) // Should fallback to helper
    }
    
    func testCheckParentAvailability_MultipleNonParentMembers() async {
        // Given - Add multiple non-parent members
        let child = mockDataManager.createUser(name: "Child")
        let helper = mockDataManager.createUser(name: "Helper")
        _ = mockDataManager.addMemberToFamily(familyId: testFamily.id, user: child, role: .child)
        _ = mockDataManager.addMemberToFamily(familyId: testFamily.id, user: helper, role: .helper)
        
        // When
        await viewModel.checkParentAvailability()
        
        // Then
        XCTAssertTrue(viewModel.canSelectParent) // Should still be available
    }
    
    // MARK: - Role Card Data Tests
    
    func testGetRoleCardData_AllRoles() {
        // When
        let roleCardData = viewModel.getRoleCardData()
        
        // Then
        XCTAssertEqual(roleCardData.count, InMemoryRole.allCases.count)
        
        // Verify all roles are represented
        let representedRoles = Set(roleCardData.map { $0.role })
        let allRoles = Set(InMemoryRole.allCases)
        XCTAssertEqual(representedRoles, allRoles)
    }
    
    func testGetRoleCardData_SelectedRole() {
        // Given
        viewModel.selectedRole = .child
        
        // When
        let roleCardData = viewModel.getRoleCardData()
        
        // Then
        let selectedCards = roleCardData.filter { $0.isSelected }
        XCTAssertEqual(selectedCards.count, 1)
        XCTAssertEqual(selectedCards.first?.role, .child)
    }
    
    func testGetRoleCardData_ParentAvailability() async {
        // Given - Make parent unavailable
        let existingParent = mockDataManager.createUser(name: "Existing Parent")
        _ = mockDataManager.addMemberToFamily(familyId: testFamily.id, user: existingParent, role: .parent)
        await viewModel.checkParentAvailability()
        
        // When
        let roleCardData = viewModel.getRoleCardData()
        
        // Then
        let parentCard = roleCardData.first { $0.role == .parent }
        XCTAssertNotNil(parentCard)
        XCTAssertFalse(parentCard!.isEnabled)
        
        // Other roles should still be enabled
        let nonParentCards = roleCardData.filter { $0.role != .parent }
        for card in nonParentCards {
            XCTAssertTrue(card.isEnabled, "Role \(card.role) should be enabled")
        }
    }
    
    func testGetRoleCardData_CardProperties() {
        // When
        let roleCardData = viewModel.getRoleCardData()
        
        // Then
        for card in roleCardData {
            XCTAssertFalse(card.id.uuidString.isEmpty)
            XCTAssertFalse(card.icon.isEmpty)
            XCTAssertFalse(card.title.isEmpty)
            XCTAssertFalse(card.description.isEmpty)
            XCTAssertEqual(card.title, card.role.displayName)
            XCTAssertEqual(card.description, card.role.description)
            XCTAssertEqual(card.icon, card.role.iconName)
        }
    }
    
    // MARK: - Error Handling Tests
    
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
    
    // MARK: - AppState Integration Tests
    
    func testSetAppState_Success() {
        // Given
        let newAppState = MockAppState()
        
        // When
        viewModel.setAppState(newAppState)
        
        // Then - Should not crash and should work with new app state
        XCTAssertNotNil(viewModel)
    }
    
    func testAppStateIntegration_FamilySet() async {
        // Given
        let role = InMemoryRole.guardian
        
        // When
        await viewModel.updateRole(role)
        
        // Then
        XCTAssertTrue(mockAppState.familySet)
        XCTAssertEqual(mockAppState.setFamilyValue?.id, testFamily.id)
    }
    
    // MARK: - Integration Tests
    
    func testCompleteUserFlow_SelectAndAssignRole() async {
        // Given
        let selectedRole = InMemoryRole.guardian
        
        // When - Select role
        await viewModel.setRole(selectedRole)
        
        // Then - Verify complete flow
        XCTAssertEqual(viewModel.selectedRole, selectedRole)
        XCTAssertTrue(viewModel.roleSelectionComplete)
        XCTAssertTrue(viewModel.showSuccessAlert)
        XCTAssertTrue(mockAppState.familySet)
        
        // Verify user was added to family with correct role
        let member = testFamily.member(withUserId: testUser.id)
        XCTAssertNotNil(member)
        XCTAssertEqual(member?.role, selectedRole)
        XCTAssertEqual(testFamily.members.count, 1)
    }
    
    func testCompleteUserFlow_ParentRoleConstraint() async {
        // Given - Add existing parent
        let existingParent = mockDataManager.createUser(name: "Existing Parent")
        _ = mockDataManager.addMemberToFamily(familyId: testFamily.id, user: existingParent, role: .parent)
        
        // When - Check availability and try to select parent
        await viewModel.checkParentAvailability()
        await viewModel.setRole(.parent)
        
        // Then - Should fallback to helper and show error
        XCTAssertEqual(viewModel.selectedRole, .helper)
        XCTAssertNotNil(viewModel.currentError)
        XCTAssertTrue(viewModel.showErrorAlert)
        
        // But should still complete successfully with helper role
        XCTAssertTrue(viewModel.roleSelectionComplete)
        
        let member = testFamily.member(withUserId: testUser.id)
        XCTAssertNotNil(member)
        XCTAssertEqual(member?.role, .helper)
    }
    
    func testCompleteUserFlow_UpdateExistingMemberRole() async {
        // Given - Add user as existing member
        _ = mockDataManager.addMemberToFamily(familyId: testFamily.id, user: testUser, role: .child)
        let newRole = InMemoryRole.guardian
        
        // When - Update role
        await viewModel.setRole(newRole)
        
        // Then - Verify role was updated, not added as new member
        XCTAssertEqual(testFamily.members.count, 1) // Should still be 1
        
        let member = testFamily.member(withUserId: testUser.id)
        XCTAssertNotNil(member)
        XCTAssertEqual(member?.role, newRole)
        
        XCTAssertTrue(viewModel.roleSelectionComplete)
        XCTAssertTrue(mockAppState.familySet)
    }
    
    func testCompleteUserFlow_RoleCardDataReflectsState() async {
        // Given
        let selectedRole = InMemoryRole.child
        
        // When - Select role
        await viewModel.setRole(selectedRole)
        
        // Get role card data after selection
        let roleCardData = viewModel.getRoleCardData()
        
        // Then - Verify card data reflects current state
        let selectedCard = roleCardData.first { $0.role == selectedRole }
        XCTAssertNotNil(selectedCard)
        XCTAssertTrue(selectedCard!.isSelected)
        
        let unselectedCards = roleCardData.filter { $0.role != selectedRole }
        for card in unselectedCards {
            XCTAssertFalse(card.isSelected, "Role \(card.role) should not be selected")
        }
    }
    
    func testCompleteUserFlow_MultipleRoleChanges() async {
        // Given
        let roles: [InMemoryRole] = [.parent, .child, .guardian, .helper]
        
        // When - Change roles multiple times
        for role in roles {
            await viewModel.setRole(role)
            
            // Then - Verify each change
            XCTAssertEqual(viewModel.selectedRole, role)
            XCTAssertTrue(viewModel.roleSelectionComplete)
            
            let member = testFamily.member(withUserId: testUser.id)
            XCTAssertNotNil(member)
            XCTAssertEqual(member?.role, role)
        }
        
        // Should still have only one member
        XCTAssertEqual(testFamily.members.count, 1)
    }
    
    // MARK: - Edge Cases Tests
    
    func testEdgeCase_FamilyWithMaxMembers() async {
        // Given - Add many members to family
        for i in 1...10 {
            let user = mockDataManager.createUser(name: "User \(i)")
            let role: InMemoryRole = i == 1 ? .parent : .child
            _ = mockDataManager.addMemberToFamily(familyId: testFamily.id, user: user, role: role)
        }
        
        // When - Add test user
        await viewModel.setRole(.helper)
        
        // Then - Should still work
        XCTAssertTrue(viewModel.roleSelectionComplete)
        XCTAssertEqual(testFamily.members.count, 11)
        
        let member = testFamily.member(withUserId: testUser.id)
        XCTAssertNotNil(member)
        XCTAssertEqual(member?.role, .helper)
    }
    
    func testEdgeCase_RapidRoleChanges() async {
        // Given
        let roles: [InMemoryRole] = [.parent, .child, .guardian, .helper, .parent]
        
        // When - Rapid role changes
        for role in roles {
            await viewModel.setRole(role)
        }
        
        // Then - Should end up with the last role
        XCTAssertEqual(viewModel.selectedRole, .parent)
        XCTAssertTrue(viewModel.roleSelectionComplete)
        
        let member = testFamily.member(withUserId: testUser.id)
        XCTAssertNotNil(member)
        XCTAssertEqual(member?.role, .parent)
        XCTAssertEqual(testFamily.members.count, 1)
    }
}
/
/ MARK: - Mock AppState Extension

extension MockAppState {
    var familySet = false
    var setFamilyValue: InMemoryFamily?
    
    func setFamily(_ family: InMemoryFamily) {
        familySet = true
        setFamilyValue = family
        currentInMemoryFamily = family
    }
}