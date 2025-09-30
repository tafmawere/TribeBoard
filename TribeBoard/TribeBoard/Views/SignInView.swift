import SwiftUI
import AuthenticationServices

/// Sign-in view with Apple ID authentication
struct SignInView: View {
    
    // MARK: - Environment
    
    @EnvironmentObject private var authService: AuthService
    
    // MARK: - State
    
    @State private var showingError = false
    @State private var currentError: AuthError?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient.brandGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xxxl) {
                        Spacer()
                            .frame(height: geometry.size.height * 0.1)
                        
                        // Logo and welcome section
                        welcomeSection
                        
                        // Sign-in section
                        signInSection
                        
                        Spacer()
                            .frame(height: geometry.size.height * 0.1)
                    }
                    .screenPadding()
                    .frame(minHeight: geometry.size.height)
                }
            }
        }
        .networkStatusBanner(onRetry: {
            Task {
                await handleSignInTap()
            }
        })
        .authErrorAlert(
            isPresented: $showingError,
            error: currentError,
            onRetry: {
                Task {
                    await handleSignInTap()
                }
            }
        )
    }
    
    // MARK: - Welcome Section
    
    private var welcomeSection: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // App logo
            TribeBoardLogo(size: .extraLarge, showBackground: false)
                .shadow(color: .white.opacity(0.3), radius: 8, x: 0, y: 4)
            
            // Welcome text
            VStack(spacing: DesignSystem.Spacing.md) {
                Text("Welcome to TribeBoard")
                    .displayMedium()
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Keep your family organized and connected")
                    .bodyLarge()
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Sign-In Section
    
    private var signInSection: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // Sign in with Apple button
            signInWithAppleButton
            
            // Loading indicator
            if authService.isLoading {
                loadingIndicator
            }
            
            // Privacy notice
            privacyNotice
        }
    }
    
    // MARK: - Sign In with Apple Button
    
    private var signInWithAppleButton: some View {
        Button(action: {
            Task {
                await handleSignInTap()
            }
        }) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "applelogo")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.black)
                
                Text("Sign in with Apple")
                    .font(DesignSystem.Typography.buttonLarge)
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
            .frame(height: DesignSystem.Layout.buttonHeight)
            .background(Color.white)
            .cornerRadius(BrandStyle.cornerRadius)
            .shadow(
                color: .black.opacity(0.1),
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .disabled(authService.isLoading)
        .opacity(authService.isLoading ? 0.6 : 1.0)
        .animation(DesignSystem.Animation.standard, value: authService.isLoading)
        .accessibilityLabel("Sign in with Apple")
        .accessibilityHint("Sign in to TribeBoard using your Apple ID")
    }
    
    // MARK: - Loading Indicator
    
    private var loadingIndicator: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(0.8)
            
            Text("Signing in...")
                .bodyMedium()
                .foregroundColor(.white.opacity(0.9))
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
        .transition(.opacity.combined(with: .scale))
    }
    
    // MARK: - Privacy Notice
    
    private var privacyNotice: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("Your privacy is protected")
                .labelLarge()
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text("We only access your name and email address. You can choose to hide your email using Apple's private relay.")
                .captionLarge()
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .lineLimit(nil)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
    }
    
    // MARK: - Sign-In Handling
    
    private func handleSignInTap() async {
        do {
            // The AuthService will handle the complete Apple Sign In flow
            try await authService.signInWithApple()
        } catch let error as AuthError {
            await handleAuthError(error)
        } catch {
            await handleAuthError(.unknownError(error))
        }
    }
    
    @MainActor
    private func handleAuthError(_ error: AuthError) {
        currentError = error
        showingError = true
    }
}

// MARK: - Preview

#Preview("Sign In View") {
    SignInView()
        .environmentObject(AuthService())
}

#Preview("Sign In View - Loading") {
    SignInView()
        .environmentObject({
            let authService = AuthService()
            authService.isLoading = true
            return authService
        }())
}