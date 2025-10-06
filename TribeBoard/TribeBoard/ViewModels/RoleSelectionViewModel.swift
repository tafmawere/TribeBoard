import SwiftUI
import Foundation

/// ViewModel for role selection with SwiftUI-compatible in-memory storage
@MainActor
class RoleSelectionViewModel: ObservableObject {
    
    // MARK: - Published Properties for SwiftUI Binding
    
    /// Currently selected role for SwiftUI binding
    @Published var selectedRole: InMemoryRole = .parent
    
    /// Loading state for SwiftUI progress indicators
    @Published var isUpdating: Bool = false
    
    /// Current error, if any
    @Published var currentError: FamilyJoinError?
    
    /// Whether Parent role can be selected (based on family constraints)
    @Published var canSelectParent: Bool = true
    
    /// Success state after role selection for SwiftUI navigation
    @Published var roleSelectionComplete: Bool = false
    
    /// Show error alert
    @Published var showErrorAlert: Bool = false
    
    /// Show success alert
    @Published var showSuccessAlert: Bool = false
    
    // MARK: - Dependencies
    
    private let dataManager: InMemoryFamilyDataManager
    private let currentFamily: InMemoryFamily
    private let currentUser: InMemoryUser
    private var appState: AppState?
    
    // MARK: - Initialization
    
    init(family: InMemoryFamily, user: InMemoryUser, dataManager: InMemoryFamilyDataManager? = nil) {
        self.currentFamily = family
        self.currentUser = user
        self.dataManager = dataManager ?? .shared
        
        // Check Parent role availability on initialization
        Task {
            await checkParentAvailability()
        }
    }
    
    /// Set the app state for SwiftUI navigation (called from view)
    func setAppState(_ appState: AppState) {
        self.appState = appState
    }
    
    // MARK: - Public Methods
    
    /// Set the selected role and validate constraints for SwiftUI binding
    func setRole(_ role: InMemoryRole) async {
        selectedRole = role
        clearError()
        
        // Validate role selection
        if role == .parent && !canSelectParent {
            showError(.alreadyMember) // Using existing error that makes sense
            selectedRole = .helper
            return
        }
        
        await updateRole(selectedRole)
    }
    
    /// Update the user's role in the family with SwiftUI-compatible in-memory storage
    func updateRole(_ role: InMemoryRole) async {
        isUpdating = true
        clearError()
        
        // Add user to family with selected role using in-memory data manager
        let success = dataManager.addMemberToFamily(
            familyId: currentFamily.id,
            user: currentUser,
            role: role
        )
        
        if success {
            // Success - role assignment completed
            roleSelectionComplete = true
            showSuccess()
            
            // Update app state for SwiftUI navigation
            appState?.setFamily(currentFamily)
            
            // Show success toast
            ToastManager.shared.success("Role assigned successfully!")
            
        } else {
            // Check if user is already a member and update their role
            let updateSuccess = dataManager.updateUserRole(
                userId: currentUser.id,
                familyId: currentFamily.id,
                newRole: role
            )
            
            if updateSuccess {
                roleSelectionComplete = true
                showSuccess()
                appState?.setFamily(currentFamily)
                ToastManager.shared.success("Role updated successfully!")
            } else {
                showError(.unknownError)
            }
        }
        
        isUpdating = false
    }
    
    /// Check if Parent role is available in the current family with SwiftUI-compatible in-memory storage
    func checkParentAvailability() async {
        // Get family members with user details from in-memory data manager
        let membersWithUsers = dataManager.getFamilyMembersWithUserDetails(familyId: currentFamily.id)
        
        // Check if any member already has the Parent role
        let hasParent = membersWithUsers.contains { memberWithUser in
            memberWithUser.member.role == .parent
        }
        
        canSelectParent = !hasParent
        
        // If Parent is taken and currently selected, default to Helper
        if !canSelectParent && selectedRole == .parent {
            selectedRole = .helper
        }
    }
    
    /// Get role card data for SwiftUI UI display
    func getRoleCardData() -> [InMemoryRoleCardData] {
        return InMemoryRole.allCases.map { role in
            InMemoryRoleCardData(
                role: role,
                isSelected: role == selectedRole,
                isEnabled: role == .parent ? canSelectParent : true,
                icon: role.iconName,
                title: role.displayName,
                description: role.description
            )
        }
    }
    
    // MARK: - Private Methods
    
    /// Show error alert with the specified error
    private func showError(_ error: FamilyJoinError) {
        currentError = error
        showErrorAlert = true
        HapticManager.shared.error()
        ToastManager.shared.error(error.localizedDescription)
    }
    
    /// Show success alert
    private func showSuccess() {
        showSuccessAlert = true
        HapticManager.shared.success()
    }
    
    /// Clear error message and alert state
    func clearError() {
        currentError = nil
        showErrorAlert = false
    }
    
    /// Get current error message for display
    var errorMessage: String? {
        return currentError?.localizedDescription
    }
}

// MARK: - In-Memory Role Card Data Model

/// Data model for role selection cards with SwiftUI compatibility
struct InMemoryRoleCardData: Identifiable {
    let id = UUID()
    let role: InMemoryRole
    let isSelected: Bool
    let isEnabled: Bool
    let icon: String
    let title: String
    let description: String
}