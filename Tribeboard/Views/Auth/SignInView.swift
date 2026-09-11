import SwiftUI

struct SignInView: View {
    let email: String
    var onChangeEmail: () -> Void

    @EnvironmentObject private var authSession: AuthSessionContext
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var showForgotPassword = false
    @FocusState private var isPasswordFocused: Bool

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Welcome back")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(LoginV3Theme.headline)
                    .padding(.bottom, 16)

                LoginV3EmailPill(email: email, onChangeEmail: onChangeEmail)
                    .padding(.bottom, 16)

                ZStack(alignment: .trailing) {
                    Group {
                        if isPasswordVisible {
                            LoginV3BorderedField(
                                placeholder: "Password",
                                text: $password,
                                isSecure: false,
                                textContentType: .password,
                                isFocused: $isPasswordFocused
                            )
                        } else {
                            LoginV3BorderedField(
                                placeholder: "Password",
                                text: $password,
                                isSecure: true,
                                textContentType: .password,
                                isFocused: $isPasswordFocused
                            )
                        }
                    }

                    Button {
                        isPasswordVisible.toggle()
                    } label: {
                        Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(LoginV3Theme.secondary)
                            .padding(.trailing, 16)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 8)

                HStack {
                    Spacer()
                    Button("Forgot password?") {
                        showForgotPassword = true
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LoginV3Theme.indigo)
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 16)

                LoginV3ContinueButton(
                    title: "Continue",
                    isLoading: authSession.isLoading,
                    isDisabled: password.isEmpty
                ) {
                    Task {
                        await authSession.signIn(email: email, password: password)
                    }
                }

                if let error = authSession.lastError, !error.isEmpty {
                    AuthInlineErrorView(message: error)
                        .padding(.top, 12)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .frame(maxWidth: 440)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.white)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    onChangeEmail()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(LoginV3Theme.indigo)
                }
            }
        }
        .sheet(isPresented: $showForgotPassword) {
            NavigationStack {
                ForgotPasswordView(initialEmail: email)
            }
        }
        .ignoresSafeArea(.keyboard)
    }
}

#Preview {
    NavigationStack {
        SignInView(email: "taf@example.com", onChangeEmail: {})
            .environmentObject(AuthSessionContext(authService: SupabaseAuthService()))
    }
}
