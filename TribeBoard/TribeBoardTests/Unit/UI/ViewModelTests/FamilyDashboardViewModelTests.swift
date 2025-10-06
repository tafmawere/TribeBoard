import XCTest
import SwiftUI
@testable import TribeBoard

/// Comprehensive unit tests for FamilyDashboardViewModel covering all user flows
@MainActor
class FamilyDashboardViewModelTests: TestBase {
    
    // MARK: - Properties
    
    var viewModel: FamilyDashboardViewModel!
    var mockDataManager: InMemoryFamilyDataManager!
    var mockAppState: MockAppState!
    var testFamily: InMemoryFamily!
    var testUsers: [InMemoryUser]!
    var currentUserId: UUID!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        mockDataManager = InMemoryFamilyDataManager()
        mockAppState = MockAppState()
        
        // Create test family and users
        testFamily = mockDataManager.createFamily(name: "Test Family", createdByUserId: UUID())
        currentUserId = UUID()
        
        testUsers = [
            InMemoryUser(id: currentUserId, name: "Current User", createdAt: Date()),
            mockDataManager.createUser(name: "Family Member 1"),
            mockDataManager.createUser(name: "Family Member 2")
        ]
        
        // Add users to data manager
        for user in testUsers {
            if !mockDataManager.users.contains(where: { $0.id == user.id }) {
                mockDataManager.users.append(user)
            }
        }
        
        // Add members to family
        _ = mockDataManager.addMemberToFamily(familyId: testFamily.id, user: testUsers[0], role: .parent)
        _ = mockDataManager.addMemberToFamily(familyId: testFamily.id, user: testUsers[1], role: .child)
        _ = mockDataManager.addMemberToFamily(familyId: testFamily.id, user: testUsers[2], role: .helper)
        
        viewModel = FamilyDashboardViewModel(
            familyId: testFamily.id,
            currentUserId: currentUserId,
            dataManager: mockDataManager
        )
    }
    
    override func tearDown() {
        mockDataManager.clearAllData()
        viewModel = nil
        mockDataManager = nil
        mockAppState = nil
        testFamily = nil
        testUsers = nil
        currentUserId = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization_DefaultState() {
        // Then
        XCTAssertEqual(viewModel.members.count, 3)
        XCTAssertNotNil(viewModel.currentFamily)
        XCTAssertEqual(viewModel.currentFamily?.id, testFamily.id)
        XCTAssertEqual(viewModel.currentUserRole, .parent)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.currentError)
        XCTAssertNil(viewModel.successMessage)
        XCTAssertFalse(viewModel.showErrorAlert)
        XCTAssertFalse(viewModel.showSuccessAlert)
        XCTAssertNil(viewModel.selectedMember)
        XCTAssertFalse(viewModel.showRoleChangeSheet)
        XCTAssertFalse(viewModel.showRemovalConfirmation)
        XCTAssertNil(viewModel.memberToRemove)
    }
    
    func testInitialization_WithCustomDataManager() {
        // Given
        let customDataManager = InMemoryFamilyDataManager()
        let customFamily = customDataManager.createFamily(name: "Custom Family", createdByUserId: UUID())
        let customUserId = UUID()
        
        // When
        let customViewModel = FamilyDashboardViewModel(
            familyId: customFamily.id,
            currentUserId: customUserId,
            dataManager: customDataManager
        )
        
        // Then
        XCTAssertNotNil(customViewModel)
        XCTAssertEqual(customViewModel.currentFamily?.id, customFamily.id)
    }
    
    func testInitialization_LoadsMembersAutomatically() {
        // Then
        XCTAssertEqual(viewModel.members.count, 3)
        
        // Verify all members are loaded with correct user details
        for (member, user) in viewModel.members {
            XCTAssertNotNil(user)
            XCTAssertTrue(testUsers.contains { $0.id == member.userId })
        }
    }
    
    // MARK: - Load Members Tests
    
    func testLoadMembers_Success() {
        // Given
        viewModel.members = [] // Clear existing members
        
        // When
        viewModel.loadMembers()
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.members.count, 3)
        XCTAssertNil(viewModel.currentError)
        
        // Verify member details
        let parentMember = viewModel.members.first { $0.member.role == .parent }
        XCTAssertNotNil(parentMember)
        XCTAssertEqual(parentMember?.user?.name, "Current User")
        
        let childMember = viewModel.members.first { $0.member.role == .child }
        XCTAssertNotNil(childMember)
        XCTAssertEqual(childMember?.user?.name, "Family Member 1")
    }
    
    func testLoadMembers_FamilyNotFound() {
        // Given
        let invalidFamilyId = UUID()
        let invalidViewModel = FamilyDashboardViewModel(
            familyId: invalidFamilyId,
            currentUserId: currentUserId,
            dataManager: mockDataManager
        )
        
        // When
        invalidViewModel.loadMembers()
        
        // Then
        XCTAssertFalse(invalidViewModel.isLoading)
        XCTAssertTrue(invalidViewModel.members.isEmpty)
        XCTAssertEqual(invalidViewModel.currentError, .familyNotFound)
        XCTAssertTrue(invalidViewModel.showErrorAlert)
    }
    
    func testLoadMembers_UpdatesCurrentUserRole() {
        // Given - Change current user's role
        _ = mockDataManager.updateUserRole(userId: currentUserId, familyId: testFamily.id, newRole: .guardian)
        
        // When
        viewModel.loadMembers()
        
        // Then
        XCTAssertEqual(viewModel.currentUserRole, .guardian)
    }
    
    func testLoadMembers_LoadingState() {
        // Given
        var loadingStates: [Bool] = []
        
        // Monitor loading state changes
        let cancellable = viewModel.$isLoading.sink { isLoading in
            loadingStates.append(isLoading)
        }
        
        // When
        viewModel.loadMembers()
        
        // Then
        XCTAssertTrue(loadingStates.contains(true)) // Should have been loading
        XCTAssertFalse(viewModel.isLoading) // Should be false at the end
        
        cancellable.cancel()
    }
    
    // MARK: - Change Role Tests
    
    func testChangeRole_Success() {
        // Given
        let memberToChange = testFamily.members.first { $0.role == .child }!
        let newRole = InMemoryRole.guardian
        
        // When
        viewModel.changeRole(for: memberToChange, to: newRole)
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.showRoleChangeSheet)
        XCTAssertNil(viewModel.selectedMember)
        XCTAssertNotNil(viewModel.successMessage)
        XCTAssertTrue(viewModel.showSuccessAlert)
        
        // Verify role was changed
        let updatedMember = testFamily.member(withUserId: memberToChange.userId)
        XCTAssertEqual(updatedMember?.role, newRole)
    }
    
    func testChangeRole_NotParent() {
        // Given - Change current user to non-parent
        _ = mockDataManager.updateUserRole(userId: currentUserId, familyId: testFamily.id, newRole: .child)
        viewModel.loadMembers() // Refresh to update current user role
        
        let memberToChange = testFamily.members.first { $0.role == .helper }!
        
        // When
        viewModel.changeRole(for: memberToChange, to: .guardian)
        
        // Then
        XCTAssertNotNil(viewModel.currentError)
        XCTAssertTrue(viewModel.showErrorAlert)
        
        // Verify role was not changed
        let unchangedMember = testFamily.member(withUserId: memberToChange.userId)
        XCTAssertEqual(unchangedMember?.role, .helper)
    }
    
    func testChangeRole_CannotChangeSelf() {
        // Given
        let currentUserMember = testFamily.member(withUserId: currentUserId)!
        
        // When
        viewModel.changeRole(for: currentUserMember, to: .guardian)
        
        // Then
        XCTAssertNotNil(viewModel.currentError)
        XCTAssertTrue(viewModel.showErrorAlert)
        
        // Verify role was not changed
        let unchangedMember = testFamily.member(withUserId: currentUserId)
        XCTAssertEqual(unchangedMember?.role, .parent)
    }
    
    func testChangeRole_ParentRoleConstraint() {
        // Given
        let memberToChange = testFamily.members.first { $0.role == .child }!
        
        // When - Try to assign parent role when one already exists
        viewModel.changeRole(for: memberToChange, to: .parent)
        
        // Then
        XCTAssertNotNil(viewModel.currentError)
        XCTAssertTrue(viewModel.showErrorAlert)
        
        // Verify role was not changed
        let unchangedMember = testFamily.member(withUserId: memberToChange.userId)
        XCTAssertEqual(unchangedMember?.role, .child)
    }
    
    // MARK: - Remove Member Tests
    
    func testRemoveMember_Success() {
        // Given
        let memberToRemove = testFamily.members.first { $0.role == .child }!
        let initialMemberCount = testFamily.members.count
        
        // When
        viewModel.removeMember(memberToRemove)
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.showRemovalConfirmation)
        XCTAssertNil(viewModel.memberToRemove)
        XCTAssertNotNil(viewModel.successMessage)
        XCTAssertTrue(viewModel.showSuccessAlert)
        
        // Verify member was removed
        XCTAssertEqual(testFamily.members.count, initialMemberCount - 1)
        XCTAssertNil(testFamily.member(withUserId: memberToRemove.userId))
        
        // Verify members list was updated
        XCTAssertEqual(viewModel.members.count, initialMemberCount - 1)
    }
    
    func testRemoveMember_NotParent() {
        // Given - Change current user to non-parent
        _ = mockDataManager.updateUserRole(userId: currentUserId, familyId: testFamily.id, newRole: .child)
        viewModel.loadMembers() // Refresh to update current user role
        
        let memberToRemove = testFamily.members.first { $0.role == .helper }!
        
        // When
        viewModel.removeMember(memberToRemove)
        
        // Then
        XCTAssertNotNil(viewModel.currentError)
        XCTAssertTrue(viewModel.showErrorAlert)
        
        // Verify member was not removed
        XCTAssertNotNil(testFamily.member(withUserId: memberToRemove.userId))
    }
    
    func testRemoveMember_CannotRemoveSelf() {
        // Given
        let currentUserMember = testFamily.member(withUserId: currentUserId)!
        
        // When
        viewModel.removeMember(currentUserMember)
        
        // Then
        XCTAssertNotNil(viewModel.currentError)
        XCTAssertTrue(viewModel.showErrorAlert)
        
        // Verify member was not removed
        XCTAssertNotNil(testFamily.member(withUserId: currentUserId))
    }
    
    func testRemoveMember_CannotRemoveParent() {
        // Given - Add another parent
        let anotherParent = mockDataManager.createUser(name: "Another Parent")
        _ = mockDataManager.addMemberToFamily(familyId: testFamily.id, user: anotherParent, role: .parent)
        viewModel.loadMembers()
        
        let parentMember = testFamily.members.first { $0.userId == anotherParent.id }!
        
        // When
        viewModel.removeMember(parentMember)
        
        // Then
        XCTAssertNotNil(viewModel.currentError)
        XCTAssertTrue(viewModel.showErrorAlert)
        
        // Verify member was not removed
        XCTAssertNotNil(testFamily.member(withUserId: anotherParent.id))
    }
    
    // MARK: - UI State Management Tests
    
    func testShowRoleChange_Success() {
        // Given
        let member = testFamily.members.first!
        
        // When
        viewModel.showRoleChange(for: member)
        
        // Then
        XCTAssertEqual(viewModel.selectedMember?.id, member.id)
        XCTAssertTrue(viewModel.showRoleChangeSheet)
    }
    
    func testShowRemovalConfirmation_Success() {
        // Given
        let member = testFamily.members.first!
        
        // When
        viewModel.showRemovalConfirmation(for: member)
        
        // Then
        XCTAssertEqual(viewModel.memberToRemove?.id, member.id)
        XCTAssertTrue(viewModel.showRemovalConfirmation)
    }
    
    func testClearSuccessMessage_Success() {
        // Given
        viewModel.successMessage = "Test success"
        viewModel.showSuccessAlert = true
        
        // When
        viewModel.clearSuccessMessage()
        
        // Then
        XCTAssertNil(viewModel.successMessage)
        XCTAssertFalse(viewModel.showSuccessAlert)
    }
    
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
    
    // MARK: - Computed Properties Tests
    
    func testCanManageMembers_Parent() {
        // Given - Current user is parent
        XCTAssertEqual(viewModel.currentUserRole, .parent)
        
        // Then
        XCTAssertTrue(viewModel.canManageMembers)
    }
    
    func testCanManageMembers_NonParent() {
        // Given - Change current user to non-parent
        _ = mockDataManager.updateUserRole(userId: currentUserId, familyId: testFamily.id, newRole: .child)
        viewModel.loadMembers()
        
        // Then
        XCTAssertFalse(viewModel.canManageMembers)
    }
    
    func testUserForMember_Success() {
        // Given
        let member = testFamily.members.first!
        
        // When
        let user = viewModel.user(for: member)
        
        // Then
        XCTAssertNotNil(user)
        XCTAssertEqual(user?.id, member.userId)
    }
    
    func testUserForMember_NotFound() {
        // Given
        let fakeMember = InMemoryMember(userId: UUID(), familyId: testFamily.id, role: .child)
        
        // When
        let user = viewModel.user(for: fakeMember)
        
        // Then
        XCTAssertNil(user)
    }
    
    func testFamilyName_Success() {
        // Then
        XCTAssertEqual(viewModel.familyName, "Test Family")
    }
    
    func testFamilyName_NoFamily() {
        // Given
        viewModel.currentFamily = nil
        
        // Then
        XCTAssertEqual(viewModel.familyName, "Unknown Family")
    }
    
    func testFamilyCode_Success() {
        // Then
        XCTAssertEqual(viewModel.familyCode, testFamily.code)
    }
    
    func testFamilyCode_NoFamily() {
        // Given
        viewModel.currentFamily = nil
        
        // Then
        XCTAssertEqual(viewModel.familyCode, "")
    }
    
    func testMemberCount_Success() {
        // Then
        XCTAssertEqual(viewModel.memberCount, 3)
    }
    
    // MARK: - Navigation Tests
    
    func testNavigateToAddMember_Success() {
        // When
        viewModel.navigateToAddMember(appState: mockAppState)
        
        // Then
        // Navigation is handled by the view layer, so we just verify the method doesn't crash
        XCTAssertNotNil(viewModel)
    }
    
    // MARK: - Integration Tests
    
    func testCompleteUserFlow_LoadAndManageMembers() {
        // Given - Initial state verification
        XCTAssertEqual(viewModel.members.count, 3)
        XCTAssertTrue(viewModel.canManageMembers)
        
        // When - Change a member's role
        let memberToChange = testFamily.members.first { $0.role == .child }!
        viewModel.changeRole(for: memberToChange, to: .guardian)
        
        // Then - Verify role change
        XCTAssertTrue(viewModel.showSuccessAlert)
        let updatedMember = testFamily.member(withUserId: memberToChange.userId)
        XCTAssertEqual(updatedMember?.role, .guardian)
        
        // When - Remove a member
        let memberToRemove = testFamily.members.first { $0.role == .helper }!
        viewModel.removeMember(memberToRemove)
        
        // Then - Verify removal
        XCTAssertEqual(viewModel.members.count, 2)
        XCTAssertNil(testFamily.member(withUserId: memberToRemove.userId))
    }
    
    func testCompleteUserFlow_NonParentRestrictions() {
        // Given - Change current user to child
        _ = mockDataManager.updateUserRole(userId: currentUserId, familyId: testFamily.id, newRole: .child)
        viewModel.loadMembers()
        
        // Then - Verify restrictions
        XCTAssertFalse(viewModel.canManageMembers)
        
        // When - Try to change role (should fail)
        let memberToChange = testFamily.members.first { $0.role == .helper }!
        viewModel.changeRole(for: memberToChange, to: .guardian)
        
        // Then - Verify failure
        XCTAssertNotNil(viewModel.currentError)
        XCTAssertTrue(viewModel.showErrorAlert)
        
        // When - Try to remove member (should fail)
        viewModel.clearError()
        viewModel.removeMember(memberToChange)
        
        // Then - Verify failure
        XCTAssertNotNil(viewModel.currentError)
        XCTAssertTrue(viewModel.showErrorAlert)
    }
    
    func testCompleteUserFlow_ErrorHandlingAndRecovery() {
        // Given - Cause an error
        let memberToChange = testFamily.members.first { $0.role == .child }!
        viewModel.changeRole(for: memberToChange, to: .parent) // Should fail due to existing parent
        
        // Then - Verify error state
        XCTAssertNotNil(viewModel.currentError)
        XCTAssertTrue(viewModel.showErrorAlert)
        
        // When - Clear error and try valid operation
        viewModel.clearError()
        viewModel.changeRole(for: memberToChange, to: .guardian)
        
        // Then - Verify recovery
        XCTAssertNil(viewModel.currentError)
        XCTAssertFalse(viewModel.showErrorAlert)
        XCTAssertTrue(viewModel.showSuccessAlert)
        
        let updatedMember = testFamily.member(withUserId: memberToChange.userId)
        XCTAssertEqual(updatedMember?.role, .guardian)
    }
    
    func testCompleteUserFlow_UIStateManagement() {
        // Given
        let member = testFamily.members.first!
        
        // When - Show role change sheet
        viewModel.showRoleChange(for: member)
        
        // Then - Verify UI state
        XCTAssertEqual(viewModel.selectedMember?.id, member.id)
        XCTAssertTrue(viewModel.showRoleChangeSheet)
        
        // When - Change role (should close sheet)
        viewModel.changeRole(for: member, to: .guardian)
        
        // Then - Verify sheet closed
        XCTAssertFalse(viewModel.showRoleChangeSheet)
        XCTAssertNil(viewModel.selectedMember)
        
        // When - Show removal confirmation
        viewModel.showRemovalConfirmation(for: member)
        
        // Then - Verify confirmation state
        XCTAssertEqual(viewModel.memberToRemove?.id, member.id)
        XCTAssertTrue(viewModel.showRemovalConfirmation)
        
        // When - Remove member (should close confirmation)
        viewModel.removeMember(member)
        
        // Then - Verify confirmation closed
        XCTAssertFalse(viewModel.showRemovalConfirmation)
        XCTAssertNil(viewModel.memberToRemove)
    }
    
    // MARK: - Edge Cases Tests
    
    func testEdgeCase_EmptyFamily() {
        // Given - Create empty family
        let emptyFamily = mockDataManager.createFamily(name: "Empty Family", createdByUserId: UUID())
        let emptyViewModel = FamilyDashboardViewModel(
            familyId: emptyFamily.id,
            currentUserId: UUID(),
            dataManager: mockDataManager
        )
        
        // Then
        XCTAssertTrue(emptyViewModel.members.isEmpty)
        XCTAssertEqual(emptyViewModel.memberCount, 0)
        XCTAssertFalse(emptyViewModel.canManageMembers) // No parent role
    }
    
    func testEdgeCase_SingleMemberFamily() {
        // Given - Create family with single member
        let singleFamily = mockDataManager.createFamily(name: "Single Family", createdByUserId: UUID())
        let singleUser = mockDataManager.createUser(name: "Single User")
        _ = mockDataManager.addMemberToFamily(familyId: singleFamily.id, user: singleUser, role: .parent)
        
        let singleViewModel = FamilyDashboardViewModel(
            familyId: singleFamily.id,
            currentUserId: singleUser.id,
            dataManager: mockDataManager
        )
        
        // Then
        XCTAssertEqual(singleViewModel.members.count, 1)
        XCTAssertTrue(singleViewModel.canManageMembers)
        
        // When - Try to remove self (should fail)
        let selfMember = singleFamily.members.first!
        singleViewModel.removeMember(selfMember)
        
        // Then
        XCTAssertNotNil(singleViewModel.currentError)
        XCTAssertEqual(singleViewModel.members.count, 1) // Should still be there
    }
}// MARK
: - Mock AppState Extension

extension MockAppState {
    var familySet = false
    var setFamilyValue: InMemoryFamily?
    
    func setFamily(_ family: InMemoryFamily) {
        familySet = true
        setFamilyValue = family
        currentInMemoryFamily = family
    }
}