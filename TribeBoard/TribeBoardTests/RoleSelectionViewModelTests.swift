import XCTest
import SwiftData
import CloudKit
@testable import TribeBoard

@MainActor
final class RoleSelectionViewModelTests: XCTestCase {
    
    var viewModel: RoleSelectionViewModel!
    var mockDataService: RoleSelectionMockDataService!
    var mockCloudKitService: RoleSelectionMockCloudKitService!
    var testUser: UserProfile!
    var testFamily: Family!
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockDataService = RoleSelectionMockDataService()
        mockCloudKitService = RoleSelectionMockCloudKitService()
        
        testUser = UserProfile(displayName: "Test User", appleUserIdHash: "test_hash")
        testFamily = Family(name: "Test Family", code: "TEST123", createdByUserId: UUID())
        
        viewModel = RoleSelectionViewModel(
            family: testFamily,
            user: testUser,
            dataService: mockDataService,
            cloudKitService: mockCloudKitService
        )
    }
    
    override func tearDown() async throws {
        viewModel = nil
        mockDataService = nil
        mockCloudKitService = nil
        testUser = nil
        testFamily = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertEqual(viewModel.selectedRole, .adult)
        XCTAssertFalse(viewModel.isUpdating)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.canSelectParentAdmin) // Default until check completes
        XCTAssertFalse(viewModel.roleSelectionComplete)
    }
    
    // MARK: - Parent Admin Availability Tests
    
    func testCheckParentAdminAvailability_NoParentAdmin() async {
        // Setup - no parent admin exists
        mockDataService.hasParentAdmin = false
        mockCloudKitService.mockMemberships = []
        
        // Execute
        await viewModel.checkParentAdminAvailability()
        
        // Verify
        XCTAssertTrue(viewModel.canSelectParentAdmin)
        XCTAssertEqual(viewModel.selectedRole, .adult) // Should remain adult
    }
    
    func testCheckParentAdminAvailability_LocalParentAdminExists() async {
        // Setup - parent admin exists locally
        mockDataService.hasParentAdmin = true
        
        // Execute
        await viewModel.checkParentAdminAvailability()
        
        // Verify
        XCTAssertFalse(viewModel.canSelectParentAdmin)
        XCTAssertEqual(viewModel.selectedRole, .adult) // Should remain adult
    }
    
    func testCheckParentAdminAvailability_CloudKitParentAdminExists() async {
        // Setup - parent admin exists in CloudKit
        mockDataService.hasParentAdmin = false
        let parentAdminRecord = createMockMembershipRecord(role: .parentAdmin)
        mockCloudKitService.mockMemberships = [parentAdminRecord]
        
        // Execute
        await viewModel.checkParentAdminAvailability()
        
        // Verify
        XCTAssertFalse(viewModel.canSelectParentAdmin)
    }
    
    func testCheckParentAdminAvailability_CurrentlySelectedParentAdmin() async {
        // Setup - parent admin exists and currently selected
        viewModel.selectedRole = .parentAdmin
        mockDataService.hasParentAdmin = true
        
        // Execute
        await viewModel.checkParentAdminAvailability()
        
        // Verify - should change to adult
        XCTAssertFalse(viewModel.canSelectParentAdmin)
        XCTAssertEqual(viewModel.selectedRole, .adult)
    }
    
    func testCheckParentAdminAvailability_NetworkError() async {
        // Setup - network error
        mockDataService.hasParentAdmin = false
        mockCloudKitService.shouldSucceed = false
        mockCloudKitService.errorToThrow = CloudKitError.networkUnavailable
        
        // Execute
        await viewModel.checkParentAdminAvailability()
        
        // Verify - should default to not allowing parent admin for safety
        XCTAssertFalse(viewModel.canSelectParentAdmin)
    }
    
    // MARK: - Role Selection Tests
    
    func testSetRole_ValidRole() async {
        // Setup
        mockDataService.shouldSucceed = true
        mockCloudKitService.shouldSucceed = true
        viewModel.canSelectParentAdmin = true
        
        // Execute
        await viewModel.setRole(.kid)
        
        // Verify
        XCTAssertEqual(viewModel.selectedRole, .kid)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testSetRole_ParentAdminWhenNotAllowed() async {
        // Setup
        viewModel.canSelectParentAdmin = false
        
        // Execute
        await viewModel.setRole(.parentAdmin)
        
        // Verify - should default to adult and show error
        XCTAssertEqual(viewModel.selectedRole, .adult)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage?.contains("Parent Admin already exists") ?? false)
    }
    
    func testSetRole_ParentAdminWhenAllowed() async {
        // Setup
        mockDataService.shouldSucceed = true
        mockCloudKitService.shouldSucceed = true
        viewModel.canSelectParentAdmin = true
        
        // Execute
        await viewModel.setRole(.parentAdmin)
        
        // Verify
        XCTAssertEqual(viewModel.selectedRole, .parentAdmin)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    // MARK: - Role Update Tests
    
    func testUpdateRole_Success() async {
        // Setup
        mockDataService.shouldSucceed = true
        mockCloudKitService.shouldSucceed = true
        mockDataService.mockMembership = Membership(family: testFamily, user: testUser, role: .adult)
        
        // Execute
        await viewModel.updateRole(.kid)
        
        // Verify
        XCTAssertFalse(viewModel.isUpdating)
        XCTAssertTrue(viewModel.roleSelectionComplete)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testUpdateRole_DataServiceFailure() async {
        // Setup
        mockDataService.shouldSucceed = false
        mockDataService.errorToThrow = DataServiceError.constraintViolation("Parent Admin already exists")
        
        // Execute
        await viewModel.updateRole(.parentAdmin)
        
        // Verify
        XCTAssertFalse(viewModel.isUpdating)
        XCTAssertFalse(viewModel.roleSelectionComplete)
        XCTAssertNotNil(viewModel.errorMessage)
    }
    
    func testUpdateRole_CloudKitFailure() async {
        // Setup
        mockDataService.shouldSucceed = true
        mockCloudKitService.shouldSucceed = false
        mockCloudKitService.errorToThrow = CloudKitError.networkUnavailable
        mockDataService.mockMembership = Membership(family: testFamily, user: testUser, role: .adult)
        
        // Execute
        await viewModel.updateRole(.kid)
        
        // Verify - should succeed locally but show sync warning
        XCTAssertFalse(viewModel.isUpdating)
        XCTAssertTrue(viewModel.roleSelectionComplete)
        XCTAssertTrue(viewModel.errorMessage?.contains("sync failed") ?? false)
    }
    
    func testUpdateRole_NewMembershipCreation() async {
        // Setup - no existing membership
        mockDataService.shouldSucceed = true
        mockCloudKitService.shouldSucceed = true
        mockDataService.mockMembership = nil // No existing membership
        
        // Execute
        await viewModel.updateRole(.adult)
        
        // Verify
        XCTAssertFalse(viewModel.isUpdating)
        XCTAssertTrue(viewModel.roleSelectionComplete)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    // MARK: - Loading State Tests
    
    func testUpdateRole_LoadingState() async {
        // Setup
        mockDataService.shouldDelay = true
        mockDataService.mockMembership = Membership(family: testFamily, user: testUser, role: .adult)
        
        // Start update
        let updateTask = Task {
            await viewModel.updateRole(.kid)
        }
        
        // Check loading state
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        XCTAssertTrue(viewModel.isUpdating)
        
        // Wait for completion
        await updateTask.value
        XCTAssertFalse(viewModel.isUpdating)
    }
    
    // MARK: - Role Card Data Tests
    
    func testGetRoleCardData() {
        // Setup
        viewModel.selectedRole = .kid
        viewModel.canSelectParentAdmin = false
        
        // Execute
        let roleCards = viewModel.getRoleCardData()
        
        // Verify
        XCTAssertEqual(roleCards.count, 4) // All roles
        
        let kidCard = roleCards.first { $0.role == .kid }
        XCTAssertNotNil(kidCard)
        XCTAssertTrue(kidCard?.isSelected ?? false)
        XCTAssertTrue(kidCard?.isEnabled ?? false)
        
        let parentAdminCard = roleCards.first { $0.role == .parentAdmin }
        XCTAssertNotNil(parentAdminCard)
        XCTAssertFalse(parentAdminCard?.isSelected ?? true)
        XCTAssertFalse(parentAdminCard?.isEnabled ?? true) // Should be disabled
        
        let adultCard = roleCards.first { $0.role == .adult }
        XCTAssertNotNil(adultCard)
        XCTAssertTrue(adultCard?.isEnabled ?? false) // Should be enabled
    }
    
    // MARK: - App State Integration Tests
    
    func testSetAppState() {
        let mockAppState = MockAppState()
        viewModel.setAppState(mockAppState)
        
        // Test that app state is updated after role selection
        Task {
            mockDataService.shouldSucceed = true
            mockDataService.mockMembership = Membership(family: testFamily, user: testUser, role: .adult)
            
            await viewModel.updateRole(.adult)
            
            // Verify app state was updated
            XCTAssertTrue(mockAppState.setFamilyCalled)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createMockMembershipRecord(role: Role) -> CKRecord {
        let record = CKRecord(recordType: "Membership")
        record["role"] = role.rawValue
        record["status"] = MembershipStatus.active.rawValue
        return record
    }
}

// MARK: - Mock Services for Role Selection Tests

class MockAppState: AppState {
    var setFamilyCalled = false
    
    override func setFamily(_ family: Family) {
        setFamilyCalled = true
        super.setFamily(family)
    }
}

class RoleSelectionMockDataService: DataService {
    var hasParentAdmin = false
    var mockMembership: Membership?
    var shouldSucceed = true
    var errorToThrow: Error?
    
    override func familyHasParentAdmin(_ family: Family) throws -> Bool {
        return hasParentAdmin
    }
    
    override func fetchMemberships(forUser user: UserProfile) throws -> [Membership] {
        if let membership = mockMembership {
            return [membership]
        }
        return []
    }
    
    override func updateMembershipRole(_ membership: Membership, to role: Role) throws {
        if !shouldSucceed {
            throw errorToThrow ?? DataServiceError.constraintViolation("Mock error")
        }
        membership.role = role
    }
}

class RoleSelectionMockCloudKitService: CloudKitService {
    var mockMemberships: [CKRecord] = []
    var shouldSucceed = true
    var shouldDelay = false
    var errorToThrow: Error?
    
    func fetchActiveMemberships(forFamilyId familyId: String) async throws -> [CKRecord] {
        if shouldDelay {
            do {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            } catch {
                // Handle sleep interruption
            }
        }
        
        if !shouldSucceed {
            throw errorToThrow ?? CloudKitError.networkUnavailable
        }
        
        return mockMemberships
    }
}