import SwiftUI
import Foundation

/// Global app state management for navigation and authentication
@MainActor
class AppState: ObservableObject {
    // MARK: - Published Properties
    
    /// Current authentication state
    @Published var isAuthenticated: Bool = false
    
    /// Current user profile (nil if not authenticated)
    @Published var currentUser: UserProfile?
    
    /// Current family membership (nil if not in a family)
    @Published var currentMembership: Membership?
    
    /// Current family (nil if not in a family)
    @Published var currentFamily: Family?
    
    /// Loading state for async operations
    @Published var isLoading: Bool = false
    
    /// Global error message
    @Published var errorMessage: String?
    
    // MARK: - Navigation State
    
    /// Current app flow state
    @Published var currentFlow: AppFlow = .onboarding
    
    /// Navigation path for deep linking and programmatic navigation
    @Published var navigationPath = NavigationPath()
    
    // MARK: - Initialization
    
    init() {
        // Check for existing authentication on app launch
        checkAuthenticationState()
    }
    
    // MARK: - Authentication Methods
    
    /// Check if user is already authenticated (mock implementation)
    private func checkAuthenticationState() {
        // TODO: Replace with real authentication check in later tasks
        // For now, assume user is not authenticated
        isAuthenticated = false
        currentFlow = .onboarding
    }
    
    /// Sign in user (mock implementation)
    func signIn(user: UserProfile) {
        currentUser = user
        isAuthenticated = true
        
        // Check if user has a family
        if let membership = getMockMembership(for: user.id) {
            currentMembership = membership
            currentFamily = getMockFamily(for: membership.familyId)
            currentFlow = .familyDashboard
        } else {
            currentFlow = .familySelection
        }
    }
    
    /// Sign out user
    func signOut() {
        currentUser = nil
        currentMembership = nil
        currentFamily = nil
        isAuthenticated = false
        currentFlow = .onboarding
        navigationPath = NavigationPath()
    }
    
    // MARK: - Family Management
    
    /// Join or create a family
    func setFamily(_ family: Family, membership: Membership) {
        currentFamily = family
        currentMembership = membership
        currentFlow = .familyDashboard
    }
    
    /// Leave current family
    func leaveFamily() {
        currentFamily = nil
        currentMembership = nil
        currentFlow = .familySelection
    }
    
    // MARK: - Navigation Methods
    
    /// Navigate to a specific flow
    func navigateTo(_ flow: AppFlow) {
        currentFlow = flow
    }
    
    /// Reset navigation to root
    func resetNavigation() {
        navigationPath = NavigationPath()
    }
    
    // MARK: - Error Handling
    
    /// Show error message
    func showError(_ message: String) {
        errorMessage = message
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Mock Data Helpers (TODO: Replace with real data in later tasks)
    
    private func getMockMembership(for userId: UUID) -> Membership? {
        // Mock: Return nil to simulate new user without family
        return nil
    }
    
    private func getMockFamily(for familyId: UUID) -> Family? {
        // Mock: Return sample family
        return Family.sampleFamilies.first
    }
}

// MARK: - App Flow Enum

/// Represents the main navigation flows in the app
enum AppFlow: String, CaseIterable {
    case onboarding = "onboarding"
    case familySelection = "family_selection"
    case createFamily = "create_family"
    case joinFamily = "join_family"
    case roleSelection = "role_selection"
    case familyDashboard = "family_dashboard"
    
    var displayName: String {
        switch self {
        case .onboarding:
            return "Onboarding"
        case .familySelection:
            return "Family Selection"
        case .createFamily:
            return "Create Family"
        case .joinFamily:
            return "Join Family"
        case .roleSelection:
            return "Role Selection"
        case .familyDashboard:
            return "Family Dashboard"
        }
    }
}