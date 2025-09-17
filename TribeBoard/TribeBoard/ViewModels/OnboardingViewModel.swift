import SwiftUI
import Foundation

/// ViewModel for the onboarding flow with Apple authentication
@MainActor
class OnboardingViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Loading state for authentication process
    @Published var isLoading: Bool = false
    
    /// Error message to display to user
    @Published var errorMessage: String?
    
    /// Success state for navigation
    @Published var authenticationSucceeded: Bool = false
    
    // MARK: - Dependencies
    
    private var appState: AppState?
    private let authService: AuthService
    
    // MARK: - Initialization
    
    init(authService: AuthService, appState: AppState? = nil) {
        self.authService = authService
        self.appState = appState
    }
    
    /// Set the app state (called from view when environment object is available)
    func setAppState(_ appState: AppState) {
        self.appState = appState
    }
    
    // MARK: - Authentication Methods
    
    /// Sign in with Apple authentication
    func signInWithApple() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Perform real Apple authentication
            try await authService.signInWithApple()
            
            // Get the authenticated user
            guard let authenticatedUser = authService.getCurrentUser() else {
                throw AuthError.authorizationFailed
            }
            
            // Update app state
            appState?.signIn(user: authenticatedUser)
            authenticationSucceeded = true
            
            // Success haptic feedback
            HapticManager.shared.success()
            
        } catch {
            // Handle authentication failure
            errorMessage = error.localizedDescription
            HapticManager.shared.error()
        }
        
        isLoading = false
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
    

}