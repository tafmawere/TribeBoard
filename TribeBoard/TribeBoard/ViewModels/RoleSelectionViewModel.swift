import SwiftUI
import Foundation

/// ViewModel for role selection with mock validation and Parent Admin constraint checking
@MainActor
class RoleSelectionViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Currently selected role
    @Published var selectedRole: Role = .adult
    
    /// Loading state for role update operations
    @Published var isUpdating: Bool = false
    
    /// Error message for role selection issues
    @Published var errorMessage: String?
    
    /// Whether Parent Admin role can be selected (based on family constraints)
    @Published var canSelectParentAdmin: Bool = true
    
    /// Success state after role selection
    @Published var roleSelectionComplete: Bool = false
    
    // MARK: - Private Properties
    
    private var appState: AppState?
    private let currentFamily: Family
    private let currentUser: UserProfile
    
    // MARK: - Initialization
    
    init(family: Family, user: UserProfile) {
        self.currentFamily = family
        self.currentUser = user
        
        // Check Parent Admin availability on initialization
        Task {
            await checkParentAdminAvailability()
        }
    }
    
    /// Set the app state (called from view)
    func setAppState(_ appState: AppState) {
        self.appState = appState
    }
    
    // MARK: - Public Methods
    
    /// Set the selected role and validate constraints
    func setRole(_ role: Role) async {
        selectedRole = role
        clearError()
        
        // Validate role selection
        if role == .parentAdmin && !canSelectParentAdmin {
            showError("A Parent Admin already exists for this family. Selecting Adult role instead.")
            selectedRole = .adult
            HapticManager.shared.warning()
            return
        }
        
        await updateRole(selectedRole)
    }
    
    /// Update the user's role in the family
    func updateRole(_ role: Role) async {
        isUpdating = true
        clearError()
        
        do {
            // Simulate API delay
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            
            // Mock role update logic
            let membership = Membership(
                familyId: currentFamily.id,
                userId: currentUser.id,
                role: role
            )
            
            // Success haptic feedback
            HapticManager.shared.success()
            
            // Show success toast
            ToastManager.shared.success("Role set to \(role.displayName)")
            
            // Update app state with new membership
            appState?.setFamily(currentFamily, membership: membership)
            
            roleSelectionComplete = true
            
        } catch {
            showError("Failed to update role. Please try again.")
            HapticManager.shared.error()
        }
        
        isUpdating = false
    }
    
    /// Check if Parent Admin role is available in the current family
    func checkParentAdminAvailability() async {
        // Mock check for existing Parent Admin
        // In a real implementation, this would query the backend
        
        // Simulate API delay
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Mock scenario: 30% chance that Parent Admin is already taken
        let isParentAdminTaken = Bool.random() && Double.random(in: 0...1) < 0.3
        
        canSelectParentAdmin = !isParentAdminTaken
        
        // If Parent Admin is taken and currently selected, default to Adult
        if !canSelectParentAdmin && selectedRole == .parentAdmin {
            selectedRole = .adult
        }
    }
    
    /// Get role card data for UI display
    func getRoleCardData() -> [RoleCardData] {
        return Role.allCases.map { role in
            RoleCardData(
                role: role,
                isSelected: role == selectedRole,
                isEnabled: role == .parentAdmin ? canSelectParentAdmin : true,
                icon: getIconName(for: role),
                title: role.displayName,
                description: role.description
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func showError(_ message: String) {
        errorMessage = message
    }
    
    private func clearError() {
        errorMessage = nil
    }
    
    private func getIconName(for role: Role) -> String {
        switch role {
        case .parentAdmin:
            return "crown.fill"
        case .adult:
            return "person.fill"
        case .kid:
            return "figure.child"
        case .visitor:
            return "person.badge.clock.fill"
        }
    }
}

// MARK: - Role Card Data Model

/// Data model for role selection cards
struct RoleCardData: Identifiable {
    let id = UUID()
    let role: Role
    let isSelected: Bool
    let isEnabled: Bool
    let icon: String
    let title: String
    let description: String
}