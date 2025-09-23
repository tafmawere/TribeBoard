import SwiftUI
import Foundation

/// Mock ViewModel for role selection with instant responses and mock validation
@MainActor
class MockRoleSelectionViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Currently selected role
    @Published var selectedRole: Role = .adult
    
    /// Loading state for role update operations (simulated)
    @Published var isUpdating: Bool = false
    
    /// Error message for role selection issues
    @Published var errorMessage: String?
    
    /// Whether Parent Admin role can be selected (mock constraint checking)
    @Published var canSelectParentAdmin: Bool = true
    
    /// Success state after role selection
    @Published var roleSelectionComplete: Bool = false
    
    // MARK: - Dependencies
    
    private let currentFamily: Family
    private let currentUser: UserProfile
    private var appState: AppState?
    
    // MARK: - Mock Data
    
    private let mockScenario: MockRoleScenario
    
    enum MockRoleScenario {
        case normalFamily        // All roles available
        case parentAdminExists   // Parent Admin already taken
        case fullFamily         // Only visitor available
    }
    
    // MARK: - Initialization
    
    init(family: Family, user: UserProfile, scenario: MockRoleScenario = .normalFamily) {
        self.currentFamily = family
        self.currentUser = user
        self.mockScenario = scenario
        
        // Set initial constraints based on scenario
        setupMockConstraints()
    }
    
    /// Set the app state (called from view)
    func setAppState(_ appState: AppState) {
        self.appState = appState
    }
    
    // MARK: - Public Methods
    
    /// Set the selected role with mock validation
    func setRole(_ role: Role) async {
        selectedRole = role
        clearError()
        
        // Mock validation with instant feedback
        if role == .parentAdmin && !canSelectParentAdmin {
            showError("A Parent Admin already exists for this family. Selecting Adult role instead.")
            selectedRole = .adult
            HapticManager.shared.warning()
            return
        }
        
        // Provide instant visual feedback
        HapticManager.shared.selection()
        
        // Auto-proceed with role update for smooth UX
        await updateRole(selectedRole)
    }
    
    /// Update the user's role with mock instant success
    func updateRole(_ role: Role) async {
        isUpdating = true
        clearError()
        
        // Simulate brief loading for realism
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Mock success scenario
        do {
            // Create mock membership
            let mockMembership = createMockMembership(role: role)
            
            // Success haptic feedback
            HapticManager.shared.success()
            
            // Show success toast
            ToastManager.shared.success("Role set to \(role.displayName)")
            
            // Update app state with mock membership
            appState?.setFamily(currentFamily, membership: mockMembership)
            
            roleSelectionComplete = true
            
        } catch {
            // Mock error scenarios (rare)
            if shouldSimulateError() {
                showError("Failed to update role. Please try again.")
                HapticManager.shared.error()
            }
        }
        
        isUpdating = false
    }
    
    /// Get role card data for UI display with mock constraints
    func getRoleCardData() -> [RoleCardData] {
        return Role.allCases.map { role in
            RoleCardData(
                role: role,
                isSelected: role == selectedRole,
                isEnabled: isRoleEnabled(role),
                icon: getIconName(for: role),
                title: role.displayName,
                description: getEnhancedDescription(for: role)
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func setupMockConstraints() {
        switch mockScenario {
        case .normalFamily:
            canSelectParentAdmin = true
            
        case .parentAdminExists:
            canSelectParentAdmin = false
            if selectedRole == .parentAdmin {
                selectedRole = .adult
            }
            
        case .fullFamily:
            canSelectParentAdmin = false
            if selectedRole != .visitor {
                selectedRole = .visitor
            }
        }
    }
    
    private func isRoleEnabled(_ role: Role) -> Bool {
        switch mockScenario {
        case .normalFamily:
            return true
            
        case .parentAdminExists:
            return role != .parentAdmin
            
        case .fullFamily:
            return role == .visitor
        }
    }
    
    private func createMockMembership(role: Role) -> Membership {
        let membership = Membership(
            family: currentFamily,
            user: currentUser,
            role: role
        )
        
        // Set mock sync status
        membership.needsSync = false
        membership.lastSyncDate = Date()
        
        return membership
    }
    
    private func shouldSimulateError() -> Bool {
        // 5% chance of simulating an error for testing
        return Int.random(in: 1...100) <= 5
    }
    
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
    
    private func getEnhancedDescription(for role: Role) -> String {
        switch role {
        case .parentAdmin:
            return "Full access to manage family members, settings, and all features"
        case .adult:
            return "Standard family member with access to all family features and activities"
        case .kid:
            return "Age-appropriate access with parental controls and limited permissions"
        case .visitor:
            return "Temporary access with restricted permissions for family guests"
        }
    }
}

// MARK: - Mock Role Scenarios for Testing

extension MockRoleSelectionViewModel {
    
    /// Creates view model for different testing scenarios
    static func forScenario(_ scenario: MockRoleScenario, family: Family? = nil, user: UserProfile? = nil) -> MockRoleSelectionViewModel {
        let mockFamily = family ?? MockDataGenerator.mockMawereFamily().family
        let mockUser = user ?? MockDataGenerator.mockAuthenticatedUser()
        
        return MockRoleSelectionViewModel(
            family: mockFamily,
            user: mockUser,
            scenario: scenario
        )
    }
    
    /// Scenario descriptions for demo purposes
    static func scenarioDescription(_ scenario: MockRoleScenario) -> String {
        switch scenario {
        case .normalFamily:
            return "New family - all roles available"
        case .parentAdminExists:
            return "Parent Admin already exists - limited options"
        case .fullFamily:
            return "Family full - only visitor access available"
        }
    }
}