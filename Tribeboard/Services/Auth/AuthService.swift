import Foundation

struct AuthUserSession: Codable, Equatable {
    let accessToken: String
    let refreshToken: String?
    let userId: String
    let email: String?
    let expiresAt: Date?
    let authProvider: String?
    let providerDisplayName: String?

    var userUUID: UUID? {
        UUID(uuidString: userId)
    }
}

enum SignUpResult: Equatable {
    case session(AuthUserSession)
    case emailVerificationRequired(email: String)
}

enum EmailOTPVerificationType: String {
    case signup
    /// Fallback for some Supabase mail/OTP configurations when `signup` rejects a valid code.
    case email
    case emailChange = "email_change"
    case recovery
    case magiclink
}

protocol AuthService {
    func restoreSession() async throws -> AuthUserSession?
    func checkEmailExists(email: String) async throws -> Bool
    func signInWithEmailPassword(email: String, password: String) async throws -> AuthUserSession
    func signUpWithEmailPassword(email: String, password: String, displayName: String?) async throws -> SignUpResult
    func verifyEmailOTP(email: String, token: String, type: EmailOTPVerificationType) async throws -> AuthUserSession
    func resendSignupVerification(email: String) async throws
    func session(fromAuthCallback parsed: AuthCallbackURLParser.ParsedSession) async throws -> AuthUserSession
    func signInWithApple() async throws -> AuthUserSession
    func signInWithGoogle() async throws -> AuthUserSession
    func signOut(currentSession: AuthUserSession?) async throws
}

final class SupabaseAuthService: AuthService {
    enum AuthError: LocalizedError {
        case backendNotConfigured
        case invalidCredentials
        case invalidOrExpiredOTP
        case emailAlreadyConfirmed
        case signUpRequiresEmailConfirmation
        case signInWithAppleNotConfigured
        case signInWithAppleFailed
        case signInWithGoogleNotConfigured
        case signInWithGoogleFailed
        case networkFailure
        case sessionExpired
        /// `auth-check` is undeployed or otherwise unreachable. Not a statement about the email.
        case emailCheckUnavailable
        case unknown(String)

        var errorDescription: String? {
            switch self {
            case .backendNotConfigured:
                return "Backend is not configured. Add SUPABASE_URL and SUPABASE_ANON_KEY."
            case .invalidCredentials:
                return "Invalid email or password."
            case .invalidOrExpiredOTP:
                return "Invalid or expired code. Please request a new one."
            case .emailAlreadyConfirmed:
                return "This email is already confirmed. Try signing in."
            case .signUpRequiresEmailConfirmation:
                return "Account created. Check your email to confirm your account before signing in."
            case .signInWithAppleNotConfigured:
                return "Apple sign-in is not available for this build."
            case .signInWithAppleFailed:
                return "Apple sign-in could not be completed. Please try again."
            case .signInWithGoogleNotConfigured:
                return "Google sign-in is not available for this build."
            case .signInWithGoogleFailed:
                return "Google sign-in could not be completed. Please try again."
            case .networkFailure:
                return "Could not reach the server. Check your connection and try again."
            case .sessionExpired:
                return "Your session expired. Please sign in again, then try saving the run."
            case .emailCheckUnavailable:
                return EmailExistenceCheckMapper.unavailableUserMessage
            case .unknown(let message):
                return message
            }
        }
    }

    private struct Storage {
        static let key = "tb.auth.session.v1"
    }

    private struct AuthTokenResponse: Decodable {
        let access_token: String?
        let refresh_token: String?
        let expires_in: Int?
        let user: UserPayload?

        struct UserPayload: Decodable {
            let id: String
            let email: String?
        }
    }

    private struct AuthErrorResponse: Decodable {
        let msg: String?
        let error_description: String?
        let message: String?
        let error_code: String?
        let code: Int?
        let error: String?
    }

    private struct VerifyOTPRequestBody: Encodable {
        let email: String
        let token: String
        let type: String
    }

    private struct UserResponse: Decodable {
        let id: String
        let email: String?
    }

    private let userDefaults: UserDefaults
    private let profileService: BackendProfileService
    private let appleSignInService: AppleSignInService
    private let googleSignInService: GoogleSignInService
    private let urlSession: URLSession

    init(
        userDefaults: UserDefaults = .standard,
        profileService: BackendProfileService = SupabaseProfileService(),
        appleSignInService: AppleSignInService = AppleSignInService(),
        googleSignInService: GoogleSignInService = GoogleSignInService(),
        urlSession: URLSession = .shared
    ) {
        self.userDefaults = userDefaults
        self.profileService = profileService
        self.appleSignInService = appleSignInService
        self.googleSignInService = googleSignInService
        self.urlSession = urlSession
    }

    func restoreSession() async throws -> AuthUserSession? {
        guard let saved = loadSavedSession() else { return nil }
        if let expiry = saved.expiresAt, expiry <= Date() {
            return try await refreshExpiredSession(saved)
        }

        guard let user = try? await fetchUser(accessToken: saved.accessToken) else {
            // Network/backend might be unavailable. Keep cached session for local continuity.
            return saved
        }

        let refreshed = AuthUserSession(
            accessToken: saved.accessToken,
            refreshToken: saved.refreshToken,
            userId: user.id,
            email: user.email ?? saved.email,
            expiresAt: saved.expiresAt,
            authProvider: saved.authProvider,
            providerDisplayName: saved.providerDisplayName
        )
        saveSession(refreshed)
        return refreshed
    }

    private func refreshExpiredSession(_ saved: AuthUserSession) async throws -> AuthUserSession? {
        guard let refreshToken = saved.refreshToken?.trimmingCharacters(in: .whitespacesAndNewlines),
              !refreshToken.isEmpty else {
            clearSavedSession()
            return nil
        }
        guard BackendConfig.isSupabaseConfigured else {
            throw AuthError.backendNotConfigured
        }

        let url = try SupabaseClientProvider.authURL(
            path: "token",
            queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")]
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = try SupabaseClientProvider.defaultHeaders()
        request.httpBody = try JSONEncoder().encode(["refresh_token": refreshToken])

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await urlSession.data(for: request)
        } catch {
#if DEBUG
            NSLog("[Auth] expired session refresh failed network error=%@", error.localizedDescription)
#endif
            throw AuthError.networkFailure
        }
        guard let http = response as? HTTPURLResponse else {
            throw AuthError.unknown("Invalid auth response.")
        }
        guard (200..<300).contains(http.statusCode) else {
#if DEBUG
            let body = String(data: data, encoding: .utf8) ?? ""
            NSLog("[Auth] expired session refresh failed status=%d body=%@", http.statusCode, body)
#endif
            clearSavedSession()
            throw AuthError.sessionExpired
        }

        let tokenResponse = try JSONDecoder().decode(AuthTokenResponse.self, from: data)
        guard let accessToken = tokenResponse.access_token?.trimmingCharacters(in: .whitespacesAndNewlines),
              !accessToken.isEmpty else {
            clearSavedSession()
            throw AuthError.sessionExpired
        }

        let resolvedUser: UserResponse
        if let user = tokenResponse.user {
            resolvedUser = UserResponse(id: user.id, email: user.email)
        } else {
            resolvedUser = try await fetchUser(accessToken: accessToken)
        }

        let refreshed = AuthUserSession(
            accessToken: accessToken,
            refreshToken: tokenResponse.refresh_token ?? saved.refreshToken,
            userId: resolvedUser.id,
            email: resolvedUser.email ?? saved.email,
            expiresAt: tokenResponse.expires_in.map { Date().addingTimeInterval(TimeInterval($0)) } ?? saved.expiresAt,
            authProvider: saved.authProvider,
            providerDisplayName: saved.providerDisplayName
        )
        saveSession(refreshed)
#if DEBUG
        NSLog("[Auth] expired session refreshed userId=%@", refreshed.userId)
#endif
        return refreshed
    }

    func checkEmailExists(email: String) async throws -> Bool {
        guard BackendConfig.isSupabaseConfigured else {
            throw AuthError.backendNotConfigured
        }
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedEmail.isEmpty, normalizedEmail.contains("@") else {
            throw AuthError.unknown("Enter a valid email address.")
        }

        let url = try SupabaseClientProvider.functionsURL(path: "auth-check")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = try SupabaseClientProvider.defaultHeaders()
        request.httpBody = try JSONEncoder().encode(["email": normalizedEmail])

        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await performAuthRequest(request)
        } catch {
            switch EmailExistenceCheckMapper.mapTransportError(error) {
            case .unavailable:
                throw AuthError.emailCheckUnavailable
            case .failed(let message):
                throw AuthError.unknown(message)
            case .exists, .doesNotExist:
                throw AuthError.emailCheckUnavailable
            }
        }

        switch EmailExistenceCheckMapper.mapHTTP(statusCode: response.statusCode, body: data) {
        case .exists:
            return true
        case .doesNotExist:
            return false
        case .unavailable:
#if DEBUG
            NSLog("[Auth] auth-check unavailable status=%d", response.statusCode)
#endif
            throw AuthError.emailCheckUnavailable
        case .failed(let message):
            throw AuthError.unknown(message)
        }
    }

    func signInWithEmailPassword(email: String, password: String) async throws -> AuthUserSession {
        guard BackendConfig.isSupabaseConfigured else {
            throw AuthError.backendNotConfigured
        }
        let url = try SupabaseClientProvider.authURL(
            path: "token",
            queryItems: [URLQueryItem(name: "grant_type", value: "password")]
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = try SupabaseClientProvider.defaultHeaders()
        request.httpBody = try JSONEncoder().encode([
            "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
            "password": password
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AuthError.unknown("Invalid auth response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw mapAuthError(data: data, statusCode: http.statusCode)
        }

        let tokenResponse = try JSONDecoder().decode(AuthTokenResponse.self, from: data)
        guard let accessToken = tokenResponse.access_token,
              let user = tokenResponse.user else {
            throw AuthError.unknown("Authentication succeeded but session payload was incomplete.")
        }
        let expiry = tokenResponse.expires_in.map { Date().addingTimeInterval(TimeInterval($0)) }
        let session = AuthUserSession(
            accessToken: accessToken,
            refreshToken: tokenResponse.refresh_token,
            userId: user.id,
            email: user.email,
            expiresAt: expiry,
            authProvider: "email",
            providerDisplayName: nil
        )
        saveSession(session)
        try? await profileService.ensureProfileExists(for: session)
        return session
    }

    func signUpWithEmailPassword(email: String, password: String, displayName: String? = nil) async throws -> SignUpResult {
        guard BackendConfig.isSupabaseConfigured else {
            throw AuthError.backendNotConfigured
        }
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedDisplayName = displayName?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let url = try SupabaseClientProvider.authURL(path: "signup")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = try SupabaseClientProvider.defaultHeaders()
        let redirectTo = AuthRedirectConfig.emailConfirmationRedirectTo
        request.httpBody = try JSONEncoder().encode(SignUpRequestBody(
            email: normalizedEmail,
            password: password,
            options: SignUpRequestBody.Options(
                emailRedirectTo: redirectTo,
                data: normalizedDisplayName.map { SignUpRequestBody.UserMetadata(fullName: $0) }
            )
        ))
#if DEBUG
        AuthDebugLog.signupRedirect(emailRedirectTo: redirectTo)
#endif

        let (data, response) = try await performAuthRequest(request)
        guard (200..<300).contains(response.statusCode) else {
            throw mapAuthError(data: data, statusCode: response.statusCode)
        }

        let signUpResponse = try JSONDecoder().decode(AuthTokenResponse.self, from: data)
        if let accessToken = signUpResponse.access_token,
           let user = signUpResponse.user {
            let session = try await finalizeSession(
                accessToken: accessToken,
                refreshToken: signUpResponse.refresh_token,
                expiresIn: signUpResponse.expires_in,
                userId: user.id,
                email: user.email ?? normalizedEmail,
                authProvider: "email",
                providerDisplayName: normalizedDisplayName
            )
            return .session(session)
        }

        if signUpResponse.user != nil {
            return .emailVerificationRequired(email: normalizedEmail)
        }

        return .emailVerificationRequired(email: normalizedEmail)
    }

    func verifyEmailOTP(email: String, token: String, type: EmailOTPVerificationType) async throws -> AuthUserSession {
        guard BackendConfig.isSupabaseConfigured else {
            throw AuthError.backendNotConfigured
        }
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedToken = EmailOTPCodeNormalizer.normalize(token)
        guard !normalizedEmail.isEmpty else {
            throw AuthError.unknown("Email is required for verification.")
        }
        guard EmailOTPCodeNormalizer.isValidLength(normalizedToken) else {
            throw AuthError.invalidOrExpiredOTP
        }

        var verifyTypes: [EmailOTPVerificationType] = [type]
        if type == .signup {
            verifyTypes.append(.email)
        }

        var lastError: Error = AuthError.invalidOrExpiredOTP
        for (index, verifyType) in verifyTypes.enumerated() {
            do {
                return try await performVerifyOTPRequest(
                    email: normalizedEmail,
                    token: normalizedToken,
                    type: verifyType
                )
            } catch let error as AuthError {
                lastError = error
                let canRetryWithNextType = index < verifyTypes.count - 1
                if canRetryWithNextType, case .invalidOrExpiredOTP = error {
#if DEBUG
                    AuthDebugLog.verifyFallback(
                        from: verifyType.rawValue,
                        to: verifyTypes[index + 1].rawValue
                    )
#endif
                    continue
                }
                throw error
            } catch {
                lastError = error
                throw error
            }
        }
        throw lastError
    }

    private func performVerifyOTPRequest(
        email: String,
        token: String,
        type: EmailOTPVerificationType
    ) async throws -> AuthUserSession {
        let verifyURL = try SupabaseClientProvider.authURL(path: "verify")
#if DEBUG
        AuthDebugLog.verifyRequest(
            email: email,
            normalizedOTP: token,
            verifyType: type.rawValue,
            endpoint: verifyURL.absoluteString
        )
#endif

        var request = URLRequest(url: verifyURL)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = try SupabaseClientProvider.defaultHeaders()
        let body = VerifyOTPRequestBody(
            email: email,
            token: token,
            type: type.rawValue
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await performAuthRequest(request)
#if DEBUG
        AuthDebugLog.verifyResponse(statusCode: response.statusCode, data: data)
#endif
        guard (200..<300).contains(response.statusCode) else {
            throw mapVerifyError(data: data, statusCode: response.statusCode)
        }

        let tokenResponse = try JSONDecoder().decode(AuthTokenResponse.self, from: data)
        guard let accessToken = tokenResponse.access_token else {
            throw AuthError.unknown("Verification succeeded but session payload was incomplete.")
        }

        let resolvedUser: UserResponse
        if let user = tokenResponse.user {
            resolvedUser = UserResponse(id: user.id, email: user.email)
        } else {
            resolvedUser = try await fetchUser(accessToken: accessToken)
        }

        return try await finalizeSession(
            accessToken: accessToken,
            refreshToken: tokenResponse.refresh_token,
            expiresIn: tokenResponse.expires_in,
            userId: resolvedUser.id,
            email: resolvedUser.email ?? email,
            authProvider: "email",
            providerDisplayName: nil
        )
    }

    func resendSignupVerification(email: String) async throws {
        guard BackendConfig.isSupabaseConfigured else {
            throw AuthError.backendNotConfigured
        }
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let url = try SupabaseClientProvider.authURL(path: "resend")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = try SupabaseClientProvider.defaultHeaders()
        let redirectTo = AuthRedirectConfig.emailConfirmationRedirectTo
        request.httpBody = try JSONEncoder().encode(ResendRequestBody(
            type: EmailOTPVerificationType.signup.rawValue,
            email: normalizedEmail,
            options: ResendRequestBody.Options(
                emailRedirectTo: redirectTo
            )
        ))
#if DEBUG
        AuthDebugLog.resendAttempt(email: normalizedEmail)
        AuthDebugLog.signupRedirect(emailRedirectTo: redirectTo)
#endif

        let (data, response) = try await performAuthRequest(request)
#if DEBUG
        AuthDebugLog.verifyResponse(statusCode: response.statusCode, data: data)
#endif
        guard (200..<300).contains(response.statusCode) else {
            throw mapResendError(data: data, statusCode: response.statusCode)
        }
    }

    func session(fromAuthCallback parsed: AuthCallbackURLParser.ParsedSession) async throws -> AuthUserSession {
        guard BackendConfig.isSupabaseConfigured else {
            throw AuthError.backendNotConfigured
        }
        let user = try await fetchUser(accessToken: parsed.accessToken)
        return try await finalizeSession(
            accessToken: parsed.accessToken,
            refreshToken: parsed.refreshToken,
            expiresIn: parsed.expiresIn,
            userId: user.id,
            email: user.email,
            authProvider: "email",
            providerDisplayName: nil
        )
    }

    func signInWithApple() async throws -> AuthUserSession {
        guard BackendConfig.isSupabaseConfigured else {
            throw AuthError.backendNotConfigured
        }

        let appleResult: AppleSignInResult
        do {
            appleResult = try await appleSignInService.beginSignIn()
        } catch {
            if let appleError = error as? AppleSignInService.AppleSignInError {
                switch appleError {
                case .presentationAnchorUnavailable:
                    throw AuthError.signInWithAppleNotConfigured
                case .cancelled:
                    throw AuthError.unknown("Apple sign-in was cancelled.")
                default:
                    throw AuthError.signInWithAppleFailed
                }
            }
            throw AuthError.signInWithAppleFailed
        }

        let url = try SupabaseClientProvider.authURL(
            path: "token",
            queryItems: [URLQueryItem(name: "grant_type", value: "id_token")]
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = try SupabaseClientProvider.defaultHeaders()
        request.httpBody = try JSONEncoder().encode([
            "provider": "apple",
            "id_token": appleResult.identityToken,
            "nonce": appleResult.nonce
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AuthError.unknown("Invalid auth response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw mapAuthError(data: data, statusCode: http.statusCode)
        }

        let tokenResponse = try JSONDecoder().decode(AuthTokenResponse.self, from: data)
        guard let accessToken = tokenResponse.access_token,
              let user = tokenResponse.user else {
            throw AuthError.signInWithAppleFailed
        }
        let expiry = tokenResponse.expires_in.map { Date().addingTimeInterval(TimeInterval($0)) }
        let displayName = formattedDisplayName(from: appleResult.fullName)
        let session = AuthUserSession(
            accessToken: accessToken,
            refreshToken: tokenResponse.refresh_token,
            userId: user.id,
            email: user.email ?? appleResult.email,
            expiresAt: expiry,
            authProvider: "apple",
            providerDisplayName: displayName
        )
        saveSession(session)
        try? await profileService.ensureProfileExists(
            for: session,
            emailOverride: appleResult.email,
            displayNameOverride: displayName
        )
        return session
    }

    func signInWithGoogle() async throws -> AuthUserSession {
        guard BackendConfig.isSupabaseConfigured else {
            throw AuthError.backendNotConfigured
        }
        if !GoogleSignInConfig.isFullyConfiguredForSupabase {
#if DEBUG
            NSLog("[Auth] GOOGLE_WEB_CLIENT_ID is missing — Supabase Google sign-in may fail until it is set in Secrets.xcconfig.")
#endif
        }

        let googleResult: GoogleSignInResult
        do {
            googleResult = try await googleSignInService.beginSignIn()
        } catch {
            if let googleError = error as? GoogleSignInService.GoogleSignInError {
                switch googleError {
                case .notConfigured, .presentationUnavailable:
                    throw AuthError.signInWithGoogleNotConfigured
                case .cancelled:
                    throw AuthError.unknown("Google sign-in was cancelled.")
                case .failed(let message):
                    throw AuthError.unknown(message)
                default:
                    throw AuthError.signInWithGoogleFailed
                }
            }
            throw AuthError.signInWithGoogleFailed
        }

        var tokenBody: [String: String] = [
            "provider": "google",
            "id_token": googleResult.idToken
        ]
        if let accessToken = googleResult.accessToken, !accessToken.isEmpty {
            tokenBody["access_token"] = accessToken
        }

        let url = try SupabaseClientProvider.authURL(
            path: "token",
            queryItems: [URLQueryItem(name: "grant_type", value: "id_token")]
        )
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = try SupabaseClientProvider.defaultHeaders()
        request.httpBody = try JSONSerialization.data(withJSONObject: tokenBody)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AuthError.unknown("Invalid auth response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw mapGoogleIdTokenAuthError(data: data, statusCode: http.statusCode)
        }

        let tokenResponse = try JSONDecoder().decode(AuthTokenResponse.self, from: data)
        guard let accessToken = tokenResponse.access_token,
              let user = tokenResponse.user else {
            throw AuthError.signInWithGoogleFailed
        }
        let expiry = tokenResponse.expires_in.map { Date().addingTimeInterval(TimeInterval($0)) }
        let displayName = googleResult.fullName
        let session = AuthUserSession(
            accessToken: accessToken,
            refreshToken: tokenResponse.refresh_token,
            userId: user.id,
            email: user.email ?? googleResult.email,
            expiresAt: expiry,
            authProvider: "google",
            providerDisplayName: displayName
        )
        saveSession(session)
        try? await profileService.ensureProfileExists(
            for: session,
            emailOverride: googleResult.email,
            displayNameOverride: displayName,
            avatarURLOverride: googleResult.avatarURL?.absoluteString
        )
        return session
    }

    func signOut(currentSession: AuthUserSession?) async throws {
        guard let session = currentSession else {
            clearSavedSession()
            return
        }

        if BackendConfig.isSupabaseConfigured,
           let url = try? SupabaseClientProvider.authURL(path: "logout") {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.allHTTPHeaderFields = try? SupabaseClientProvider.defaultHeaders(accessToken: session.accessToken)
            _ = try? await URLSession.shared.data(for: request)
        }
        clearSavedSession()
    }

    private func fetchUser(accessToken: String) async throws -> UserResponse {
        let url = try SupabaseClientProvider.authURL(path: "user")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = try SupabaseClientProvider.defaultHeaders(accessToken: accessToken)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw AuthError.unknown("Unable to validate session.")
        }
        return try JSONDecoder().decode(UserResponse.self, from: data)
    }

    private struct SignUpRequestBody: Encodable {
        struct UserMetadata: Encodable {
            let fullName: String

            enum CodingKeys: String, CodingKey {
                case fullName = "full_name"
            }
        }

        struct Options: Encodable {
            let emailRedirectTo: String
            let data: UserMetadata?

            enum CodingKeys: String, CodingKey {
                case emailRedirectTo = "email_redirect_to"
                case data
            }
        }

        let email: String
        let password: String
        let options: Options
    }

    private struct ResendRequestBody: Encodable {
        struct Options: Encodable {
            let emailRedirectTo: String

            enum CodingKeys: String, CodingKey {
                case emailRedirectTo = "email_redirect_to"
            }
        }

        let type: String
        let email: String
        let options: Options
    }

    private func performAuthRequest(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AuthError.networkFailure
        }
        guard let http = response as? HTTPURLResponse else {
            throw AuthError.unknown("Invalid auth response.")
        }
        return (data, http)
    }

    private func finalizeSession(
        accessToken: String,
        refreshToken: String?,
        expiresIn: Int?,
        userId: String,
        email: String?,
        authProvider: String,
        providerDisplayName: String?
    ) async throws -> AuthUserSession {
        let expiry = expiresIn.map { Date().addingTimeInterval(TimeInterval($0)) }
        let session = AuthUserSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            userId: userId,
            email: email,
            expiresAt: expiry,
            authProvider: authProvider,
            providerDisplayName: providerDisplayName
        )
        saveSession(session)
        try? await profileService.ensureProfileExists(for: session)
        return session
    }

    private func mapAuthError(data: Data, statusCode: Int) -> Error {
        if statusCode == 400 || statusCode == 401 {
            return AuthError.invalidCredentials
        }
        if let decoded = try? JSONDecoder().decode(AuthErrorResponse.self, from: data) {
            let message = decoded.msg ?? decoded.error_description ?? decoded.message
            if let message, !message.isEmpty {
                return AuthError.unknown(message)
            }
        }
        return AuthError.unknown("Authentication failed (\(statusCode)).")
    }

    private func mapGoogleIdTokenAuthError(data: Data, statusCode: Int) -> Error {
        let message = authErrorMessage(from: data)
#if DEBUG
        if let message, !message.isEmpty {
            NSLog("[Auth] Google id_token exchange failed (\(statusCode)): \(message)")
        } else {
            NSLog("[Auth] Google id_token exchange failed (\(statusCode)).")
        }
#endif
        let lowered = message?.lowercased() ?? ""
        if lowered.contains("nonce") || lowered.contains("both exist or not") {
            return AuthError.unknown(
                "Google sign-in failed: Supabase rejected the Google ID token nonce. In Supabase Dashboard → Authentication → Providers → Google, turn on “Skip nonce check”, then try again."
            )
        }
        if lowered.contains("audience")
            || lowered.contains("client")
            || lowered.contains("issuer")
            || lowered.contains("oidc") {
            return AuthError.unknown(
                "Google sign-in failed: client ID mismatch. Add your Web and iOS Google client IDs in Supabase (web first, comma-separated) and set GOOGLE_WEB_CLIENT_ID in Secrets.xcconfig."
            )
        }
        if let message, !message.isEmpty {
            return AuthError.unknown("Google sign-in failed: \(message)")
        }
        return AuthError.signInWithGoogleFailed
    }

    private func mapVerifyError(data: Data, statusCode: Int) -> Error {
        if statusCode >= 500 {
            return AuthError.networkFailure
        }
        let decoded = try? JSONDecoder().decode(AuthErrorResponse.self, from: data)
        let message = authErrorMessage(from: data)
        let lowered = message?.lowercased() ?? ""
        let errorCode = decoded?.error_code?.lowercased() ?? ""

        if errorCode.contains("otp_expired") || lowered.contains("expired") {
            return AuthError.invalidOrExpiredOTP
        }
        if errorCode.contains("otp_disabled") || errorCode.contains("validation") {
            return AuthError.invalidOrExpiredOTP
        }
        if errorCode.contains("invalid") && errorCode.contains("otp") {
            return AuthError.invalidOrExpiredOTP
        }
        if lowered.contains("already") && (lowered.contains("confirm") || lowered.contains("verified")) {
            return AuthError.emailAlreadyConfirmed
        }
        if statusCode == 400 || statusCode == 401 || statusCode == 403 || statusCode == 422 {
            return AuthError.invalidOrExpiredOTP
        }
        if let message, !message.isEmpty {
            return AuthError.unknown(message)
        }
        return AuthError.invalidOrExpiredOTP
    }

    private func mapResendError(data: Data, statusCode: Int) -> Error {
        let message = authErrorMessage(from: data)
        let lowered = message?.lowercased() ?? ""
        if lowered.contains("already") && (lowered.contains("confirm") || lowered.contains("verified")) {
            return AuthError.emailAlreadyConfirmed
        }
        if statusCode >= 500 {
            return AuthError.networkFailure
        }
        if let message, !message.isEmpty {
            return AuthError.unknown(message)
        }
        return AuthError.unknown("Could not resend verification code (\(statusCode)).")
    }

    private func authErrorMessage(from data: Data) -> String? {
        guard let decoded = try? JSONDecoder().decode(AuthErrorResponse.self, from: data) else {
            return nil
        }
        if let errorCode = decoded.error_code, !errorCode.isEmpty {
            if let message = decoded.msg ?? decoded.error_description ?? decoded.message, !message.isEmpty {
                return "\(errorCode): \(message)"
            }
            return errorCode
        }
        return decoded.msg ?? decoded.error_description ?? decoded.message ?? decoded.error
    }

    private func loadSavedSession() -> AuthUserSession? {
        guard let data = userDefaults.data(forKey: Storage.key) else { return nil }
        return try? JSONDecoder().decode(AuthUserSession.self, from: data)
    }

    private func saveSession(_ session: AuthUserSession) {
        if let data = try? JSONEncoder().encode(session) {
            userDefaults.set(data, forKey: Storage.key)
        }
    }

    private func clearSavedSession() {
        userDefaults.removeObject(forKey: Storage.key)
    }

    private func formattedDisplayName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let formatter = PersonNameComponentsFormatter()
        formatter.style = .default
        let value = formatter.string(from: components).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

protocol BackendProfileService {
    func ensureProfileExists(
        for session: AuthUserSession,
        emailOverride: String?,
        displayNameOverride: String?,
        avatarURLOverride: String?
    ) async throws
}

extension BackendProfileService {
    func ensureProfileExists(for session: AuthUserSession) async throws {
        try await ensureProfileExists(for: session, emailOverride: nil, displayNameOverride: nil, avatarURLOverride: nil)
    }

    func ensureProfileExists(
        for session: AuthUserSession,
        emailOverride: String?,
        displayNameOverride: String?
    ) async throws {
        try await ensureProfileExists(
            for: session,
            emailOverride: emailOverride,
            displayNameOverride: displayNameOverride,
            avatarURLOverride: nil
        )
    }
}

struct SupabaseProfileService: BackendProfileService {
    private enum ProfileServiceError: LocalizedError {
        case invalidUserId
        case requestFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidUserId:
                return "Authenticated user id is not a valid UUID."
            case .requestFailed(let message):
                return message
            }
        }
    }

    private struct BackendProfileRecord: Decodable {
        let id: UUID
        let email: String?
        let display_name: String?
        let first_name: String?
        let last_name: String?
        let avatar_url: String?
    }

    func ensureProfileExists(
        for session: AuthUserSession,
        emailOverride: String? = nil,
        displayNameOverride: String? = nil,
        avatarURLOverride: String? = nil
    ) async throws {
        guard BackendConfig.isSupabaseConfigured else { return }
        guard let userId = session.userUUID else {
            throw ProfileServiceError.invalidUserId
        }
        let normalizedProviderName = displayNameOverride?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let normalizedEmail = (emailOverride ?? session.email)?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let normalizedAvatarURL = avatarURLOverride?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let existing = try await fetchProfile(id: userId, accessToken: session.accessToken)
        if let existing {
            let shouldUpdateDisplayName = (existing.display_name?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty == nil)
                && normalizedProviderName != nil
            let shouldUpdateEmail = (existing.email?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty == nil)
                && normalizedEmail != nil
            let shouldUpdateAvatar = (existing.avatar_url?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty == nil)
                && normalizedAvatarURL != nil
            guard shouldUpdateDisplayName || shouldUpdateEmail || shouldUpdateAvatar else { return }
            var patchPayload: [String: String] = [:]
            if shouldUpdateDisplayName, let normalizedProviderName {
                patchPayload["display_name"] = normalizedProviderName
            }
            if shouldUpdateEmail, let normalizedEmail {
                patchPayload["email"] = normalizedEmail
            }
            if shouldUpdateAvatar, let normalizedAvatarURL {
                patchPayload["avatar_url"] = normalizedAvatarURL
            }
            try await patchProfile(id: userId, payload: patchPayload, accessToken: session.accessToken)
            return
        }

        try await createProfile(
            id: userId,
            email: normalizedEmail,
            displayName: normalizedProviderName,
            avatarURL: normalizedAvatarURL,
            accessToken: session.accessToken
        )
    }

    private func fetchProfile(id: UUID, accessToken: String) async throws -> BackendProfileRecord? {
        let url = try SupabaseClientProvider.restURL(path: "profiles?select=id,email,display_name,first_name,last_name,avatar_url&id=eq.\(id.uuidString)&limit=1")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.allHTTPHeaderFields = try SupabaseClientProvider.defaultHeaders(accessToken: accessToken)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ProfileServiceError.requestFailed("Invalid profile response.")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw ProfileServiceError.requestFailed("Profile fetch failed (\(http.statusCode)).")
        }
        let records = try JSONDecoder().decode([BackendProfileRecord].self, from: data)
        return records.first
    }

    private func createProfile(
        id: UUID,
        email: String?,
        displayName: String?,
        avatarURL: String?,
        accessToken: String
    ) async throws {
        let url = try SupabaseClientProvider.restURL(path: "profiles")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        var headers = try SupabaseClientProvider.defaultHeaders(accessToken: accessToken)
        headers["Prefer"] = "resolution=merge-duplicates,return=minimal"
        request.allHTTPHeaderFields = headers
        let payload: [[String: String?]] = [[
            "id": id.uuidString,
            "email": email,
            "display_name": displayName,
            "avatar_url": avatarURL
        ]]
        request.httpBody = try JSONEncoder().encode(payload)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ProfileServiceError.requestFailed("Profile create failed.")
        }
    }

    private func patchProfile(id: UUID, payload: [String: String], accessToken: String) async throws {
        guard !payload.isEmpty else { return }
        let url = try SupabaseClientProvider.restURL(path: "profiles?id=eq.\(id.uuidString)")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        var headers = try SupabaseClientProvider.defaultHeaders(accessToken: accessToken)
        headers["Prefer"] = "return=minimal"
        request.allHTTPHeaderFields = headers
        request.httpBody = try JSONEncoder().encode(payload)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw ProfileServiceError.requestFailed("Profile update failed.")
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
