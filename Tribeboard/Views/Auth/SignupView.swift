import SwiftUI

struct SignUpView: View {
    let email: String
    var onChangeEmail: () -> Void

    @EnvironmentObject private var authSession: AuthSessionContext
    @State private var fullName = ""
    @State private var password = ""
    @FocusState private var isNameFocused: Bool
    @FocusState private var isPasswordFocused: Bool

    private var isCreateDisabled: Bool {
        fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Create your\naccount")
                    .font(.system(size: 24, weight: .heavy))
                    .foregroundStyle(LoginV3Theme.headline)
                    .padding(.bottom, 16)

                LoginV3EmailPill(email: email, onChangeEmail: onChangeEmail)
                    .padding(.bottom, 16)

                LoginV3BorderedField(
                    placeholder: "Full name",
                    text: $fullName,
                    textContentType: .name,
                    isFocused: $isNameFocused
                )
                .padding(.bottom, 12)

                LoginV3BorderedField(
                    placeholder: "Create password",
                    text: $password,
                    isSecure: true,
                    textContentType: .newPassword,
                    isFocused: $isPasswordFocused
                )
                .padding(.bottom, 16)

                LoginV3ContinueButton(
                    title: "Create Account",
                    isLoading: authSession.isLoading,
                    isDisabled: isCreateDisabled
                ) {
                    Task {
                        _ = await authSession.signUp(
                            email: email,
                            password: password,
                            displayName: fullName.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
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
        .ignoresSafeArea(.keyboard)
    }
}

#Preview {
    NavigationStack {
        SignUpView(email: "taf@example.com", onChangeEmail: {})
            .environmentObject(AuthSessionContext(authService: SupabaseAuthService()))
    }
}
