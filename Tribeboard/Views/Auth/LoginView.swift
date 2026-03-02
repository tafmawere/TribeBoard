import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        AuthScreenContainer {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Welcome back")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(AuthTheme.textPrimary)
                        .padding(.top, 16)

                    Text("Log in to continue coordinating with your family.")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(AuthTheme.textSecondary)

                    Spacer().frame(height: 8)

                    AuthCardField(
                        title: "Email",
                        placeholder: "Enter your email",
                        text: $viewModel.email
                    )

                    AuthCardField(
                        title: "Password",
                        placeholder: "Enter your password",
                        text: $viewModel.password,
                        isSecure: true
                    )

                    AuthInlineErrorView(message: viewModel.errorMessage)

                    AuthPrimaryButton(
                        title: "Log In",
                        isLoading: viewModel.isLoading,
                        isDisabled: false
                    ) {
                        Task {
                            await viewModel.loginTapped()
                        }
                    }
                    .padding(.top, 4)

                    HStack {
                        Spacer()
                        NavigationLink("Forgot password?") {
                            ForgotPasswordView()
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(AuthTheme.primary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle("Log In")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        LoginView()
    }
}
