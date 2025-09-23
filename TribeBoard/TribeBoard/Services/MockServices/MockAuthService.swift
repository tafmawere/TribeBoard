import Foundation
import SwiftUI

/// Mock authentication service for UI/UX prototype
@MainActor
class MockAuthService: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current authentication state
    @Published var isAuthenticated: Bool = false
    
    /// Current authenticated user profile
    @Published var currentUser: UserProfile?
    
    /// Loading state for authentication operations
    @Published var isLoading: Bool = false
    
    // MARK: - Mock Data
    
    private let mockUser = UserProfile(
        displayName: "Demo User",
        appleUserIdHash: "mock_apple_user_hash_12345"
    )
    
    // MARK: - Initialization
    
    init() {
        // Start with unauthenticated state for demo
    }
    
    // MARK: - Public Authentication Methods
    
    /// Mock sign in with Apple ID - always succeeds instantly
    func signInWithApple() async throws {
        isLoading = true
        
        // Simulate brief loading for realistic feel
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Always succeed with mock user
        currentUser = mockUser
        isAuthenticated = true
        isLoading = false
    }
    
    /// Mock sign in with Google - always succeeds instantly
    func signInWithGoogle() async throws {
        isLoading = true
        
        // Simulate brief loading for realistic feel
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Always succeed with mock user
        currentUser = mockUser
        isAuthenticated = true
        isLoading = false
    }
    
    /// Mock sign out - always succeeds instantly
    func signOut() async throws {
        isLoading = true
        
        // Simulate brief loading
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
        
        // Clear authentication state
        currentUser = nil
        isAuthenticated = false
        isLoading = false
    }
    
    /// Get current authenticated user
    func getCurrentUser() -> UserProfile? {
        return currentUser
    }
    
    /// Check if user is currently authenticated
    func checkAuthenticationStatus() -> Bool {
        return isAuthenticated && currentUser != nil
    }
    
    /// Mock method to check existing authentication on app launch
    func checkExistingAuthentication() async {
        // For prototype, start unauthenticated to show onboarding flow
        // In a real demo scenario, this could be configured to start authenticated
        isAuthenticated = false
        currentUser = nil
    }
    
    /// Set mock authentication state (useful for demo scenarios)
    func setMockAuthenticationState(authenticated: Bool, user: UserProfile? = nil) {
        isAuthenticated = authenticated
        currentUser = user ?? (authenticated ? mockUser : nil)
    }
}