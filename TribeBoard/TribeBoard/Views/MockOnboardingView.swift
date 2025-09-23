import SwiftUI

/// Enhanced onboarding view with mock authentication and smooth animations
struct MockOnboardingView: View {
    @StateObject private var viewModel: MockOnboardingViewModel
    @EnvironmentObject private var appState: AppState
    
    // Sheet presentation states
    @State private var showTermsOfService = false
    @State private var showPrivacyPolicy = false
    
    init(mockAuthService: MockAuthService) {
        self._viewModel = StateObject(wrappedValue: MockOnboardingViewModel(mockAuthService: mockAuthService))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient.brandGradientSubtle
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        Spacer(minLength: geometry.size.height * 0.08)
                        
                        // Logo and branding section with animation
                        logoSection
                        
                        Spacer(minLength: 32)
                        
                        // Authentication section
                        authenticationSection
                        
                        Spacer(minLength: geometry.size.height * 0.08)
                        
                        // Footer with Terms and Privacy links
                        footerSection
                    }
                    .padding(.vertical, 20)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            viewModel.setAppState(appState)
            viewModel.resetAnimationStates()
        }
        .sheet(isPresented: $showTermsOfService) {
            TermsOfServiceView()
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .withToast()
    }
    
    // MARK: - Logo Section
    
    private var logoSection: some View {
        VStack(spacing: 32) {
            // Animated logo
            TribeBoardLogoWithText(size: .large)
                .scaleEffect(viewModel.logoScale)
                .animation(.easeInOut(duration: 0.3), value: viewModel.logoScale)
            
            VStack(spacing: 16) {
                Text("Welcome to TribeBoard")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.brandPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Connect your family, organize your life")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
    }
    
    // MARK: - Authentication Section
    
    private var authenticationSection: some View {
        VStack(spacing: 24) {
            Text("Sign in to get started")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            VStack(spacing: 16) {
                // Sign in with Apple button
                signInButton(
                    title: "Sign in with Apple",
                    icon: "applelogo",
                    backgroundColor: .black,
                    action: {
                        Task {
                            await viewModel.signInWithApple()
                        }
                    }
                )
                
                // Sign in with Google button (placeholder)
                signInButton(
                    title: "Sign in with Google",
                    icon: "globe",
                    backgroundColor: .blue,
                    action: {
                        Task {
                            await viewModel.signInWithGoogle()
                        }
                    }
                )
            }
            .padding(.horizontal, 40)
            
            // Enhanced error message with animation
            if let errorMessage = viewModel.errorMessage {
                errorMessageView(errorMessage)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .bottom))
                    ))
                    .padding(.horizontal, 40)
            }
            
            // Success animation overlay
            if viewModel.showSuccessAnimation {
                successAnimationView
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale),
                        removal: .opacity
                    ))
            }
        }
    }
    
    // MARK: - Sign In Button
    
    private func signInButton(
        title: String,
        icon: String,
        backgroundColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        AccessibleButton(
            action: action,
            label: title,
            hint: "Authenticates you to access TribeBoard",
            hapticStyle: .medium
        ) {
            HStack(spacing: 12) {
                if viewModel.isLoading {
                    // Enhanced loading indicator with progress
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            .frame(width: 20, height: 20)
                        
                        Circle()
                            .trim(from: 0, to: viewModel.loadingProgress)
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: 20, height: 20)
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.1), value: viewModel.loadingProgress)
                    }
                } else {
                    Image(systemName: icon)
                        .font(.title3)
                }
                
                Text(viewModel.isLoading ? "Signing in..." : title)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                    .fill(backgroundColor)
                    .opacity(viewModel.isLoading ? 0.7 : 1.0)
            )
            .scaleEffect(viewModel.buttonScale)
            .animation(.easeInOut(duration: 0.1), value: viewModel.buttonScale)
        }
        .disabled(viewModel.isLoading)
    }
    
    // MARK: - Error Message View
    
    private func errorMessageView(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.caption)
            
            Text(message)
                .font(.caption)
                .foregroundColor(.red)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            Button(action: viewModel.clearError) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red.opacity(0.7))
                    .font(.caption)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Success Animation View
    
    private var successAnimationView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
                .scaleEffect(viewModel.showSuccessAnimation ? 1.0 : 0.5)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: viewModel.showSuccessAnimation)
            
            Text("Welcome to TribeBoard!")
                .font(.headline)
                .foregroundColor(.green)
                .opacity(viewModel.showSuccessAnimation ? 1.0 : 0.0)
                .animation(.easeInOut(duration: 0.3).delay(0.2), value: viewModel.showSuccessAnimation)
        }
        .padding(.horizontal, 40)
    }
    
    // MARK: - Footer Section
    
    private var footerSection: some View {
        VStack(spacing: 12) {
            Text("By signing in, you agree to our")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                Button("Terms of Service") {
                    showTermsOfService = true
                }
                .font(.caption)
                .foregroundColor(.brandPrimary)
                .accessibilityLabel("View Terms of Service")
                .accessibilityHint("Opens the Terms of Service document")
                
                Text("•")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button("Privacy Policy") {
                    showPrivacyPolicy = true
                }
                .font(.caption)
                .foregroundColor(.brandPrimary)
                .accessibilityLabel("View Privacy Policy")
                .accessibilityHint("Opens the Privacy Policy document")
            }
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Preview

#Preview {
    MockOnboardingView(mockAuthService: MockAuthService())
        .environmentObject(AppState())
}