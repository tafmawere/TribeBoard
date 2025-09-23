import SwiftUI
import Foundation

/// Enhanced ViewModel for the onboarding flow with mock authentication and animations
@MainActor
class MockOnboardingViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Loading state for authentication process
    @Published var isLoading: Bool = false
    
    /// Error message to display to user
    @Published var errorMessage: String?
    
    /// Success state for navigation
    @Published var authenticationSucceeded: Bool = false
    
    /// Animation states for enhanced UX
    @Published var showSuccessAnimation: Bool = false
    @Published var buttonScale: CGFloat = 1.0
    @Published var logoScale: CGFloat = 1.0
    
    /// Loading progress for realistic feel
    @Published var loadingProgress: Double = 0.0
    
    // MARK: - Dependencies
    
    private var appState: AppState?
    private let mockAuthService: MockAuthService
    
    // MARK: - Initialization
    
    init(mockAuthService: MockAuthService, appState: AppState? = nil) {
        self.mockAuthService = mockAuthService
        self.appState = appState
    }
    
    /// Set the app state (called from view when environment object is available)
    func setAppState(_ appState: AppState) {
        self.appState = appState
    }
    
    // MARK: - Authentication Methods
    
    /// Sign in with Apple authentication using mock service
    func signInWithApple() async {
        await performMockAuthentication(provider: "Apple")
    }
    
    /// Sign in with Google authentication using mock service
    func signInWithGoogle() async {
        await performMockAuthentication(provider: "Google")
    }
    
    /// Perform mock authentication with enhanced animations
    private func performMockAuthentication(provider: String) async {
        // Start loading state
        isLoading = true
        errorMessage = nil
        loadingProgress = 0.0
        
        // Button press animation
        withAnimation(.easeInOut(duration: 0.1)) {
            buttonScale = 0.95
        }
        
        // Reset button scale
        withAnimation(.easeInOut(duration: 0.1).delay(0.1)) {
            buttonScale = 1.0
        }
        
        do {
            // Simulate realistic loading progress
            await animateLoadingProgress()
            
            // Perform mock authentication
            if provider == "Apple" {
                try await mockAuthService.signInWithApple()
            } else {
                try await mockAuthService.signInWithGoogle()
            }
            
            // Get the authenticated user
            guard let authenticatedUser = mockAuthService.getCurrentUser() else {
                throw MockAuthError.authorizationFailed
            }
            
            // Show success animation
            await showAuthenticationSuccess()
            
            // Update app state
            appState?.signIn(user: authenticatedUser)
            authenticationSucceeded = true
            
            // Success haptic feedback
            HapticManager.shared.success()
            
        } catch {
            // Handle authentication failure
            await showAuthenticationError(error)
            HapticManager.shared.error()
        }
        
        isLoading = false
        loadingProgress = 0.0
    }
    
    /// Animate loading progress for realistic feel
    private func animateLoadingProgress() async {
        let steps = 20
        let stepDuration = 25_000_000 // 0.025 seconds in nanoseconds
        
        for i in 1...steps {
            try? await Task.sleep(nanoseconds: UInt64(stepDuration))
            
            withAnimation(.easeInOut(duration: 0.1)) {
                loadingProgress = Double(i) / Double(steps)
            }
        }
    }
    
    /// Show success animation
    private func showAuthenticationSuccess() async {
        // Logo pulse animation
        withAnimation(.easeInOut(duration: 0.3)) {
            logoScale = 1.1
        }
        
        // Success state animation
        withAnimation(.easeInOut(duration: 0.5)) {
            showSuccessAnimation = true
        }
        
        // Brief delay to show success state
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Reset logo scale
        withAnimation(.easeInOut(duration: 0.3)) {
            logoScale = 1.0
        }
    }
    
    /// Show authentication error with animation
    private func showAuthenticationError(_ error: Error) async {
        errorMessage = error.localizedDescription
        
        // Error shake animation
        withAnimation(.easeInOut(duration: 0.1)) {
            buttonScale = 0.98
        }
        
        withAnimation(.easeInOut(duration: 0.1).delay(0.1)) {
            buttonScale = 1.0
        }
    }
    
    /// Clear error message
    func clearError() {
        withAnimation(.easeInOut(duration: 0.3)) {
            errorMessage = nil
        }
    }
    
    /// Reset all animation states
    func resetAnimationStates() {
        showSuccessAnimation = false
        buttonScale = 1.0
        logoScale = 1.0
        loadingProgress = 0.0
    }
}

// MARK: - Mock Authentication Errors

enum MockAuthError: LocalizedError {
    case authorizationFailed
    case networkError
    case userCancelled
    
    var errorDescription: String? {
        switch self {
        case .authorizationFailed:
            return "Authentication failed. Please try again."
        case .networkError:
            return "Network connection error. Please check your connection."
        case .userCancelled:
            return "Authentication was cancelled."
        }
    }
}