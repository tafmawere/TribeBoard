import SwiftUI
import Foundation

/// A view modifier that provides consistent environment object setup for SwiftUI previews
/// This ensures all previews have the necessary environment objects to prevent crashes
struct PreviewEnvironmentModifier: ViewModifier {
    
    // MARK: - Configuration
    
    /// The type of preview environment to set up
    let environmentType: PreviewEnvironmentType
    
    /// Optional custom AppState for specific preview scenarios
    let customAppState: AppState?
    
    // MARK: - Initialization
    
    /// Initialize with default preview environment
    init() {
        self.environmentType = .default
        self.customAppState = nil
    }
    
    /// Initialize with specific environment type
    /// - Parameter environmentType: The type of preview environment to create
    init(environmentType: PreviewEnvironmentType) {
        self.environmentType = environmentType
        self.customAppState = nil
    }
    
    /// Initialize with custom AppState
    /// - Parameter customAppState: Custom AppState instance for the preview
    init(customAppState: AppState) {
        self.environmentType = .custom
        self.customAppState = customAppState
    }
    
    // MARK: - ViewModifier Implementation
    
    func body(content: Content) -> some View {
        content
            .environmentObject(getAppState())
            .environment(\.environmentObjectAvailable, true)
    }
    
    // MARK: - Private Methods
    
    /// Get the appropriate AppState for the preview environment
    /// - Returns: Configured AppState instance
    private func getAppState() -> AppState {
        if let customAppState = customAppState {
            return customAppState
        }
        
        switch environmentType {
        case .default:
            return AppStateFactory.createPreviewAppState()
        case .unauthenticated:
            return AppStateFactory.createTestAppState(scenario: .unauthenticated)
        case .authenticated:
            return AppStateFactory.createTestAppState(scenario: .authenticated)
        case .loading:
            return AppStateFactory.createTestAppState(scenario: .loading)
        case .error:
            return AppStateFactory.createTestAppState(scenario: .error)
        case .familySelection:
            return AppStateFactory.createTestAppState(scenario: .familySelection)
        case .parentAdmin:
            return AppStateFactory.createTestAppState(withRole: .parentAdmin)
        case .adult:
            return AppStateFactory.createTestAppState(withRole: .adult)
        case .kid:
            return AppStateFactory.createTestAppState(withRole: .kid)
        case .visitor:
            return AppStateFactory.createTestAppState(withRole: .visitor)
        case .custom:
            // This should not happen since customAppState would be set
            return AppStateFactory.createPreviewAppState()
        }
    }
}

// MARK: - Preview Environment Types

/// Types of preview environments that can be set up
enum PreviewEnvironmentType {
    /// Default preview environment with authenticated user and family
    case `default`
    
    /// Unauthenticated user state
    case unauthenticated
    
    /// Authenticated user with family
    case authenticated
    
    /// Loading state
    case loading
    
    /// Error state
    case error
    
    /// Family selection state
    case familySelection
    
    /// Parent admin role
    case parentAdmin
    
    /// Adult role
    case adult
    
    /// Kid role
    case kid
    
    /// Visitor role
    case visitor
    
    /// Custom environment (requires custom AppState)
    case custom
}

// MARK: - View Extensions for Preview Environment

extension View {
    
    /// Apply default preview environment with all necessary environment objects
    /// - Returns: View with preview environment applied
    func previewEnvironment() -> some View {
        modifier(PreviewEnvironmentModifier())
    }
    
    /// Apply specific preview environment type
    /// - Parameter type: The type of preview environment to apply
    /// - Returns: View with specified preview environment applied
    func previewEnvironment(_ type: PreviewEnvironmentType) -> some View {
        modifier(PreviewEnvironmentModifier(environmentType: type))
    }
    
    /// Apply custom preview environment with specific AppState
    /// - Parameter appState: Custom AppState instance for the preview
    /// - Returns: View with custom preview environment applied
    func previewEnvironment(customAppState: AppState) -> some View {
        modifier(PreviewEnvironmentModifier(customAppState: customAppState))
    }
    
    /// Apply preview environment for specific user role
    /// - Parameter role: The user role to configure in the preview
    /// - Returns: View with role-specific preview environment applied
    func previewEnvironment(role: Role) -> some View {
        let environmentType: PreviewEnvironmentType
        switch role {
        case .parentAdmin:
            environmentType = .parentAdmin
        case .adult:
            environmentType = .adult
        case .kid:
            environmentType = .kid
        case .visitor:
            environmentType = .visitor
        }
        return modifier(PreviewEnvironmentModifier(environmentType: environmentType))
    }
    
    /// Apply preview environment for unauthenticated state
    /// - Returns: View with unauthenticated preview environment applied
    func previewEnvironmentUnauthenticated() -> some View {
        modifier(PreviewEnvironmentModifier(environmentType: .unauthenticated))
    }
    
    /// Apply preview environment for loading state
    /// - Returns: View with loading preview environment applied
    func previewEnvironmentLoading() -> some View {
        modifier(PreviewEnvironmentModifier(environmentType: .loading))
    }
    
    /// Apply preview environment for error state
    /// - Returns: View with error preview environment applied
    func previewEnvironmentError() -> some View {
        modifier(PreviewEnvironmentModifier(environmentType: .error))
    }
    
    /// Apply preview environment for family selection state
    /// - Returns: View with family selection preview environment applied
    func previewEnvironmentFamilySelection() -> some View {
        modifier(PreviewEnvironmentModifier(environmentType: .familySelection))
    }
}

// MARK: - Preview Environment Validation

/// Utility for validating preview environments
struct PreviewEnvironmentValidator {
    
    /// Validate that a preview environment is properly configured
    /// - Parameter appState: The AppState to validate
    /// - Returns: Validation result
    @MainActor
    static func validatePreviewEnvironment(_ appState: AppState) -> PreviewEnvironmentValidationResult {
        let stateValidation = appState.validateState()
        
        var previewIssues: [String] = []
        var isValid = stateValidation.isValid
        
        // Additional preview-specific validations
        if appState.currentFlow == .familyDashboard && appState.currentFamily == nil {
            previewIssues.append("Preview shows family dashboard but no family is configured")
            isValid = false
        }
        
        return PreviewEnvironmentValidationResult(
            isValid: isValid,
            appStateValidation: stateValidation,
            previewSpecificIssues: previewIssues,
            recommendations: generatePreviewRecommendations(for: previewIssues)
        )
    }
    
    /// Generate recommendations for preview environment issues
    /// - Parameter issues: List of preview-specific issues
    /// - Returns: List of recommendations
    private static func generatePreviewRecommendations(for issues: [String]) -> [String] {
        var recommendations: [String] = []
        
        for issue in issues {
            if issue.contains("family dashboard") {
                recommendations.append("Use .previewEnvironment(.authenticated) or provide a custom AppState with family data")
            }
        }
        
        return recommendations
    }
}

/// Result of preview environment validation
struct PreviewEnvironmentValidationResult {
    /// Whether the preview environment is valid
    let isValid: Bool
    
    /// AppState validation result
    let appStateValidation: AppStateValidationResult
    
    /// Preview-specific issues
    let previewSpecificIssues: [String]
    
    /// Recommendations for fixing issues
    let recommendations: [String]
    
    /// All issues combined
    var allIssues: [String] {
        return appStateValidation.issues + previewSpecificIssues
    }
}

// MARK: - Preview Environment Logger

/// Logger for preview environment setup
struct PreviewEnvironmentLogger {
    
    /// Log preview environment setup
    /// - Parameters:
    ///   - type: The environment type being set up
    ///   - viewName: Name of the view using the preview environment
    static func logPreviewSetup(type: PreviewEnvironmentType, for viewName: String) {
        #if DEBUG
        print("🎨 PreviewEnvironment: Setting up \(type) environment for \(viewName)")
        #endif
    }
    
    /// Log preview environment validation issues
    /// - Parameters:
    ///   - result: The validation result
    ///   - viewName: Name of the view being validated
    static func logValidationIssues(result: PreviewEnvironmentValidationResult, for viewName: String) {
        #if DEBUG
        if !result.isValid {
            print("⚠️ PreviewEnvironment: Validation issues for \(viewName):")
            result.allIssues.forEach { issue in
                print("   - \(issue)")
            }
            result.recommendations.forEach { recommendation in
                print("   💡 \(recommendation)")
            }
        }
        #endif
    }
}