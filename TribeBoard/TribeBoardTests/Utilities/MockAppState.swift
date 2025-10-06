import Foundation
import SwiftUI
@testable import TribeBoard

/// Mock implementation of AppState for testing purposes
/// Provides configurable state management and navigation tracking
@MainActor
class MockAppState: ObservableObject {
    
    // MARK: - Published Properties (matching AppState)
    
    @Published var currentUser: UserProfile?
    @Published var currentInMemoryFamily: InMemoryFamily?
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var currentError: Error?
    
    // MARK: - Navigation Tracking
    
    private(set) var navigationCalled: Bool = false
    private(set) var lastNavigationDestination: NavigationDestination?
    private(set) var navigationCallCount: Int = 0
    
    // MARK: - Family Management Tracking
    
    private(set) var familySet: Bool = false
    private(set) var setFamilyCallCount: Int = 0
    private(set) var setFamilyValue: InMemoryFamily?
    
    // MARK: - User Management Tracking
    
    private(set) var userSet: Bool = false
    private(set) var setUserCallCount: Int = 0
    
    // MARK: - Configuration Properties
    
    /// Controls whether navigation operations should succeed
    var shouldSucceedNavigation: Bool = true
    
    /// Controls whether family operations should succeed
    var shouldSucceedFamilyOperations: Bool = true
    
    /// Delay to simulate async operations
    var simulatedDelay: TimeInterval = 0.0
    
    // MARK: - Navigation Destinations
    
    enum NavigationDestination {
        case roleSelection
        case familyDashboard
        case createFamily
        case joinFamily
        case settings
        case onboarding
    }
    
    // MARK: - Initialization
    
    init() {
        reset()
    }
    
    // MARK: - Test Configuration Methods
    
    /// Reset the mock to its default state
    func reset() {
        currentUser = nil
        currentInMemoryFamily = nil
        isAuthenticated = false
        isLoading = false
        currentError = nil
        
        // Reset tracking
        navigationCalled = false
        lastNavigationDestination = nil
        navigationCallCount = 0
        familySet = false
        setFamilyCallCount = 0
        setFamilyValue = nil
        userSet = false
        setUserCallCount = 0
        
        // Reset configuration
        shouldSucceedNavigation = true
        shouldSucceedFamilyOperations = true
        simulatedDelay = 0.0
    }
    
    /// Configure navigation success/failure
    /// - Parameter shouldSucceed: Whether navigation should succeed
    func setShouldSucceedNavigation(_ shouldSucceed: Bool) {
        shouldSucceedNavigation = shouldSucceed
    }
    
    /// Configure family operations success/failure
    /// - Parameter shouldSucceed: Whether family operations should succeed
    func setShouldSucceedFamilyOperations(_ shouldSucceed: Bool) {
        shouldSucceedFamilyOperations = shouldSucceed
    }
    
    /// Set simulated delay for async operations
    /// - Parameter delay: The delay in seconds
    func setSimulatedDelay(_ delay: TimeInterval) {
        simulatedDelay = delay
    }
    
    /// Set current user for testing
    /// - Parameter user: The user profile to set
    func setCurrentUser(_ user: UserProfile?) {
        setUserCallCount += 1
        userSet = user != nil
        currentUser = user
        isAuthenticated = user != nil
    }
    
    /// Set authentication state
    /// - Parameter authenticated: Whether user is authenticated
    func setAuthenticated(_ authenticated: Bool) {
        isAuthenticated = authenticated
        if !authenticated {
            currentUser = nil
        }
    }
    
    /// Set loading state
    /// - Parameter loading: Whether app is in loading state
    func setLoading(_ loading: Bool) {
        isLoading = loading
    }
    
    /// Set current error
    /// - Parameter error: The error to set
    func setError(_ error: Error?) {
        currentError = error
    }
    
    // MARK: - AppState Interface Implementation
    
    /// Mock implementation of setFamily
    /// - Parameter family: The family to set as current
    func setFamily(_ family: InMemoryFamily) {
        setFamilyCallCount += 1
        familySet = true
        setFamilyValue = family
        currentInMemoryFamily = family
    }
    
    /// Mock implementation of clearFamily
    func clearFamily() {
        currentInMemoryFamily = nil
        familySet = false
        setFamilyValue = nil
    }
    
    /// Mock implementation of navigateToRoleSelection
    func navigateToRoleSelection() {
        navigationCallCount += 1
        navigationCalled = true
        lastNavigationDestination = .roleSelection
        
        if !shouldSucceedNavigation {
            currentError = MockAppStateError.navigationFailed
        }
    }
    
    /// Mock implementation of navigateToFamilyDashboard
    func navigateToFamilyDashboard() {
        navigationCallCount += 1
        navigationCalled = true
        lastNavigationDestination = .familyDashboard
        
        if !shouldSucceedNavigation {
            currentError = MockAppStateError.navigationFailed
        }
    }
    
    /// Mock implementation of navigateToCreateFamily
    func navigateToCreateFamily() {
        navigationCallCount += 1
        navigationCalled = true
        lastNavigationDestination = .createFamily
        
        if !shouldSucceedNavigation {
            currentError = MockAppStateError.navigationFailed
        }
    }
    
    /// Mock implementation of navigateToJoinFamily
    func navigateToJoinFamily() {
        navigationCallCount += 1
        navigationCalled = true
        lastNavigationDestination = .joinFamily
        
        if !shouldSucceedNavigation {
            currentError = MockAppStateError.navigationFailed
        }
    }
    
    /// Mock implementation of navigateToSettings
    func navigateToSettings() {
        navigationCallCount += 1
        navigationCalled = true
        lastNavigationDestination = .settings
        
        if !shouldSucceedNavigation {
            currentError = MockAppStateError.navigationFailed
        }
    }
    
    /// Mock implementation of navigateToOnboarding
    func navigateToOnboarding() {
        navigationCallCount += 1
        navigationCalled = true
        lastNavigationDestination = .onboarding
        
        if !shouldSucceedNavigation {
            currentError = MockAppStateError.navigationFailed
        }
    }
    
    // MARK: - Test Utility Methods
    
    /// Check if navigation was called with specific destination
    /// - Parameter destination: The expected destination
    /// - Returns: True if navigation was called with the destination
    func wasNavigationCalled(to destination: NavigationDestination) -> Bool {
        return navigationCalled && lastNavigationDestination == destination
    }
    
    /// Get navigation call count
    /// - Returns: The number of times navigation was called
    func getNavigationCallCount() -> Int {
        return navigationCallCount
    }
    
    /// Get family operation call count
    /// - Returns: The number of times setFamily was called
    func getFamilyOperationCallCount() -> Int {
        return setFamilyCallCount
    }
    
    /// Check if family was set with specific family
    /// - Parameter family: The expected family
    /// - Returns: True if the family was set
    func wasFamilySet(_ family: InMemoryFamily) -> Bool {
        return familySet && setFamilyValue?.id == family.id
    }
    
    /// Simulate app restart (clears all state)
    func simulateAppRestart() {
        reset()
    }
    
    /// Simulate network connectivity change
    /// - Parameter connected: Whether network is connected
    func simulateNetworkChange(connected: Bool) {
        if !connected {
            currentError = MockAppStateError.networkUnavailable
        } else {
            currentError = nil
        }
    }
    
    /// Simulate memory pressure (clears non-essential state)
    func simulateMemoryPressure() {
        // Clear family data but keep user authentication
        currentInMemoryFamily = nil
        familySet = false
        setFamilyValue = nil
    }
    
    // MARK: - State Validation
    
    /// Validate current state consistency
    /// - Returns: True if state is consistent
    func validateStateConsistency() -> Bool {
        // Check authentication consistency
        if isAuthenticated && currentUser == nil {
            return false
        }
        
        if !isAuthenticated && currentUser != nil {
            return false
        }
        
        // Check family state consistency
        if familySet && currentInMemoryFamily == nil {
            return false
        }
        
        return true
    }
    
    /// Get current state summary for debugging
    /// - Returns: Dictionary describing current state
    func getStateSummary() -> [String: Any] {
        return [
            "isAuthenticated": isAuthenticated,
            "hasCurrentUser": currentUser != nil,
            "hasCurrentFamily": currentInMemoryFamily != nil,
            "isLoading": isLoading,
            "hasError": currentError != nil,
            "navigationCallCount": navigationCallCount,
            "familySetCallCount": setFamilyCallCount,
            "lastNavigation": lastNavigationDestination?.description ?? "none"
        ]
    }
}

// MARK: - Mock Errors

enum MockAppStateError: LocalizedError {
    case navigationFailed
    case familyOperationFailed
    case networkUnavailable
    case stateInconsistent
    
    var errorDescription: String? {
        switch self {
        case .navigationFailed:
            return "Mock navigation operation failed"
        case .familyOperationFailed:
            return "Mock family operation failed"
        case .networkUnavailable:
            return "Mock network unavailable"
        case .stateInconsistent:
            return "Mock state is inconsistent"
        }
    }
}

// MARK: - NavigationDestination Extensions

extension MockAppState.NavigationDestination {
    var description: String {
        switch self {
        case .roleSelection:
            return "roleSelection"
        case .familyDashboard:
            return "familyDashboard"
        case .createFamily:
            return "createFamily"
        case .joinFamily:
            return "joinFamily"
        case .settings:
            return "settings"
        case .onboarding:
            return "onboarding"
        }
    }
}

// MARK: - Test Scenarios

extension MockAppState {
    
    /// Configure for family creation test scenario
    func configureForFamilyCreationTest() {
        reset()
        setCurrentUser(UserProfile(displayName: "Test Creator", appleUserIdHash: "creator_hash"))
        setShouldSucceedNavigation(true)
        setShouldSucceedFamilyOperations(true)
    }
    
    /// Configure for family joining test scenario
    func configureForFamilyJoiningTest() {
        reset()
        setCurrentUser(UserProfile(displayName: "Test Joiner", appleUserIdHash: "joiner_hash"))
        setShouldSucceedNavigation(true)
        setShouldSucceedFamilyOperations(true)
    }
    
    /// Configure for error scenario testing
    func configureForErrorScenario() {
        reset()
        setShouldSucceedNavigation(false)
        setShouldSucceedFamilyOperations(false)
    }
    
    /// Configure for performance testing
    func configureForPerformanceTest() {
        reset()
        setSimulatedDelay(0.001) // Very small delay for performance tests
    }
}