import Foundation
import AuthenticationServices
import SwiftData
import CryptoKit

/// Errors that can occur during authentication
enum AuthError: LocalizedError {
    case authorizationFailed
    case userCancelled
    case networkUnavailable
    case invalidCredentials
    case keychainError(Error)
    case dataServiceError(Error)
    case unknownError(Error)
    
    var errorDescription: String? {
        switch self {
        case .authorizationFailed:
            return "Authentication failed. Please try again."
        case .userCancelled:
            return "Sign in was cancelled."
        case .networkUnavailable:
            return "Network unavailable. Please check your connection."
        case .invalidCredentials:
            return "Invalid credentials received from Apple."
        case .keychainError(let error):
            return "Secure storage error: \(error.localizedDescription)"
        case .dataServiceError(let error):
            return "Data error: \(error.localizedDescription)"
        case .unknownError(let error):
            return "An unexpected error occurred: \(error.localizedDescription)"
        }
    }
}

/// Service for handling Apple authentication and user profile management
@MainActor
class AuthService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current authentication state
    @Published var isAuthenticated: Bool = false
    
    /// Current authenticated user profile
    @Published var currentUser: UserProfile?
    
    /// Loading state for authentication operations
    @Published var isLoading: Bool = false
    
    // MARK: - Dependencies
    
    private let keychainService: KeychainService
    private var dataService: DataService?
    
    // MARK: - Private Properties
    
    private var authorizationController: ASAuthorizationController?
    private var authContinuation: CheckedContinuation<ASAuthorization, Error>?
    
    // MARK: - Initialization
    
    init(keychainService: KeychainService = KeychainService()) {
        self.keychainService = keychainService
        super.init()
    }
    
    /// Set the data service (called by ServiceCoordinator)
    func setDataService(_ dataService: DataService) {
        self.dataService = dataService
        
        // Check for existing authentication after data service is set
        Task {
            await checkExistingAuthentication()
        }
    }
    
    // MARK: - Public Authentication Methods
    
    /// Sign in with Apple ID
    /// - Throws: AuthError if authentication fails
    func signInWithApple() async throws {
        // Check network connectivity before attempting authentication
        guard NetworkMonitor.shared.isNetworkAvailableForAuth() else {
            throw AuthError.networkUnavailable
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            let authorization = try await performAppleSignIn()
            let (userProfile, appleUserId) = try await processAuthorization(authorization)
            
            // Store authentication data securely
            try await storeAuthenticationData(userProfile, appleUserId: appleUserId)
            
            // Update authentication state
            currentUser = userProfile
            isAuthenticated = true
            
        } catch {
            // Handle specific error types
            if let authError = error as? AuthError {
                throw authError
            } else if let asError = error as? ASAuthorizationError {
                throw mapASAuthorizationError(asError)
            } else {
                // Check if error might be network-related
                if isNetworkError(error) {
                    throw AuthError.networkUnavailable
                }
                throw AuthError.unknownError(error)
            }
        }
    }
    
    /// Sign out current user
    func signOut() async throws {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Clear stored authentication data
            try keychainService.clearAll()
            
            // Update authentication state
            currentUser = nil
            isAuthenticated = false
            
        } catch {
            throw AuthError.keychainError(error)
        }
    }
    
    /// Get current authenticated user
    /// - Returns: Current user profile or nil if not authenticated
    func getCurrentUser() -> UserProfile? {
        return currentUser
    }
    
    /// Check if user is currently authenticated
    /// - Returns: True if user is authenticated, false otherwise
    func checkAuthenticationStatus() -> Bool {
        return isAuthenticated && currentUser != nil
    }
    
    // MARK: - Private Authentication Methods
    
    /// Check for existing authentication on app launch
    func checkExistingAuthentication() async {
        guard let dataService = dataService else { 
            print("🔍 AuthService: DataService not available for authentication check")
            return 
        }
        
        print("🔍 AuthService: Checking existing authentication...")
        
        do {
            // Try to retrieve stored Apple user identifier and hash
            guard let storedAppleUserId = try keychainService.retrieveAppleUserId(),
                  let storedHash = try keychainService.retrieveAppleUserIdHash() else {
                print("ℹ️ AuthService: No stored authentication credentials found")
                return
            }
            
            print("🔍 AuthService: Found stored credentials, verifying with Apple...")
            
            // Verify the credential is still valid with Apple
            let credentialState = await checkAppleIDCredentialState(storedAppleUserId)
            
            if credentialState == .authorized {
                print("✅ AuthService: Apple credentials are still valid")
                
                // Try to find user profile with stored hash
                if let userProfile = try dataService.fetchUserProfile(byAppleUserIdHash: storedHash) {
                    print("✅ AuthService: User profile found, restoring authentication state")
                    // User is still authenticated
                    await MainActor.run {
                        currentUser = userProfile
                        isAuthenticated = true
                    }
                } else {
                    print("❌ AuthService: User profile not found, clearing stored data")
                    // User profile not found, clear stored data
                    try keychainService.clearAll()
                }
            } else {
                print("❌ AuthService: Apple credentials are no longer valid (state: \(credentialState)), clearing stored data")
                // Credential is no longer valid, clear stored data
                try keychainService.clearAll()
            }
            
        } catch {
            print("❌ AuthService: Error checking existing authentication: \(error.localizedDescription)")
            // If there's any error checking authentication, clear stored data
            try? keychainService.clearAll()
        }
    }
    
    /// Perform Apple Sign In authorization
    private func performAppleSignIn() async throws -> ASAuthorization {
        return try await withCheckedThrowingContinuation { continuation in
            self.authContinuation = continuation
            
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            let request = appleIDProvider.createRequest()
            request.requestedScopes = [.fullName, .email]
            
            let authorizationController = ASAuthorizationController(authorizationRequests: [request])
            authorizationController.delegate = self
            authorizationController.presentationContextProvider = self
            
            self.authorizationController = authorizationController
            authorizationController.performRequests()
        }
    }
    
    /// Process the authorization result and create/retrieve user profile
    private func processAuthorization(_ authorization: ASAuthorization) async throws -> (UserProfile, String) {
        guard let dataService = dataService else {
            throw AuthError.dataServiceError(DataServiceError.invalidData("DataService not available"))
        }
        
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw AuthError.invalidCredentials
        }
        
        let appleUserId = appleIDCredential.user
        
        // Create hash from Apple user identifier for privacy
        let userIdHash = createUserIdHash(from: appleUserId)
        
        // Try to find existing user profile
        if let existingUser = try dataService.fetchUserProfile(byAppleUserIdHash: userIdHash) {
            return (existingUser, appleUserId)
        }
        
        // Create new user profile
        let displayName = extractDisplayName(from: appleIDCredential)
        
        do {
            let newUser = try dataService.createUserProfile(
                displayName: displayName,
                appleUserIdHash: userIdHash
            )
            return (newUser, appleUserId)
        } catch {
            throw AuthError.dataServiceError(error)
        }
    }
    
    /// Store authentication data securely
    private func storeAuthenticationData(_ userProfile: UserProfile, appleUserId: String) async throws {
        do {
            try keychainService.storeAppleUserId(appleUserId)
            try keychainService.storeAppleUserIdHash(userProfile.appleUserIdHash)
        } catch {
            throw AuthError.keychainError(error)
        }
    }
    
    /// Create a secure hash from Apple user identifier
    private func createUserIdHash(from userIdentifier: String) -> String {
        let inputData = Data(userIdentifier.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Extract display name from Apple ID credential
    private func extractDisplayName(from credential: ASAuthorizationAppleIDCredential) -> String {
        // Try to get full name from credential
        if let fullName = credential.fullName {
            let firstName = fullName.givenName ?? ""
            let lastName = fullName.familyName ?? ""
            
            if !firstName.isEmpty || !lastName.isEmpty {
                return "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
            }
        }
        
        // Fallback to email if available
        if let email = credential.email, !email.isEmpty {
            // Extract name part from email (before @)
            let emailComponents = email.components(separatedBy: "@")
            if let emailName = emailComponents.first, !emailName.isEmpty {
                return emailName.capitalized
            }
        }
        
        // Final fallback
        return "TribeBoard User"
    }
    
    /// Check Apple ID credential state
    private func checkAppleIDCredentialState(_ appleUserId: String) async -> ASAuthorizationAppleIDProvider.CredentialState {
        return await withCheckedContinuation { continuation in
            let appleIDProvider = ASAuthorizationAppleIDProvider()
            appleIDProvider.getCredentialState(forUserID: appleUserId) { credentialState, error in
                if let error = error {
                    print("❌ AuthService: Error checking Apple ID credential state: \(error.localizedDescription)")
                    // If there's an error, assume not authorized for safety
                    continuation.resume(returning: .notFound)
                } else {
                    print("ℹ️ AuthService: Apple ID credential state: \(credentialState)")
                    continuation.resume(returning: credentialState)
                }
            }
        }
    }
    
    /// Map ASAuthorizationError to AuthError
    private func mapASAuthorizationError(_ error: ASAuthorizationError) -> AuthError {
        switch error.code {
        case .canceled:
            return .userCancelled
        case .failed:
            return .authorizationFailed
        case .invalidResponse:
            return .invalidCredentials
        case .notHandled:
            return .authorizationFailed
        case .unknown:
            return .unknownError(error)
        case .notInteractive:
            return .authorizationFailed
        case .matchedExcludedCredential:
            return .invalidCredentials
        case .credentialImport:
            return .authorizationFailed
        case .credentialExport:
            return .authorizationFailed
        case .preferSignInWithApple:
            return .authorizationFailed
        case .deviceNotConfiguredForPasskeyCreation:
            return .authorizationFailed
        @unknown default:
            return .unknownError(error)
        }
    }
    
    /// Check if an error is likely network-related
    private func isNetworkError(_ error: Error) -> Bool {
        let nsError = error as NSError
        
        // Check for common network error domains and codes
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorTimedOut,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorCannotFindHost,
                 NSURLErrorDNSLookupFailed:
                return true
            default:
                return false
            }
        }
        
        // Check for other network-related error indicators
        let errorDescription = error.localizedDescription.lowercased()
        return errorDescription.contains("network") ||
               errorDescription.contains("internet") ||
               errorDescription.contains("connection") ||
               errorDescription.contains("offline")
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AuthService: ASAuthorizationControllerDelegate {
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        authContinuation?.resume(returning: authorization)
        authContinuation = nil
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        authContinuation?.resume(throwing: error)
        authContinuation = nil
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AuthService: ASAuthorizationControllerPresentationContextProviding {
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        // Get the key window for presentation
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window available for Apple Sign In presentation")
        }
        return window
    }
}