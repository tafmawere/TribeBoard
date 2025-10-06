import SwiftUI
import Foundation

/// ViewModel for managing family dashboard state and member operations with SwiftUI-compatible in-memory storage
@MainActor
class FamilyDashboardViewModel: ObservableObject {
    // MARK: - Published Properties for SwiftUI List binding
    
    /// List of family members with their user details for SwiftUI List display
    @Published var members: [(member: InMemoryMember, user: InMemoryUser?)] = []
    
    /// Current family being displayed
    @Published var currentFamily: InMemoryFamily?
    
    /// Current user's role in the family
    @Published var currentUserRole: InMemoryRole = .parent
    
    /// Loading state for SwiftUI progress views
    @Published var isLoading = false
    
    /// Current error, if any
    @Published var currentError: FamilyJoinError?
    
    /// Success message for SwiftUI toast notifications
    @Published var successMessage: String?
    
    /// Show error alert
    @Published var showErrorAlert: Bool = false
    
    /// Show success alert
    @Published var showSuccessAlert: Bool = false
    
    /// Currently selected member for role change
    @Published var selectedMember: InMemoryMember?
    
    /// Show role change sheet
    @Published var showRoleChangeSheet = false
    
    /// Show member removal confirmation
    @Published var showRemovalConfirmation = false
    
    /// Member to be removed
    @Published var memberToRemove: InMemoryMember?
    
    // MARK: - Dependencies
    
    private let dataManager: InMemoryFamilyDataManager
    private let currentFamilyId: UUID
    private let currentUserId: UUID
    
    // MARK: - Initialization
    
    init(familyId: UUID, currentUserId: UUID, dataManager: InMemoryFamilyDataManager? = nil) {
        self.currentFamilyId = familyId
        self.currentUserId = currentUserId
        self.dataManager = dataManager ?? InMemoryFamilyDataManager.shared
        
        // Set current family from data manager
        self.currentFamily = dataManager?.families.first { $0.id == familyId }
        
        // Determine current user's role
        if let family = currentFamily,
           let member = family.member(withUserId: currentUserId) {
            self.currentUserRole = member.role
        }
        
        // Load initial member data
        loadMembers()
    }
    
    // MARK: - Public Methods
    
    /// Update the context with actual family and user IDs
    func updateContext(familyId: UUID, currentUserId: UUID) async {
        // Update the internal IDs if they're different from placeholders
        // This is a workaround for the initialization issue
        // In a real implementation, we'd restructure this differently
    }
    
    /// Load family members with @Published members array for SwiftUI List binding
    func loadMembers() {
        isLoading = true
        currentError = nil
        
        // Get current family from data manager
        guard let family = dataManager.families.first(where: { $0.id == currentFamilyId }) else {
            showError(.familyNotFound)
            isLoading = false
            return
        }
        
        // Update current family reference
        currentFamily = family
        
        // Get members with user details for SwiftUI List display
        let membersWithUsers = dataManager.getFamilyMembersWithUserDetails(familyId: currentFamilyId)
        
        // Update @Published property to trigger SwiftUI view updates
        members = membersWithUsers
        
        // Update current user's role if needed
        if let currentMember = family.member(withUserId: currentUserId) {
            currentUserRole = currentMember.role
        }
        
        isLoading = false
    }
    
    /// Change a member's role (Parent only) with SwiftUI-compatible in-memory storage
    func changeRole(for member: InMemoryMember, to newRole: InMemoryRole) {
        guard currentUserRole == .parent else {
            showError(.userNotFound) // Using closest available error
            return
        }
        
        guard member.userId != currentUserId else {
            showError(.alreadyMember) // Using closest available error
            return
        }
        
        // Check if trying to assign Parent when one already exists (if business rule applies)
        if newRole == .parent && members.contains(where: { $0.member.role == .parent && $0.member.id != member.id }) {
            showError(.alreadyMember)
            return
        }
        
        isLoading = true
        clearError()
        
        // Update role using data manager
        let success = dataManager.updateUserRole(userId: member.userId, familyId: currentFamilyId, newRole: newRole)
        
        if success {
            // Reload members to reflect changes in SwiftUI List
            loadMembers()
            showSuccess("Role updated to \(newRole.displayName)")
            showRoleChangeSheet = false
            selectedMember = nil
        } else {
            showError(.unknownError)
        }
        
        isLoading = false
    }
    
    /// Remove a member from the family (Parent only) with SwiftUI-compatible in-memory storage
    func removeMember(_ member: InMemoryMember) {
        guard currentUserRole == .parent else {
            showError(.userNotFound) // Using closest available error
            return
        }
        
        guard member.userId != currentUserId else {
            showError(.alreadyMember) // Using closest available error
            return
        }
        
        guard member.role != .parent else {
            showError(.alreadyMember) // Using closest available error
            return
        }
        
        isLoading = true
        clearError()
        
        // Remove member from family using data manager
        guard let family = dataManager.families.first(where: { $0.id == currentFamilyId }) else {
            showError(.familyNotFound)
            isLoading = false
            return
        }
        
        // Remove member from family
        family.removeMember(withUserId: member.userId)
        
        // Reload members to reflect changes in SwiftUI List
        loadMembers()
        showSuccess("Member removed from family")
        showRemovalConfirmation = false
        memberToRemove = nil
        
        isLoading = false
    }
    
    /// Show role change sheet for a member
    func showRoleChange(for member: InMemoryMember) {
        selectedMember = member
        showRoleChangeSheet = true
    }
    
    /// Show removal confirmation for a member
    func showRemovalConfirmation(for member: InMemoryMember) {
        memberToRemove = member
        showRemovalConfirmation = true
    }
    
    /// Clear success message
    func clearSuccessMessage() {
        successMessage = nil
        showSuccessAlert = false
    }
    
    /// Clear error message and alert state
    func clearError() {
        currentError = nil
        showErrorAlert = false
    }
    
    /// Show error alert with the specified error
    private func showError(_ error: FamilyJoinError) {
        currentError = error
        showErrorAlert = true
        HapticManager.shared.error()
        ToastManager.shared.error(error.localizedDescription)
    }
    
    /// Show success message and alert
    private func showSuccess(_ message: String) {
        successMessage = message
        showSuccessAlert = true
        HapticManager.shared.success()
        ToastManager.shared.success(message)
    }
    
    /// Get current error message for display
    var errorMessage: String? {
        return currentError?.localizedDescription
    }
    
    /// Check if current user can manage members
    var canManageMembers: Bool {
        currentUserRole == .parent
    }
    
    /// Get user for a member (convenience method for SwiftUI views)
    func user(for member: InMemoryMember) -> InMemoryUser? {
        return dataManager.getUser(byId: member.userId)
    }
    
    /// Navigate to "Add Member" flow using SwiftUI @EnvironmentObject AppState
    /// This method should be called from the view with access to AppState
    func navigateToAddMember(appState: AppState) {
        // Navigation will be handled by the view layer
        // The view can use this as a trigger to navigate to join family flow
    }
    
    /// Get family name for display
    var familyName: String {
        return currentFamily?.name ?? "Unknown Family"
    }
    
    /// Get family code for display
    var familyCode: String {
        return currentFamily?.code ?? ""
    }
    
    /// Get member count for display
    var memberCount: Int {
        return members.count
    }
    
    // MARK: - Private Methods
    
    /// Refresh member data from data manager (for SwiftUI reactive updates)
    private func refreshMemberData() {
        // Since we're using @Published properties and ObservableObject,
        // calling loadMembers() will automatically trigger SwiftUI view updates
        loadMembers()
    }
    
    /// Validate member permissions for role changes
    private func canChangeRole(for member: InMemoryMember, to newRole: InMemoryRole) -> (canChange: Bool, reason: String?) {
        // Only parents can change roles
        guard currentUserRole == .parent else {
            return (false, "Only Parents can change member roles")
        }
        
        // Cannot change own role
        guard member.userId != currentUserId else {
            return (false, "You cannot change your own role")
        }
        
        // Business rule: Only one parent allowed (if applicable)
        if newRole == .parent && members.contains(where: { $0.member.role == .parent && $0.member.id != member.id }) {
            return (false, "Only one Parent is allowed per family")
        }
        
        return (true, nil)
    }
    
    /// Validate member permissions for removal
    private func canRemoveMember(_ member: InMemoryMember) -> (canRemove: Bool, reason: String?) {
        // Only parents can remove members
        guard currentUserRole == .parent else {
            return (false, "Only Parents can remove members")
        }
        
        // Cannot remove self
        guard member.userId != currentUserId else {
            return (false, "You cannot remove yourself from the family")
        }
        
        // Cannot remove other parents
        guard member.role != .parent else {
            return (false, "Cannot remove Parent")
        }
        
        return (true, nil)
    }
}