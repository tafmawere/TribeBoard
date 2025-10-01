import XCTest
import SwiftData
@testable import TribeBoard

/// Comprehensive test utilities for shared testing functionality
class TestUtilities {
    
    // MARK: - Test Environment Management
    
    /// Sets up a complete test environment with all necessary components
    static func setupCompleteTestEnvironment() -> TestEnvironment {
        let mockServices = MockServiceContainer()
        let testContainer = createTestModelContainer()
        let testConfiguration = TestConfiguration.default
        
        return TestEnvironment(
            mockServices: mockServices,
            testContainer: testContainer,
            configuration: testConfiguration
        )
    }
    
    /// Creates an in-memory model container for testing
    static func createTestModelContainer() -> ModelContainer {
        let schema = Schema([
            UserProfile.self,
            Family.self,
            ChildProfile.self,
            SchoolRun.self,
            MealPlan.self,
            GroceryItem.self,
            ShoppingTask.self,
            Membership.self
        ] as [any PersistentModel.Type])
        
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create test model container: \(error)")
        }
    }
    
    /// Cleans up test environment and resets all state
    static func cleanupTestEnvironment(_ environment: TestEnvironment) {
        environment.mockServices.resetAll()
        // Model container cleanup is handled automatically for in-memory containers
    }
    
    // MARK: - Mock Service Configuration
    
    /// Configures all mock services with default test data
    static func configureDefaultMockServices(_ mockServices: MockServiceContainer) {
        // Configure auth service with default user
        let defaultUser = TestDataFactory.createTestUserProfile(displayName: "Default Test User")
        mockServices.authService.setMockUserProfile(defaultUser)
        mockServices.authService.setAuthenticationState(.authenticated)
        
        // Configure keychain with default data
        let keychainData = TestDataFactory.createTestKeychainData()
        for (key, data) in keychainData {
            mockServices.keychainService.prePopulate(data: data, for: key)
        }
        
        // Configure data service with default family
        let familyScenario = TestDataFactory.createCompleteFamilyScenario()
        TestDataFactory.configureMockDataService(mockServices.dataService, with: familyScenario)
    }
    
    /// Configures mock services for authentication testing scenarios
    static func configureMockServicesForAuthTesting(_ mockServices: MockServiceContainer, scenario: AuthTestScenario) {
        TestDataFactory.configureMockAuthService(mockServices.authService, with: scenario)
        TestDataFactory.configureMockKeychain(mockServices.keychainService, with: scenario)
        
        // Reset data service to clean state for auth testing
        mockServices.dataService.reset()
    }
    
    /// Configures mock services for family testing scenarios
    static func configureMockServicesForFamilyTesting(_ mockServices: MockServiceContainer, scenario: FamilyTestScenario) {
        TestDataFactory.configureMockDataService(mockServices.dataService, with: scenario)
        
        // Configure auth service with family creator
        mockServices.authService.setMockUserProfile(scenario.creator)
        mockServices.authService.setAuthenticationState(.authenticated)
    }
    
    /// Configures mock services for error testing scenarios
    static func configureMockServicesForErrorTesting(_ mockServices: MockServiceContainer, errorType: TestErrorType) {
        switch errorType {
        case .authenticationError(let authError):
            mockServices.authService.setMockError(authError)
        case .dataServiceError(let dataError):
            mockServices.dataService.setMockError(dataError)
        case .keychainError(let keychainError):
            mockServices.keychainService.setMockError(keychainError)
        case .networkError:
            mockServices.authService.setNetworkUnavailable(true)
            mockServices.dataService.setNetworkUnavailable(true)
        }
    }
    
    // MARK: - Test Data Generation and Cleanup
    
    /// Generates a complete test dataset for comprehensive testing
    static func generateCompleteTestDataset() -> CompleteTestDataset {
        let users = TestDataFactory.createMultipleTestUserProfiles(count: 5)
        let families = TestDataFactory.createMultipleTestFamilies(count: 3)
        let authScenarios = (0..<3).map { _ in TestDataFactory.createCompleteAuthScenario() }
        let familyScenarios = (0..<3).map { _ in TestDataFactory.createCompleteFamilyScenario() }
        
        return CompleteTestDataset(
            users: users,
            families: families,
            authScenarios: authScenarios,
            familyScenarios: familyScenarios
        )
    }
    
    /// Populates a test model context with comprehensive test data
    @MainActor
    static func populateTestContext(_ context: ModelContext, with dataset: CompleteTestDataset) throws {
        // Insert users
        for user in dataset.users {
            context.insert(user)
        }
        
        // Insert families
        for family in dataset.families {
            context.insert(family)
        }
        
        // Create memberships linking users to families
        for (familyIndex, family) in dataset.families.enumerated() {
            let familyUsers = Array(dataset.users.dropFirst(familyIndex).prefix(2))
            for (userIndex, user) in familyUsers.enumerated() {
                let role: Role = userIndex == 0 ? .parentAdmin : .parent
                let membership = TestDataFactory.createTestMembership(
                    familyId: family.id,
                    userId: user.id,
                    role: role
                )
                context.insert(membership)
            }
        }
        
        try context.save()
    }
    
    /// Cleans up all test data from a model context
    @MainActor
    static func cleanupTestContext(_ context: ModelContext) throws {
        // Delete all test entities
        let entityTypes: [any PersistentModel.Type] = [
            UserProfile.self,
            Family.self,
            ChildProfile.self,
            SchoolRun.self,
            MealPlan.self,
            GroceryItem.self,
            ShoppingTask.self,
            Membership.self
        ]
        
        for entityType in entityTypes {
            try context.delete(model: entityType)
        }
        
        try context.save()
    }
    
    // MARK: - Test State Management
    
    /// Captures the current state of mock services for later restoration
    static func captureTestState(_ mockServices: MockServiceContainer) -> TestStateSnapshot {
        return TestStateSnapshot(
            authState: mockServices.authService.currentState,
            keychainData: mockServices.keychainService.getAllStoredData(),
            dataServiceState: mockServices.dataService.currentState
        )
    }
    
    /// Restores mock services to a previously captured state
    static func restoreTestState(_ mockServices: MockServiceContainer, from snapshot: TestStateSnapshot) {
        mockServices.authService.restoreState(snapshot.authState)
        mockServices.keychainService.restoreData(snapshot.keychainData)
        mockServices.dataService.restoreState(snapshot.dataServiceState)
    }
    
    /// Creates a test state checkpoint that can be restored later
    static func createTestCheckpoint(_ environment: TestEnvironment) -> TestCheckpoint {
        let stateSnapshot = captureTestState(environment.mockServices)
        return TestCheckpoint(
            timestamp: Date(),
            stateSnapshot: stateSnapshot,
            configuration: environment.configuration
        )
    }
    
    /// Restores test environment to a checkpoint
    static func restoreToCheckpoint(_ environment: TestEnvironment, checkpoint: TestCheckpoint) {
        restoreTestState(environment.mockServices, from: checkpoint.stateSnapshot)
        environment.configuration = checkpoint.configuration
    }
    
    // MARK: - Performance Testing Utilities
    
    /// Measures the execution time of a synchronous operation
    static func measureExecutionTime<T>(operation: () throws -> T) rethrows -> (result: T, executionTime: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try operation()
        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
        return (result, executionTime)
    }
    
    /// Measures the execution time of an asynchronous operation
    static func measureAsyncExecutionTime<T>(operation: () async throws -> T) async rethrows -> (result: T, executionTime: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
        return (result, executionTime)
    }
    
    /// Creates a performance benchmark for repeated operations
    static func createPerformanceBenchmark(name: String, iterations: Int = 100) -> PerformanceBenchmark {
        return PerformanceBenchmark(name: name, iterations: iterations)
    }
    
    // MARK: - Validation Utilities
    
    /// Validates that a test environment is properly configured
    static func validateTestEnvironment(_ environment: TestEnvironment) -> TestEnvironmentValidationResult {
        var issues: [String] = []
        
        // Validate mock services
        if !environment.mockServices.authService.isConfigured {
            issues.append("MockAuthService is not properly configured")
        }
        
        if !environment.mockServices.dataService.isConfigured {
            issues.append("MockDataService is not properly configured")
        }
        
        if !environment.mockServices.keychainService.isConfigured {
            issues.append("MockKeychainService is not properly configured")
        }
        
        // Validate test container
        if environment.testContainer == nil {
            issues.append("Test model container is not initialized")
        }
        
        return TestEnvironmentValidationResult(
            isValid: issues.isEmpty,
            issues: issues
        )
    }
    
    /// Validates test data integrity
    static func validateTestData(_ dataset: CompleteTestDataset) -> TestDataValidationResult {
        var issues: [String] = []
        
        // Validate users
        for user in dataset.users {
            if !TestDataFactory.validateUserProfile(user) {
                issues.append("Invalid user profile: \(user.displayName)")
            }
        }
        
        // Validate families
        for family in dataset.families {
            if !TestDataFactory.validateFamily(family) {
                issues.append("Invalid family: \(family.name)")
            }
        }
        
        return TestDataValidationResult(
            isValid: issues.isEmpty,
            issues: issues
        )
    }
    
    // MARK: - Test Debugging Utilities
    
    /// Prints detailed information about the current test environment
    static func debugTestEnvironment(_ environment: TestEnvironment) {
        print("=== Test Environment Debug Info ===")
        print("Auth Service State: \(environment.mockServices.authService.currentState)")
        print("Data Service State: \(environment.mockServices.dataService.currentState)")
        print("Keychain Data Count: \(environment.mockServices.keychainService.getAllStoredData().count)")
        print("Test Configuration: \(environment.configuration)")
        print("===================================")
    }
    
    /// Prints detailed information about test data
    static func debugTestData(_ dataset: CompleteTestDataset) {
        print("=== Test Data Debug Info ===")
        print("Users: \(dataset.users.count)")
        print("Families: \(dataset.families.count)")
        print("Auth Scenarios: \(dataset.authScenarios.count)")
        print("Family Scenarios: \(dataset.familyScenarios.count)")
        print("============================")
    }
    
    /// Creates a detailed test report for debugging failures
    static func createTestReport(testName: String, environment: TestEnvironment, error: Error?) -> TestReport {
        return TestReport(
            testName: testName,
            timestamp: Date(),
            environment: environment,
            error: error,
            environmentValidation: validateTestEnvironment(environment)
        )
    }
}

// MARK: - Supporting Types

/// Container for all mock services used in testing
class MockServiceContainer {
    let authService: MockAuthService
    let dataService: MockDataService
    let keychainService: MockKeychainService
    
    init() {
        self.authService = MockAuthService()
        self.dataService = MockDataService()
        self.keychainService = MockKeychainService()
    }
    
    func resetAll() {
        authService.reset()
        dataService.reset()
        keychainService.reset()
    }
}

/// Complete test environment configuration
struct TestEnvironment {
    let mockServices: MockServiceContainer
    let testContainer: ModelContainer
    var configuration: TestConfiguration
}

/// Test configuration settings
struct TestConfiguration {
    let enableLogging: Bool
    let enablePerformanceMonitoring: Bool
    let defaultTimeout: TimeInterval
    let enableAccessibilityTesting: Bool
    
    static let `default` = TestConfiguration(
        enableLogging: false,
        enablePerformanceMonitoring: false,
        defaultTimeout: 5.0,
        enableAccessibilityTesting: true
    )
    
    static let debug = TestConfiguration(
        enableLogging: true,
        enablePerformanceMonitoring: true,
        defaultTimeout: 10.0,
        enableAccessibilityTesting: true
    )
}

/// Complete test dataset for comprehensive testing
struct CompleteTestDataset {
    let users: [UserProfile]
    let families: [Family]
    let authScenarios: [AuthTestScenario]
    let familyScenarios: [FamilyTestScenario]
}

/// Test error types for error scenario testing
enum TestErrorType {
    case authenticationError(AuthError)
    case dataServiceError(DataServiceError)
    case keychainError(KeychainService.KeychainError)
    case networkError
}

/// Snapshot of test state for restoration
struct TestStateSnapshot {
    let authState: MockAuthService.AuthState
    let keychainData: [String: Data]
    let dataServiceState: MockDataService.DataState
}

/// Test checkpoint for state management
struct TestCheckpoint {
    let timestamp: Date
    let stateSnapshot: TestStateSnapshot
    let configuration: TestConfiguration
}

/// Performance benchmark for testing
class PerformanceBenchmark {
    let name: String
    let iterations: Int
    private var executionTimes: [TimeInterval] = []
    
    init(name: String, iterations: Int) {
        self.name = name
        self.iterations = iterations
    }
    
    func recordExecution(time: TimeInterval) {
        executionTimes.append(time)
    }
    
    var averageTime: TimeInterval {
        guard !executionTimes.isEmpty else { return 0 }
        return executionTimes.reduce(0, +) / Double(executionTimes.count)
    }
    
    var minTime: TimeInterval {
        return executionTimes.min() ?? 0
    }
    
    var maxTime: TimeInterval {
        return executionTimes.max() ?? 0
    }
}

/// Test environment validation result
struct TestEnvironmentValidationResult {
    let isValid: Bool
    let issues: [String]
}

/// Test data validation result
struct TestDataValidationResult {
    let isValid: Bool
    let issues: [String]
}

/// Comprehensive test report for debugging
struct TestReport {
    let testName: String
    let timestamp: Date
    let environment: TestEnvironment
    let error: Error?
    let environmentValidation: TestEnvironmentValidationResult
    
    var summary: String {
        var summary = "Test Report: \(testName)\n"
        summary += "Timestamp: \(timestamp)\n"
        summary += "Environment Valid: \(environmentValidation.isValid)\n"
        
        if let error = error {
            summary += "Error: \(error.localizedDescription)\n"
        }
        
        if !environmentValidation.issues.isEmpty {
            summary += "Issues: \(environmentValidation.issues.joined(separator: ", "))\n"
        }
        
        return summary
    }
}