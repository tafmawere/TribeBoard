import XCTest
import SwiftData
@testable import TribeBoard

@MainActor
final class FamilyDashboardViewModelTests: XCTestCase {
    
    var viewModel: FamilyDashboardViewModel!
    var mockDataService: MockDataService!
    var mockCloudKitService: MockCloudKitService!
    var testUser: UserProfile!
    var testFamily: Family!
    var testMembership: Membership!
    
    override func setUp() async throws {
        try await super.setUp()
        
        mockDataService = MockDataService()
        mockCloudKitService = MockCloudKitService()
        
        testUser = UserProfile(displayName: "Test User", appleUserIdHash: "test_hash")
        testFamily = Family(name: "Test Family", code: "TEST123", createdByUserId: testUser.id)
        testMembership = Membership(family: testFamily, user: testUser, role: .parentAdmin)
        
        viewModel = FamilyDashboardViewModel(
            family: testFamily,
            currentUserMembership: testMembership,
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
        testMembership = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    @MainActor func testInitialization() {
        XCTAssertEqual(viewModel.members.count, 0)
        XCTAssertEqual(viewModel.currentUserRole, .parentAdmin)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.showingRoleChangeSheet)
        XCTAssertNil(viewModel.memberToChangeRole)
    }
    
    // MARK: - Load Members Tests
    
    func testLoadMembers_Success() async {
        // Setup
        let member1 = createTestMembership(role: .parentAdmin, displayName: "Parent")
        let member2 = createTestMembership(role: .adult, displayName: "Adult")
        let member3 = createTestMembership(role: .kid, displayName: "Kid")
        
        mockDataService.mockMembers = [member1, member2, member3]
        mockDataService.shouldSucceed = true
        
        // Execute
        await viewModel.loadMembers()
        
        // Verify
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.members.count, 3)
        XCTAssertNil(viewModel.errorMessage)
        
        // Verify sorting (Parent Admin first)
        XCTAssertEqual(viewModel.members[0].role, .parentAdmin)
    }
    
    func testLoadMembers_DataServiceFailure() async {
        // Setup
        mockDataService.shouldSucceed = false
        mockDataService.errorToThrow = DataServiceError.fetchFailed("Network error")
        
        // Execute
        await viewModel.loadMembers()
        
        // Verify
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.members.count, 0)
        XCTAssertNotNil(viewModel.errorMessage)
    }
    
    func testLoadMembers_EmptyResult() async {
        // Setup
        mockDataService.mockMembers = []
        mockDataService.shouldSucceed = true
        
        // Execute
        await viewModel.loadMembers()
        
        // Verify
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.members.count, 0)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    // MARK: - Role Change Tests
    
    func testChangeRole_Success() async {
        // Setup
        let member = createTestMembership(role: .adult, displayName: "Test Member")
        mockDataService.shouldSucceed = true
        mockCloudKitService.shouldSucceed = true
        
        // Execute
        await viewModel.changeRole(for: member, to: .kid)
        
        // Verify
        XCTAssertEqual(member.role, .kid)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testChangeRole_ParentAdminConstraint() async {
        // Setup
        let member = createTestMembership(role: .adult, displayName: "Test Member")
        mockDataService.shouldSucceed = false
        mockDataService.errorToThrow = DataServiceError.constraintViolation("Parent Admin already exists")
        
        // Execute
        await viewModel.changeRole(for: member, to: .parentAdmin)
        
        // Verify
        XCTAssertNotEqual(member.role, .parentAdmin)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage?.contains("Parent Admin") ?? false)
    }
    
    func testChangeRole_CloudKitFailure() async {
        // Setup
        let member = createTestMembership(role: .adult, displayName: "Test Member")
        mockDataService.shouldSucceed = true
        mockCloudKitService.shouldSucceed = false
        mockCloudKitService.errorToThrow = CloudKitError.networkUnavailable
        
        // Execute
        await viewModel.changeRole(for: member, to: .kid)
        
        // Verify - should succeed locally but show sync warning
        XCTAssertEqual(member.role, .kid)
        XCTAssertTrue(viewModel.errorMessage?.contains("sync") ?? false)
    }
    
    func testChangeRole_SameRole() async {
        // Setup
        let member = createTestMembership(role: .adult, displayName: "Test Member")
        
        // Execute
        await viewModel.changeRole(for: member, to: .adult)
        
        // Verify - should do nothing
        XCTAssertEqual(member.role, .adult)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    // MARK: - Remove Member Tests
    
    func testRemoveMember_Success() async {
        // Setup
        let member = createTestMembership(role: .adult, displayName: "Test Member")
        viewModel.members = [testMembership, member]
        mockDataService.shouldSucceed = true
        mockCloudKitService.shouldSucceed = true
        
        // Execute
        await viewModel.removeMember(member)
        
        // Verify
        XCTAssertEqual(member.status, .removed)
        XCTAssertEqual(viewModel.members.count, 1) // Should be filtered out
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testRemoveMember_CannotRemoveSelf() async {
        // Execute - try to remove current user
        await viewModel.removeMember(testMembership)
        
        // Verify - should show error
        XCTAssertNotEqual(testMembership.status, .removed)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage?.contains("cannot remove yourself") ?? false)
    }
    
    func testRemoveMember_CannotRemoveParentAdmin() async {
        // Setup - non-admin trying to remove parent admin
        let nonAdminMembership = Membership(family: testFamily, user: testUser, role: .adult)
        let parentAdminMember = createTestMembership(role: .parentAdmin, displayName: "Parent Admin")
        
        let nonAdminViewModel = FamilyDashboardViewModel(
            family: testFamily,
            currentUserMembership: nonAdminMembership,
            dataService: mockDataService,
            cloudKitService: mockCloudKitService
        )
        
        // Execute
        await nonAdminViewModel.removeMember(parentAdminMember)
        
        // Verify - should show error
        XCTAssertNotEqual(parentAdminMember.status, .removed)
        XCTAssertNotNil(nonAdminViewModel.errorMessage)
    }
    
    func testRemoveMember_DataServiceFailure() async {
        // Setup
        let member = createTestMembership(role: .adult, displayName: "Test Member")
        mockDataService.shouldSucceed = false
        mockDataService.errorToThrow = DataServiceError.updateFailed("Database error")
        
        // Execute
        await viewModel.removeMember(member)
        
        // Verify
        XCTAssertNotEqual(member.status, .removed)
        XCTAssertNotNil(viewModel.errorMessage)
    }
    
    // MARK: - Permission Tests
    
    @MainActor func testCanChangeRole_ParentAdmin() {
        // Parent Admin should be able to change any role
        let member = createTestMembership(role: .adult, displayName: "Test Member")
        
        XCTAssertTrue(viewModel.canChangeRole(for: member))
    }
    
    @MainActor func testCanChangeRole_NonAdmin() {
        // Setup non-admin user
        let nonAdminMembership = Membership(family: testFamily, user: testUser, role: .adult)
        let nonAdminViewModel = FamilyDashboardViewModel(
            family: testFamily,
            currentUserMembership: nonAdminMembership,
            dataService: mockDataService,
            cloudKitService: mockCloudKitService
        )
        
        let member = createTestMembership(role: .kid, displayName: "Test Member")
        
        XCTAssertFalse(nonAdminViewModel.canChangeRole(for: member))
    }
    
    @MainActor func testCanRemoveMember_ParentAdmin() {
        let member = createTestMembership(role: .adult, displayName: "Test Member")
        
        XCTAssertTrue(viewModel.canRemoveMember(member))
    }
    
    @MainActor func testCanRemoveMember_NonAdmin() {
        // Setup non-admin user
        let nonAdminMembership = Membership(family: testFamily, user: testUser, role: .adult)
        let nonAdminViewModel = FamilyDashboardViewModel(
            family: testFamily,
            currentUserMembership: nonAdminMembership,
            dataService: mockDataService,
            cloudKitService: mockCloudKitService
        )
        
        let member = createTestMembership(role: .kid, displayName: "Test Member")
        
        XCTAssertFalse(nonAdminViewModel.canRemoveMember(member))
    }
    
    @MainActor func testCanRemoveMember_Self() {
        XCTAssertFalse(viewModel.canRemoveMember(testMembership))
    }
    
    // MARK: - UI State Tests
    
    @MainActor func testShowRoleChangeSheet() {
        let member = createTestMembership(role: .adult, displayName: "Test Member")
        
        viewModel.showRoleChangeSheet(for: member)
        
        XCTAssertTrue(viewModel.showingRoleChangeSheet)
        XCTAssertEqual(viewModel.memberToChangeRole?.id, member.id)
    }
    
    @MainActor func testHideRoleChangeSheet() {
        let member = createTestMembership(role: .adult, displayName: "Test Member")
        viewModel.memberToChangeRole = member
        viewModel.showingRoleChangeSheet = true
        
        viewModel.hideRoleChangeSheet()
        
        XCTAssertFalse(viewModel.showingRoleChangeSheet)
        XCTAssertNil(viewModel.memberToChangeRole)
    }
    
    // MARK: - Loading State Tests
    
    func testLoadMembers_LoadingState() async {
        // Setup
        mockDataService.shouldDelay = true
        
        // Start loading
        let loadTask = Task {
            await viewModel.loadMembers()
        }
        
        // Check loading state
        try await Task.sleep(nanoseconds: 10_000_000) // 0.01 seconds
        XCTAssertTrue(viewModel.isLoading)
        
        // Wait for completion
        await loadTask.value
        XCTAssertFalse(viewModel.isLoading)
    }
    
    // MARK: - Error Handling Tests
    
    @MainActor func testClearError() {
        viewModel.errorMessage = "Test error"
        XCTAssertNotNil(viewModel.errorMessage)
        
        viewModel.clearError()
        XCTAssertNil(viewModel.errorMessage)
    }
    
    // MARK: - Refresh Tests
    
    func testRefresh() async {
        // Setup initial state
        viewModel.members = [testMembership]
        
        // Setup new data
        let newMember = createTestMembership(role: .adult, displayName: "New Member")
        mockDataService.mockMembers = [testMembership, newMember]
        mockDataService.shouldSucceed = true
        
        // Execute
        await viewModel.refresh()
        
        // Verify
        XCTAssertEqual(viewModel.members.count, 2)
        XCTAssertNil(viewModel.errorMessage)
    }
    
    // MARK: - Helper Methods
    
    private func createTestMembership(role: Role, displayName: String) -> Membership {
        let user = UserProfile(displayName: displayName, appleUserIdHash: "hash_\(displayName)")
        return Membership(family: testFamily, user: user, role: role)
    }
}

// MARK: - Mock Service Extensions

extension MockDataService {
    var mockMembers: [Membership] = []
    
    override func fetchActiveMembers(forFamily family: Family) throws -> [Membership] {
        if shouldDelay {
            // Simulate delay in async context
            Task {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
        
        if !shouldSucceed {
            throw errorToThrow ?? DataServiceError.fetchFailed("Mock error")
        }
        
        return mockMembers.filter { $0.status == .active }
    }
    
    override func removeMember(_ membership: Membership) throws {
        if !shouldSucceed {
            throw errorToThrow ?? DataServiceError.updateFailed("Mock error")
        }
        membership.remove()
    }
}