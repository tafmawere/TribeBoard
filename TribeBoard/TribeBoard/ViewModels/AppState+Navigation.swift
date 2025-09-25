import SwiftUI
import Foundation

// MARK: - AppState Navigation Extension

extension AppState {
    
    // MARK: - Navigation State Manager
    
    /// Navigation state manager for safe navigation operations
    private static var navigationStateManager: NavigationStateManager?
    
    /// Get or create navigation state manager
    func getNavigationStateManager() -> NavigationStateManager {
        if let manager = AppState.navigationStateManager {
            return manager
        }
        
        let manager = NavigationStateManager(appState: self)
        AppState.navigationStateManager = manager
        return manager
    }
    
    // MARK: - Safe Navigation Methods
    
    /// Safely navigate to a school run route with validation and error handling
    func safeNavigate(to route: SchoolRunRoute) {
        let manager = getNavigationStateManager()
        manager.navigate(to: route)
        
        // Update AppState navigation path to stay in sync
        navigationPath = manager.navigationPath
    }
    
    /// Safely navigate back with error handling
    func safeNavigateBack() {
        let manager = getNavigationStateManager()
        manager.navigateBack()
        
        // Update AppState navigation path to stay in sync
        navigationPath = manager.navigationPath
    }
    
    /// Reset navigation to root with safe fallback
    func safeResetNavigation() {
        let manager = getNavigationStateManager()
        manager.resetToRoot()
        
        // Update AppState navigation path to stay in sync
        navigationPath = manager.navigationPath
    }
    
    /// Navigate to a specific route and reset the stack
    func safeNavigateAndReset(to route: SchoolRunRoute) {
        let manager = getNavigationStateManager()
        manager.navigateAndReset(to: route)
        
        // Update AppState navigation path to stay in sync
        navigationPath = manager.navigationPath
    }
    
    // MARK: - Navigation Validation
    
    /// Validate if navigation is safe based on current app state
    func validateNavigationState() -> NavigationValidationResult {
        // Check authentication
        guard isAuthenticated else {
            return .invalid(.notAuthenticated)
        }
        
        // Check family membership
        guard currentFamily != nil else {
            return .invalid(.noFamilyMembership)
        }
        
        // Check user profile
        guard currentUser != nil else {
            return .invalid(.noUserProfile)
        }
        
        // Check membership role
        guard currentMembership != nil else {
            return .invalid(.noMembershipRole)
        }
        
        return .valid
    }
    
    /// Check if user can access a specific school run route
    func canAccess(route: SchoolRunRoute) -> Bool {
        let validationResult = validateNavigationState()
        guard case .valid = validationResult else {
            return false
        }
        
        guard let membership = currentMembership else {
            return false
        }
        
        switch route {
        case .dashboard, .scheduledList:
            // Basic routes accessible to all family members
            return true
            
        case .scheduleNew:
            // Only parents can create new runs
            return membership.role.canCreateSchoolRuns
            
        case .runDetail:
            // All family members can view run details
            return true
            
        case .runExecution:
            // Only parents can execute runs
            return membership.role.canExecuteSchoolRuns
        }
    }
    
    // MARK: - Navigation Error Handling
    
    /// Handle navigation errors with appropriate user feedback
    func handleNavigationError(_ error: NavigationError) {
        // Show error message to user
        showError(error.localizedDescription)
        
        // Log error for debugging
        print("Navigation Error in AppState: \(error)")
        
        // Attempt automatic recovery based on error type
        switch error {
        case .invalidAppState:
            // Reset to onboarding if app state is invalid
            if !isAuthenticated {
                currentFlow = .onboarding
            } else if currentFamily == nil {
                currentFlow = .familySelection
            }
            
        case .insufficientPermissions:
            // Navigate to dashboard for insufficient permissions
            currentFlow = .familyDashboard
            selectedNavigationTab = .dashboard
            
        case .navigationStackOverflow, .routeValidationFailed, .unknownError:
            // Reset navigation for serious errors
            safeResetNavigation()
            
        case .cannotNavigateBack:
            // No action needed, user is already at root
            break
        }
    }
    
    /// Attempt to recover from navigation errors
    func attemptNavigationRecovery() {
        let manager = getNavigationStateManager()
        manager.attemptRecovery()
        
        // Sync navigation path
        navigationPath = manager.navigationPath
        
        // Clear any error messages
        if manager.navigationError == nil {
            clearError()
        }
    }
    
    // MARK: - Enhanced Tab Navigation with Safety
    
    /// Safely select a navigation tab with validation
    func safeSelectTab(_ tab: NavigationTab) {
        // Validate navigation state first
        let validationResult = validateNavigationState()
        guard case .valid = validationResult else {
            handleNavigationValidationFailure(validationResult)
            return
        }
        
        // Update selected tab
        selectedNavigationTab = tab
        
        // Reset navigation path for clean navigation
        safeResetNavigation()
        
        // Handle specific navigation logic for each tab
        switch tab {
        case .dashboard:
            // Ensure we're in the family dashboard flow
            if currentFlow != .familyDashboard {
                currentFlow = .familyDashboard
            }
            
        case .calendar:
            // Calendar navigation handled by MainNavigationView
            break
            
        case .schoolRun:
            // Navigate to school run dashboard safely
            safeNavigate(to: .dashboard)
            
        case .tasks:
            // Tasks navigation handled by MainNavigationView
            break
            
        case .messages:
            // Messages navigation handled by MainNavigationView
            break
        }
    }
    
    /// Handle navigation validation failures
    private func handleNavigationValidationFailure(_ result: NavigationValidationResult) {
        guard case .invalid(let reason) = result else { return }
        
        switch reason {
        case .notAuthenticated:
            // Redirect to onboarding
            currentFlow = .onboarding
            showError("Please sign in to continue")
            
        case .noFamilyMembership:
            // Redirect to family selection
            currentFlow = .familySelection
            showError("Please join or create a family to continue")
            
        case .noUserProfile:
            // Sign out and redirect to onboarding
            Task {
                await signOut()
            }
            showError("User profile is missing. Please sign in again")
            
        case .noMembershipRole:
            // Redirect to role selection
            currentFlow = .roleSelection
            showError("Please select your role in the family")
        }
    }
    
    // MARK: - Navigation State Synchronization
    
    /// Synchronize navigation state with the navigation manager
    func syncNavigationState() {
        let manager = getNavigationStateManager()
        navigationPath = manager.navigationPath
        
        // Handle any navigation errors
        if let error = manager.navigationError {
            handleNavigationError(error)
        }
    }
    
    /// Get current navigation error if any
    func getCurrentNavigationError() -> NavigationError? {
        let manager = getNavigationStateManager()
        return manager.navigationError
    }
    
    /// Clear navigation errors
    func clearNavigationError() {
        let manager = getNavigationStateManager()
        manager.clearError()
    }
    
    // MARK: - Navigation State Queries
    
    /// Check if navigation is currently in progress
    func isNavigating() -> Bool {
        let manager = getNavigationStateManager()
        return manager.isNavigating
    }
    
    /// Get current navigation depth
    func getNavigationDepth() -> Int {
        let manager = getNavigationStateManager()
        return manager.navigationDepth
    }
    
    /// Check if at navigation root
    func isAtNavigationRoot() -> Bool {
        let manager = getNavigationStateManager()
        return manager.isAtRoot
    }
    
    /// Check if can navigate back
    func canNavigateBack() -> Bool {
        let manager = getNavigationStateManager()
        return manager.canNavigateBack
    }
}

// MARK: - Navigation Validation Types

/// Result of navigation validation
enum NavigationValidationResult {
    case valid
    case invalid(NavigationValidationFailureReason)
}

/// Reasons why navigation validation might fail
enum NavigationValidationFailureReason {
    case notAuthenticated
    case noFamilyMembership
    case noUserProfile
    case noMembershipRole
    
    var localizedDescription: String {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .noFamilyMembership:
            return "User is not a member of any family"
        case .noUserProfile:
            return "User profile is missing"
        case .noMembershipRole:
            return "User membership role is not defined"
        }
    }
}