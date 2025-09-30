import XCTest

/// Manages mock environment setup for UI tests
class MockUITestEnvironment {
    
    // MARK: - Properties
    
    private let app: XCUIApplication
    
    // MARK: - Mock Configuration
    
    struct MockConfiguration {
        var authenticationEnabled: Bool = true
        var networkEnabled: Bool = false
        var animationsEnabled: Bool = false
        var mockDataEnabled: Bool = true
        var errorSimulationEnabled: Bool = false
        var performanceTestingEnabled: Bool = false
        
        // Authentication mock settings
        var mockAuthSuccess: Bool = true
        var mockAuthDelay: TimeInterval = 0.5
        var mockUserName: String = "Test User"
        var mockUserEmail: String = "test@example.com"
        
        // Data mock settings
        var mockFamilyCount: Int = 1
        var mockChildrenCount: Int = 2
        var mockSchoolRunsCount: Int = 1
        
        // Error simulation settings
        var simulateNetworkError: Bool = false
        var simulateAuthError: Bool = false
        var simulateDataError: Bool = false
    }
    
    private var configuration: MockConfiguration
    
    // MARK: - Initialization
    
    init(app: XCUIApplication, configuration: MockConfiguration = MockConfiguration()) {
        self.app = app
        self.configuration = configuration
    }
    
    // MARK: - Environment Setup
    
    /// Configures the app with mock environment settings
    func setupMockEnvironment() {
        setupLaunchArguments()
        setupLaunchEnvironment()
    }
    
    private func setupLaunchArguments() {
        var arguments: [String] = []
        
        // Core testing arguments
        arguments.append("-UITesting")
        
        if !configuration.animationsEnabled {
            arguments.append("-DisableAnimations")
        }
        
        if configuration.mockDataEnabled {
            arguments.append("-UseMockServices")
        }
        
        if configuration.performanceTestingEnabled {
            arguments.append("-PerformanceTesting")
        }
        
        if configuration.errorSimulationEnabled {
            arguments.append("-SimulateErrors")
        }
        
        app.launchArguments = arguments
    }
    
    private func setupLaunchEnvironment() {
        var environment: [String: String] = [:]
        
        // Core environment variables
        environment["UI_TESTING"] = "1"
        environment["DISABLE_NETWORK_CALLS"] = configuration.networkEnabled ? "0" : "1"
        
        // Authentication mock settings
        environment["MOCK_AUTH_SERVICE"] = configuration.authenticationEnabled ? "1" : "0"
        environment["MOCK_AUTH_SUCCESS"] = configuration.mockAuthSuccess ? "1" : "0"
        environment["MOCK_AUTH_DELAY"] = String(configuration.mockAuthDelay)
        environment["MOCK_USER_NAME"] = configuration.mockUserName
        environment["MOCK_USER_EMAIL"] = configuration.mockUserEmail
        
        // Data mock settings
        environment["MOCK_DATA_SERVICE"] = configuration.mockDataEnabled ? "1" : "0"
        environment["MOCK_FAMILY_COUNT"] = String(configuration.mockFamilyCount)
        environment["MOCK_CHILDREN_COUNT"] = String(configuration.mockChildrenCount)
        environment["MOCK_SCHOOL_RUNS_COUNT"] = String(configuration.mockSchoolRunsCount)
        
        // Error simulation settings
        environment["SIMULATE_NETWORK_ERROR"] = configuration.simulateNetworkError ? "1" : "0"
        environment["SIMULATE_AUTH_ERROR"] = configuration.simulateAuthError ? "1" : "0"
        environment["SIMULATE_DATA_ERROR"] = configuration.simulateDataError ? "1" : "0"
        
        app.launchEnvironment = environment
    }
    
    // MARK: - Configuration Methods
    
    /// Configures for successful authentication testing
    func configureForAuthenticationSuccess(userName: String = "Test User", 
                                         userEmail: String = "test@example.com") {
        configuration.authenticationEnabled = true
        configuration.mockAuthSuccess = true
        configuration.mockUserName = userName
        configuration.mockUserEmail = userEmail
        configuration.simulateAuthError = false
    }
    
    /// Configures for authentication failure testing
    func configureForAuthenticationFailure() {
        configuration.authenticationEnabled = true
        configuration.mockAuthSuccess = false
        configuration.simulateAuthError = true
    }
    
    /// Configures for network error testing
    func configureForNetworkError() {
        configuration.networkEnabled = false
        configuration.simulateNetworkError = true
    }
    
    /// Configures for performance testing
    func configureForPerformanceTesting() {
        configuration.performanceTestingEnabled = true
        configuration.animationsEnabled = false
        configuration.mockAuthDelay = 0.1 // Faster for performance tests
    }
    
    /// Configures for accessibility testing
    func configureForAccessibilityTesting() {
        configuration.animationsEnabled = false
        configuration.mockAuthDelay = 0.1
        // Accessibility testing works better with real data
        configuration.mockDataEnabled = true
    }
    
    /// Configures with custom family data
    func configureWithFamilyData(familyCount: Int = 1, 
                                childrenCount: Int = 2, 
                                schoolRunsCount: Int = 1) {
        configuration.mockDataEnabled = true
        configuration.mockFamilyCount = familyCount
        configuration.mockChildrenCount = childrenCount
        configuration.mockSchoolRunsCount = schoolRunsCount
    }
    
    // MARK: - Preset Configurations
    
    /// Returns configuration for basic UI testing
    static func basicUITestConfiguration() -> MockConfiguration {
        var config = MockConfiguration()
        config.authenticationEnabled = true
        config.mockAuthSuccess = true
        config.animationsEnabled = false
        config.mockDataEnabled = true
        return config
    }
    
    /// Returns configuration for authentication flow testing
    static func authenticationTestConfiguration() -> MockConfiguration {
        var config = MockConfiguration()
        config.authenticationEnabled = true
        config.mockAuthSuccess = true
        config.mockAuthDelay = 0.5
        config.animationsEnabled = false
        config.mockDataEnabled = false // Focus on auth only
        return config
    }
    
    /// Returns configuration for error scenario testing
    static func errorTestConfiguration() -> MockConfiguration {
        var config = MockConfiguration()
        config.errorSimulationEnabled = true
        config.simulateNetworkError = true
        config.animationsEnabled = false
        return config
    }
    
    /// Returns configuration for performance testing
    static func performanceTestConfiguration() -> MockConfiguration {
        var config = MockConfiguration()
        config.performanceTestingEnabled = true
        config.animationsEnabled = false
        config.mockAuthDelay = 0.1
        config.mockDataEnabled = true
        return config
    }
    
    /// Returns configuration for accessibility testing
    static func accessibilityTestConfiguration() -> MockConfiguration {
        var config = MockConfiguration()
        config.animationsEnabled = false
        config.mockAuthDelay = 0.1
        config.mockDataEnabled = true
        config.authenticationEnabled = true
        config.mockAuthSuccess = true
        return config
    }
    
    // MARK: - Runtime Configuration Updates
    
    /// Updates authentication settings (requires app restart)
    func updateAuthenticationSettings(success: Bool, delay: TimeInterval = 0.5) {
        configuration.mockAuthSuccess = success
        configuration.mockAuthDelay = delay
        configuration.simulateAuthError = !success
    }
    
    /// Updates data settings (requires app restart)
    func updateDataSettings(familyCount: Int, childrenCount: Int, schoolRunsCount: Int) {
        configuration.mockFamilyCount = familyCount
        configuration.mockChildrenCount = childrenCount
        configuration.mockSchoolRunsCount = schoolRunsCount
    }
    
    /// Enables error simulation (requires app restart)
    func enableErrorSimulation(networkError: Bool = false, 
                             authError: Bool = false, 
                             dataError: Bool = false) {
        configuration.errorSimulationEnabled = true
        configuration.simulateNetworkError = networkError
        configuration.simulateAuthError = authError
        configuration.simulateDataError = dataError
    }
    
    /// Disables all error simulation
    func disableErrorSimulation() {
        configuration.errorSimulationEnabled = false
        configuration.simulateNetworkError = false
        configuration.simulateAuthError = false
        configuration.simulateDataError = false
    }
    
    // MARK: - Validation
    
    /// Validates that the mock environment is properly configured
    func validateEnvironment() -> EnvironmentValidationResult {
        var issues: [String] = []
        
        // Check for conflicting settings
        if configuration.mockAuthSuccess && configuration.simulateAuthError {
            issues.append("Conflicting auth settings: success enabled but error simulation also enabled")
        }
        
        if !configuration.mockDataEnabled && configuration.mockFamilyCount > 0 {
            issues.append("Mock data disabled but family count specified")
        }
        
        if configuration.performanceTestingEnabled && configuration.animationsEnabled {
            issues.append("Performance testing enabled but animations not disabled")
        }
        
        return EnvironmentValidationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    // MARK: - Debug Information
    
    /// Returns current configuration as debug string
    func debugDescription() -> String {
        return """
        Mock UI Test Environment Configuration:
        - Authentication Enabled: \(configuration.authenticationEnabled)
        - Mock Auth Success: \(configuration.mockAuthSuccess)
        - Auth Delay: \(configuration.mockAuthDelay)s
        - Mock Data Enabled: \(configuration.mockDataEnabled)
        - Animations Enabled: \(configuration.animationsEnabled)
        - Error Simulation: \(configuration.errorSimulationEnabled)
        - Network Errors: \(configuration.simulateNetworkError)
        - Auth Errors: \(configuration.simulateAuthError)
        - Data Errors: \(configuration.simulateDataError)
        - Family Count: \(configuration.mockFamilyCount)
        - Children Count: \(configuration.mockChildrenCount)
        - School Runs Count: \(configuration.mockSchoolRunsCount)
        """
    }
}

// MARK: - Supporting Types

struct EnvironmentValidationResult {
    let isValid: Bool
    let issues: [String]
}

// MARK: - Convenience Extensions

extension MockUITestEnvironment {
    
    /// Quick setup for standard UI tests
    static func setupStandardUITest(app: XCUIApplication) -> MockUITestEnvironment {
        let environment = MockUITestEnvironment(
            app: app, 
            configuration: basicUITestConfiguration()
        )
        environment.setupMockEnvironment()
        return environment
    }
    
    /// Quick setup for authentication tests
    static func setupAuthenticationTest(app: XCUIApplication) -> MockUITestEnvironment {
        let environment = MockUITestEnvironment(
            app: app, 
            configuration: authenticationTestConfiguration()
        )
        environment.setupMockEnvironment()
        return environment
    }
    
    /// Quick setup for error scenario tests
    static func setupErrorTest(app: XCUIApplication) -> MockUITestEnvironment {
        let environment = MockUITestEnvironment(
            app: app, 
            configuration: errorTestConfiguration()
        )
        environment.setupMockEnvironment()
        return environment
    }
}