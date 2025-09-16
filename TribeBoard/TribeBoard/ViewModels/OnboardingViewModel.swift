import SwiftUI
import Foundation

/// Authentication errors
enum AuthenticationError: LocalizedError {
    case signInFailed
    case networkUnavailable
    case userCancelled
    
    var errorDescription: String? {
        switch self {
        case .signInFailed:
            return "Sign in failed. Please try again."
        case .networkUnavailable:
            return "Network unavailable. Please check your connection."
        case .userCancelled:
            return "Sign in was cancelled."
        }
    }
}

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
            
            // Mock authentication success with occasional failure for testing
            if Bool.random() && Double.random(in: 0...1) < 0.1 { // 10% chance of failure for testing
                throw AuthenticationError.signInFailed
            }
            
            // Mock authentication success
            let mockUser = createMockUser()
            
            // Update app state
            appState?.signIn(user: mockUser)
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
        
        return UserProfile(
            displayName: randomName,
            appleUserIdHash: mockHash
        )
    }
}