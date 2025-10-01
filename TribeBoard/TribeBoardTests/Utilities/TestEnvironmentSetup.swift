import XCTest
import SwiftData
@testable import TribeBoard

/// Utilities for setting up and tearing down test environments
class TestEnvironmentSetup {
    
    // MARK: - Environment Setup
    
    /// Sets up a complete test environment for unit tests
    static func setupUnitTestEnvironment() -> UnitTestEnvironment {
        let mockServices = MockServiceContainer()
        let testContainer = TestUtilities.createTestModelContainer()
        let stateManager = MockServiceStateManager()
        let configuration = TestConfiguration.default
        
        // Configure default state
        TestUtilities.configureDefaultMockServices(mockServices)
        
        return UnitTestEnvironment(
            mockServices: mockServices,
            testContainer: testContainer,
            stateManager: stateManager,
            configuration: configuration
        )
    }
    
    /// Sets up a test environment for integration tests
    static func setupIntegrationTestEnvironment() -> IntegrationTestEnvironment {
        let mockServices = MockServiceContainer()
        let testContainer = TestUtilities.createTestModelContainer()
        let stateManager = MockServiceStateManager()
        let configuration = TestConfiguration.default
        
        // Configure for integration testing
        TestUtilities.configureDefaultMockServices(mockServices)
        
        return IntegrationTestEnvironment(
            mockServices: mockServices,
            testContainer: testContainer,
            stateManager: stateManager,
            configuration: configuration
        )
    }
    
    /// Sets up a test environment for performance tests
    static func setupPerformanceTestEnvironment() -> PerformanceTestEnvironment {
        let mockServices = MockServiceContainer()
        let testContainer = TestUtilities.createTestModelContainer()
        let stateManager = MockServiceStateManager()
        let configuration = TestConfiguration(
            enableLogging: false,
            enablePerformanceMonitoring: true,
            defaultTimeout: 30.0,
            enableAccessibilityTesting: false
        )
        
        // Configure for performance testing
        stateManager.configureLargeDatasetState(mockServices)
        
        return PerformanceTestEnvironment(
            mockServices: mockServices,
            testContainer: testContainer,
            stateManager: stateManager,
            configuration: configuration
        )
    }
    
    /// Sets up a test environment for accessibility tests
    static func setupAccessibilityTestEnvironment() -> AccessibilityTestEnvironment {
        let mockServices = MockServiceContainer()
        let testContainer = TestUtilities.createTestModelContainer()
        let stateManager = MockServiceStateManager()
        let configuration = TestConfiguration(
            enableLogging: true,
            enablePerformanceMonitoring: false,
            defaultTimeout: 15.0,
            enableAccessibilityTesting: true
        )
        
        // Configure for accessibility testing
        TestUtilities.configureDefaultMockServices(mockServices)
        
        return AccessibilityTestEnvironment(
            mockServices: mockServices,
            testContainer: testContainer,
            stateManager: stateManager,
            configuration: configuration
        )
    }
    
    // MARK: - Environment Teardown
    
    /// Tears down a unit test environment
    static func teardownUnitTestEnvironment(_ environment: UnitTestEnvironment) {
        environment.mockServices.resetAll()
        environment.stateManager.clearAllStates()
    }
    
    /// Tears down an integration test environment
    static func teardownIntegrationTestEnvironment(_ environment: IntegrationTestEnvironment) {
        environment.mockServices.resetAll()
        environment.stateManager.clearAllStates()
    }
    
    /// Tears down a performance test environment
    static func teardownPerformanceTestEnvironment(_ environment: PerformanceTestEnvironment) {
        environment.mockServices.resetAll()
        environment.stateManager.clearAllStates()
    }
    
    /// Tears down an accessibility test environment
    static func teardownAccessibilityTestEnvironment(_ environment: AccessibilityTestEnvironment) {
        environment.mockServices.resetAll()
        environment.stateManager.clearAllStates()
    }
    
    // MARK: - Specialized Environment Setup
    
    /// Sets up environment for authentication testing
    static func setupAuthenticationTestEnvironment() -> AuthenticationTestEnvironment {
        let mockServices = MockServiceContainer()
        let testContainer = TestUtilities.createTestModelContainer()
        let stateManager = MockServiceStateManager()
        let configuration = TestConfiguration.default
        
        // Start with unauthenticated state
        stateManager.configureUnauthenticatedState(mockServices)
        
        return AuthenticationTestEnvironment(
            mockServices: mockServices,
            testContainer: testContainer,
            stateManager: stateManager,
            configuration: configuration
        )
    }
    
    /// Sets up environment for family management testing
    static func setupFamilyTestEnvironment() -> FamilyTestEnvironment {
        let mockServices = MockServiceContainer()
        let testContainer = TestUtilities.createTestModelContainer()
        let stateManager = MockServiceStateManager()
        let configuration = TestConfiguration.default
        
        // Configure with authenticated user ready for family operations
        stateManager.configureFamilyCreationState(mockServices)
        
        return FamilyTestEnvironment(
            mockServices: mockServices,
            testContainer: testContainer,
            stateManager: stateManager,
            configuration: configuration
        )
    }
    
    /// Sets up environment for error scenario testing
    static func setupErrorTestEnvironment() -> ErrorTestEnvironment {
        let mockServices = MockServiceContainer()
        let testContainer = TestUtilities.createTestModelContainer()
        let stateManager = MockServiceStateManager()
        let configuration = TestConfiguration.debug // Enable logging for error scenarios
        
        return ErrorTestEnvironment(
            mockServices: mockServices,
            testContainer: testContainer,
            stateManager: stateManager,
            configuration: configuration
        )
    }
    
    // MARK: - Environment Validation
    
    /// Validates that a test environment is properly set up
    static func validateEnvironmentSetup<T: TestEnvironmentProtocol>(_ environment: T) -> EnvironmentValidationResult {
        var issues: [String] = []
        
        // Validate mock services
        if !environment.mockServices.authService.isConfigured {
            issues.append("MockAuthService not configured")
        }
        
        if !environment.mockServices.dataService.isConfigured {
            issues.append("MockDataService not configured")
        }
        
        if !environment.mockServices.keychainService.isConfigured {
            issues.append("MockKeychainService not configured")
        }
        
        // Validate test container
        if environment.testContainer == nil {
            issues.append("Test container not initialized")
        }
        
        // Validate state manager
        if environment.stateManager == nil {
            issues.append("State manager not initialized")
        }
        
        return EnvironmentValidationResult(
            isValid: issues.isEmpty,
            issues: issues
        )
    }
    
    // MARK: - Environment Reset
    
    /// Resets an environment to its initial state
    static func resetEnvironment<T: TestEnvironmentProtocol>(_ environment: T) {
        environment.mockServices.resetAll()
        environment.stateManager.clearAllStates()
        
        // Reconfigure based on environment type
        if environment is AuthenticationTestEnvironment {
            environment.stateManager.configureUnauthenticatedState(environment.mockServices)
        } else if environment is FamilyTestEnvironment {
            environment.stateManager.configureFamilyCreationState(environment.mockServices)
        } else {
            TestUtilities.configureDefaultMockServices(environment.mockServices)
        }
    }
    
    // MARK: - Environment Cloning
    
    /// Creates a copy of an existing environment
    static func cloneEnvironment<T: TestEnvironmentProtocol>(_ environment: T) -> T {
        // Create new environment of same type
        let newEnvironment: T
        
        switch environment {
        case is UnitTestEnvironment:
            newEnvironment = setupUnitTestEnvironment() as! T
        case is IntegrationTestEnvironment:
            newEnvironment = setupIntegrationTestEnvironment() as! T
        case is PerformanceTestEnvironment:
            newEnvironment = setupPerformanceTestEnvironment() as! T
        case is AccessibilityTestEnvironment:
            newEnvironment = setupAccessibilityTestEnvironment() as! T
        case is AuthenticationTestEnvironment:
            newEnvironment = setupAuthenticationTestEnvironment() as! T
        case is FamilyTestEnvironment:
            newEnvironment = setupFamilyTestEnvironment() as! T
        case is ErrorTestEnvironment:
            newEnvironment = setupErrorTestEnvironment() as! T
        default:
            fatalError("Unknown environment type")
        }
        
        // Copy state from original environment
        let stateSnapshot = TestUtilities.captureTestState(environment.mockServices)
        TestUtilities.restoreTestState(newEnvironment.mockServices, from: stateSnapshot)
        
        return newEnvironment
    }
    
    // MARK: - Environment Comparison
    
    /// Compares two test environments
    static func compareEnvironments<T: TestEnvironmentProtocol>(_ env1: T, _ env2: T) -> EnvironmentComparisonResult {
        let stateComparison = env1.stateManager.compareStates(env1.mockServices, env2.mockServices)
        
        var differences = stateComparison.differences
        
        // Compare configurations
        if env1.configuration.enableLogging != env2.configuration.enableLogging {
            differences.append("Logging configuration differs")
        }
        
        if env1.configuration.enablePerformanceMonitoring != env2.configuration.enablePerformanceMonitoring {
            differences.append("Performance monitoring configuration differs")
        }
        
        if env1.configuration.defaultTimeout != env2.configuration.defaultTimeout {
            differences.append("Default timeout differs")
        }
        
        if env1.configuration.enableAccessibilityTesting != env2.configuration.enableAccessibilityTesting {
            differences.append("Accessibility testing configuration differs")
        }
        
        return EnvironmentComparisonResult(
            areEqual: differences.isEmpty,
            differences: differences
        )
    }
}

// MARK: - Environment Protocols

/// Protocol for all test environments
protocol TestEnvironmentProtocol {
    var mockServices: MockServiceContainer { get }
    var testContainer: ModelContainer { get }
    var stateManager: MockServiceStateManager { get }
    var configuration: TestConfiguration { get set }
}

// MARK: - Specific Environment Types

/// Environment for unit tests
struct UnitTestEnvironment: TestEnvironmentProtocol {
    let mockServices: MockServiceContainer
    let testContainer: ModelContainer
    let stateManager: MockServiceStateManager
    var configuration: TestConfiguration
}

/// Environment for integration tests
struct IntegrationTestEnvironment: TestEnvironmentProtocol {
    let mockServices: MockServiceContainer
    let testContainer: ModelContainer
    let stateManager: MockServiceStateManager
    var configuration: TestConfiguration
}

/// Environment for performance tests
struct PerformanceTestEnvironment: TestEnvironmentProtocol {
    let mockServices: MockServiceContainer
    let testContainer: ModelContainer
    let stateManager: MockServiceStateManager
    var configuration: TestConfiguration
}

/// Environment for accessibility tests
struct AccessibilityTestEnvironment: TestEnvironmentProtocol {
    let mockServices: MockServiceContainer
    let testContainer: ModelContainer
    let stateManager: MockServiceStateManager
    var configuration: TestConfiguration
}

/// Environment for authentication tests
struct AuthenticationTestEnvironment: TestEnvironmentProtocol {
    let mockServices: MockServiceContainer
    let testContainer: ModelContainer
    let stateManager: MockServiceStateManager
    var configuration: TestConfiguration
}

/// Environment for family management tests
struct FamilyTestEnvironment: TestEnvironmentProtocol {
    let mockServices: MockServiceContainer
    let testContainer: ModelContainer
    let stateManager: MockServiceStateManager
    var configuration: TestConfiguration
}

/// Environment for error scenario tests
struct ErrorTestEnvironment: TestEnvironmentProtocol {
    let mockServices: MockServiceContainer
    let testContainer: ModelContainer
    let stateManager: MockServiceStateManager
    var configuration: TestConfiguration
}

// MARK: - Validation Results

/// Result of environment validation
struct EnvironmentValidationResult {
    let isValid: Bool
    let issues: [String]
}

/// Result of environment comparison
struct EnvironmentComparisonResult {
    let areEqual: Bool
    let differences: [String]
}