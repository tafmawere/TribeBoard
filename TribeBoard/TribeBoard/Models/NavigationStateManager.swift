import SwiftUI
import Foundation

/// Manages navigation state and provides safe navigation methods with error handling
@MainActor
class NavigationStateManager: ObservableObject {
    // MARK: - Published Properties
    
    /// Navigation path for programmatic navigation
    @Published var navigationPath = NavigationPath()
    
    /// Current route being displayed
    @Published var currentRoute: SchoolRunRoute?
    
    /// Navigation error state
    @Published var navigationError: NavigationError?
    
    /// Loading state for navigation operations
    @Published var isNavigating: Bool = false
    
    // MARK: - Private Properties
    
    /// Maximum navigation stack depth to prevent infinite loops
    private let maxStackDepth: Int = 10
    
    /// Navigation history for recovery purposes
    private var navigationHistory: [SchoolRunRoute] = []
    
    /// Weak reference to AppState for validation
    private weak var appState: AppState?
    
    // MARK: - Initialization
    
    init(appState: AppState? = nil) {
        self.appState = appState
    }
    
    // MARK: - Safe Navigation Methods
    
    /// Safely navigate to a school run route with validation and error handling
    func navigate(to route: SchoolRunRoute) {
        guard validateNavigationPreconditions() else {
            handleNavigationError(.invalidAppState)
            return
        }
        
        guard navigationPath.count < maxStackDepth else {
            handleNavigationError(.navigationStackOverflow)
            return
        }
        
        isNavigating = true
        
        do {
            // Validate the route before navigation
            try validateRoute(route)
            
            // Add to navigation history
            if let currentRoute = currentRoute {
                navigationHistory.append(currentRoute)
            }
            
            // Perform navigation
            navigationPath.append(route)
            currentRoute = route
            
            // Clear any previous errors
            navigationError = nil
            
        } catch let error as NavigationError {
            handleNavigationError(error)
        } catch {
            handleNavigationError(.unknownError(error.localizedDescription))
        }
        
        isNavigating = false
    }
    
    /// Safely navigate back with error handling
    func navigateBack() {
        guard !navigationPath.isEmpty else {
            handleNavigationError(.cannotNavigateBack)
            return
        }
        
        isNavigating = true
        
        // Remove last route from path
        navigationPath.removeLast()
        
        // Update current route
        if let lastRoute = navigationHistory.popLast() {
            currentRoute = lastRoute
        } else {
            currentRoute = .dashboard // Default fallback
        }
        
        navigationError = nil
        isNavigating = false
    }
    
    /// Reset navigation to root with safe fallback
    func resetToRoot() {
        isNavigating = true
        
        navigationPath = NavigationPath()
        currentRoute = .dashboard
        navigationHistory.removeAll()
        navigationError = nil
        
        isNavigating = false
    }
    
    /// Navigate to a specific route and reset the stack
    func navigateAndReset(to route: SchoolRunRoute) {
        resetToRoot()
        navigate(to: route)
    }
    
    // MARK: - Navigation Validation
    
    /// Validate navigation preconditions
    private func validateNavigationPreconditions() -> Bool {
        guard let appState = appState else {
            return false
        }
        
        // Check if user is authenticated
        guard appState.isAuthenticated else {
            return false
        }
        
        // Check if user has a family
        guard appState.currentFamily != nil else {
            return false
        }
        
        return true
    }
    
    /// Validate a specific route before navigation
    private func validateRoute(_ route: SchoolRunRoute) throws {
        switch route {
        case .dashboard:
            // Dashboard is always accessible
            break
            
        case .scheduleNew:
            // Check if user has permission to create runs
            guard let appState = appState,
                  let membership = appState.currentMembership,
                  membership.role.canCreateSchoolRuns else {
                throw NavigationError.insufficientPermissions
            }
            
        case .scheduledList:
            // List is accessible to all family members
            break
            
        case .runDetail(let run):
            // Validate that the run exists and user has access
            try validateRunAccess(run)
            
        case .runExecution(let run):
            // Validate that the run exists and user can execute it
            try validateRunAccess(run)
            guard let appState = appState,
                  let membership = appState.currentMembership,
                  membership.role.canExecuteSchoolRuns else {
                throw NavigationError.insufficientPermissions
            }
        }
    }
    
    /// Validate user access to a specific run
    private func validateRunAccess(_ run: ScheduledSchoolRun) throws {
        guard let appState = appState,
              let _ = appState.currentFamily else {
            throw NavigationError.invalidAppState
        }
        
        // In a real app, this would check if the run belongs to the current family
        // For now, we'll assume all runs are accessible within the family
    }
    
    // MARK: - Error Handling
    
    /// Handle navigation errors with appropriate recovery actions
    private func handleNavigationError(_ error: NavigationError) {
        navigationError = error
        
        // Log error for debugging
        print("Navigation Error: \(error.localizedDescription)")
        
        // Attempt recovery based on error type
        switch error {
        case .invalidAppState:
            // Reset to a safe state
            resetToRoot()
            
        case .insufficientPermissions:
            // Navigate back to a safe location
            if !navigationHistory.isEmpty {
                navigateBack()
            } else {
                resetToRoot()
            }
            
        case .navigationStackOverflow:
            // Reset navigation to prevent further issues
            resetToRoot()
            
        case .cannotNavigateBack:
            // Already at root, no action needed
            break
            
        case .routeValidationFailed:
            // Navigate back to previous safe location
            if !navigationHistory.isEmpty {
                navigateBack()
            } else {
                resetToRoot()
            }
            
        case .unknownError:
            // Reset to safe state for unknown errors
            resetToRoot()
        }
    }
    
    // MARK: - Recovery Methods
    
    /// Attempt to recover from navigation errors
    func attemptRecovery() {
        guard let error = navigationError else { return }
        
        switch error {
        case .invalidAppState:
            // Try to re-validate app state
            if validateNavigationPreconditions() {
                navigationError = nil
            }
            
        case .insufficientPermissions:
            // Navigate to a safe location
            resetToRoot()
            navigationError = nil
            
        case .navigationStackOverflow:
            // Clear the stack
            resetToRoot()
            navigationError = nil
            
        case .cannotNavigateBack:
            // Clear the error, user is already at root
            navigationError = nil
            
        case .routeValidationFailed:
            // Navigate to dashboard
            resetToRoot()
            navigationError = nil
            
        case .unknownError:
            // Reset everything
            resetToRoot()
            navigationError = nil
        }
    }
    
    /// Clear navigation error
    func clearError() {
        navigationError = nil
    }
    
    // MARK: - State Management
    
    /// Set the AppState reference for validation
    func setAppState(_ appState: AppState) {
        self.appState = appState
    }
    
    /// Get current navigation depth
    var navigationDepth: Int {
        navigationPath.count
    }
    
    /// Check if navigation is at root
    var isAtRoot: Bool {
        navigationPath.isEmpty
    }
    
    /// Check if can navigate back
    var canNavigateBack: Bool {
        !navigationPath.isEmpty
    }
}

// MARK: - Navigation Error Types

/// Errors that can occur during navigation
enum NavigationError: Error, LocalizedError, Equatable {
    case invalidAppState
    case insufficientPermissions
    case navigationStackOverflow
    case cannotNavigateBack
    case routeValidationFailed(String)
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidAppState:
            return "App state is invalid or missing required data"
        case .insufficientPermissions:
            return "You don't have permission to access this feature"
        case .navigationStackOverflow:
            return "Navigation stack is too deep"
        case .cannotNavigateBack:
            return "Cannot navigate back from current location"
        case .routeValidationFailed(let details):
            return "Route validation failed: \(details)"
        case .unknownError(let details):
            return "An unknown navigation error occurred: \(details)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidAppState:
            return "Please restart the app or sign in again"
        case .insufficientPermissions:
            return "Contact your family admin for access"
        case .navigationStackOverflow:
            return "Navigation has been reset to prevent issues"
        case .cannotNavigateBack:
            return "You are already at the main screen"
        case .routeValidationFailed:
            return "Please try navigating to a different section"
        case .unknownError:
            return "Please try again or restart the app"
        }
    }
}

// MARK: - Role Extensions for Navigation Permissions

extension Role {
    /// Check if role can create school runs
    var canCreateSchoolRuns: Bool {
        switch self {
        case .parentAdmin, .adult:
            return true
        case .kid, .visitor:
            return false
        }
    }
    
    /// Check if role can execute school runs
    var canExecuteSchoolRuns: Bool {
        switch self {
        case .parentAdmin, .adult:
            return true
        case .kid, .visitor:
            return false
        }
    }
}