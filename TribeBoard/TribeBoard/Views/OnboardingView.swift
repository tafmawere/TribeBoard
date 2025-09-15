import SwiftUI

/// Onboarding view with TribeBoard branding and Sign in with Apple
struct OnboardingView: View {
    @StateObject private var viewModel: OnboardingViewModel
    @EnvironmentObject private var appState: AppState
    
    init() {
        // Initialize viewModel without appState - will be injected when view appears
        self._viewModel = StateObject(wrappedValue: OnboardingViewModel())
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
                        
                        // Logo and branding section
                        VStack(spacing: 32) {
                            TribeBoardLogoWithText(size: .large)
                            
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
                        
                        Spacer(minLength: 32)
                        
                        // Authentication section
                        VStack(spacing: 24) {
                            Text("Sign in to get started")
                                .font(.title3)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            // Enhanced Sign in with Apple button
                            AccessibleButton(
                                action: {
                                    Task {
                                        await viewModel.signInWithApple()
                                    }
                                },
                                label: "Sign in with Apple",
                                hint: "Authenticates you with your Apple ID to access TribeBoard",
                                hapticStyle: .medium
                            ) {
                                HStack(spacing: 12) {
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "applelogo")
                                            .font(.title3)
                                    }
                                    
                                    Text(viewModel.isLoading ? "Signing in..." : "Sign in with Apple")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                                        .fill(Color.black)
                                        .opacity(viewModel.isLoading ? 0.7 : 1.0)
                                )
                            }
                            .disabled(viewModel.isLoading)
                            .padding(.horizontal, 40)
                            
                            // Enhanced error message
                            if let errorMessage = viewModel.errorMessage {
                                InlineErrorView(message: errorMessage) {
                                    viewModel.clearError()
                                }
                                .padding(.horizontal, 40)
                            }
                        }
                        
                        Spacer(minLength: geometry.size.height * 0.08)
                        
                        // Footer
                        VStack(spacing: 12) {
                            Text("By signing in, you agree to our")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 16) {
                                Button("Terms of Service") {
                                    // TODO: Open terms of service
                                }
                                .font(.caption)
                                .foregroundColor(.brandPrimary)
                                
                                Text("•")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Button("Privacy Policy") {
                                    // TODO: Open privacy policy
                                }
                                .font(.caption)
                                .foregroundColor(.brandPrimary)
                            }
                        }
                        .padding(.horizontal, 32)
                    }
                    .padding(.vertical, 20)
                }
            }
        }
        .navigationBarHidden(true)
        .withToast()
        .onAppear {
            // Inject the actual appState when view appears
            viewModel.setAppState(appState)
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}