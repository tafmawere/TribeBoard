import SwiftUI

enum LoginRoute: Hashable {
    case signIn(email: String)
    case signUp(email: String)
}

struct LoginSheetView: View {
    @EnvironmentObject private var authSession: AuthSessionContext
    @State private var email = ""
    @State private var navigationPath = NavigationPath()
    @State private var isCheckingEmail = false
    @State private var localError: String?
    @FocusState private var isEmailFocused: Bool

    private var normalizedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            GeometryReader { geometry in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        headerBlock

                        Spacer().frame(height: 40)

                        formBlock

                        footerBlock
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: 440)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .background(Color.white)
            .navigationDestination(for: LoginRoute.self) { route in
                switch route {
                case .signIn(let email):
                    SignInView(email: email) {
                        if !navigationPath.isEmpty {
                            navigationPath.removeLast()
                        }
                    }
                case .signUp(let email):
                    SignUpView(email: email) {
                        if !navigationPath.isEmpty {
                            navigationPath.removeLast()
                        }
                    }
                }
            }
        }
        .background(Color.white)
        .ignoresSafeArea(.keyboard)
    }

    private var headerBlock: some View {
        VStack(spacing: 0) {
            LoginV3AppIcon()
                .padding(.bottom, 28)

            Text("Log in or sign up")
                .font(.system(size: 22, weight: .heavy))
                .foregroundStyle(LoginV3Theme.headline)
                .multilineTextAlignment(.center)
                .padding(.bottom, 4)

            Text("Welcome to TribeBoard")
                .font(.system(size: 13))
                .foregroundStyle(LoginV3Theme.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 32)
    }

    private var formBlock: some View {
        VStack(spacing: 0) {
            LoginV3EmailField(
                placeholder: "Email or phone number",
                text: $email,
                isFocused: $isEmailFocused
            )
            .padding(.bottom, 12)

            LoginV3ContinueButton(
                title: "Continue",
                isLoading: isCheckingEmail || authSession.isLoading
            ) {
                continueTapped()
            }
            .padding(.bottom, 16)

            if let localError, !localError.isEmpty {
                AuthInlineErrorView(message: localError)
                    .padding(.bottom, 12)
            } else if let error = authSession.lastError, !error.isEmpty {
                AuthInlineErrorView(message: error)
                    .padding(.bottom, 12)
            }

            LoginV3OrDivider()
                .padding(.bottom, 16)

            LoginV3GoogleContinueButton(isDisabled: authSession.isLoading) {
                Task { await authSession.signInWithGoogle() }
            }
            .padding(.bottom, 16)

            LoginV3AppleContinueButton(isDisabled: authSession.isLoading) {
                Task { await authSession.signInWithApple() }
            }
            .padding(.bottom, 24)
        }
    }

    private var footerBlock: some View {
        VStack(spacing: 12) {
            LoginV3LegalFooter()

            if !BackendConfig.isBackendConfigured {
                Text("Backend not configured. Set SUPABASE_URL and SUPABASE_ANON_KEY in app configuration.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(LoginV3Theme.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func continueTapped() {
        localError = nil
        authSession.lastError = nil

        guard !normalizedEmail.isEmpty else {
            localError = "Please enter your email."
            return
        }

        guard normalizedEmail.contains("@") else {
            localError = "Please enter a valid email address."
            return
        }

        isEmailFocused = false

        Task {
            isCheckingEmail = true
            defer { isCheckingEmail = false }
            do {
                let exists = try await authSession.checkEmailExists(email: normalizedEmail)
                if exists {
                    navigationPath.append(LoginRoute.signIn(email: normalizedEmail))
                } else {
                    navigationPath.append(LoginRoute.signUp(email: normalizedEmail))
                }
            } catch {
                localError = error.localizedDescription
            }
        }
    }
}

#Preview {
    LoginSheetView()
        .environmentObject(AuthSessionContext(authService: SupabaseAuthService()))
        .presentationDetents([.height(520), .large])
}
