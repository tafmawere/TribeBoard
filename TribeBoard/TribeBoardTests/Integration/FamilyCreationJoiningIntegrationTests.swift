import XCTest
import SwiftUI
@testable import TribeBoard

/// Integration tests for complete family creation and joining flows
@MainActor
class FamilyCreationJoiningIntegrationTests: TestBase {
    
    // MARK: - Properties
    
    var dataManager: InMemoryFamilyDataManager!
    var mockQRCodeService: MockQRCodeService!
    var mockAppState: MockAppState!
    
    // ViewModels
    var createFamilyViewModel: CreateFamilyViewModel!
    var joinFamilyViewModel: JoinFamilyViewModel!
    var roleSelectionViewModel: RoleSelectionViewModel!
    var familyDashboardViewModel: FamilyDashboardViewModel!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        dataManager = InMemoryFamilyDataManager()
        mockQRCodeService = MockQRCodeService()
        mockAppState = MockAppState()
        
        // Configure mock services
        mockQRCodeService.mockQRImage = Image(systemName: "qrcode")
        
        // Initialize ViewModels
        createFamilyViewModel = CreateFamilyViewModel(
            dataManager: dataManager,
            qrCodeService: mockQRCodeService
        )
        
        joinFamilyViewModel = JoinFamilyViewModel(dataManager: dataManager)
    }
    
    override func tearDown() {
        dataManager.clearAllData()
        createFamilyViewModel = nil
        joinFamilyViewModel = nil
        roleSelectionViewModel = nil
        familyDashboardViewModel = nil
        dataManager = nil
        mockQRCodeService = nil
        mockAppState = nil
        super.tearDown()
    }
    
    // MARK: - Complete Family Creation Flow Tests
    
    func testCompleteFamilyCreationFlow_Success() async {
        // Given
        let familyName = "Integration Test Family"
        let creatorUser = createTestUser(name: "Family Creator")
        mockAppState.currentUser = creatorUser
        
        createFamilyViewModel.familyName = familyName
        
        // When - Create family
        await createFamilyViewModel.createFamily(with: mockAppState)
        
        // Then - Verify family creation
        XCTAssertEqual(createFamilyViewModel.creationState, .completed)
        XCTAssertNotNil(createFamilyViewModel.createdFamily)
        XCTAssertEqual(createFamilyViewModel.createdFamily?.name, familyName)
        XCTAssertNotNil(createFamilyViewModel.qrCodeImage)
        
        // Verify data persistence
        XCTAssertEqual(dataManager.families.count, 1)
        XCTAssertEqual(dataManager.users.count, 1)
        
        let createdFamily = createFamilyViewModel.createdFamily!
        XCTAssertEqual(createdFamily.members.count, 1)
        XCTAssertEqual(createdFamily.members.first?.role, .parent)
        
        // Verify navigation was triggered
        XCTAssertTrue(mockAppState.navigationCalled)
        XCTAssertEqual(mockAppState.lastNavigationDestination, .roleSelection)
        
        // When - Continue to role selection
        let creatorInMemoryUser = InMemoryUser(
            id: creatorUser.id,
            name: creatorUser.displayName,
            createdAt: creatorUser.createdAt
        )
        
        roleSelectionViewModel = RoleSelectionViewModel(
            family: createdFamily,
            user: creatorInMemoryUser,
            dataManager: dataManager
        )
        roleSelectionViewModel.setAppState(mockAppState)
        
        // Select parent role (should already be assigned)
        await roleSelectionViewModel.setRole(.parent)
        
        // Then - Verify role selection
        XCTAssertTrue(roleSelectionViewModel.roleSelectionComplete)
        XCTAssertEqual(roleSelectionViewModel.selectedRole, .parent)
        XCTAssertTrue(mockAppState.familySet)
        
        // When - Navigate to dashboard
        familyDashboardViewModel = FamilyDashboardViewModel(
            familyId: createdFamily.id,
            currentUserId: creatorUser.id,
            dataManager: dataManager
        )
        
        // Then - Verify dashboard state
        XCTAssertEqual(familyDashboardViewModel.members.count, 1)
        XCTAssertEqual(familyDashboardViewModel.currentUserRole, .parent)
        XCTAssertTrue(familyDashboardViewModel.canManageMembers)
        XCTAssertEqual(familyDashboardViewModel.familyName, familyName)
        XCTAssertEqual(familyDashboardViewModel.familyCode, createdFamily.code)
    }
    
    func testCompleteFamilyCreationFlow_WithMultipleSteps() async {
        // Given
        let familyName = "Multi-Step Family"
        let creatorUser = createTestUser(name: "Creator")
        mockAppState.currentUser = creatorUser
        
        // Step 1: Create family
        createFamilyViewModel.familyName = familyName
        await createFamilyViewModel.createFamily(with: mockAppState)
        
        let createdFamily = createFamilyViewModel.createdFamily!
        
        // Step 2: Role selection for creator
        let creatorInMemoryUser = InMemoryUser(
            id: creatorUser.id,
            name: creatorUser.displayName,
            createdAt: creatorUser.createdAt
        )
        
        roleSelectionViewModel = RoleSelectionViewModel(
            family: createdFamily,
            user: creatorInMemoryUser,
            dataManager: dataManager
        )
        roleSelectionViewModel.setAppState(mockAppState)
        
        await roleSelectionViewModel.setRole(.parent)
        
        // Step 3: Dashboard view
        familyDashboardViewModel = FamilyDashboardViewModel(
            familyId: createdFamily.id,
            currentUserId: creatorUser.id,
            dataManager: dataManager
        )
        
        // Step 4: Add another member via join flow
        let joiningUser = createTestUser(name: "Joining Member")
        mockAppState.currentUser = joiningUser
        
        joinFamilyViewModel.familyCode = createdFamily.code
        await joinFamilyViewModel.searchFamily(by: createdFamily.code)
        await joinFamilyViewModel.joinFamily(with: mockAppState)
        
        // Step 5: Role selection for joining member
        let joiningInMemoryUser = InMemoryUser(
            id: joiningUser.id,
            name: joiningUser.displayName,
            createdAt: joiningUser.createdAt
        )
        
        let joiningRoleViewModel = RoleSelectionViewModel(
            family: createdFamily,
            user: joiningInMemoryUser,
            dataManager: dataManager
        )
        joiningRoleViewModel.setAppState(mockAppState)
        
        await joiningRoleViewModel.setRole(.child)
        
        // Step 6: Verify final state
        familyDashboardViewModel.loadMembers()
        
        // Then - Verify complete flow
        XCTAssertEqual(familyDashboardViewModel.members.count, 2)
        XCTAssertEqual(dataManager.families.count, 1)
        XCTAssertEqual(dataManager.users.count, 2)
        
        let parentMember = createdFamily.members.first { $0.role == .parent }
        let childMember = createdFamily.members.first { $0.role == .child }
        
        XCTAssertNotNil(parentMember)
        XCTAssertNotNil(childMember)
        XCTAssertEqual(parentMember?.userId, creatorUser.id)
        XCTAssertEqual(childMember?.userId, joiningUser.id)
    }
    
    // MARK: - Complete Family Joining Flow Tests
    
    func testCompleteFamilyJoiningFlow_Success() async {
        // Given - Pre-existing family
        let existingFamily = dataManager.createFamily(name: "Existing Family", createdByUserId: UUID())
        let joiningUser = createTestUser(name: "Joining User")
        mockAppState.currentUser = joiningUser
        
        // When - Search for family
        await joinFamilyViewModel.searchFamily(by: existingFamily.code)
        
        // Then - Verify search results
        XCTAssertNotNil(joinFamilyViewModel.foundFamily)
        XCTAssertEqual(joinFamilyViewModel.foundFamily?.id, existingFamily.id)
        XCTAssertTrue(joinFamilyViewModel.showConfirmation)
        
        // When - Join family
        await joinFamilyViewModel.joinFamily(with: mockAppState)
        
        // Then - Verify join results
        XCTAssertTrue(joinFamilyViewModel.showSuccessAlert)
        XCTAssertTrue(mockAppState.familySet)
        XCTAssertEqual(existingFamily.members.count, 1)
        
        // When - Continue to role selection
        let joiningInMemoryUser = InMemoryUser(
            id: joiningUser.id,
            name: joiningUser.displayName,
            createdAt: joiningUser.createdAt
        )
        
        roleSelectionViewModel = RoleSelectionViewModel(
            family: existingFamily,
            user: joiningInMemoryUser,
            dataManager: dataManager
        )
        roleSelectionViewModel.setAppState(mockAppState)
        
        await roleSelectionViewModel.setRole(.guardian)
        
        // Then - Verify role selection
        XCTAssertTrue(roleSelectionViewModel.roleSelectionComplete)
        XCTAssertEqual(roleSelectionViewModel.selectedRole, .guardian)
        
        let member = existingFamily.member(withUserId: joiningUser.id)
        XCTAssertNotNil(member)
        XCTAssertEqual(member?.role, .guardian)
        
        // When - Navigate to dashboard
        familyDashboardViewModel = FamilyDashboardViewModel(
            familyId: existingFamily.id,
            currentUserId: joiningUser.id,
            dataManager: dataManager
        )
        
        // Then - Verify dashboard state
        XCTAssertEqual(familyDashboardViewModel.members.count, 1)
        XCTAssertEqual(familyDashboardViewModel.currentUserRole, .guardian)
        XCTAssertFalse(familyDashboardViewModel.canManageMembers) // Only parents can manage
    }
    
    func testCompleteFamilyJoiningFlow_MultipleMembers() async {
        // Given - Create family with existing parent
        let family = dataManager.createFamily(name: "Multi-Member Family", createdByUserId: UUID())
        let parentUser = dataManager.createUser(name: "Parent User")
        _ = dataManager.addMemberToFamily(familyId: family.id, user: parentUser, role: .parent)
        
        // Member 1: Join as child
        let childUser = createTestUser(name: "Child User")
        mockAppState.currentUser = childUser
        
        await joinFamilyViewModel.searchFamily(by: family.code)
        await joinFamilyViewModel.joinFamily(with: mockAppState)
        
        let childInMemoryUser = InMemoryUser(
            id: childUser.id,
            name: childUser.displayName,
            createdAt: childUser.createdAt
        )
        
        let childRoleViewModel = RoleSelectionViewModel(
            family: family,
            user: childInMemoryUser,
            dataManager: dataManager
        )
        childRoleViewModel.setAppState(mockAppState)
        await childRoleViewModel.setRole(.child)
        
        // Member 2: Join as helper
        let helperUser = createTestUser(name: "Helper User")
        mockAppState.currentUser = helperUser
        
        // Reset join view model for new user
        joinFamilyViewModel.reset()
        await joinFamilyViewModel.searchFamily(by: family.code)
        await joinFamilyViewModel.joinFamily(with: mockAppState)
        
        let helperInMemoryUser = InMemoryUser(
            id: helperUser.id,
            name: helperUser.displayName,
            createdAt: helperUser.createdAt
        )
        
        let helperRoleViewModel = RoleSelectionViewModel(
            family: family,
            user: helperInMemoryUser,
            dataManager: dataManager
        )
        helperRoleViewModel.setAppState(mockAppState)
        await helperRoleViewModel.setRole(.helper)
        
        // Then - Verify final state
        XCTAssertEqual(family.members.count, 3)
        XCTAssertEqual(dataManager.users.count, 3) // parentUser + childUser + helperUser
        
        let parentMember = family.members.first { $0.role == .parent }
        let childMember = family.members.first { $0.role == .child }
        let helperMember = family.members.first { $0.role == .helper }
        
        XCTAssertNotNil(parentMember)
        XCTAssertNotNil(childMember)
        XCTAssertNotNil(helperMember)
        
        XCTAssertEqual(parentMember?.userId, parentUser.id)
        XCTAssertEqual(childMember?.userId, childUser.id)
        XCTAssertEqual(helperMember?.userId, helperUser.id)
    }
    
    // MARK: - Error Handling Integration Tests
    
    func testIntegrationFlow_HandleErrors() async {
        // Test 1: Family creation with invalid input
        createFamilyViewModel.familyName = "" // Invalid
        mockAppState.currentUser = createTestUser()
        
        await createFamilyViewModel.createFamily(with: mockAppState)
        
        XCTAssertTrue(createFamilyViewModel.isFailed)
        XCTAssertEqual(createFamilyViewModel.currentError, .emptyFamilyName)
        
        // Test 2: Fix error and retry
        createFamilyViewModel.familyName = "Valid Family Name"
        await createFamilyViewModel.retryCreation(with: mockAppState)
        
        XCTAssertEqual(createFamilyViewModel.creationState, .completed)
        XCTAssertNotNil(createFamilyViewModel.createdFamily)
        
        // Test 3: Join with invalid code
        let joiningUser = createTestUser(name: "Joining User")
        mockAppState.currentUser = joiningUser
        
        await joinFamilyViewModel.searchFamily(by: "INVALID")
        
        XCTAssertEqual(joinFamilyViewModel.currentError, .familyNotFound)
        XCTAssertNil(joinFamilyViewModel.foundFamily)
        
        // Test 4: Fix error and join successfully
        joinFamilyViewModel.clearError()
        await joinFamilyViewModel.searchFamily(by: createFamilyViewModel.createdFamily!.code)
        await joinFamilyViewModel.joinFamily(with: mockAppState)
        
        XCTAssertTrue(joinFamilyViewModel.showSuccessAlert)
        XCTAssertNil(joinFamilyViewModel.currentError)
    }
    
    func testIntegrationFlow_RoleConstraints() async {
        // Given - Create family with parent
        let family = dataManager.createFamily(name: "Role Constraint Family", createdByUserId: UUID())
        let parentUser = dataManager.createUser(name: "Parent User")
        _ = dataManager.addMemberToFamily(familyId: family.id, user: parentUser, role: .parent)
        
        // When - New user tries to join as parent
        let newUser = createTestUser(name: "New User")
        mockAppState.currentUser = newUser
        
        await joinFamilyViewModel.searchFamily(by: family.code)
        await joinFamilyViewModel.joinFamily(with: mockAppState)
        
        let newInMemoryUser = InMemoryUser(
            id: newUser.id,
            name: newUser.displayName,
            createdAt: newUser.createdAt
        )
        
        roleSelectionViewModel = RoleSelectionViewModel(
            family: family,
            user: newInMemoryUser,
            dataManager: dataManager
        )
        roleSelectionViewModel.setAppState(mockAppState)
        
        // Check parent availability
        await roleSelectionViewModel.checkParentAvailability()
        
        // Then - Parent should not be available
        XCTAssertFalse(roleSelectionViewModel.canSelectParent)
        XCTAssertEqual(roleSelectionViewModel.selectedRole, .helper) // Should fallback
        
        // When - Try to select parent anyway
        await roleSelectionViewModel.setRole(.parent)
        
        // Then - Should fallback to helper and show error
        XCTAssertEqual(roleSelectionViewModel.selectedRole, .helper)
        XCTAssertNotNil(roleSelectionViewModel.currentError)
        XCTAssertTrue(roleSelectionViewModel.roleSelectionComplete) // But still complete with helper
        
        let member = family.member(withUserId: newUser.id)
        XCTAssertNotNil(member)
        XCTAssertEqual(member?.role, .helper)
    }
    
    // MARK: - Data Consistency Tests
    
    func testDataConsistency_AcrossViewModels() async {
        // Given - Create family through CreateFamilyViewModel
        let familyName = "Consistency Test Family"
        let creatorUser = createTestUser(name: "Creator")
        mockAppState.currentUser = creatorUser
        
        createFamilyViewModel.familyName = familyName
        await createFamilyViewModel.createFamily(with: mockAppState)
        
        let createdFamily = createFamilyViewModel.createdFamily!
        
        // When - Access same family through JoinFamilyViewModel
        await joinFamilyViewModel.searchFamily(by: createdFamily.code)
        
        // Then - Data should be consistent
        XCTAssertEqual(joinFamilyViewModel.foundFamily?.id, createdFamily.id)
        XCTAssertEqual(joinFamilyViewModel.foundFamily?.name, familyName)
        XCTAssertEqual(joinFamilyViewModel.memberCount, 1) // Creator is already a member
        
        // When - Access through FamilyDashboardViewModel
        familyDashboardViewModel = FamilyDashboardViewModel(
            familyId: createdFamily.id,
            currentUserId: creatorUser.id,
            dataManager: dataManager
        )
        
        // Then - Data should be consistent
        XCTAssertEqual(familyDashboardViewModel.familyName, familyName)
        XCTAssertEqual(familyDashboardViewModel.familyCode, createdFamily.code)
        XCTAssertEqual(familyDashboardViewModel.members.count, 1)
        XCTAssertEqual(familyDashboardViewModel.currentUserRole, .parent)
    }
    
    func testDataConsistency_AfterModifications() async {
        // Given - Create family and add members
        let family = dataManager.createFamily(name: "Modification Test Family", createdByUserId: UUID())
        let parentUser = dataManager.createUser(name: "Parent")
        let childUser = dataManager.createUser(name: "Child")
        
        _ = dataManager.addMemberToFamily(familyId: family.id, user: parentUser, role: .parent)
        _ = dataManager.addMemberToFamily(familyId: family.id, user: childUser, role: .child)
        
        // When - Modify through FamilyDashboardViewModel
        familyDashboardViewModel = FamilyDashboardViewModel(
            familyId: family.id,
            currentUserId: parentUser.id,
            dataManager: dataManager
        )
        
        let childMember = family.member(withUserId: childUser.id)!
        familyDashboardViewModel.changeRole(for: childMember, to: .guardian)
        
        // Then - Changes should be reflected in data manager
        let updatedMember = dataManager.getFamilyMembersWithUserDetails(familyId: family.id)
            .first { $0.member.userId == childUser.id }
        
        XCTAssertNotNil(updatedMember)
        XCTAssertEqual(updatedMember?.member.role, .guardian)
        
        // When - Access through new ViewModel instance
        let newDashboardViewModel = FamilyDashboardViewModel(
            familyId: family.id,
            currentUserId: parentUser.id,
            dataManager: dataManager
        )
        
        // Then - Changes should be visible
        let memberInNewViewModel = newDashboardViewModel.members
            .first { $0.member.userId == childUser.id }
        
        XCTAssertNotNil(memberInNewViewModel)
        XCTAssertEqual(memberInNewViewModel?.member.role, .guardian)
    }
    
    // MARK: - Edge Case Tests (Task 13 Requirements)
    
    func testEdgeCase_InvalidFamilyCodes() async {
        // Test various invalid family code formats
        let invalidCodes = [
            "", // Empty code
            "ABC", // Too short
            "ABCDEFG", // Too long
            "abc123", // Lowercase
            "ABC-123", // Special characters
            "ABC 123", // Spaces
            "ABCDEF", // All letters
            "123456", // All numbers
            "ABC12!", // Invalid character
            "АБВГДЕ" // Non-ASCII characters
        ]
        
        for invalidCode in invalidCodes {
            // Reset for each test
            joinFamilyViewModel.reset()
            
            // When - Try to search with invalid code
            await joinFamilyViewModel.searchFamily(by: invalidCode)
            
            // Then - Should fail with appropriate error
            XCTAssertEqual(joinFamilyViewModel.currentError, .invalidCodeFormat, 
                          "Failed for invalid code: '\(invalidCode)'")
            XCTAssertNil(joinFamilyViewModel.foundFamily)
            XCTAssertFalse(joinFamilyViewModel.showConfirmation)
        }
    }
    
    func testEdgeCase_DuplicateFamilyCreation() async {
        // Given - Create first family
        let familyName = "Duplicate Test Family"
        let firstUser = createTestUser(name: "First Creator")
        mockAppState.currentUser = firstUser
        
        createFamilyViewModel.familyName = familyName
        await createFamilyViewModel.createFamily(with: mockAppState)
        
        let firstFamily = createFamilyViewModel.createdFamily!
        
        // When - Try to create another family with same name (should succeed with different code)
        let secondUser = createTestUser(name: "Second Creator")
        mockAppState.currentUser = secondUser
        
        let secondCreateViewModel = CreateFamilyViewModel(
            dataManager: dataManager,
            qrCodeService: mockQRCodeService
        )
        secondCreateViewModel.familyName = familyName
        
        await secondCreateViewModel.createFamily(with: mockAppState)
        
        // Then - Should succeed with different family code
        XCTAssertEqual(secondCreateViewModel.creationState, .completed)
        XCTAssertNotNil(secondCreateViewModel.createdFamily)
        
        let secondFamily = secondCreateViewModel.createdFamily!
        XCTAssertNotEqual(firstFamily.code, secondFamily.code)
        XCTAssertEqual(firstFamily.name, secondFamily.name)
        XCTAssertEqual(dataManager.families.count, 2)
    }
    
    func testEdgeCase_AppRestartBehavior() async {
        // Given - Create family and add members
        let family = dataManager.createFamily(name: "Restart Test Family", createdByUserId: UUID())
        let parentUser = dataManager.createUser(name: "Parent")
        let childUser = dataManager.createUser(name: "Child")
        
        _ = dataManager.addMemberToFamily(familyId: family.id, user: parentUser, role: .parent)
        _ = dataManager.addMemberToFamily(familyId: family.id, user: childUser, role: .child)
        
        // Verify data exists
        XCTAssertEqual(dataManager.families.count, 1)
        XCTAssertEqual(dataManager.users.count, 2)
        XCTAssertEqual(family.members.count, 2)
        
        // When - Simulate app restart by clearing all data
        dataManager.clearAllData()
        mockAppState.simulateAppRestart()
        
        // Then - All family data should be cleared
        XCTAssertEqual(dataManager.families.count, 0)
        XCTAssertEqual(dataManager.users.count, 0)
        XCTAssertNil(mockAppState.currentInMemoryFamily)
        XCTAssertNil(mockAppState.currentUser)
        XCTAssertFalse(mockAppState.isAuthenticated)
        
        // When - Try to access previously existing family
        await joinFamilyViewModel.searchFamily(by: family.code)
        
        // Then - Should not find the family
        XCTAssertEqual(joinFamilyViewModel.currentError, .familyNotFound)
        XCTAssertNil(joinFamilyViewModel.foundFamily)
    }
    
    func testEdgeCase_MultipleUsersJoiningSameFamily() async {
        // Given - Create family with parent
        let family = dataManager.createFamily(name: "Multi-User Family", createdByUserId: UUID())
        let parentUser = dataManager.createUser(name: "Parent")
        _ = dataManager.addMemberToFamily(familyId: family.id, user: parentUser, role: .parent)
        
        // Create multiple users to join
        let users = [
            createTestUser(name: "Child 1"),
            createTestUser(name: "Child 2"),
            createTestUser(name: "Guardian"),
            createTestUser(name: "Helper 1"),
            createTestUser(name: "Helper 2")
        ]
        
        let roles: [Role] = [.child, .child, .guardian, .helper, .helper]
        
        // When - Multiple users join simultaneously
        for (index, user) in users.enumerated() {
            mockAppState.currentUser = user
            
            // Create new join view model for each user
            let userJoinViewModel = JoinFamilyViewModel(dataManager: dataManager)
            await userJoinViewModel.searchFamily(by: family.code)
            await userJoinViewModel.joinFamily(with: mockAppState)
            
            // Assign role
            let userInMemory = InMemoryUser(
                id: user.id,
                name: user.displayName,
                createdAt: user.createdAt
            )
            
            let roleViewModel = RoleSelectionViewModel(
                family: family,
                user: userInMemory,
                dataManager: dataManager
            )
            roleViewModel.setAppState(mockAppState)
            await roleViewModel.setRole(roles[index])
            
            // Verify each user was added successfully
            XCTAssertTrue(roleViewModel.roleSelectionComplete)
            XCTAssertEqual(roleViewModel.selectedRole, roles[index])
        }
        
        // Then - All users should be in the family
        XCTAssertEqual(family.members.count, 6) // 1 parent + 5 new members
        XCTAssertEqual(dataManager.users.count, 6) // parentUser + 5 new users
        
        // Verify role distribution
        let membersByRole = Dictionary(grouping: family.members) { $0.role }
        XCTAssertEqual(membersByRole[.parent]?.count, 1)
        XCTAssertEqual(membersByRole[.child]?.count, 2)
        XCTAssertEqual(membersByRole[.guardian]?.count, 1)
        XCTAssertEqual(membersByRole[.helper]?.count, 2)
    }
    
    func testEdgeCase_RoleConstraintsAndConflicts() async {
        // Given - Create family with existing parent
        let family = dataManager.createFamily(name: "Role Constraint Family", createdByUserId: UUID())
        let existingParent = dataManager.createUser(name: "Existing Parent")
        _ = dataManager.addMemberToFamily(familyId: family.id, user: existingParent, role: .parent)
        
        // When - New user tries to join as parent
        let newUser = createTestUser(name: "New User")
        mockAppState.currentUser = newUser
        
        await joinFamilyViewModel.searchFamily(by: family.code)
        await joinFamilyViewModel.joinFamily(with: mockAppState)
        
        let newInMemoryUser = InMemoryUser(
            id: newUser.id,
            name: newUser.displayName,
            createdAt: newUser.createdAt
        )
        
        roleSelectionViewModel = RoleSelectionViewModel(
            family: family,
            user: newInMemoryUser,
            dataManager: dataManager
        )
        roleSelectionViewModel.setAppState(mockAppState)
        
        // Check parent availability
        await roleSelectionViewModel.checkParentAvailability()
        
        // Then - Parent should not be available
        XCTAssertFalse(roleSelectionViewModel.canSelectParent)
        
        // When - Try to force parent role selection
        await roleSelectionViewModel.setRole(.parent)
        
        // Then - Should fallback to helper role
        XCTAssertEqual(roleSelectionViewModel.selectedRole, .helper)
        XCTAssertNotNil(roleSelectionViewModel.currentError)
        
        let member = family.member(withUserId: newUser.id)
        XCTAssertNotNil(member)
        XCTAssertEqual(member?.role, .helper)
        
        // Verify only one parent exists
        let parentMembers = family.members.filter { $0.role == .parent }
        XCTAssertEqual(parentMembers.count, 1)
        XCTAssertEqual(parentMembers.first?.userId, existingParent.id)
    }
    
    func testEdgeCase_NetworkAndErrorRecovery() async {
        // Test 1: Network unavailable during family creation
        mockAppState.simulateNetworkChange(connected: false)
        
        let familyName = "Network Test Family"
        let user = createTestUser(name: "Creator")
        mockAppState.currentUser = user
        
        createFamilyViewModel.familyName = familyName
        await createFamilyViewModel.createFamily(with: mockAppState)
        
        // Should still succeed (in-memory operations don't require network)
        XCTAssertEqual(createFamilyViewModel.creationState, .completed)
        XCTAssertNotNil(createFamilyViewModel.createdFamily)
        
        // Test 2: QR code generation failure
        mockQRCodeService.configureForFailure(error: .generationFailed)
        
        let secondFamilyName = "QR Test Family"
        let secondUser = createTestUser(name: "Second Creator")
        mockAppState.currentUser = secondUser
        
        let secondCreateViewModel = CreateFamilyViewModel(
            dataManager: dataManager,
            qrCodeService: mockQRCodeService
        )
        secondCreateViewModel.familyName = secondFamilyName
        
        await secondCreateViewModel.createFamily(with: mockAppState)
        
        // Family should be created but QR code should be nil
        XCTAssertEqual(secondCreateViewModel.creationState, .completed)
        XCTAssertNotNil(secondCreateViewModel.createdFamily)
        XCTAssertNil(secondCreateViewModel.qrCodeImage)
        
        // Test 3: Recovery after error
        mockQRCodeService.configureForSuccess()
        mockAppState.simulateNetworkChange(connected: true)
        
        // Retry QR code generation
        await secondCreateViewModel.generateQRCode()
        
        // Should now have QR code
        XCTAssertNotNil(secondCreateViewModel.qrCodeImage)
    }
    
    func testEdgeCase_ConcurrentFamilyOperations() async {
        // Given - Multiple users trying to create families simultaneously
        let users = [
            createTestUser(name: "Creator 1"),
            createTestUser(name: "Creator 2"),
            createTestUser(name: "Creator 3")
        ]
        
        let familyNames = ["Family 1", "Family 2", "Family 3"]
        var createdFamilies: [InMemoryFamily] = []
        
        // When - Create families concurrently
        await withTaskGroup(of: InMemoryFamily?.self) { group in
            for (index, user) in users.enumerated() {
                group.addTask { [self] in
                    let localMockAppState = MockAppState()
                    localMockAppState.currentUser = user
                    
                    let localCreateViewModel = CreateFamilyViewModel(
                        dataManager: dataManager,
                        qrCodeService: mockQRCodeService
                    )
                    localCreateViewModel.familyName = familyNames[index]
                    
                    await localCreateViewModel.createFamily(with: localMockAppState)
                    return localCreateViewModel.createdFamily
                }
            }
            
            for await family in group {
                if let family = family {
                    createdFamilies.append(family)
                }
            }
        }
        
        // Then - All families should be created with unique codes
        XCTAssertEqual(createdFamilies.count, 3)
        XCTAssertEqual(dataManager.families.count, 3)
        
        let familyCodes = Set(createdFamilies.map { $0.code })
        XCTAssertEqual(familyCodes.count, 3) // All codes should be unique
        
        let familyNames = Set(createdFamilies.map { $0.name })
        XCTAssertEqual(familyNames.count, 3) // All names should be unique
    }
    
    func testEdgeCase_MemoryPressureAndDataIntegrity() async {
        // Given - Create large family with many members
        let family = dataManager.createFamily(name: "Large Family", createdByUserId: UUID())
        let parentUser = dataManager.createUser(name: "Parent")
        _ = dataManager.addMemberToFamily(familyId: family.id, user: parentUser, role: .parent)
        
        // Add many members
        for i in 1...100 {
            let user = dataManager.createUser(name: "Member \(i)")
            _ = dataManager.addMemberToFamily(familyId: family.id, user: user, role: .child)
        }
        
        // Verify initial state
        XCTAssertEqual(dataManager.families.count, 1)
        XCTAssertEqual(dataManager.users.count, 101) // 1 parent + 100 children
        XCTAssertEqual(family.members.count, 101)
        
        // When - Simulate memory pressure
        mockAppState.simulateMemoryPressure()
        
        // Then - Data should remain intact (in-memory storage should persist)
        XCTAssertEqual(dataManager.families.count, 1)
        XCTAssertEqual(dataManager.users.count, 101)
        XCTAssertEqual(family.members.count, 101)
        
        // App state family reference should be cleared
        XCTAssertNil(mockAppState.currentInMemoryFamily)
        XCTAssertFalse(mockAppState.familySet)
        
        // When - Try to access family after memory pressure
        familyDashboardViewModel = FamilyDashboardViewModel(
            familyId: family.id,
            currentUserId: parentUser.id,
            dataManager: dataManager
        )
        
        // Then - Should still work correctly
        XCTAssertEqual(familyDashboardViewModel.members.count, 101)
        XCTAssertEqual(familyDashboardViewModel.currentUserRole, .parent)
    }
    
    func testEdgeCase_StateConsistencyAcrossViewModels() async {
        // Given - Create family through one view model
        let familyName = "Consistency Test"
        let user = createTestUser(name: "User")
        mockAppState.currentUser = user
        
        createFamilyViewModel.familyName = familyName
        await createFamilyViewModel.createFamily(with: mockAppState)
        
        let family = createFamilyViewModel.createdFamily!
        
        // When - Access same family through different view models simultaneously
        let dashboardViewModel1 = FamilyDashboardViewModel(
            familyId: family.id,
            currentUserId: user.id,
            dataManager: dataManager
        )
        
        let dashboardViewModel2 = FamilyDashboardViewModel(
            familyId: family.id,
            currentUserId: user.id,
            dataManager: dataManager
        )
        
        // Modify family through one view model
        let newMember = dataManager.createUser(name: "New Member")
        _ = dataManager.addMemberToFamily(familyId: family.id, user: newMember, role: .child)
        
        // Refresh both view models
        dashboardViewModel1.loadMembers()
        dashboardViewModel2.loadMembers()
        
        // Then - Both should show consistent state
        XCTAssertEqual(dashboardViewModel1.members.count, dashboardViewModel2.members.count)
        XCTAssertEqual(dashboardViewModel1.memberCount, dashboardViewModel2.memberCount)
        XCTAssertEqual(dashboardViewModel1.familyName, dashboardViewModel2.familyName)
        XCTAssertEqual(dashboardViewModel1.familyCode, dashboardViewModel2.familyCode)
        
        // Both should reflect the new member
        XCTAssertEqual(dashboardViewModel1.members.count, 2) // Original user + new member
        XCTAssertEqual(dashboardViewModel2.members.count, 2)
    }
    
    // MARK: - Performance Integration Tests
    
    func testPerformance_LargeFamilyOperations() async {
        // Given - Create family with many members
        let family = dataManager.createFamily(name: "Large Family", createdByUserId: UUID())
        let parentUser = dataManager.createUser(name: "Parent")
        _ = dataManager.addMemberToFamily(familyId: family.id, user: parentUser, role: .parent)
        
        // Add 50 members
        for i in 1...50 {
            let user = dataManager.createUser(name: "Member \(i)")
            _ = dataManager.addMemberToFamily(familyId: family.id, user: user, role: .child)
        }
        
        // When - Load dashboard (should be fast)
        measure {
            let dashboardViewModel = FamilyDashboardViewModel(
                familyId: family.id,
                currentUserId: parentUser.id,
                dataManager: dataManager
            )
            
            // Access computed properties
            _ = dashboardViewModel.members
            _ = dashboardViewModel.memberCount
            _ = dashboardViewModel.canManageMembers
        }
        
        // Then - Should complete within reasonable time
        XCTAssertEqual(dataManager.families.count, 1)
        XCTAssertEqual(dataManager.users.count, 51) // 1 parent + 50 children
    }
    
    func testPerformance_ConcurrentFamilyAccess() async {
        // Given - Create multiple families
        var families: [InMemoryFamily] = []
        for i in 1...10 {
            let family = dataManager.createFamily(name: "Family \(i)", createdByUserId: UUID())
            let parentUser = dataManager.createUser(name: "Parent \(i)")
            _ = dataManager.addMemberToFamily(familyId: family.id, user: parentUser, role: .parent)
            families.append(family)
        }
        
        // When - Access all families concurrently
        measure {
            let group = DispatchGroup()
            
            for family in families {
                group.enter()
                Task {
                    let dashboardViewModel = FamilyDashboardViewModel(
                        familyId: family.id,
                        currentUserId: family.members.first!.userId,
                        dataManager: dataManager
                    )
                    
                    // Access properties
                    _ = dashboardViewModel.members
                    _ = dashboardViewModel.familyName
                    _ = dashboardViewModel.memberCount
                    
                    group.leave()
                }
            }
            
            group.wait()
        }
        
        // Then - All operations should complete successfully
        XCTAssertEqual(dataManager.families.count, 10)
        XCTAssertEqual(dataManager.users.count, 10)
    }
    
    // MARK: - Helper Methods
    
    private func createTestUser(name: String = "Test User") -> UserProfile {
        return UserProfile(
            displayName: name,
            appleUserIdHash: "test_hash_\(UUID().uuidString.prefix(8))"
        )
    }
}// MARK:
 - Mock AppState Extension

extension MockAppState {
    var familySet = false
    var setFamilyValue: InMemoryFamily?
    
    func setFamily(_ family: InMemoryFamily) {
        familySet = true
        setFamilyValue = family
        currentInMemoryFamily = family
    }
}