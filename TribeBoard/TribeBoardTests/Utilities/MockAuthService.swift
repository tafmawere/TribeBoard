import Foundation
import AuthenticationServices
@testable import TribeBoard

/// Mock implementation of AuthService for testing purposes
/// Provides configurable success/failure scenarios and state management
@MainActor
class MockAuthService: ObservableObject {
    
    // MARK: - Published Properties (matching AuthService)
    
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: UserProfile?
    @Published var isLoading: Bool = false
    
    // MARK: - Configuration Properties
    
    /// Controls whether authentication operations should succeed
    var shouldSucceed: Bool = true
    
    /// The error to throw when operations fail
    var errorToThrow: AuthError = .authorizationFailed
    
    /// Controls which specific operations should fail
    var failingOperations: Set<Operation> = []
    
    /// Simulated network availability
    var isNetworkAvailable: Bool = true
    
    /// Simulated Apple credential state
    var appleCredentialState: ASAuthorizationAppleIDProvider.CredentialState = .authorized
    
    /// Delay to simulate async operations
    var simulatedDelay: TimeInterval = 0.1
    
    // MARK: - Call Tracking
    
    private(set) var signInCallCount = 0
    private(set) var signOutCallCount = 0
    private(set) var checkAuthCallCount = 0
    private(set) var getCurrentUserCallCount = 0
    
    // MARK: - Mock Data
    
    /// Mock user profile to return on successful authentication
    var mockUserProfile: UserProfile?
    
    /// Mock Apple user ID for testing
    var mockAppleUserId: String = "mock.apple.user.id"
    
    /// Mock Apple user ID hash for testing
    var mockAppleUserIdHash: String = "mock_hash_value"
    
    // MARK: - Operation Types
    
    enum Operation {
        case signIn
        case signOut
        case checkExistingAuth
        case getCurrentUser
        case checkAuthStatus
    }
    
    // MARK: - Dependencies
    
    private var mockKeychainService: MockKeychainService?
    private var mockDataService: MockDataService?
    
    // MARK: - Initialization
    
    init() {
        // Create default mock user profile
        mockUserProfile = UserProfile(
            id: UUID(),
            displayName: "Test User",
            appleUserIdHash: mockAppleUserIdHash,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    // MARK: - Test Configuration Methods
    
    /// Reset the mock to its default state
    func reset() {
        isAuthenticated = false
        currentUser = nil
        isLoading = false
        shouldSucceed = true
        errorToThrow = .authorizationFailed
        failingOperations.removeAll()
        isNetworkAvailable = true
        appleCredentialState = .authorized
        simulatedDelay = 0.1
        
        // Reset call counts
        signInCallCount = 0
        signOutCallCount = 0
        checkAuthCallCount = 0
        getCurrentUserCallCount = 0
        
        // Reset mock data
        mockUserProfile = UserProfile(
            id: UUID(),
            displayName: "Test User",
            appleUserIdHash: mockAppleUserIdHash,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    /// Configure the mock to fail for specific operations
    /// - Parameter operations: The operations that should fail
    func setFailingOperations(_ operations: Set<Operation>) {
        failingOperations = operations
    }
    
    /// Configure the mock to throw a specific error
    /// - Parameter error: The error to throw when operations fail
    func setError(_ error: AuthError) {
        errorToThrow = error
    }
    
    /// Configure network availability
    /// - Parameter available: Whether network should be available
    func setNetworkAvailable(_ available: Bool) {
        isNetworkAvailable = available
    }
    
    /// Configure Apple credential state
    /// - Parameter state: The credential state to simulate
    func setAppleCredentialState(_ state: ASAuthorizationAppleIDProvider.CredentialState) {
        appleCredentialState = state
    }
    
    /// Set mock user profile to return on authentication
    /// - Parameter userProfile: The user profile to return
    func setMockUserProfile(_ userProfile: UserProfile) {
        mockUserProfile = userProfile
    }
    
    /// Set dependencies for testing
    /// - Parameters:
    ///   - keychainService: Mock keychain service
    ///   - dataService: Mock data service
    func setMockDependencies(keychainService: MockKeychainService, dataService: MockDataService) {
        mockKeychainService = keychainService
        mockDataService = dataService
    }
    
    // MARK: - Private Helper Methods
    
    private func shouldFailOperation(_ operation: Operation) -> Bool {
        return !shouldSucceed || failingOperations.contains(operation)
    }
    
    private func throwErrorIfNeeded(for operation: Operation) throws {
        if shouldFailOperation(operation) {
            throw errorToThrow
        }
    }
    
    private func simulateDelay() async {
        if simulatedDelay > 0 {
            try? await Task.sleep(nanoseconds: UInt64(simulatedDelay * 1_000_000_000))
        }
    }
    
    // MARK: - AuthService Interface Implementation
    
    /// Mock implementation of setDataService
    /// - Parameter dataService: The data service (ignored in mock)
    func setDataService(_ dataService: DataService) {
        // In mock, we don't need to do anything here
        // The mock data service is set via setMockDependencies
    }
    
    /// Mock sign in with Apple ID
    /// - Throws: AuthError if configured to fail
    func signInWithApple() async throws {
        signInCallCount += 1
        
        await simulateDelay()
        
        isLoading = true
        defer { isLoading = false }
        
        // Check network availability
        if !isNetworkAvailable {
            throw AuthError.networkUnavailable
        }
        
        try throwErrorIfNeeded(for: .signIn)
        
        // Simulate successful authentication
        currentUser = mockUserProfile
        isAuthenticated = true
        
        // Store authentication data in mock keychain if available
        if let mockKeychain = mockKeychainService {
            try mockKeychain.storeAppleUserId(mockAppleUserId)
            try mockKeychain.storeAppleUserIdHash(mockAppleUserIdHash)
        }
    }
    
    /// Mock sign out current user
    func signOut() async throws {
        signOutCallCount += 1
        
        await simulateDelay()
        
        isLoading = true
        defer { isLoading = false }
        
        try throwErrorIfNeeded(for: .signOut)
        
        // Clear authentication state
        currentUser = nil
        isAuthenticated = false
        
        // Clear mock keychain if available
        if let mockKeychain = mockKeychainService {
            try mockKeychain.clearAll()
        }
    }
    
    /// Mock get current authenticated user
    /// - Returns: Current user profile or nil if not authenticated
    func getCurrentUser() -> UserProfile? {
        getCurrentUserCallCount += 1
        
        if shouldFailOperation(.getCurrentUser) {
            return nil
        }
        
        return currentUser
    }
    
    /// Mock check if user is currently authenticated
    /// - Returns: True if user is authenticated, false otherwise
    func checkAuthenticationStatus() -> Bool {
        if shouldFailOperation(.checkAuthStatus) {
            return false
        }
        
        return isAuthenticated && currentUser != nil
    }
    
    /// Mock check for existing authentication
    func checkExistingAuthentication() async {
        checkAuthCallCount += 1
        
        await simulateDelay()
        
        if shouldFailOperation(.checkExistingAuth) {
            return
        }
        
        // Simulate checking stored credentials
        guard let mockKeychain = mockKeychainService else { return }
        
        do {
            guard let storedAppleUserId = try mockKeychain.retrieveAppleUserId(),
                  let storedHash = try mockKeychain.retrieveAppleUserIdHash() else {
                return
            }
            
            // Check Apple credential state
            if appleCredentialState == .authorized {
                // Try to find user profile
                if let mockDataService = mockDataService,
                   let userProfile = try mockDataService.fetchUserProfile(byAppleUserIdHash: storedHash) {
                    currentUser = userProfile
                    isAuthenticated = true
                } else {
                    // Clear stored data if user profile not found
                    try mockKeychain.clearAll()
                }
            } else {
                // Clear stored data if credential not authorized
                try mockKeychain.clearAll()
            }
        } catch {
            // Clear stored data on error
            try? mockKeychain.clearAll()
        }
    }
    
    // MARK: - Test Utility Methods
    
    /// Simulate successful authentication with specific user
    /// - Parameter userProfile: The user profile to authenticate
    func simulateSuccessfulAuthentication(with userProfile: UserProfile) {
        currentUser = userProfile
        isAuthenticated = true
        mockUserProfile = userProfile
    }
    
    /// Simulate authentication failure
    /// - Parameter error: The error to simulate
    func simulateAuthenticationFailure(with error: AuthError) {
        currentUser = nil
        isAuthenticated = false
        errorToThrow = error
        shouldSucceed = false
    }
    
    /// Get call counts for test verification
    /// - Returns: Dictionary of operation names to call counts
    func getCallCounts() -> [String: Int] {
        return [
            "signIn": signInCallCount,
            "signOut": signOutCallCount,
            "checkAuth": checkAuthCallCount,
            "getCurrentUser": getCurrentUserCallCount
        ]
    }
    
    /// Check if user is in a specific authentication state
    /// - Parameter authenticated: Expected authentication state
    /// - Returns: True if current state matches expected state
    func isInAuthenticationState(_ authenticated: Bool) -> Bool {
        return isAuthenticated == authenticated
    }
}