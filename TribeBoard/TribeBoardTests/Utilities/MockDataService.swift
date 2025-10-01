import Foundation
import SwiftData
import AuthenticationServices
@testable import TribeBoard

/// Mock implementation of DataService for testing purposes
/// Provides in-memory data operations and configurable error scenarios
@MainActor
class MockDataService: ObservableObject {
    
    // MARK: - In-Memory Storage
    
    private var userProfiles: [UUID: UserProfile] = [:]
    private var userProfilesByHash: [String: UserProfile] = [:]
    private var families: [UUID: Family] = [:]
    private var familiesByCode: [String: Family] = [:]
    private var memberships: [UUID: Membership] = [:]
    
    // MARK: - Configuration Properties
    
    /// Controls whether operations should succeed
    var shouldSucceed: Bool = true
    
    /// The error to throw when operations fail
    var errorToThrow: DataServiceError = .invalidData("Mock error")
    
    /// Controls which specific operations should fail
    var failingOperations: Set<Operation> = []
    
    /// Delay to simulate async operations
    var simulatedDelay: TimeInterval = 0.05
    
    /// Mock user to return for authentication tests
    var userToReturn: UserProfile?
    
    /// Whether to return existing user or create new one
    var shouldReturnExistingUser: Bool = false
    
    /// Mock Apple credential state for testing
    var appleCredentialState: ASAuthorizationAppleIDProvider.CredentialState = .authorized
    
    // MARK: - Call Tracking
    
    private(set) var createUserProfileCallCount = 0
    private(set) var fetchUserProfileCallCount = 0
    private(set) var createFamilyCallCount = 0
    private(set) var fetchFamilyCallCount = 0
    private(set) var createMembershipCallCount = 0
    
    // MARK: - Operation Types
    
    enum Operation {
        case createUserProfile
        case fetchUserProfileByHash
        case fetchUserProfileById
        case createFamily
        case fetchFamilyByCode
        case fetchFamilyById
        case createMembership
        case fetchMemberships
    }
    
    // MARK: - Test Configuration Methods
    
    /// Reset the mock to its default state
    func reset() {
        userProfiles.removeAll()
        userProfilesByHash.removeAll()
        families.removeAll()
        familiesByCode.removeAll()
        memberships.removeAll()
        
        shouldSucceed = true
        errorToThrow = .invalidData("Mock error")
        failingOperations.removeAll()
        simulatedDelay = 0.05
        userToReturn = nil
        shouldReturnExistingUser = false
        appleCredentialState = .authorized
        
        // Reset call counts
        createUserProfileCallCount = 0
        fetchUserProfileCallCount = 0
        createFamilyCallCount = 0
        fetchFamilyCallCount = 0
        createMembershipCallCount = 0
    }
    
    /// Configure the mock to fail for specific operations
    /// - Parameter operations: The operations that should fail
    func setFailingOperations(_ operations: Set<Operation>) {
        failingOperations = operations
    }
    
    /// Configure the mock to throw a specific error
    /// - Parameter error: The error to throw when operations fail
    func setError(_ error: DataServiceError) {
        errorToThrow = error
    }
    
    /// Configure the mock to throw a specific AuthError
    /// - Parameter error: The AuthError to throw when operations fail
    func setError(_ error: AuthError) {
        switch error {
        case .dataServiceError(let dataError):
            if let dsError = dataError as? DataServiceError {
                errorToThrow = dsError
            } else {
                errorToThrow = .invalidData(dataError.localizedDescription)
            }
        default:
            errorToThrow = .invalidData(error.localizedDescription)
        }
    }
    
    /// Set the user to return for authentication tests
    /// - Parameter user: The user profile to return
    func setUserToReturn(_ user: UserProfile?) {
        userToReturn = user
    }
    
    /// Configure whether to return existing user or create new one
    /// - Parameter shouldReturn: Whether to return existing user
    func setShouldReturnExistingUser(_ shouldReturn: Bool) {
        shouldReturnExistingUser = shouldReturn
    }
    
    /// Set the Apple credential state for testing
    /// - Parameter state: The credential state to simulate
    func setAppleCredentialState(_ state: ASAuthorizationAppleIDProvider.CredentialState) {
        appleCredentialState = state
    }
    
    /// Set whether operations should succeed
    /// - Parameter succeed: Whether operations should succeed
    func setShouldSucceed(_ succeed: Bool) {
        shouldSucceed = succeed
    }
    
    /// Set the simulated delay for async operations
    /// - Parameter delay: The delay in seconds
    func setSimulatedDelay(_ delay: TimeInterval) {
        simulatedDelay = delay
    }
    
    /// Pre-populate the mock with a user profile
    /// - Parameters:
    ///   - userProfile: The user profile to store
    ///   - hash: The Apple user ID hash to associate with the profile
    func prePopulateUser(_ userProfile: UserProfile, withHash hash: String) {
        userProfiles[userProfile.id] = userProfile
        userProfilesByHash[hash] = userProfile
    }
    
    /// Pre-populate the mock with a family
    /// - Parameter family: The family to store
    func prePopulateFamily(_ family: Family) {
        families[family.id] = family
        familiesByCode[family.code] = family
    }
    
    /// Get all stored user profiles for inspection
    /// - Returns: Dictionary of all stored user profiles
    func getAllUserProfiles() -> [UUID: UserProfile] {
        return userProfiles
    }
    
    /// Get all stored families for inspection
    /// - Returns: Dictionary of all stored families
    func getAllFamilies() -> [UUID: Family] {
        return families
    }
    
    /// Get the number of stored items of a specific type
    /// - Parameter type: The type to count
    /// - Returns: The count of stored items
    func getStoredItemCount(for type: StoredItemType) -> Int {
        switch type {
        case .userProfile:
            return userProfiles.count
        case .family:
            return families.count
        case .membership:
            return memberships.count
        }
    }
    
    enum StoredItemType {
        case userProfile
        case family
        case membership
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
    
    // MARK: - DataService Interface Implementation
    
    /// Mock implementation of createUserProfile
    /// - Parameters:
    ///   - displayName: The display name for the user
    ///   - appleUserIdHash: The Apple user ID hash
    ///   - avatarUrl: Optional avatar URL
    /// - Returns: The created user profile
    /// - Throws: DataServiceError if configured to fail
    func createUserProfile(displayName: String, appleUserIdHash: String, avatarUrl: URL? = nil) throws -> UserProfile {
        createUserProfileCallCount += 1
        
        try throwErrorIfNeeded(for: .createUserProfile)
        
        // Return configured user if available
        if let configuredUser = userToReturn {
            // Store the user profile
            userProfiles[configuredUser.id] = configuredUser
            userProfilesByHash[appleUserIdHash] = configuredUser
            return configuredUser
        }
        
        // Check if user already exists
        if userProfilesByHash[appleUserIdHash] != nil {
            throw DataServiceError.constraintViolation("User profile with this Apple ID hash already exists")
        }
        
        let userProfile = UserProfile(
            displayName: displayName,
            appleUserIdHash: appleUserIdHash
        )
        
        // Store the user profile
        userProfiles[userProfile.id] = userProfile
        userProfilesByHash[appleUserIdHash] = userProfile
        
        return userProfile
    }
    
    /// Mock implementation of fetchUserProfile by Apple ID hash
    /// - Parameter hash: The Apple user ID hash to search for
    /// - Returns: The user profile if found, nil otherwise
    /// - Throws: DataServiceError if configured to fail
    func fetchUserProfile(byAppleUserIdHash hash: String) throws -> UserProfile? {
        fetchUserProfileCallCount += 1
        
        try throwErrorIfNeeded(for: .fetchUserProfileByHash)
        
        // Return configured user if shouldReturnExistingUser is true
        if shouldReturnExistingUser {
            return userToReturn
        }
        
        return userProfilesByHash[hash]
    }
    
    /// Mock implementation of fetchUserProfile by ID
    /// - Parameter id: The user ID to search for
    /// - Returns: The user profile if found, nil otherwise
    /// - Throws: DataServiceError if configured to fail
    func fetchUserProfile(byId id: UUID) throws -> UserProfile? {
        fetchUserProfileCallCount += 1
        
        try throwErrorIfNeeded(for: .fetchUserProfileById)
        
        return userProfiles[id]
    }
    
    /// Mock implementation of createFamily
    /// - Parameters:
    ///   - name: The family name
    ///   - code: The family code
    ///   - createdByUserId: The ID of the user creating the family
    /// - Returns: The created family
    /// - Throws: DataServiceError if configured to fail
    func createFamily(name: String, code: String, createdByUserId: UUID) throws -> Family {
        createFamilyCallCount += 1
        
        try throwErrorIfNeeded(for: .createFamily)
        
        // Check if family code already exists
        if familiesByCode[code] != nil {
            throw DataServiceError.constraintViolation("Family code '\(code)' already exists")
        }
        
        let family = Family(
            id: UUID(),
            name: name,
            code: code,
            createdByUserId: createdByUserId,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // Store the family
        families[family.id] = family
        familiesByCode[code] = family
        
        return family
    }
    
    /// Mock implementation of fetchFamily by code
    /// - Parameter code: The family code to search for
    /// - Returns: The family if found, nil otherwise
    /// - Throws: DataServiceError if configured to fail
    func fetchFamily(byCode code: String) throws -> Family? {
        fetchFamilyCallCount += 1
        
        try throwErrorIfNeeded(for: .fetchFamilyByCode)
        
        return familiesByCode[code]
    }
    
    /// Mock implementation of fetchFamily by ID
    /// - Parameter id: The family ID to search for
    /// - Returns: The family if found, nil otherwise
    /// - Throws: DataServiceError if configured to fail
    func fetchFamily(byId id: UUID) throws -> Family? {
        fetchFamilyCallCount += 1
        
        try throwErrorIfNeeded(for: .fetchFamilyById)
        
        return families[id]
    }
    
    /// Mock implementation of fetchAllFamilies
    /// - Returns: Array of all families
    /// - Throws: DataServiceError if configured to fail
    func fetchAllFamilies() throws -> [Family] {
        return Array(families.values)
    }
    
    /// Mock implementation of familyCodeExists
    /// - Parameter code: The family code to check
    /// - Returns: True if the code exists, false otherwise
    /// - Throws: DataServiceError if configured to fail
    func familyCodeExists(_ code: String) throws -> Bool {
        return familiesByCode[code] != nil
    }
    
    /// Mock implementation of createMembership
    /// - Parameters:
    ///   - family: The family for the membership
    ///   - user: The user for the membership
    ///   - role: The role for the membership
    /// - Returns: The created membership
    /// - Throws: DataServiceError if configured to fail
    func createMembership(family: Family, user: UserProfile, role: Role) throws -> Membership {
        createMembershipCallCount += 1
        
        try throwErrorIfNeeded(for: .createMembership)
        
        let membership = Membership(
            id: UUID(),
            familyId: family.id,
            userId: user.id,
            role: role,
            status: .active,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        memberships[membership.id] = membership
        
        return membership
    }
    
    /// Mock implementation of fetchMemberships for user
    /// - Parameter user: The user to fetch memberships for
    /// - Returns: Array of memberships for the user
    /// - Throws: DataServiceError if configured to fail
    func fetchMemberships(forUser user: UserProfile) throws -> [Membership] {
        try throwErrorIfNeeded(for: .fetchMemberships)
        
        return memberships.values.filter { $0.userId == user.id }
    }
    
    // MARK: - Test Utility Methods
    
    /// Populate the mock with test data
    func populateWithTestData() {
        let testUser = UserProfile(
            displayName: "Test User",
            appleUserIdHash: "test_hash_123"
        )
        
        let testFamily = Family(
            id: UUID(),
            name: "Test Family",
            code: "TEST123",
            createdByUserId: testUser.id,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        prePopulateUser(testUser, withHash: "test_hash_123")
        prePopulateFamily(testFamily)
    }
    
    /// Get call counts for test verification
    /// - Returns: Dictionary of operation names to call counts
    func getCallCounts() -> [String: Int] {
        return [
            "createUserProfile": createUserProfileCallCount,
            "fetchUserProfile": fetchUserProfileCallCount,
            "createFamily": createFamilyCallCount,
            "fetchFamily": fetchFamilyCallCount,
            "createMembership": createMembershipCallCount
        ]
    }
    
    /// Check if a specific user exists by hash
    /// - Parameter hash: The Apple user ID hash to check
    /// - Returns: True if the user exists, false otherwise
    func hasUser(withHash hash: String) -> Bool {
        return userProfilesByHash[hash] != nil
    }
    
    /// Check if a specific family exists by code
    /// - Parameter code: The family code to check
    /// - Returns: True if the family exists, false otherwise
    func hasFamily(withCode code: String) -> Bool {
        return familiesByCode[code] != nil
    }
    
    // MARK: - State Management Extensions
    
    /// Complete data service state
    struct DataState {
        var userCount: Int = 0
        var familyCount: Int = 0
        var membershipCount: Int = 0
        var callCounts: [String: Int] = [:]
        var lastError: DataServiceError?
        var isNetworkAvailable: Bool = true
        var responseDelay: TimeInterval = 0.0
    }
    
    /// Response delay for performance testing
    private var responseDelay: TimeInterval = 0.0
    
    /// Network availability for testing
    private var networkAvailable: Bool = true
    
    /// Whether the service is configured for testing
    var isConfigured: Bool = true
    
    /// Get current complete state
    var currentState: DataState {
        return DataState(
            userCount: userProfiles.count,
            familyCount: families.count,
            membershipCount: memberships.count,
            callCounts: getCallCounts(),
            lastError: shouldSucceed ? nil : errorToThrow,
            isNetworkAvailable: networkAvailable,
            responseDelay: responseDelay
        )
    }
    
    /// Set mock error for testing
    func setMockError(_ error: DataServiceError) {
        errorToThrow = error
        shouldSucceed = false
    }
    
    /// Set network unavailable state
    func setNetworkUnavailable(_ unavailable: Bool) {
        networkAvailable = !unavailable
        if unavailable {
            setMockError(.invalidData("Network unavailable"))
        }
    }
    
    /// Set response delay for performance testing
    func setResponseDelay(_ delay: TimeInterval) {
        responseDelay = delay
        simulatedDelay = delay
    }
    
    /// Restore state from snapshot
    func restoreState(_ state: DataState) {
        // Clear current data
        reset()
        
        // Restore configuration
        networkAvailable = state.isNetworkAvailable
        responseDelay = state.responseDelay
        simulatedDelay = state.responseDelay
        
        if let error = state.lastError {
            setMockError(error)
        } else {
            shouldSucceed = true
        }
    }
}