import XCTest
import SwiftData
@testable import TribeBoard

/// Base class for database tests providing common setup, teardown, and utilities
@MainActor
class DatabaseTestBase: XCTestCase {
    
    // MARK: - Properties
    
    /// In-memory ModelContainer for testing
    var modelContainer: ModelContainer!
    
    /// DataService instance for testing
    var dataService: DataService!
    
    /// Mock CloudKit service for testing
    var mockCloudKitService: MockCloudKitService!
    
    /// Main context for testing
    var testContext: ModelContext {
        modelContainer.mainContext
    }
    
    // MARK: - Test Metrics Integration
    
    private var testStartTime: Date?
    private var testStartMemory: Int?
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Record test start metrics
        testStartTime = Date()
        testStartMemory = getCurrentMemoryUsage()
        
        print("🧪 DatabaseTestBase: Setting up test environment...")
        
        // Create in-memory container for testing
        modelContainer = try createInMemoryContainer()
        
        // Create mock CloudKit service
        mockCloudKitService = MockCloudKitService()
        
        // Initialize DataService with test context and mock CloudKit
        dataService = DataService(
            modelContext: testContext,
            cloudKitService: mockCloudKitService
        )
        
        // Verify clean state
        try assertDatabaseIsClean()
        
        print("✅ DatabaseTestBase: Test environment setup complete")
    }
    
    override func tearDown() async throws {
        print("🧹 DatabaseTestBase: Cleaning up test environment...")
        
        // Record test completion metrics
        recordTestMetrics()
        
        // Clean up test data
        try cleanupTestData()
        
        // Verify cleanup was successful
        try assertDatabaseIsClean()
        
        // Reset mock service
        mockCloudKitService?.reset()
        
        // Reset references
        dataService = nil
        mockCloudKitService = nil
        modelContainer = nil
        
        print("✅ DatabaseTestBase: Test environment cleanup complete")
        
        try await super.tearDown()
    }
    
    // MARK: - Test Metrics Recording
    
    /// Records test metrics for reporting
    private func recordTestMetrics() {
        guard let startTime = testStartTime,
              let startMemory = testStartMemory else { return }
        
        let duration = Date().timeIntervalSince(startTime)
        let endMemory = getCurrentMemoryUsage()
        let memoryUsage = max(0, endMemory - startMemory)
        
        let testName = name.components(separatedBy: " ").last?.replacingOccurrences(of: "]", with: "") ?? "unknown"
        let className = String(describing: type(of: self))
        
        // Metrics tracking placeholder
        print("📊 Test metrics: \(testName) - Duration: \(duration)s, Memory: \(memoryUsage) bytes")
        
        // Mark coverage for basic operations
        markBasicOperationsCovered()
    }
    
    /// Marks basic database operations as covered
    private func markBasicOperationsCovered() {
        // This will be called by specific test methods to mark their coverage
        // Base class doesn't mark any specific operations
    }
    
    // MARK: - Container Creation
    
    /// Creates an in-memory ModelContainer for testing
    private func createInMemoryContainer() throws -> ModelContainer {
        print("🧠 DatabaseTestBase: Creating in-memory ModelContainer...")
        
        do {
            let schema = Schema([
                Family.self,
                UserProfile.self,
                Membership.self
            ])
            
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
            
            let container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            print("✅ DatabaseTestBase: In-memory ModelContainer created successfully")
            return container
            
        } catch {
            print("❌ DatabaseTestBase: Failed to create in-memory ModelContainer")
            print("   Error: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Test Data Creation Helpers
    
    /// Creates a test family with valid data
    func createTestFamily(
        name: String = "Test Family",
        code: String = "TEST123",
        createdByUserId: UUID = UUID()
    ) throws -> Family {
        print("🏠 DatabaseTestBase: Creating test family - Name: '\(name)', Code: '\(code)'")
        
        let family = Family(name: name, code: code, createdByUserId: createdByUserId)
        testContext.insert(family)
        try testContext.save()
        
        // Mark coverage
        markCovered("Family.create")
        
        print("✅ DatabaseTestBase: Test family created - ID: \(family.id)")
        return family
    }
    
    /// Creates a test user profile with valid data
    func createTestUser(
        displayName: String = "Test User",
        appleUserIdHash: String = "test_hash_123456789"
    ) throws -> UserProfile {
        print("👤 DatabaseTestBase: Creating test user - Name: '\(displayName)'")
        
        let user = UserProfile(displayName: displayName, appleUserIdHash: appleUserIdHash)
        testContext.insert(user)
        try testContext.save()
        
        // Mark coverage
        markCovered("UserProfile.create")
        
        print("✅ DatabaseTestBase: Test user created - ID: \(user.id)")
        return user
    }
    
    /// Creates a test membership with valid relationships
    func createTestMembership(
        family: Family? = nil,
        user: UserProfile? = nil,
        role: Role = .kid
    ) throws -> Membership {
        print("🤝 DatabaseTestBase: Creating test membership - Role: \(role.displayName)")
        
        let testFamily = family ?? (try createTestFamily())
        let testUser = user ?? (try createTestUser())
        
        let membership = Membership(family: testFamily, user: testUser, role: role)
        testContext.insert(membership)
        try testContext.save()
        
        // Mark coverage
        markCovered("Membership.create")
        
        print("✅ DatabaseTestBase: Test membership created - ID: \(membership.id)")
        return membership
    }
    
    // MARK: - Database State Validation
    
    /// Asserts that the database is in a clean state (no records)
    func assertDatabaseIsClean() throws {
        let familyCount = try countRecords(Family.self)
        let userCount = try countRecords(UserProfile.self)
        let membershipCount = try countRecords(Membership.self)
        
        XCTAssertEqual(familyCount, 0, "Database should have no Family records")
        XCTAssertEqual(userCount, 0, "Database should have no UserProfile records")
        XCTAssertEqual(membershipCount, 0, "Database should have no Membership records")
        
        if familyCount == 0 && userCount == 0 && membershipCount == 0 {
            print("✅ DatabaseTestBase: Database is clean")
        } else {
            print("⚠️ DatabaseTestBase: Database is not clean - Families: \(familyCount), Users: \(userCount), Memberships: \(membershipCount)")
        }
    }
    
    /// Counts records of a specific type
    func countRecords<T: PersistentModel>(_ type: T.Type) throws -> Int {
        let descriptor = FetchDescriptor<T>()
        let records = try testContext.fetch(descriptor)
        return records.count
    }
    
    /// Asserts that a specific number of records exist for a type
    func assertRecordCount<T: PersistentModel>(_ type: T.Type, expectedCount: Int, file: StaticString = #file, line: UInt = #line) throws {
        let actualCount = try countRecords(type)
        XCTAssertEqual(actualCount, expectedCount, "Expected \(expectedCount) \(String(describing: type)) records, but found \(actualCount)", file: file, line: line)
    }
    
    // MARK: - Database Operations
    
    /// Saves the test context
    func saveContext() throws {
        try testContext.save()
    }
    
    /// Fetches all records of a specific type
    func fetchAllRecords<T: PersistentModel>(_ type: T.Type) throws -> [T] {
        let descriptor = FetchDescriptor<T>()
        return try testContext.fetch(descriptor)
    }
    
    /// Fetches records with a predicate
    func fetchRecords<T: PersistentModel>(_ type: T.Type, predicate: Predicate<T>) throws -> [T] {
        let descriptor = FetchDescriptor<T>(predicate: predicate)
        return try testContext.fetch(descriptor)
    }
    
    // MARK: - Cleanup Helpers
    
    /// Cleans up all test data from the database
    private func cleanupTestData() throws {
        print("🧹 DatabaseTestBase: Cleaning up test data...")
        
        // Delete all memberships first (due to relationships)
        let memberships = try fetchAllRecords(Membership.self)
        for membership in memberships {
            testContext.delete(membership)
        }
        
        // Delete all families
        let families = try fetchAllRecords(Family.self)
        for family in families {
            testContext.delete(family)
        }
        
        // Delete all users
        let users = try fetchAllRecords(UserProfile.self)
        for user in users {
            testContext.delete(user)
        }
        
        // Save changes
        try testContext.save()
        
        print("✅ DatabaseTestBase: Test data cleanup complete")
    }
    
    // MARK: - Assertion Helpers
    
    /// Asserts that a family has the expected properties
    func assertFamily(
        _ family: Family,
        hasName expectedName: String,
        code expectedCode: String,
        createdByUserId expectedUserId: UUID,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertEqual(family.name, expectedName, "Family name mismatch", file: file, line: line)
        XCTAssertEqual(family.code, expectedCode, "Family code mismatch", file: file, line: line)
        XCTAssertEqual(family.createdByUserId, expectedUserId, "Family createdByUserId mismatch", file: file, line: line)
        XCTAssertTrue(family.isFullyValid, "Family should be fully valid", file: file, line: line)
    }
    
    /// Asserts that a user profile has the expected properties
    func assertUserProfile(
        _ user: UserProfile,
        hasDisplayName expectedName: String,
        appleUserIdHash expectedHash: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertEqual(user.displayName, expectedName, "User display name mismatch", file: file, line: line)
        XCTAssertEqual(user.appleUserIdHash, expectedHash, "User Apple ID hash mismatch", file: file, line: line)
        XCTAssertTrue(user.isFullyValid, "User should be fully valid", file: file, line: line)
    }
    
    /// Asserts that a membership has the expected properties
    func assertMembership(
        _ membership: Membership,
        hasRole expectedRole: Role,
        status expectedStatus: MembershipStatus = .active,
        family expectedFamily: Family? = nil,
        user expectedUser: UserProfile? = nil,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertEqual(membership.role, expectedRole, "Membership role mismatch", file: file, line: line)
        XCTAssertEqual(membership.status, expectedStatus, "Membership status mismatch", file: file, line: line)
        XCTAssertTrue(membership.isFullyValid, "Membership should be fully valid", file: file, line: line)
        
        if let expectedFamily = expectedFamily {
            XCTAssertEqual(membership.family?.id, expectedFamily.id, "Membership family mismatch", file: file, line: line)
        }
        
        if let expectedUser = expectedUser {
            XCTAssertEqual(membership.user?.id, expectedUser.id, "Membership user mismatch", file: file, line: line)
        }
    }
    
    /// Asserts that a validation error contains expected messages
    func assertValidationError(
        _ error: Error,
        containsMessages expectedMessages: [String],
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard let dataServiceError = error as? DataServiceError else {
            XCTFail("Expected DataServiceError, got \(type(of: error))", file: file, line: line)
            return
        }
        
        switch dataServiceError {
        case .validationFailed(let messages):
            for expectedMessage in expectedMessages {
                XCTAssertTrue(
                    messages.contains { $0.contains(expectedMessage) },
                    "Validation error should contain message: '\(expectedMessage)'. Actual messages: \(messages)",
                    file: file,
                    line: line
                )
            }
        default:
            XCTFail("Expected validation failed error, got \(dataServiceError)", file: file, line: line)
        }
    }
    
    // MARK: - Performance Testing Helpers
    
    /// Measures the execution time of a synchronous operation
    func measureTime<T>(
        operation: () throws -> T,
        file: StaticString = #file,
        line: UInt = #line
    ) rethrows -> (result: T, duration: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try operation()
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        return (result: result, duration: duration)
    }
    
    /// Measures the execution time of an asynchronous operation
    func measureAsyncTime<T>(
        operation: () async throws -> T,
        file: StaticString = #file,
        line: UInt = #line
    ) async rethrows -> (result: T, duration: TimeInterval) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let endTime = CFAbsoluteTimeGetCurrent()
        let duration = endTime - startTime
        
        return (result: result, duration: duration)
    }
    
    /// Measures and records performance metrics for an operation
    func measurePerformance<T>(
        operationName: String,
        benchmark: TimeInterval,
        memoryLimit: Int,
        operation: () throws -> T,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> T {
        let startMemory = getCurrentMemoryUsage()
        let (result, duration) = try measureTime(operation: operation)
        let endMemory = getCurrentMemoryUsage()
        let memoryUsage = max(0, endMemory - startMemory)
        
        let passed = duration <= benchmark && memoryUsage <= memoryLimit
        
        // Record performance metrics
        let testName = name.components(separatedBy: " ").last?.replacingOccurrences(of: "]", with: "") ?? "unknown"
        
        TestMetricsCollector.shared.recordPerformanceMetric(
            testName: testName,
            operationName: operationName,
            duration: duration,
            benchmark: benchmark,
            memoryUsage: memoryUsage,
            memoryLimit: memoryLimit,
            recordCount: 1,
            passed: passed
        )
        
        CITestReporter.shared.recordPerformanceResult(
            testName: testName,
            operationName: operationName,
            duration: duration,
            benchmark: benchmark,
            memoryUsage: memoryUsage,
            memoryLimit: memoryLimit,
            passed: passed
        )
        
        // Assert performance requirements
        XCTAssertLessThanOrEqual(duration, benchmark, 
                                "Operation '\(operationName)' took \(String(format: "%.3f", duration))s, expected ≤ \(String(format: "%.3f", benchmark))s", 
                                file: file, line: line)
        XCTAssertLessThanOrEqual(memoryUsage, memoryLimit, 
                                "Operation '\(operationName)' used \(memoryUsage) bytes, expected ≤ \(memoryLimit) bytes", 
                                file: file, line: line)
        
        return result
    }
    
    /// Measures and records performance metrics for an async operation
    func measureAsyncPerformance<T>(
        operationName: String,
        benchmark: TimeInterval,
        memoryLimit: Int,
        operation: () async throws -> T,
        file: StaticString = #file,
        line: UInt = #line
    ) async throws -> T {
        let startMemory = getCurrentMemoryUsage()
        let (result, duration) = try await measureAsyncTime(operation: operation)
        let endMemory = getCurrentMemoryUsage()
        let memoryUsage = max(0, endMemory - startMemory)
        
        let passed = duration <= benchmark && memoryUsage <= memoryLimit
        
        // Record performance metrics
        let testName = name.components(separatedBy: " ").last?.replacingOccurrences(of: "]", with: "") ?? "unknown"
        
        TestMetricsCollector.shared.recordPerformanceMetric(
            testName: testName,
            operationName: operationName,
            duration: duration,
            benchmark: benchmark,
            memoryUsage: memoryUsage,
            memoryLimit: memoryLimit,
            recordCount: 1,
            passed: passed
        )
        
        CITestReporter.shared.recordPerformanceResult(
            testName: testName,
            operationName: operationName,
            duration: duration,
            benchmark: benchmark,
            memoryUsage: memoryUsage,
            memoryLimit: memoryLimit,
            passed: passed
        )
        
        // Assert performance requirements
        XCTAssertLessThanOrEqual(duration, benchmark, 
                                "Async operation '\(operationName)' took \(String(format: "%.3f", duration))s, expected ≤ \(String(format: "%.3f", benchmark))s", 
                                file: file, line: line)
        XCTAssertLessThanOrEqual(memoryUsage, memoryLimit, 
                                "Async operation '\(operationName)' used \(memoryUsage) bytes, expected ≤ \(memoryLimit) bytes", 
                                file: file, line: line)
        
        return result
    }
    
    // MARK: - Memory Testing Helpers
    
    /// Gets the current memory usage in bytes
    func getCurrentMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int(info.resident_size)
        } else {
            return 0
        }
    }
    
    /// Asserts that memory usage doesn't increase by more than the specified limit during operation
    func assertMemoryUsageWithin<T>(
        limit: Int,
        operation: () throws -> T,
        file: StaticString = #file,
        line: UInt = #line
    ) throws -> T {
        let initialMemory = getCurrentMemoryUsage()
        let result = try operation()
        let finalMemory = getCurrentMemoryUsage()
        let memoryIncrease = finalMemory - initialMemory
        
        XCTAssertLessThanOrEqual(memoryIncrease, limit, 
                                "Memory usage increased by \(memoryIncrease) bytes, expected ≤ \(limit) bytes", 
                                file: file, line: line)
        return result
    }
    
    // MARK: - CloudKit Testing Helpers
    
    /// Configures the mock CloudKit service for testing
    func configureMockCloudKit(
        shouldFailOperations: Bool = false,
        networkDelay: TimeInterval = 0,
        conflictScenario: ConflictScenario = .none
    ) {
        mockCloudKitService.shouldFailOperations = shouldFailOperations
        mockCloudKitService.networkDelay = networkDelay
        mockCloudKitService.conflictScenario = conflictScenario
    }
    
    /// Simulates a CloudKit network error
    func simulateCloudKitNetworkError() {
        mockCloudKitService.simulateNetworkError()
        markOperationCovered("CloudKit.handleError")
    }
    
    /// Simulates a CloudKit conflict scenario
    func simulateCloudKitConflict(_ scenario: ConflictScenario) {
        mockCloudKitService.simulateConflict(scenario: scenario)
        markOperationCovered("CloudKit.resolveConflict")
    }
    
    // MARK: - Coverage Tracking Helpers
    
    /// Convenience method to mark operations as covered in tests
    func markCovered(_ operations: String...) {
        // Coverage tracking placeholder - operations: \(operations.joined(separator: ", "))
    }
    
    /// Convenience method to mark a single operation as covered
    func markOperationCovered(_ operation: String) {
        // Coverage tracking placeholder - operation: \(operation)
    }
}