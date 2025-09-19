import XCTest
import SwiftData
@testable import TribeBoard

/// Tests for complete end-to-end user workflows
@MainActor
class EndToEndWorkflowTests: DatabaseTestBase {
    
    // MARK: - Test Properties
    
    private var authService: AuthService!
    private var cloudKitService: MockCloudKitService!
    private var qrCodeService: QRCodeService!
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Initialize services for integration testing
        authService = AuthService()
        cloudKitService = MockCloudKitService()
        qrCodeService = QRCodeService()
        
        // Set up service dependencies
        authService.setDataService(dataService)
    }
    
    override func tearDown() async throws {
        // Clean up services
        authService = nil
        cloudKitService = nil
        qrCodeService = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Complete Family Creation Workflow Tests
    
    /// Tests the complete family creation workflow: user profile → family → membership → QR code
    /// Requirements: 8.1
    func testCompleteFamilyCreationWorkflow() async throws {
        print("🧪 Testing complete family creation workflow...")
        
        // Step 1: Create user profile (simulating authenticated user)
        let userDisplayName = "Family Creator"
        let userAppleIdHash = "creator_hash_1234567890"
        
        let user = try dataService.createUserProfile(
            displayName: userDisplayName,
            appleUserIdHash: userAppleIdHash
        )
        
        // Verify user creation
        XCTAssertEqual(user.displayName, userDisplayName)
        XCTAssertEqual(user.appleUserIdHash, userAppleIdHash)
        XCTAssertTrue(user.isFullyValid)
        
        // Step 2: Generate unique family code
        let familyCode = try dataService.generateUniqueFamilyCode()
        XCTAssertTrue(dataService.isValidFamilyCodeFormat(familyCode))
        XCTAssertFalse(try dataService.familyCodeExists(familyCode))
        
        // Step 3: Create family
        let familyName = "Test Family"
        let family = try dataService.createFamily(
            name: familyName,
            code: familyCode,
            createdByUserId: user.id
        )
        
        // Verify family creation
        XCTAssertEqual(family.name, familyName)
        XCTAssertEqual(family.code, familyCode)
        XCTAssertEqual(family.createdByUserId, user.id)
        XCTAssertTrue(family.isFullyValid)
        
        // Step 4: Create parent admin membership for creator
        let membership = try dataService.createMembership(
            family: family,
            user: user,
            role: .parentAdmin
        )
        
        // Verify membership creation
        XCTAssertEqual(membership.role, .parentAdmin)
        XCTAssertEqual(membership.status, .active)
        XCTAssertEqual(membership.family?.id, family.id)
        XCTAssertEqual(membership.user?.id, user.id)
        XCTAssertTrue(membership.isFullyValid)
        
        // Step 5: Verify family has parent admin
        XCTAssertTrue(family.hasParentAdmin)
        XCTAssertEqual(family.activeMembers.count, 1)
        
        // Step 6: Generate QR code for family
        let qrCodeImage = qrCodeService.generateQRCode(from: familyCode)
        XCTAssertNotNil(qrCodeImage)
        
        // Step 7: Verify complete workflow state
        let fetchedFamily = try dataService.fetchFamily(byCode: familyCode)
        XCTAssertNotNil(fetchedFamily)
        XCTAssertEqual(fetchedFamily?.id, family.id)
        
        let familyMemberships = try dataService.fetchActiveMemberships(forFamily: family)
        XCTAssertEqual(familyMemberships.count, 1)
        XCTAssertEqual(familyMemberships.first?.role, .parentAdmin)
        
        print("✅ Complete family creation workflow test passed")
    }
    
    /// Tests family creation workflow with validation errors
    /// Requirements: 8.1
    func testFamilyCreationWorkflowWithValidationErrors() async throws {
        print("🧪 Testing family creation workflow with validation errors...")
        
        // Step 1: Create valid user
        let user = try dataService.createUserProfile(
            displayName: "Test User",
            appleUserIdHash: "test_hash_1234567890"
        )
        
        // Step 2: Attempt to create family with invalid name
        do {
            _ = try dataService.createFamily(
                name: "", // Invalid empty name
                code: "VALID123",
                createdByUserId: user.id
            )
            XCTFail("Should have thrown validation error for empty family name")
        } catch let error as DataServiceError {
            switch error {
            case .validationFailed(let messages):
                XCTAssertTrue(messages.contains { $0.contains("name") })
            default:
                XCTFail("Expected validation failed error, got \(error)")
            }
        }
        
        // Step 3: Attempt to create family with invalid code
        do {
            _ = try dataService.createFamily(
                name: "Valid Family",
                code: "X", // Invalid short code
                createdByUserId: user.id
            )
            XCTFail("Should have thrown validation error for invalid family code")
        } catch let error as DataServiceError {
            switch error {
            case .validationFailed(let messages):
                XCTAssertTrue(messages.contains { $0.contains("code") })
            default:
                XCTFail("Expected validation failed error, got \(error)")
            }
        }
        
        // Step 4: Create valid family
        let family = try dataService.createFamily(
            name: "Valid Family",
            code: "VALID123",
            createdByUserId: user.id
        )
        
        // Step 5: Attempt to create duplicate family code
        do {
            _ = try dataService.createFamily(
                name: "Another Family",
                code: "VALID123", // Duplicate code
                createdByUserId: user.id
            )
            XCTFail("Should have thrown validation error for duplicate family code")
        } catch let error as DataServiceError {
            switch error {
            case .validationFailed(let messages):
                XCTAssertTrue(messages.contains { $0.contains("already exists") })
            default:
                XCTFail("Expected validation failed error, got \(error)")
            }
        }
        
        print("✅ Family creation workflow validation error test passed")
    }
    
    // MARK: - Complete Family Joining Workflow Tests
    
    /// Tests the complete family joining workflow: find family → validate code → create membership
    /// Requirements: 8.2
    func testCompleteFamilyJoiningWorkflow() async throws {
        print("🧪 Testing complete family joining workflow...")
        
        // Step 1: Set up existing family with parent admin
        let parentUser = try dataService.createUserProfile(
            displayName: "Parent User",
            appleUserIdHash: "parent_hash_1234567890"
        )
        
        let family = try dataService.createFamily(
            name: "Existing Family",
            code: "EXIST123",
            createdByUserId: parentUser.id
        )
        
        let parentMembership = try dataService.createMembership(
            family: family,
            user: parentUser,
            role: .parentAdmin
        )
        
        // Step 2: Create new user wanting to join
        let joiningUser = try dataService.createUserProfile(
            displayName: "Joining User",
            appleUserIdHash: "joining_hash_1234567890"
        )
        
        // Step 3: Find family by code (simulating QR code scan)
        let foundFamily = try dataService.fetchFamily(byCode: "EXIST123")
        XCTAssertNotNil(foundFamily)
        XCTAssertEqual(foundFamily?.id, family.id)
        
        // Step 4: Validate that user can join family
        let canJoin = try dataService.canUserJoinFamily(user: joiningUser, family: family)
        XCTAssertTrue(canJoin)
        
        // Step 5: Create membership for joining user
        let joiningMembership = try dataService.createMembership(
            family: family,
            user: joiningUser,
            role: .kid
        )
        
        // Verify membership creation
        XCTAssertEqual(joiningMembership.role, .kid)
        XCTAssertEqual(joiningMembership.status, .active)
        XCTAssertEqual(joiningMembership.family?.id, family.id)
        XCTAssertEqual(joiningMembership.user?.id, joiningUser.id)
        
        // Step 6: Verify family state after joining
        let activeMemberships = try dataService.fetchActiveMemberships(forFamily: family)
        XCTAssertEqual(activeMemberships.count, 2)
        
        let memberCount = try dataService.getActiveMemberCount(for: family)
        XCTAssertEqual(memberCount, 2)
        
        // Step 7: Verify both users are properly associated
        let parentMemberships = try dataService.fetchMemberships(forUser: parentUser)
        XCTAssertEqual(parentMemberships.count, 1)
        XCTAssertEqual(parentMemberships.first?.role, .parentAdmin)
        
        let joiningUserMemberships = try dataService.fetchMemberships(forUser: joiningUser)
        XCTAssertEqual(joiningUserMemberships.count, 1)
        XCTAssertEqual(joiningUserMemberships.first?.role, .kid)
        
        print("✅ Complete family joining workflow test passed")
    }
    
    /// Tests family joining workflow with constraint violations
    /// Requirements: 8.2
    func testFamilyJoiningWorkflowWithConstraints() async throws {
        print("🧪 Testing family joining workflow with constraints...")
        
        // Step 1: Set up existing family
        let parentUser = try dataService.createUserProfile(
            displayName: "Parent User",
            appleUserIdHash: "parent_hash_1234567890"
        )
        
        let family = try dataService.createFamily(
            name: "Test Family",
            code: "TEST123",
            createdByUserId: parentUser.id
        )
        
        let parentMembership = try dataService.createMembership(
            family: family,
            user: parentUser,
            role: .parentAdmin
        )
        
        // Step 2: Attempt to join with invalid family code
        let joiningUser = try dataService.createUserProfile(
            displayName: "Joining User",
            appleUserIdHash: "joining_hash_1234567890"
        )
        
        let nonExistentFamily = try dataService.fetchFamily(byCode: "INVALID")
        XCTAssertNil(nonExistentFamily)
        
        // Step 3: Join family successfully first time
        let membership = try dataService.createMembership(
            family: family,
            user: joiningUser,
            role: .kid
        )
        
        // Step 4: Attempt to join same family again (should fail)
        do {
            _ = try dataService.createMembership(
                family: family,
                user: joiningUser,
                role: .adult
            )
            XCTFail("Should have thrown constraint violation for duplicate membership")
        } catch let error as DataServiceError {
            switch error {
            case .constraintViolation(let message):
                XCTAssertTrue(message.contains("already a member"))
            default:
                XCTFail("Expected constraint violation error, got \(error)")
            }
        }
        
        // Step 5: Verify family state remains consistent
        let activeMemberships = try dataService.fetchActiveMemberships(forFamily: family)
        XCTAssertEqual(activeMemberships.count, 2) // Parent + one joining user
        
        print("✅ Family joining workflow constraint test passed")
    }
    
    // MARK: - Complete Role Management Workflow Tests
    
    /// Tests the complete role management workflow: validate constraints → update role → sync
    /// Requirements: 8.3
    func testCompleteRoleManagementWorkflow() async throws {
        print("🧪 Testing complete role management workflow...")
        
        // Step 1: Set up family with multiple members
        let (family, users, memberships) = TestDataFactory.createFamilyWithMembers(memberCount: 3)
        
        // Insert test data
        testContext.insert(family)
        for user in users {
            testContext.insert(user)
        }
        for membership in memberships {
            testContext.insert(membership)
        }
        try testContext.save()
        
        // Verify initial setup
        XCTAssertEqual(memberships.count, 3)
        XCTAssertEqual(memberships[0].role, .parentAdmin) // First member is parent admin
        XCTAssertEqual(memberships[1].role, .kid)
        XCTAssertEqual(memberships[2].role, .kid)
        
        // Step 2: Validate role change constraints
        let kidMembership = memberships[1]
        
        // Valid role change: kid → adult
        let validRoleChange = try dataService.validateRoleChange(
            membership: kidMembership,
            newRole: .adult
        )
        XCTAssertTrue(validRoleChange.isValid)
        
        // Invalid role change: kid → parentAdmin (parent admin already exists)
        let invalidRoleChange = try dataService.validateRoleChange(
            membership: kidMembership,
            newRole: .parentAdmin
        )
        XCTAssertFalse(invalidRoleChange.isValid)
        XCTAssertTrue(invalidRoleChange.message.contains("Parent Admin already exists"))
        
        // Step 3: Perform valid role update
        try dataService.updateMembershipRole(kidMembership, to: .adult)
        
        // Verify role update
        XCTAssertEqual(kidMembership.role, .adult)
        
        // Step 4: Test parent admin role transfer
        let currentParentAdmin = memberships[0]
        let newParentAdminCandidate = memberships[2]
        
        // First, change current parent admin to regular adult
        try dataService.updateMembershipRole(currentParentAdmin, to: .adult)
        XCTAssertEqual(currentParentAdmin.role, .adult)
        
        // Now the family should have no parent admin
        XCTAssertFalse(family.hasParentAdmin)
        
        // Now we can promote someone to parent admin
        try dataService.updateMembershipRole(newParentAdminCandidate, to: .parentAdmin)
        XCTAssertEqual(newParentAdminCandidate.role, .parentAdmin)
        
        // Step 5: Verify final family state
        XCTAssertTrue(family.hasParentAdmin)
        let activeMemberships = try dataService.fetchActiveMemberships(forFamily: family)
        XCTAssertEqual(activeMemberships.count, 3)
        
        let parentAdmins = activeMemberships.filter { $0.role == .parentAdmin }
        XCTAssertEqual(parentAdmins.count, 1)
        XCTAssertEqual(parentAdmins.first?.id, newParentAdminCandidate.id)
        
        // Step 6: Test role change validation after changes
        let finalValidation = try dataService.validateRoleChange(
            membership: currentParentAdmin,
            newRole: .parentAdmin
        )
        XCTAssertFalse(finalValidation.isValid) // Should fail because parent admin exists
        
        print("✅ Complete role management workflow test passed")
    }
    
    /// Tests role management workflow with complex constraint scenarios
    /// Requirements: 8.3
    func testRoleManagementWorkflowComplexConstraints() async throws {
        print("🧪 Testing role management workflow with complex constraints...")
        
        // Step 1: Create family with mixed roles
        let (family, users, memberships) = TestDataFactory.createFamilyWithMixedRoles()
        
        // Insert test data
        testContext.insert(family)
        for user in users {
            testContext.insert(user)
        }
        for membership in memberships {
            testContext.insert(membership)
        }
        try testContext.save()
        
        // Find specific role memberships
        let parentAdminMembership = memberships.first { $0.role == .parentAdmin }!
        let adultMembership = memberships.first { $0.role == .adult }!
        let kidMembership = memberships.first { $0.role == .kid }!
        let visitorMembership = memberships.first { $0.role == .visitor }!
        
        // Step 2: Test various role change scenarios
        
        // Adult → Kid (should be valid)
        let adultToKid = try dataService.validateRoleChange(
            membership: adultMembership,
            newRole: .kid
        )
        XCTAssertTrue(adultToKid.isValid)
        
        // Kid → Visitor (should be valid)
        let kidToVisitor = try dataService.validateRoleChange(
            membership: kidMembership,
            newRole: .visitor
        )
        XCTAssertTrue(kidToVisitor.isValid)
        
        // Visitor → Adult (should be valid)
        let visitorToAdult = try dataService.validateRoleChange(
            membership: visitorMembership,
            newRole: .adult
        )
        XCTAssertTrue(visitorToAdult.isValid)
        
        // Any role → ParentAdmin (should be invalid while parent admin exists)
        let adultToParentAdmin = try dataService.validateRoleChange(
            membership: adultMembership,
            newRole: .parentAdmin
        )
        XCTAssertFalse(adultToParentAdmin.isValid)
        
        // Step 3: Perform a series of role changes
        try dataService.updateMembershipRole(adultMembership, to: .kid)
        try dataService.updateMembershipRole(kidMembership, to: .visitor)
        try dataService.updateMembershipRole(visitorMembership, to: .adult)
        
        // Step 4: Verify all changes were applied correctly
        XCTAssertEqual(adultMembership.role, .kid)
        XCTAssertEqual(kidMembership.role, .visitor)
        XCTAssertEqual(visitorMembership.role, .adult)
        XCTAssertEqual(parentAdminMembership.role, .parentAdmin) // Unchanged
        
        // Step 5: Verify family still has exactly one parent admin
        XCTAssertTrue(family.hasParentAdmin)
        let activeMemberships = try dataService.fetchActiveMemberships(forFamily: family)
        let parentAdmins = activeMemberships.filter { $0.role == .parentAdmin }
        XCTAssertEqual(parentAdmins.count, 1)
        
        print("✅ Role management workflow complex constraints test passed")
    }
    
    // MARK: - Workflow Error Recovery Tests
    
    /// Tests error recovery in family creation workflow
    /// Requirements: 8.1, 8.2, 8.3
    func testWorkflowErrorRecovery() async throws {
        print("🧪 Testing workflow error recovery...")
        
        // Step 1: Start family creation workflow
        let user = try dataService.createUserProfile(
            displayName: "Test User",
            appleUserIdHash: "test_hash_1234567890"
        )
        
        // Step 2: Create family successfully
        let family = try dataService.createFamily(
            name: "Test Family",
            code: "TEST123",
            createdByUserId: user.id
        )
        
        // Step 3: Simulate error during membership creation
        // (This would happen if database constraints fail)
        
        // First, create a valid membership
        let membership = try dataService.createMembership(
            family: family,
            user: user,
            role: .parentAdmin
        )
        
        // Step 4: Verify system state is consistent after error recovery
        let fetchedFamily = try dataService.fetchFamily(byCode: "TEST123")
        XCTAssertNotNil(fetchedFamily)
        
        let familyMemberships = try dataService.fetchActiveMemberships(forFamily: family)
        XCTAssertEqual(familyMemberships.count, 1)
        
        // Step 5: Test that subsequent operations work correctly
        let anotherUser = try dataService.createUserProfile(
            displayName: "Another User",
            appleUserIdHash: "another_hash_1234567890"
        )
        
        let anotherMembership = try dataService.createMembership(
            family: family,
            user: anotherUser,
            role: .kid
        )
        
        XCTAssertEqual(anotherMembership.role, .kid)
        
        // Verify final state
        let finalMemberships = try dataService.fetchActiveMemberships(forFamily: family)
        XCTAssertEqual(finalMemberships.count, 2)
        
        print("✅ Workflow error recovery test passed")
    }
    
    // MARK: - Cross-Workflow Integration Tests
    
    /// Tests integration between multiple workflows
    /// Requirements: 8.1, 8.2, 8.3
    func testCrossWorkflowIntegration() async throws {
        print("🧪 Testing cross-workflow integration...")
        
        // Workflow 1: Family Creation
        let creator = try dataService.createUserProfile(
            displayName: "Family Creator",
            appleUserIdHash: "creator_hash_1234567890"
        )
        
        let family = try dataService.createFamily(
            name: "Integration Test Family",
            code: "INTEG123",
            createdByUserId: creator.id
        )
        
        let creatorMembership = try dataService.createMembership(
            family: family,
            user: creator,
            role: .parentAdmin
        )
        
        // Workflow 2: Family Joining (multiple users)
        let joiner1 = try dataService.createUserProfile(
            displayName: "Joiner One",
            appleUserIdHash: "joiner1_hash_1234567890"
        )
        
        let joiner2 = try dataService.createUserProfile(
            displayName: "Joiner Two",
            appleUserIdHash: "joiner2_hash_1234567890"
        )
        
        let membership1 = try dataService.createMembership(
            family: family,
            user: joiner1,
            role: .adult
        )
        
        let membership2 = try dataService.createMembership(
            family: family,
            user: joiner2,
            role: .kid
        )
        
        // Workflow 3: Role Management
        // Promote joiner1 to parent admin (after demoting creator)
        try dataService.updateMembershipRole(creatorMembership, to: .adult)
        try dataService.updateMembershipRole(membership1, to: .parentAdmin)
        
        // Verify integrated state
        let finalMemberships = try dataService.fetchActiveMemberships(forFamily: family)
        XCTAssertEqual(finalMemberships.count, 3)
        
        let parentAdmins = finalMemberships.filter { $0.role == .parentAdmin }
        XCTAssertEqual(parentAdmins.count, 1)
        XCTAssertEqual(parentAdmins.first?.user?.id, joiner1.id)
        
        let adults = finalMemberships.filter { $0.role == .adult }
        XCTAssertEqual(adults.count, 1)
        XCTAssertEqual(adults.first?.user?.id, creator.id)
        
        let kids = finalMemberships.filter { $0.role == .kid }
        XCTAssertEqual(kids.count, 1)
        XCTAssertEqual(kids.first?.user?.id, joiner2.id)
        
        // Test QR code generation still works
        let qrCode = qrCodeService.generateQRCode(from: family.code)
        XCTAssertNotNil(qrCode)
        
        print("✅ Cross-workflow integration test passed")
    }
}