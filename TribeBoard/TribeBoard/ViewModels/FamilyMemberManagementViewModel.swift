import SwiftUI
import Foundation

/// View model for family member management with mock operations
@MainActor
class FamilyMemberManagementViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    @Published var members: [MockFamilyMember] = []
    @Published var pendingInvitations: [MockPendingInvitation] = []
    
    // MARK: - Sheet States
    
    @Published var showInviteMember = false
    @Published var showRoleEditor = false
    @Published var showRemoveConfirmation = false
    
    @Published var selectedMember: MockFamilyMember?
    @Published var memberToRemove: MockFamilyMember?
    
    // MARK: - Properties
    
    let familyId: UUID
    let currentUserRole: Role
    let currentUserId: UUID
    let familyCode: String
    
    var canManageMembers: Bool {
        currentUserRole == .parentAdmin
    }
    
    var adminCount: Int {
        members.filter { $0.role == .parentAdmin }.count
    }
    
    var adultCount: Int {
        members.filter { $0.role == .adult }.count
    }
    
    var childCount: Int {
        members.filter { $0.role == .kid }.count
    }
    
    // MARK: - Initialization
    
    init(familyId: UUID, currentUserRole: Role) {
        self.familyId = familyId
        self.currentUserRole = currentUserRole
        self.currentUserId = UUID() // Mock current user ID
        self.familyCode = "FAM\(Int.random(in: 1000...9999))"
    }
    
    // MARK: - Public Methods
    
    func loadMembers() async {
        isLoading = true
        
        // Simulate loading delay
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        // Load mock family members
        let mockData = MockDataGenerator.mockMawereFamily()
        members = mockData.users.enumerated().map { index, user in
            MockFamilyMember(
                id: user.id,
                displayName: user.displayName,
                email: user.appleUserIdHash.replacingOccurrences(of: "hash_", with: "") + "@example.com",
                role: mockData.memberships[index].role,
                joinedDate: Calendar.current.date(byAdding: .day, value: -Int.random(in: 1...365), to: Date()) ?? Date(),
                isCurrentUser: index == 0 // First user is current user
            )
        }
        
        // Load mock pending invitations
        pendingInvitations = [
            MockPendingInvitation(
                id: UUID(),
                email: "newmember@example.com",
                role: .adult,
                sentDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date(),
                invitedBy: currentUserId
            ),
            MockPendingInvitation(
                id: UUID(),
                email: "cousin@example.com",
                role: .visitor,
                sentDate: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
                invitedBy: currentUserId
            )
        ]
        
        isLoading = false
        successMessage = "Family members loaded"
    }
    
    func inviteMember(email: String, role: Role) {
        // Mock invite operation
        let newInvitation = MockPendingInvitation(
            id: UUID(),
            email: email,
            role: role,
            sentDate: Date(),
            invitedBy: currentUserId
        )
        
        pendingInvitations.append(newInvitation)
        successMessage = "Invitation sent to \(email)"
    }
    
    func editMemberRole(_ member: MockFamilyMember) {
        selectedMember = member
        showRoleEditor = true
    }
    
    func updateMemberRole(_ member: MockFamilyMember, newRole: Role) {
        if let index = members.firstIndex(where: { $0.id == member.id }) {
            members[index].role = newRole
            successMessage = "Role updated for \(member.displayName)"
        }
    }
    
    func showRemoveConfirmation(for member: MockFamilyMember) {
        memberToRemove = member
        showRemoveConfirmation = true
    }
    
    func removeMember(_ member: MockFamilyMember) {
        members.removeAll { $0.id == member.id }
        memberToRemove = nil
        successMessage = "\(member.displayName) removed from family"
    }
    
    func resendInvitation(_ invitation: MockPendingInvitation) {
        // Mock resend operation
        if let index = pendingInvitations.firstIndex(where: { $0.id == invitation.id }) {
            pendingInvitations[index].sentDate = Date()
            successMessage = "Invitation resent to \(invitation.email)"
        }
    }
    
    func cancelInvitation(_ invitation: MockPendingInvitation) {
        pendingInvitations.removeAll { $0.id == invitation.id }
        successMessage = "Invitation cancelled for \(invitation.email)"
    }
    
    func copyFamilyCode() {
        // Mock copy to clipboard
        successMessage = "Family code \(familyCode) copied to clipboard!"
    }
    
    func clearError() {
        errorMessage = nil
    }
}

// MARK: - Mock Data Models

/// Mock family member for prototype
struct MockFamilyMember: Identifiable {
    let id: UUID
    let displayName: String
    let email: String
    var role: Role
    let joinedDate: Date
    let isCurrentUser: Bool
}

/// Mock pending invitation for prototype
struct MockPendingInvitation: Identifiable {
    let id: UUID
    let email: String
    let role: Role
    var sentDate: Date
    let invitedBy: UUID
}