import SwiftUI

struct SignupView: View {
    @EnvironmentObject var flow: AppFlowState
    @State private var emailOrPhone = ""

    var body: some View {
        AuthScreenContainer {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Spacer()
                        Text("TribeBoard")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(AuthTheme.textPrimary)
                        Spacer()
                    }
                    .overlay(alignment: .trailing) {
                        Button {
                            // UI-only placeholder action.
                        } label: {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(AuthTheme.textPrimary)
                        }
                    }

                    Text("Your family, in sync.")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundStyle(AuthTheme.textPrimary)
                        .padding(.top, 8)

                    Text("Sign in or create your account to start coordinating with ease.")
                        .font(.system(size: 34 / 2, weight: .regular))
                        .foregroundStyle(AuthTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Spacer().frame(height: 10)

                    HStack {
                        Spacer()
                        AppIconView(size: 84)
                        Spacer()
                    }
                    .padding(.vertical, 8)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Email or Phone number")
                            .font(.system(size: 29 / 2, weight: .regular))
                            .foregroundStyle(AuthTheme.textPrimary)

                        TextField("Enter email or phone", text: $emailOrPhone)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(.primary)
                            .tint(AuthTheme.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color(uiColor: .tertiarySystemBackground))
                            .overlay {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color(uiColor: .separator).opacity(0.35), lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }

                    AuthPrimaryButton(
                        title: "Continue",
                        isLoading: false,
                        isDisabled: emailOrPhone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ) {
                        flow.signIn()
                    }
                    .padding(.top, 8)

                    AuthDividerText(text: "or")
                        .padding(.vertical, 4)

                    AuthSecondaryOutlineButton(title: "Continue with Apple") {
                        flow.signIn()
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Secure & Private. Your data belongs to your tribe.")
                            .font(.system(size: 15 / 1.2, weight: .medium))
                    }
                    .foregroundStyle(AuthTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 10)

                    Text("By continuing, you agree to our Terms of Services and Privacy Policy")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AuthTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, -2)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 30)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        SignupView()
            .environmentObject(AppFlowState())
    }
}
