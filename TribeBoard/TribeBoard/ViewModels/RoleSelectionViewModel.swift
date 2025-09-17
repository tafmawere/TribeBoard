import SwiftUI
import Foundation

/// ViewModel for role selection with real validation and Parent Admin constraint checking
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
    
    // MARK: - Dependencies
    
    private let dataService: DataService
    private let cloudKitService: CloudKitService
    private let currentFamily: Family
    private let currentUser: UserProfile
    private var appState: AppState?
    
    // MARK: - Initialization
    
    init(family: Family, user: UserProfile, dataService: DataService, cloudKitService: CloudKitService) {
        self.currentFamily = family
        self.currentUser = user
        self.dataService = dataService
        self.cloudKitService = cloudKitService
        
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
    
    /// Update the user's role in the family with real backend integration
    func updateRole(_ role: Role) async {
        isUpdating = true
        clearError()
        
        do {
            // Get or create the user's membership
            let membership = try await getOrCreateMembership(role: role)
            
            // If membership already exists, update the role
            if membership.role != role {
                try dataService.updateMembershipRole(membership, to: role)
                
                // Sync to CloudKit
                try await cloudKitService.save(membership)
                
                // Mark as synced
                membership.needsSync = false
                membership.lastSyncDate = Date()
                try dataService.save()
            }
            
            // Success haptic feedback
            HapticManager.shared.success()
            
            // Show success toast
            ToastManager.shared.success("Role set to \(role.displayName)")
            
            // Update app state with membership
            appState?.setFamily(currentFamily, membership: membership)
            
            roleSelectionComplete = true
            
        } catch {
            if let dataError = error as? DataServiceError {
                showError(dataError.localizedDescription)
            } else if let cloudKitError = error as? CloudKitError {
                showError("Role updated locally. Sync failed: \(cloudKitError.localizedDescription)")
            } else {
                showError("Failed to update role: \(error.localizedDescription)")
            }
            HapticManager.shared.error()
        }
        
        isUpdating = false
    }
    
    /// Check if Parent Admin role is available in the current family with real backend integration
    func checkParentAdminAvailability() async {
        do {
            // Check local storage first
            let hasLocalParentAdmin = try dataService.familyHasParentAdmin(currentFamily)
            
            if hasLocalParentAdmin {
                canSelectParentAdmin = false
            } else {
                // Check CloudKit for the most up-to-date information
                let membershipRecords = try await cloudKitService.fetchActiveMemberships(forFamilyId: currentFamily.id.uuidString)
                
                let hasCloudKitParentAdmin = membershipRecords.contains { record in
                    guard let roleString = record[CKFieldName.membershipRole] as? String,
                          let role = Role(rawValue: roleString) else {
                        return false
                    }
                    return role == .parentAdmin
                }
                
                canSelectParentAdmin = !hasCloudKitParentAdmin
            }
            
            // If Parent Admin is taken and currently selected, default to Adult
            if !canSelectParentAdmin && selectedRole == .parentAdmin {
                selectedRole = .adult
            }
            
        } catch {
            // If check fails, default to not allowing Parent Admin selection for safety
            canSelectParentAdmin = false
            if selectedRole == .parentAdmin {
                selectedRole = .adult
            }
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
    
    /// Get or create membership for the current user
    private func getOrCreateMembership(role: Role) async throws -> Membership {
        // Check if user already has a membership in this family
        let existingMemberships = try dataService.fetchMemberships(forUser: currentUser)
        
        if let existingMembership = existingMemberships.first(where: { $0.family?.id == currentFamily.id && $0.status == .active }) {
            return existingMembership
        } else {
            // Create new membership
            return try dataService.createMembership(
                family: currentFamily,
                user: currentUser,
                role: role
            )
        }
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