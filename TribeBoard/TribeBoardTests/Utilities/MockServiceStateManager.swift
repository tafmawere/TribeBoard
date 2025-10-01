import Foundation
@testable import TribeBoard

/// Manages state and configuration for mock services during testing
class MockServiceStateManager {
    
    // MARK: - Properties
    
    private var authServiceStates: [String: MockAuthService.AuthState] = [:]
    private var dataServiceStates: [String: MockDataService.DataState] = [:]
    private var keychainServiceStates: [String: [String: Data]] = [:]
    
    // MARK: - State Management
    
    /// Saves the current state of all mock services with a given identifier
    func saveState(identifier: String, mockServices: MockServiceContainer) {
        authServiceStates[identifier] = mockServices.authService.currentState
        dataServiceStates[identifier] = mockServices.dataService.currentState
        keychainServiceStates[identifier] = mockServices.keychainService.getAllStoredData()
    }
    
    /// Restores mock services to a previously saved state
    func restoreState(identifier: String, mockServices: MockServiceContainer) -> Bool {
        guard let authState = authServiceStates[identifier],
              let dataState = dataServiceStates[identifier],
              let keychainData = keychainServiceStates[identifier] else {
            return false
        }
        
        mockServices.authService.restoreState(authState)
        mockServices.dataService.restoreState(dataState)
        mockServices.keychainService.restoreData(keychainData)
        
        return true
    }
    
    /// Removes a saved state
    func removeState(identifier: String) {
        authServiceStates.removeValue(forKey: identifier)
        dataServiceStates.removeValue(forKey: identifier)
        keychainServiceStates.removeValue(forKey: identifier)
    }
    
    /// Clears all saved states
    func clearAllStates() {
        authServiceStates.removeAll()
        dataServiceStates.removeAll()
        keychainServiceStates.removeAll()
    }
    
    /// Lists all saved state identifiers
    func getSavedStateIdentifiers() -> [String] {
        return Array(authServiceStates.keys)
    }
    
    // MARK: - Predefined State Configurations
    
    /// Configures mock services for unauthenticated state
    func configureUnauthenticatedState(_ mockServices: MockServiceContainer) {
        mockServices.authService.setAuthenticationState(.unauthenticated)
        mockServices.authService.setMockUserProfile(nil)
        mockServices.keychainService.reset()
        mockServices.dataService.reset()
    }
    
    /// Configures mock services for authenticated state with default user
    func configureAuthenticatedState(_ mockServices: MockServiceContainer) {
        let defaultUser = TestDataFactory.createTestUserProfile(displayName: "Authenticated User")
        let authScenario = TestDataFactory.createCompleteAuthScenario()
        
        mockServices.authService.setAuthenticationState(.authenticated)
        mockServices.authService.setMockUserProfile(defaultUser)
        
        TestDataFactory.configureMockKeychain(mockServices.keychainService, with: authScenario)
        
        let familyScenario = TestDataFactory.createCompleteFamilyScenario()
        TestDataFactory.configureMockDataService(mockServices.dataService, with: familyScenario)
    }
    
    /// Configures mock services for authentication in progress state
    func configureAuthenticatingState(_ mockServices: MockServiceContainer) {
        mockServices.authService.setAuthenticationState(.authenticating)
        mockServices.authService.setMockUserProfile(nil)
        mockServices.keychainService.reset()
        mockServices.dataService.reset()
    }
    
    /// Configures mock services for authentication error state
    func configureAuthenticationErrorState(_ mockServices: MockServiceContainer, error: AuthError = .authorizationFailed) {
        mockServices.authService.setAuthenticationState(.error(error))
        mockServices.authService.setMockError(error)
        mockServices.authService.setMockUserProfile(nil)
        mockServices.keychainService.reset()
        mockServices.dataService.reset()
    }
    
    /// Configures mock services for network unavailable state
    func configureNetworkUnavailableState(_ mockServices: MockServiceContainer) {
        mockServices.authService.setNetworkUnavailable(true)
        mockServices.dataService.setNetworkUnavailable(true)
        mockServices.authService.setAuthenticationState(.error(.networkUnavailable))
    }
    
    /// Configures mock services for family creation scenario
    func configureFamilyCreationState(_ mockServices: MockServiceContainer) {
        let creator = TestDataFactory.createTestUserProfile(displayName: "Family Creator")
        
        mockServices.authService.setAuthenticationState(.authenticated)
        mockServices.authService.setMockUserProfile(creator)
        
        // Configure keychain with creator data
        let keychainData = [
            KeychainService.appleUserIdKey: "creator.apple.id".data(using: .utf8)!,
            KeychainService.appleUserIdHashKey: creator.appleUserIdHash.data(using: .utf8)!
        ]
        
        for (key, data) in keychainData {
            mockServices.keychainService.prePopulate(data: data, for: key)
        }
        
        // Reset data service for clean family creation
        mockServices.dataService.reset()
        mockServices.dataService.prePopulateUser(creator, withHash: creator.appleUserIdHash)
    }
    
    /// Configures mock services for family joining scenario
    func configureFamilyJoiningState(_ mockServices: MockServiceContainer) {
        let joiner = TestDataFactory.createTestUserProfile(displayName: "Family Joiner")
        let existingFamily = TestDataFactory.createTestFamily(name: "Existing Family", code: "JOIN123")
        
        mockServices.authService.setAuthenticationState(.authenticated)
        mockServices.authService.setMockUserProfile(joiner)
        
        // Configure keychain with joiner data
        let keychainData = [
            KeychainService.appleUserIdKey: "joiner.apple.id".data(using: .utf8)!,
            KeychainService.appleUserIdHashKey: joiner.appleUserIdHash.data(using: .utf8)!
        ]
        
        for (key, data) in keychainData {
            mockServices.keychainService.prePopulate(data: data, for: key)
        }
        
        // Configure data service with existing family
        mockServices.dataService.reset()
        mockServices.dataService.prePopulateUser(joiner, withHash: joiner.appleUserIdHash)
        mockServices.dataService.prePopulateFamily(existingFamily)
    }
    
    // MARK: - Error Scenario Configurations
    
    /// Configures mock services for keychain error scenarios
    func configureKeychainErrorState(_ mockServices: MockServiceContainer, error: KeychainService.KeychainError) {
        mockServices.keychainService.setMockError(error)
        mockServices.authService.setAuthenticationState(.error(.keychainError(error)))
    }
    
    /// Configures mock services for data service error scenarios
    func configureDataServiceErrorState(_ mockServices: MockServiceContainer, error: DataServiceError) {
        mockServices.dataService.setMockError(error)
        
        // Set up authenticated user but with data service issues
        let user = TestDataFactory.createTestUserProfile(displayName: "User with Data Issues")
        mockServices.authService.setAuthenticationState(.authenticated)
        mockServices.authService.setMockUserProfile(user)
    }
    
    /// Configures mock services for Apple ID authorization failure
    func configureAppleIDFailureState(_ mockServices: MockServiceContainer) {
        mockServices.authService.setMockError(.authorizationFailed)
        mockServices.authService.setAuthenticationState(.error(.authorizationFailed))
        mockServices.keychainService.reset()
        mockServices.dataService.reset()
    }
    
    /// Configures mock services for user cancellation scenario
    func configureUserCancellationState(_ mockServices: MockServiceContainer) {
        mockServices.authService.setMockError(.userCancelled)
        mockServices.authService.setAuthenticationState(.unauthenticated)
        mockServices.keychainService.reset()
        mockServices.dataService.reset()
    }
    
    // MARK: - Performance Testing Configurations
    
    /// Configures mock services for performance testing with large datasets
    func configureLargeDatasetState(_ mockServices: MockServiceContainer) {
        let users = TestDataFactory.createMultipleTestUserProfiles(count: 100)
        let families = TestDataFactory.createMultipleTestFamilies(count: 20)
        
        mockServices.dataService.reset()
        
        // Pre-populate with large dataset
        for user in users {
            mockServices.dataService.prePopulateUser(user, withHash: user.appleUserIdHash)
        }
        
        for family in families {
            mockServices.dataService.prePopulateFamily(family)
        }
        
        // Set authenticated user
        let authenticatedUser = users.first!
        mockServices.authService.setAuthenticationState(.authenticated)
        mockServices.authService.setMockUserProfile(authenticatedUser)
    }
    
    /// Configures mock services for slow response simulation
    func configureSlowResponseState(_ mockServices: MockServiceContainer, delay: TimeInterval = 2.0) {
        mockServices.authService.setResponseDelay(delay)
        mockServices.dataService.setResponseDelay(delay)
        mockServices.keychainService.setResponseDelay(delay)
        
        // Configure with normal authenticated state
        configureAuthenticatedState(mockServices)
    }
    
    // MARK: - State Validation
    
    /// Validates that mock services are in expected state
    func validateState(_ mockServices: MockServiceContainer, expectedState: ExpectedMockState) -> StateValidationResult {
        var issues: [String] = []
        
        // Validate auth service state
        if mockServices.authService.currentState.authenticationState != expectedState.authenticationState {
            issues.append("Auth state mismatch: expected \(expectedState.authenticationState), got \(mockServices.authService.currentState.authenticationState)")
        }
        
        // Validate user profile presence
        let hasUserProfile = mockServices.authService.currentState.userProfile != nil
        if hasUserProfile != expectedState.shouldHaveUserProfile {
            issues.append("User profile presence mismatch: expected \(expectedState.shouldHaveUserProfile), got \(hasUserProfile)")
        }
        
        // Validate keychain data
        let keychainDataCount = mockServices.keychainService.getAllStoredData().count
        if keychainDataCount < expectedState.minimumKeychainEntries {
            issues.append("Insufficient keychain data: expected at least \(expectedState.minimumKeychainEntries), got \(keychainDataCount)")
        }
        
        // Validate data service state
        if mockServices.dataService.currentState.userCount < expectedState.minimumUsers {
            issues.append("Insufficient users: expected at least \(expectedState.minimumUsers), got \(mockServices.dataService.currentState.userCount)")
        }
        
        if mockServices.dataService.currentState.familyCount < expectedState.minimumFamilies {
            issues.append("Insufficient families: expected at least \(expectedState.minimumFamilies), got \(mockServices.dataService.currentState.familyCount)")
        }
        
        return StateValidationResult(
            isValid: issues.isEmpty,
            issues: issues
        )
    }
    
    // MARK: - State Comparison
    
    /// Compares two mock service states
    func compareStates(_ state1: MockServiceContainer, _ state2: MockServiceContainer) -> StateComparisonResult {
        var differences: [String] = []
        
        // Compare auth states
        if state1.authService.currentState.authenticationState != state2.authService.currentState.authenticationState {
            differences.append("Authentication state differs")
        }
        
        // Compare user profiles
        let user1 = state1.authService.currentState.userProfile
        let user2 = state2.authService.currentState.userProfile
        
        if (user1 == nil) != (user2 == nil) {
            differences.append("User profile presence differs")
        } else if let u1 = user1, let u2 = user2, u1.id != u2.id {
            differences.append("User profile identity differs")
        }
        
        // Compare keychain data
        let keychain1 = state1.keychainService.getAllStoredData()
        let keychain2 = state2.keychainService.getAllStoredData()
        
        if keychain1.count != keychain2.count {
            differences.append("Keychain data count differs")
        }
        
        // Compare data service states
        let data1 = state1.dataService.currentState
        let data2 = state2.dataService.currentState
        
        if data1.userCount != data2.userCount {
            differences.append("User count differs")
        }
        
        if data1.familyCount != data2.familyCount {
            differences.append("Family count differs")
        }
        
        return StateComparisonResult(
            areEqual: differences.isEmpty,
            differences: differences
        )
    }
}

// MARK: - Supporting Types

/// Expected mock service state for validation
struct ExpectedMockState {
    let authenticationState: MockAuthService.AuthenticationState
    let shouldHaveUserProfile: Bool
    let minimumKeychainEntries: Int
    let minimumUsers: Int
    let minimumFamilies: Int
    
    static let unauthenticated = ExpectedMockState(
        authenticationState: .unauthenticated,
        shouldHaveUserProfile: false,
        minimumKeychainEntries: 0,
        minimumUsers: 0,
        minimumFamilies: 0
    )
    
    static let authenticated = ExpectedMockState(
        authenticationState: .authenticated,
        shouldHaveUserProfile: true,
        minimumKeychainEntries: 2,
        minimumUsers: 1,
        minimumFamilies: 1
    )
    
    static let authenticating = ExpectedMockState(
        authenticationState: .authenticating,
        shouldHaveUserProfile: false,
        minimumKeychainEntries: 0,
        minimumUsers: 0,
        minimumFamilies: 0
    )
}

/// Result of state validation
struct StateValidationResult {
    let isValid: Bool
    let issues: [String]
}

/// Result of state comparison
struct StateComparisonResult {
    let areEqual: Bool
    let differences: [String]
}