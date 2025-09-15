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
                    VStack(spacing: 40) {
                        Spacer(minLength: geometry.size.height * 0.1)
                        
                        // Logo and branding section
                        VStack(spacing: 24) {
                            TribeBoardLogoWithText(size: .extraLarge)
                            
                            VStack(spacing: 12) {
                                Text("Welcome to TribeBoard")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.brandPrimary)
                                    .multilineTextAlignment(.center)
                                
                                Text("Connect your family, organize your life")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        }
                        
                        Spacer(minLength: 40)
                        
                        // Authentication section
                        VStack(spacing: 20) {
                            Text("Sign in to get started")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            // Sign in with Apple button
                            Button(action: {
                                Task {
                                    await viewModel.signInWithApple()
                                }
                            }) {
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
                                .frame(height: 56)
                                .background(
                                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                                        .fill(Color.black)
                                        .opacity(viewModel.isLoading ? 0.7 : 1.0)
                                )
                            }
                            .disabled(viewModel.isLoading)
                            .padding(.horizontal, 32)
                            
                            // Error message
                            if let errorMessage = viewModel.errorMessage {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    
                                    Text(errorMessage)
                                        .font(.subheadline)
                                        .foregroundColor(.red)
                                        .multilineTextAlignment(.leading)
                                }
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                                        .fill(Color.red.opacity(0.1))
                                )
                                .padding(.horizontal, 32)
                            }
                        }
                        
                        Spacer(minLength: geometry.size.height * 0.1)
                        
                        // Footer
                        VStack(spacing: 8) {
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
        .onAppear {
            // Inject the actual appState when view appears
            viewModel.setAppState(appState)
        }
        .alert("Authentication Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("Try Again") {
                viewModel.clearError()
            }
            Button("Cancel", role: .cancel) {
                viewModel.clearError()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
        .environmentObject(AppState())
}