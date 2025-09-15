import SwiftUI
import Foundation

/// ViewModel for managing family dashboard state and member operations
@MainActor
class FamilyDashboardViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// List of family members with their memberships
    @Published var members: [Membership] = []
    
    /// Associated user profiles for members
    @Published var userProfiles: [UUID: UserProfile] = [:]
    
    /// Current user's role in the family
    @Published var currentUserRole: Role = .adult
    
    /// Loading state for async operations
    @Published var isLoading = false
    
    /// Error message for display
    @Published var errorMessage: String?
    
    /// Success message for operations
    @Published var successMessage: String?
    
    /// Currently selected member for role change
    @Published var selectedMember: Membership?
    
    /// Show role change sheet
    @Published var showRoleChangeSheet = false
    
    /// Show member removal confirmation
    @Published var showRemovalConfirmation = false
    
    /// Member to be removed
    @Published var memberToRemove: Membership?
    
    // MARK: - Private Properties
    
    private let currentFamily: Family
    private let currentUserId: UUID
    
    // MARK: - Initialization
    
    init(family: Family, currentUserId: UUID, currentUserRole: Role) {
        self.currentFamily = family
        self.currentUserId = currentUserId
        self.currentUserRole = currentUserRole
    }
    
    // MARK: - Public Methods
    
    /// Load family members and their profiles
    func loadMembers() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Simulate network delay
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            // Mock data: Generate sample memberships for the family
            let mockMemberships = generateMockMemberships()
            let mockProfiles = generateMockUserProfiles(for: mockMemberships)
            
            await MainActor.run {
                self.members = mockMemberships
                self.userProfiles = mockProfiles
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load family members: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    /// Change a member's role (Parent Admin only)
    func changeRole(for member: Membership, to newRole: Role) async {
        guard currentUserRole == .parentAdmin else {
            errorMessage = "Only Parent Admin can change member roles"
            return
        }
        
        guard member.userId != currentUserId else {
            errorMessage = "You cannot change your own role"
            return
        }
        
        // Check if trying to assign Parent Admin when one already exists
        if newRole == .parentAdmin && members.contains(where: { $0.role == .parentAdmin }) {
            errorMessage = "Only one Parent Admin is allowed per family"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Simulate network delay
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Mock: Update the member's role
            if let index = members.firstIndex(where: { $0.id == member.id }) {
                await MainActor.run {
                    self.members[index].role = newRole
                    self.successMessage = "Role updated to \(newRole.displayName)"
                    self.isLoading = false
                    self.showRoleChangeSheet = false
                    self.selectedMember = nil
                }
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to update role: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    /// Remove a member from the family (Parent Admin only)
    func removeMember(_ member: Membership) async {
        guard currentUserRole == .parentAdmin else {
            errorMessage = "Only Parent Admin can remove members"
            return
        }
        
        guard member.userId != currentUserId else {
            errorMessage = "You cannot remove yourself from the family"
            return
        }
        
        guard member.role != .parentAdmin else {
            errorMessage = "Cannot remove Parent Admin"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Simulate network delay
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Mock: Remove the member (soft delete by changing status)
            if let index = members.firstIndex(where: { $0.id == member.id }) {
                await MainActor.run {
                    self.members[index].status = .removed
                    // Remove from display list
                    self.members.removeAll { $0.id == member.id }
                    self.successMessage = "Member removed from family"
                    self.isLoading = false
                    self.showRemovalConfirmation = false
                    self.memberToRemove = nil
                }
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to remove member: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    /// Show role change sheet for a member
    func showRoleChange(for member: Membership) {
        selectedMember = member
        showRoleChangeSheet = true
    }
    
    /// Show removal confirmation for a member
    func showRemovalConfirmation(for member: Membership) {
        memberToRemove = member
        showRemovalConfirmation = true
    }
    
    /// Clear success message
    func clearSuccessMessage() {
        successMessage = nil
    }
    
    /// Clear error message
    func clearErrorMessage() {
        errorMessage = nil
    }
    
    /// Check if current user can manage members
    var canManageMembers: Bool {
        currentUserRole == .parentAdmin
    }
    
    /// Get user profile for a member
    func userProfile(for membership: Membership) -> UserProfile? {
        return userProfiles[membership.userId]
    }
    
    // MARK: - Private Methods
    
    /// Generate mock memberships for testing
    private func generateMockMemberships() -> [Membership] {
        let familyId = currentFamily.id
        
        // Create memberships with different roles
        var memberships: [Membership] = []
        
        // Current user membership
        let currentUserMembership = Membership(
            familyId: familyId,
            userId: currentUserId,
            role: currentUserRole
        )
        memberships.append(currentUserMembership)
        
        // Additional mock members
        let additionalMembers = [
            (Role.adult, "Active"),
            (Role.kid, "Active"),
            (Role.visitor, "Active"),
            (Role.adult, "Invited")
        ]
        
        for (role, statusString) in additionalMembers {
            let status: MembershipStatus = statusString == "Active" ? .active : .invited
            var membership = Membership(
                familyId: familyId,
                userId: UUID(),
                role: role
            )
            membership.status = status
            memberships.append(membership)
        }
        
        // Ensure only one Parent Admin exists
        if currentUserRole != .parentAdmin {
            // Add a Parent Admin if current user is not one
            let adminMembership = Membership(
                familyId: familyId,
                userId: UUID(),
                role: .parentAdmin
            )
            memberships.insert(adminMembership, at: 0)
        }
        
        return memberships.filter { $0.status != .removed }
    }
    
    /// Generate mock user profiles for memberships
    private func generateMockUserProfiles(for memberships: [Membership]) -> [UUID: UserProfile] {
        var profiles: [UUID: UserProfile] = [:]
        
        let mockNames = [
            "Sarah Johnson",
            "Mike Garcia", 
            "Emma Chen",
            "Alex Smith",
            "Jordan Taylor",
            "Casey Morgan"
        ]
        
        for (index, membership) in memberships.enumerated() {
            let name = index < mockNames.count ? mockNames[index] : "Family Member \(index + 1)"
            let profile = UserProfile.mock(
                displayName: name,
                appleUserIdHash: "hash_\(membership.userId.uuidString.prefix(8))"
            )
            profiles[membership.userId] = profile
        }
        
        return profiles
    }
}