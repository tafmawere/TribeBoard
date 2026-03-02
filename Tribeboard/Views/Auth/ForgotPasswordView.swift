import SwiftUI

struct ForgotPasswordView: View {
    @StateObject private var viewModel = AuthViewModel()

    var body: some View {
        AuthScreenContainer {
            VStack(alignment: .leading, spacing: 16) {
                Text("Forgot your password?")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(AuthTheme.textPrimary)
                    .padding(.top, 20)

                Text("Enter your email and we will send you a reset link.")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(AuthTheme.textSecondary)

                AuthCardField(
                    title: "Email",
                    placeholder: "Enter your email",
                    text: $viewModel.email
                )
                .padding(.top, 8)

                AuthInlineErrorView(message: viewModel.errorMessage)

                if viewModel.didSendReset {
                    Text("Check your email for a password reset link.")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.green.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }

                AuthPrimaryButton(
                    title: "Send reset link",
                    isLoading: viewModel.isLoading,
                    isDisabled: false
                ) {
                    Task {
                        await viewModel.resetTapped()
                    }
                }
                .padding(.top, 6)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 26)
        }
        .navigationTitle("Forgot Password")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ForgotPasswordView()
    }
}
