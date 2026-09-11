import SwiftUI

struct EmailVerificationView: View {
    let email: String
    var onChangeEmail: () -> Void

    @EnvironmentObject private var authSession: AuthSessionContext
    @State private var verificationCode = ""
    @State private var resendCooldownSeconds = 0
    @FocusState private var isCodeFieldFocused: Bool

    private let resendCooldownTotal = 60

    /// Must match the normalized email stored at signup (`pendingVerificationEmail`).
    private var verificationEmail: String {
        authSession.pendingVerificationEmail ?? email
    }

    private var normalizedVerificationCode: String {
        EmailOTPCodeNormalizer.normalize(verificationCode)
    }

    private var isVerifyEnabled: Bool {
        EmailOTPCodeNormalizer.isValidLength(normalizedVerificationCode)
    }

    var body: some View {
        AuthScreenContainer {
            VStack(spacing: 0) {
                Spacer(minLength: 8)

                VStack(spacing: 14) {
                    AppIconView(size: 60)
                        .padding(.bottom, 2)

                    Text("Verify your email")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundStyle(AuthTheme.textPrimary)
                        .multilineTextAlignment(.center)

                    Text("Enter the code we sent to \(verificationEmail).")
                        .font(.subheadline)
                        .foregroundStyle(AuthTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, -4)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Verification code")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(AuthTheme.textPrimary)

                        TextField("Verification code", text: $verificationCode)
                            .keyboardType(.numberPad)
                            .textContentType(.oneTimeCode)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($isCodeFieldFocused)
                            .font(.system(size: 22, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.primary)
                            .tint(AuthTheme.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color(uiColor: .tertiarySystemBackground))
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color(uiColor: .separator).opacity(0.35), lineWidth: 1)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .onChange(of: verificationCode) { _, newValue in
                                let normalized = EmailOTPCodeNormalizer.normalize(newValue)
                                if normalized != newValue {
                                    verificationCode = normalized
                                }
                            }
                    }
                    .padding(.top, 4)

                    AuthPrimaryButton(
                        title: "Verify Email",
                        isLoading: authSession.isLoading,
                        isDisabled: !isVerifyEnabled
                    ) {
                        Task {
                            await authSession.verifyEmailOTP(
                                email: verificationEmail,
                                code: normalizedVerificationCode
                            )
                        }
                    }

                    if let error = authSession.lastError, !error.isEmpty {
                        AuthInlineErrorView(message: error)
                    }

                    if let success = authSession.lastSuccessMessage, !success.isEmpty {
                        Text(success)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color.green)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.green.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    resendButton

                    Button(action: onChangeEmail) {
                        Text("Change email")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AuthTheme.primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(authSession.isLoading)

                    Text("You can also tap the confirmation link in your email. It opens TribeBoard and confirms your account.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(AuthTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .frame(maxWidth: 420)
                .padding(.horizontal, 24)

                Spacer(minLength: 8)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            isCodeFieldFocused = true
        }
        .task(id: resendCooldownSeconds) {
            guard resendCooldownSeconds > 0 else { return }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if resendCooldownSeconds > 0 {
                resendCooldownSeconds -= 1
            }
        }
    }

    @ViewBuilder
    private var resendButton: some View {
        if resendCooldownSeconds > 0 {
            Text("Resend code in \(resendCooldownSeconds)s")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(AuthTheme.textSecondary)
                .frame(maxWidth: .infinity)
        } else {
            Button {
                Task {
                    await authSession.resendVerificationCode(email: verificationEmail)
                    if authSession.lastError == nil {
                        resendCooldownSeconds = resendCooldownTotal
                    }
                }
            } label: {
                Text("Resend Code")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AuthTheme.primary)
            }
            .buttonStyle(.plain)
            .disabled(authSession.isLoading)
        }
    }
}

#Preview {
    EmailVerificationView(email: "parent@example.com", onChangeEmail: {})
        .environmentObject(AuthSessionContext())
}
