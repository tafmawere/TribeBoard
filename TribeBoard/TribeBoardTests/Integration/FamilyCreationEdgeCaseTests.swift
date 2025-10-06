import XCTest
import SwiftUI
@testable import TribeBoard

/// Edge case tests for family creation and joining flows (Task 13)
/// Tests complete user flows and edge cases as specified in the requirements
@MainActor
class FamilyCreationEdgeCaseTests: XCTestCase {
    
    // MARK: - Properties
    
    var dataManager: InMemoryFamilyDataManager!
    var mockAppState: MockAppState!
    var mockQRCodeService: MockQRCodeService!
    
    // ViewModels
    var createFamilyViewModel: CreateFamilyViewModel!
    var joinFamilyViewModel: JoinFamilyViewModel!
    var roleSelectionViewModel: RoleSelectionViewModel!
    var familyDashboardViewModel: FamilyDashboardViewModel!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        dataManager = InMemoryFamilyDataManager()
        mockAppState = MockAppState()
        mockQRCodeService = MockQRCodeService()
        
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
        mockAppState = nil
        mockQRCodeService = nil
        super.tearDown()
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
    
    // MARK: - Complete Flow Tests
    
    func testCompleteFlow_FamilyCreationToRoleSelectionToDashboard() async {
        // Given
        let familyName = "Complete Flow Test Family"
        let creatorUser = createTestUser(name: "Family Creator")
        mockAppState.currentUser = creatorUser
        
        createFamilyViewModel.familyName = familyName
        
        // When - Create family
        await createFamilyViewModel.createFamily(with: mockAppState)
        
        // Then - Verify family creation
        XCTAssertEqual(createFamilyViewModel.creationState, .completed)
        XCTAssertNotNil(createFamilyViewModel.createdFamily)
        XCTAssertEqual(createFamilyViewModel.createdFamily?.name, familyName)
        
        let createdFamily = createFamilyViewModel.createdFamily!
        
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
        
        await roleSelectionViewModel.setRole(.parent)
        
        // Then - Verify role selection
        XCTAssertTrue(roleSelectionViewModel.roleSelectionComplete)
        XCTAssertEqual(roleSelectionViewModel.selectedRole, .parent)
        
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
    
    func testCompleteFlow_FamilyJoiningToRoleSelectionToDashboard() async {
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
    
    // MARK: - Helper Methods
    
    private func createTestUser(name: String = "Test User") -> UserProfile {
        return UserProfile(
            displayName: name,
            appleUserIdHash: "test_hash_\(UUID().uuidString.prefix(8))"
        )
    }
}