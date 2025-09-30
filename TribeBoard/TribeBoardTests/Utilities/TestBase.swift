import XCTest
import SwiftData
@testable import TribeBoard

/// Base class for all unit tests providing common setup, teardown, and utility methods
class TestBase: XCTestCase {
    
    // MARK: - Properties
    
    /// Mock services available to all tests
    var mockAuthService: MockAuthService!
    var mockDataService: MockDataService!
    var mockKeychainService: MockKeychainService!
    
    /// Test model container for SwiftData testing
    var testContainer: ModelContainer!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        setupMockServices()
        setupTestContainer()
    }
    
    override func tearDown() {
        cleanupTestEnvironment()
        super.tearDown()
    }
    
    // MARK: - Setup Methods
    
    private func setupMockServices() {
        mockAuthService = MockAuthService()
        mockDataService = MockDataService()
        mockKeychainService = MockKeychainService()
    }
    
    private func setupTestContainer() {
        let schema = Schema([
            UserProfile.self,
            Family.self,
            ChildProfile.self,
            SchoolRun.self,
            MealPlan.self,
            GroceryItem.self,
            ShoppingTask.self
        ])
        
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        
        do {
            testContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to create test container: \(error)")
        }
    }
    
    private func cleanupTestEnvironment() {
        // Reset mock services
        mockAuthService?.reset()
        mockDataService?.reset()
        mockKeychainService?.reset()
        
        // Clear test container
        testContainer = nil
    }
    
    // MARK: - Test Utilities
    
    /// Creates a test expectation with a descriptive name
    func expectation(description: String, timeout: TimeInterval = 5.0) -> XCTestExpectation {
        return XCTestExpectation(description: description)
    }
    
    /// Waits for expectations with default timeout
    func waitForExpectations(timeout: TimeInterval = 5.0) {
        wait(for: [], timeout: timeout)
    }
    
    /// Asserts that an async operation completes successfully
    func assertAsyncSuccess<T>(_ operation: @escaping () async throws -> T, 
                              file: StaticString = #filePath, 
                              line: UInt = #line) async {
        do {
            _ = try await operation()
        } catch {
            XCTFail("Expected success but got error: \(error)", file: file, line: line)
        }
    }
    
    /// Asserts that an async operation throws a specific error
    func assertAsyncThrows<T, E: Error & Equatable>(_ expectedError: E,
                                                   _ operation: @escaping () async throws -> T,
                                                   file: StaticString = #filePath,
                                                   line: UInt = #line) async {
        do {
            _ = try await operation()
            XCTFail("Expected error \(expectedError) but operation succeeded", file: file, line: line)
        } catch let error as E {
            XCTAssertEqual(error, expectedError, file: file, line: line)
        } catch {
            XCTFail("Expected error \(expectedError) but got \(error)", file: file, line: line)
        }
    }
    
    /// Creates a test context for SwiftData operations
    @MainActor
    func createTestContext() -> ModelContext {
        return ModelContext(testContainer)
    }
    
    /// Performs an operation in a test context and saves changes
    @MainActor
    func performInTestContext<T>(_ operation: (ModelContext) throws -> T) throws -> T {
        let context = createTestContext()
        let result = try operation(context)
        try context.save()
        return result
    }
}

// MARK: - Test Data Helpers

extension TestBase {
    
    /// Creates a test user profile
    func createTestUser(name: String = "Test User", 
                       email: String = "test@example.com") -> UserProfile {
        return UserProfile(
            id: UUID(),
            name: name,
            email: email,
            appleUserID: "test.apple.id.\(UUID().uuidString)"
        )
    }
    
    /// Creates a test family
    func createTestFamily(name: String = "Test Family", 
                         createdBy: UserProfile? = nil) -> Family {
        let creator = createdBy ?? createTestUser()
        return Family(
            id: UUID(),
            name: name,
            createdBy: creator.id,
            inviteCode: "TEST\(Int.random(in: 1000...9999))"
        )
    }
    
    /// Creates a test child profile
    func createTestChild(name: String = "Test Child", 
                        family: Family? = nil) -> ChildProfile {
        let testFamily = family ?? createTestFamily()
        return ChildProfile(
            id: UUID(),
            name: name,
            familyID: testFamily.id,
            dateOfBirth: Calendar.current.date(byAdding: .year, value: -8, to: Date()) ?? Date()
        )
    }
}