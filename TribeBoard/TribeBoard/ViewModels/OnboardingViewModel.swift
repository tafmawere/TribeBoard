import SwiftUI
import Foundation

/// ViewModel for the onboarding flow with mock authentication
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
    
    // MARK: - Initialization
    
    init(appState: AppState? = nil) {
        self.appState = appState
    }
    
    /// Set the app state (called from view when environment object is available)
    func setAppState(_ appState: AppState) {
        self.appState = appState
    }
    
    // MARK: - Authentication Methods
    
    /// Mock Sign in with Apple authentication
    func signInWithApple() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Simulate network delay
            try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            
            // Mock authentication success
            let mockUser = createMockUser()
            
            // Update app state
            appState?.signIn(user: mockUser)
            authenticationSucceeded = true
            
        } catch {
            // Handle mock authentication failure (rare case for testing)
            if Bool.random() && false { // Disabled for now - always succeed
                errorMessage = "Authentication failed. Please try again."
            } else {
                // Success path
                let mockUser = createMockUser()
                appState?.signIn(user: mockUser)
                authenticationSucceeded = true
            }
        }
        
        isLoading = false
    }
    
    /// Clear error message
    func clearError() {
        errorMessage = nil
    }
    
    // MARK: - Private Methods
    
    /// Creates a mock user for testing
    private func createMockUser() -> UserProfile {
        let mockNames = [
            "Sarah Johnson",
            "Mike Garcia", 
            "Emma Chen",
            "Alex Smith",
            "Jordan Taylor",
            "Casey Morgan"
        ]
        
        let randomName = mockNames.randomElement() ?? "Test User"
        let mockHash = "mock_hash_\(UUID().uuidString.prefix(8))"
        
        return UserProfile.mock(
            displayName: randomName,
            appleUserIdHash: mockHash
        )
    }
}