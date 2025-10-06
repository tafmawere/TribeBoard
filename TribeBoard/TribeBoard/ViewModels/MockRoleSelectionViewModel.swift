import SwiftUI
import Foundation

/// Mock ViewModel for role selection with instant responses and mock validation
@MainActor
class MockRoleSelectionViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Currently selected role
    @Published var selectedRole: InMemoryRole = .helper
    
    /// Loading state for role update operations (simulated)
    @Published var isUpdating: Bool = false
    
    /// Error message for role selection issues
    @Published var errorMessage: String?
    
    /// Whether Parent role can be selected (mock constraint checking)
    @Published var canSelectParent: Bool = true
    
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
    func setRole(_ role: InMemoryRole) async {
        selectedRole = role
        clearError()
        
        // Mock validation with instant feedback
        if role == .parent && !canSelectParent {
            showError("A Parent already exists for this family. Selecting Helper role instead.")
            selectedRole = .helper
            return
        }
        
        // Auto-proceed with role update for smooth UX
        await updateRole(selectedRole)
    }
    
    /// Update the user's role with mock instant success
    func updateRole(_ role: InMemoryRole) async {
        isUpdating = true
        clearError()
        
        // Simulate brief loading for realism
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Mock success scenario
        // Create mock membership
        let mockMembership = createMockMembership(role: role)
        
        // Success haptic feedback
        HapticManager.shared.success()
        
        // Show success toast
        ToastManager.shared.success("Role set to \(role.displayName)")
        
        // Update app state with mock membership
        appState?.setFamily(currentFamily, membership: mockMembership)
        
        roleSelectionComplete = true
        
        isUpdating = false
    }
    
    /// Get role card data for UI display with mock constraints
    func getRoleCardData() -> [InMemoryRoleCardData] {
        return InMemoryRole.allCases.map { role in
            InMemoryRoleCardData(
                role: role,
                isSelected: role == selectedRole,
                isEnabled: isRoleEnabled(role),
                icon: role.iconName,
                title: role.displayName,
                description: getEnhancedDescription(for: role)
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func setupMockConstraints() {
        switch mockScenario {
        case .normalFamily:
            canSelectParent = true
            
        case .parentAdminExists:
            canSelectParent = false
            if selectedRole == .parent {
                selectedRole = .helper
            }
            
        case .fullFamily:
            canSelectParent = false
            if selectedRole != .helper {
                selectedRole = .helper
            }
        }
    }
    
    private func isRoleEnabled(_ role: InMemoryRole) -> Bool {
        switch mockScenario {
        case .normalFamily:
            return true
            
        case .parentAdminExists:
            return role != .parent
            
        case .fullFamily:
            return role == .helper
        }
    }
    
    private func createMockMembership(role: InMemoryRole) -> Membership {
        let membership = Membership(
            family: currentFamily,
            user: currentUser,
            role: Role.adult // Convert to old Role type for compatibility
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
    

    
    private func getEnhancedDescription(for role: InMemoryRole) -> String {
        switch role {
        case .parent:
            return "Primary caregiver with full family management access"
        case .child:
            return "Family member with age-appropriate access and features"
        case .guardian:
            return "Trusted adult with supervisory responsibilities"
        case .helper:
            return "Support person who assists with family activities"
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