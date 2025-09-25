import SwiftUI
import Foundation

/// Factory for creating AppState instances with safe defaults
/// Used by SafeEnvironmentObject for fallback scenarios
@MainActor
struct AppStateFactory {
    
    // MARK: - Factory Methods
    
    /// Create a fallback AppState with safe defaults for when environment object is missing
    /// - Returns: AppState instance with minimal safe configuration
    static func createFallbackAppState() -> AppState {
        let appState = AppState()
        
        // Configure with safe defaults
        appState.isAuthenticated = false
        appState.currentUser = nil
        appState.currentFamily = nil
        appState.currentMembership = nil
        appState.currentFlow = .onboarding
        appState.isLoading = false
        appState.errorMessage = nil
        appState.selectedNavigationTab = .dashboard
        appState.navigationPath = NavigationPath()
        
        // Log that we're using a fallback
        print("🔄 AppStateFactory: Created fallback AppState for missing environment object")
        
        return appState
    }
    
    /// Create a mock AppState for previews with realistic data
    /// - Returns: AppState instance configured for SwiftUI previews
    static func createPreviewAppState() -> AppState {
        let appState = AppState()
        
        // Configure with preview-friendly data
        appState.isAuthenticated = true
        appState.currentUser = createMockUser()
        appState.currentFamily = createMockFamily()
        appState.currentMembership = createMockMembership()
        appState.currentFlow = .familyDashboard
        appState.isLoading = false
        appState.errorMessage = nil
        appState.selectedNavigationTab = .dashboard
        appState.navigationPath = NavigationPath()
        
        return appState
    }
    
    /// Create an AppState for testing scenarios
    /// - Parameter scenario: The test scenario to configure
    /// - Returns: AppState instance configured for the test scenario
    static func createTestAppState(scenario: TestScenario = .authenticated) -> AppState {
        let appState = AppState()
        
        switch scenario {
        case .unauthenticated:
            appState.isAuthenticated = false
            appState.currentUser = nil
            appState.currentFamily = nil
            appState.currentMembership = nil
            appState.currentFlow = .onboarding
            
        case .authenticated:
            appState.isAuthenticated = true
            appState.currentUser = createMockUser()
            appState.currentFamily = createMockFamily()
            appState.currentMembership = createMockMembership()
            appState.currentFlow = .familyDashboard
            
        case .loading:
            appState.isAuthenticated = false
            appState.isLoading = true
            appState.currentFlow = .onboarding
            
        case .error:
            appState.isAuthenticated = false
            appState.errorMessage = "Test error message"
            appState.currentFlow = .onboarding
            
        case .familySelection:
            appState.isAuthenticated = true
            appState.currentUser = createMockUser()
            appState.currentFamily = nil
            appState.currentMembership = nil
            appState.currentFlow = .familySelection
        }
        
        appState.selectedNavigationTab = .dashboard
        appState.navigationPath = NavigationPath()
        
        return appState
    }
    
    /// Create an AppState with specific user role for testing
    /// - Parameter role: The user role to configure
    /// - Returns: AppState instance configured with the specified role
    static func createTestAppState(withRole role: Role) -> AppState {
        let appState = createTestAppState(scenario: .authenticated)
        
        // Update membership with specific role
        if let membership = appState.currentMembership,
           let family = membership.family,
           let user = membership.user {
            let updatedMembership = Membership(family: family, user: user, role: role)
            appState.currentMembership = updatedMembership
        }
        
        return appState
    }
    
    // MARK: - Mock Data Creation
    
    /// Create a mock user for testing/preview purposes
    /// - Returns: Mock UserProfile instance
    private static func createMockUser() -> UserProfile {
        return UserProfile(
            displayName: "Test User",
            appleUserIdHash: "test_hash_12345"
        )
    }
    
    /// Create a mock family for testing/preview purposes
    /// - Returns: Mock Family instance
    private static func createMockFamily() -> Family {
        return Family(
            name: "Test Family",
            code: "TEST123",
            createdByUserId: UUID()
        )
    }
    
    /// Create a mock membership for testing/preview purposes
    /// - Returns: Mock Membership instance
    private static func createMockMembership() -> Membership {
        return Membership(
            family: createMockFamily(),
            user: createMockUser(),
            role: .parentAdmin
        )
    }
}

// MARK: - Test Scenarios

/// Test scenarios for AppState configuration
enum TestScenario {
    case unauthenticated
    case authenticated
    case loading
    case error
    case familySelection
}

// MARK: - AppState Extension for Safe Environment Object

extension AppState {
    
    /// Create a fallback AppState instance for SafeEnvironmentObject
    /// This is the primary factory method used by SafeEnvironmentObject
    /// - Returns: AppState with safe default configuration
    static func createFallback() -> AppState {
        return AppStateFactory.createFallbackAppState()
    }
    
    /// Create a preview AppState instance for SwiftUI previews
    /// - Returns: AppState configured for previews
    static func createPreview() -> AppState {
        return AppStateFactory.createPreviewAppState()
    }
    
    /// Create a test AppState instance for unit testing
    /// - Parameter scenario: The test scenario to configure
    /// - Returns: AppState configured for testing
    static func createTest(scenario: TestScenario = .authenticated) -> AppState {
        return AppStateFactory.createTestAppState(scenario: scenario)
    }
    
    /// Create a test AppState instance with specific role
    /// - Parameter role: The user role to configure
    /// - Returns: AppState configured with the specified role
    static func createTest(withRole role: Role) -> AppState {
        return AppStateFactory.createTestAppState(withRole: role)
    }
    
    /// Validate the current AppState for consistency
    /// - Returns: Validation result indicating any issues
    func validateState() -> AppStateValidationResult {
        var issues: [String] = []
        var isValid = true
        
        // Check authentication consistency
        if isAuthenticated && currentUser == nil {
            issues.append("User is marked as authenticated but currentUser is nil")
            isValid = false
        }
        
        if !isAuthenticated && currentUser != nil {
            issues.append("User is not authenticated but currentUser is set")
            isValid = false
        }
        
        // Check family membership consistency
        if currentMembership != nil && currentFamily == nil {
            issues.append("User has membership but no family is set")
            isValid = false
        }
        
        if currentFamily != nil && currentMembership == nil {
            issues.append("User has family but no membership is set")
            isValid = false
        }
        
        // Check flow consistency
        if currentFlow == .familyDashboard && !isAuthenticated {
            issues.append("App flow is set to family dashboard but user is not authenticated")
            isValid = false
        }
        
        if currentFlow == .familyDashboard && currentFamily == nil {
            issues.append("App flow is set to family dashboard but no family is set")
            isValid = false
        }
        
        return AppStateValidationResult(
            isValid: isValid,
            issues: issues,
            recommendations: generateRecommendations(for: issues)
        )
    }
    
    /// Generate recommendations based on validation issues
    /// - Parameter issues: List of validation issues
    /// - Returns: List of recommendations to fix the issues
    private func generateRecommendations(for issues: [String]) -> [String] {
        var recommendations: [String] = []
        
        for issue in issues {
            if issue.contains("authenticated") {
                recommendations.append("Ensure authentication state is properly synchronized with user data")
            }
            if issue.contains("membership") || issue.contains("family") {
                recommendations.append("Verify family membership data is consistent")
            }
            if issue.contains("flow") {
                recommendations.append("Check that app flow matches the current user state")
            }
        }
        
        return recommendations
    }
}

// MARK: - AppState Validation Result

/// Result of AppState validation
struct AppStateValidationResult {
    /// Whether the AppState is in a valid state
    let isValid: Bool
    
    /// List of validation issues found
    let issues: [String]
    
    /// Recommendations to fix the issues
    let recommendations: [String]
    
    /// Whether there are any critical issues that need immediate attention
    var hasCriticalIssues: Bool {
        return !isValid && !issues.isEmpty
    }
}