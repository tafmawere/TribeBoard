import SwiftUI

/// Wrapper view that manages authentication state and navigation
/// Shows SignInView when not authenticated, main app when authenticated
struct AuthenticationStateView: View {
    
    // MARK: - Environment
    
    @EnvironmentObject private var authService: AuthService
    
    // MARK: - State
    
    @State private var showingSignIn = false
    @State private var isCheckingAuthentication = true
    
    var body: some View {
        ZStack {
            if isCheckingAuthentication {
                // Show loading state while checking authentication
                authenticationCheckingView
            } else if authService.isAuthenticated {
                // User is authenticated - show main app content
                authenticatedContent
            } else {
                // User is not authenticated - show sign-in view
                SignInView()
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .onAppear {
            checkAuthenticationStatus()
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            handleAuthenticationStateChange(isAuthenticated)
        }
        .animation(DesignSystem.Animation.smooth, value: authService.isAuthenticated)
        .animation(DesignSystem.Animation.smooth, value: isCheckingAuthentication)
    }
    
    // MARK: - Authentication Checking View
    
    private var authenticationCheckingView: some View {
        ZStack {
            // Background gradient matching sign-in view
            LinearGradient.brandGradient
                .ignoresSafeArea()
            
            VStack(spacing: DesignSystem.Spacing.xl) {
                // App logo
                TribeBoardLogo(size: .large, showBackground: false)
                    .shadow(color: .white.opacity(0.3), radius: 8, x: 0, y: 4)
                
                // Loading indicator
                VStack(spacing: DesignSystem.Spacing.md) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    
                    Text("Checking authentication...")
                        .bodyMedium()
                        .foregroundColor(.white.opacity(0.9))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Checking authentication status")
        .accessibilityHint("Please wait while we verify your sign-in status")
    }
    
    // MARK: - Authenticated Content
    
    private var authenticatedContent: some View {
        MainNavigationView()
            .transition(.asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            ))
    }
    
    // MARK: - Authentication Management
    
    private func checkAuthenticationStatus() {
        Task {
            // Add a small delay to show the checking state
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            await MainActor.run {
                withAnimation(DesignSystem.Animation.standard) {
                    isCheckingAuthentication = false
                }
            }
        }
    }
    
    private func handleAuthenticationStateChange(_ isAuthenticated: Bool) {
        if isAuthenticated {
            // User just signed in - provide haptic feedback
            HapticManager.shared.success()
        } else {
            // User signed out - provide light haptic feedback
            HapticManager.shared.lightImpact()
        }
    }
}

// MARK: - Preview

#Preview("Authentication State - Not Authenticated") {
    AuthenticationStateView()
        .environmentObject({
            let authService = AuthService()
            authService.isAuthenticated = false
            return authService
        }())
}

#Preview("Authentication State - Authenticated") {
    AuthenticationStateView()
        .environmentObject({
            let authService = AuthService()
            authService.isAuthenticated = true
            authService.currentUser = UserProfile(
                displayName: "John Doe",
                appleUserIdHash: "sample_hash"
            )
            return authService
        }())
}

#Preview("Authentication State - Checking") {
    AuthenticationStateView()
        .environmentObject(AuthService())
        .onAppear {
            // Simulate the checking state
        }
}