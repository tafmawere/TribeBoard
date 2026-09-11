import Foundation
import Combine

@MainActor
final class AuthSessionContext: ObservableObject {
    @Published private(set) var currentUserId: String?
    @Published private(set) var currentUserEmail: String?
    @Published private(set) var currentUserProviderDisplayName: String?
    @Published private(set) var currentAuthProvider: String?
    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published var lastError: String?
    @Published var lastSuccessMessage: String?
    @Published private(set) var didRestoreSession: Bool = false
    @Published private(set) var pendingVerificationEmail: String?

    var currentAccessToken: String? {
        currentSession?.accessToken
    }

    private let authService: AuthService
    private let backendProfileContext: BackendProfileContext?
    private var currentSession: AuthUserSession?

    init(
        authService: AuthService,
        backendProfileContext: BackendProfileContext? = nil
    ) {
        self.authService = authService
        self.backendProfileContext = backendProfileContext
        pendingVerificationEmail = PendingEmailVerificationPersistence.load()
    }

    convenience init() {
        self.init(authService: SupabaseAuthService(), backendProfileContext: nil)
    }

    func restoreSession() async {
        isLoading = true
        defer {
            isLoading = false
            didRestoreSession = true
        }
        if pendingVerificationEmail == nil {
            pendingVerificationEmail = PendingEmailVerificationPersistence.load()
        }
        do {
            if let session = try await authService.restoreSession() {
                clearPendingVerification()
                apply(session: session)
                Task { [weak self] in
                    await self?.refreshProfile(for: session)
                }
            } else {
                clearState(keepPendingVerification: true)
            }
        } catch {
            clearState(keepPendingVerification: true)
            lastError = error.localizedDescription
        }
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        lastError = nil
        lastSuccessMessage = nil
        defer { isLoading = false }
        do {
            let session = try await authService.signInWithEmailPassword(email: email, password: password)
            clearPendingVerification()
            apply(session: session)
            Task { [weak self] in
                await self?.refreshProfile(for: session)
            }
        } catch {
            clearState(keepPendingVerification: true)
            lastError = error.localizedDescription
        }
    }

    func checkEmailExists(email: String) async throws -> Bool {
        lastError = nil
        return try await authService.checkEmailExists(email: email)
    }

    /// Returns `true` when the user should continue to the email verification screen.
    func signUp(email: String, password: String, displayName: String? = nil) async -> Bool {
        isLoading = true
        lastError = nil
        lastSuccessMessage = nil
        defer { isLoading = false }
        do {
            let result = try await authService.signUpWithEmailPassword(
                email: email,
                password: password,
                displayName: displayName
            )
            switch result {
            case .session(let session):
                clearPendingVerification()
                apply(session: session)
                Task { [weak self] in
                    await self?.refreshProfile(for: session)
                }
                return false
            case .emailVerificationRequired(let email):
                clearState(keepPendingVerification: true)
                setPendingVerification(email: email)
                return true
            }
        } catch {
            clearState(keepPendingVerification: true)
            lastError = error.localizedDescription
            return false
        }
    }

    func verifyEmailOTP(email: String, code: String) async {
        isLoading = true
        lastError = nil
        lastSuccessMessage = nil
        defer { isLoading = false }
        let verifyEmail = (pendingVerificationEmail ?? email)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !verifyEmail.isEmpty else {
            lastError = "Missing email for verification. Go back and sign up again."
            return
        }
        do {
            let session = try await authService.verifyEmailOTP(
                email: verifyEmail,
                token: code,
                type: .signup
            )
            clearPendingVerification()
            apply(session: session)
            Task { [weak self] in
                await self?.refreshProfile(for: session)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func resendVerificationCode(email: String) async {
        isLoading = true
        lastError = nil
        lastSuccessMessage = nil
        defer { isLoading = false }
        let resendEmail = (pendingVerificationEmail ?? email)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        do {
            try await authService.resendSignupVerification(email: resendEmail)
            setPendingVerification(email: resendEmail)
            lastSuccessMessage = "A new code has been sent."
        } catch {
            lastError = error.localizedDescription
        }
    }

    func applyAuthCallbackSession(_ parsed: AuthCallbackURLParser.ParsedSession) async {
        isLoading = true
        lastError = nil
        lastSuccessMessage = nil
        defer { isLoading = false }
        do {
            let session = try await authService.session(fromAuthCallback: parsed)
            clearPendingVerification()
            apply(session: session)
            lastSuccessMessage = "Email confirmed."
            Task { [weak self] in
                await self?.refreshProfile(for: session)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func cancelPendingVerification() {
        clearPendingVerification()
        lastError = nil
        lastSuccessMessage = nil
    }

    func signInWithApple() async {
        isLoading = true
        lastError = nil
        lastSuccessMessage = nil
        defer { isLoading = false }
        do {
            let session = try await authService.signInWithApple()
            clearPendingVerification()
            apply(session: session)
            Task { [weak self] in
                await self?.refreshProfile(for: session)
            }
        } catch {
            clearState(keepPendingVerification: true)
            lastError = error.localizedDescription
        }
    }

    func signInWithGoogle() async {
        isLoading = true
        lastError = nil
        lastSuccessMessage = nil
        defer { isLoading = false }
        do {
            let session = try await authService.signInWithGoogle()
            clearPendingVerification()
            apply(session: session)
            Task { [weak self] in
                await self?.refreshProfile(for: session)
            }
        } catch {
            clearState(keepPendingVerification: true)
            lastError = error.localizedDescription
        }
    }

    func signOut() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await authService.signOut(currentSession: currentSession)
        } catch {
            lastError = error.localizedDescription
        }
        clearPendingVerification()
        clearState(keepPendingVerification: false)
    }

    private func refreshProfile(for session: AuthUserSession) async {
        await backendProfileContext?.ensureProfileExists(
            email: session.email,
            providerDisplayName: session.providerDisplayName
        )
        await backendProfileContext?.refreshProfile(
            authEmail: session.email,
            providerDisplayName: session.providerDisplayName
        )
    }

    private func setPendingVerification(email: String) {
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        pendingVerificationEmail = normalized
        PendingEmailVerificationPersistence.save(email: normalized)
    }

    private func clearPendingVerification() {
        pendingVerificationEmail = nil
        PendingEmailVerificationPersistence.clear()
    }

    private func apply(session: AuthUserSession) {
        currentSession = session
        currentUserId = session.userId
        currentUserEmail = session.email
        currentUserProviderDisplayName = session.providerDisplayName
        currentAuthProvider = session.authProvider
        isAuthenticated = true
        lastError = nil
    }

    private func clearState(keepPendingVerification: Bool) {
        currentSession = nil
        currentUserId = nil
        currentUserEmail = nil
        currentUserProviderDisplayName = nil
        currentAuthProvider = nil
        isAuthenticated = false
        backendProfileContext?.reset()
        if !keepPendingVerification {
            clearPendingVerification()
        }
    }
}
