import XCTest
import SwiftData
@testable import TribeBoard

/// Tests to verify the database testing infrastructure works correctly
@MainActor
final class DatabaseInfrastructureTests: DatabaseTestBase {
    
    // MARK: - DatabaseTestBase Tests
    
    func testDatabaseTestBaseSetup() async throws {
        // Test that the base class sets up correctly
        XCTAssertNotNil(modelContainer, "ModelContainer should be initialized")
        XCTAssertNotNil(dataService, "DataService should be initialized")
        XCTAssertNotNil(testContext, "Test context should be available")
        
        // Test that database starts clean
        try assertDatabaseIsClean()
    }
    
    func testCreateTestFamily() throws {
        // Test creating a test family
        let family = try createTestFamily(name: "Infrastructure Test Family", code: "INFRA01", createdByUserId: UUID())
        
        XCTAssertEqual(family.name, "Infrastructure Test Family")
        XCTAssertEqual(family.code, "INFRA01")
        XCTAssertTrue(family.isFullyValid)
        
        // Verify it was saved to database
        try assertRecordCount(Family.self, expectedCount: 1)
    }
    
    func testCreateTestUser() throws {
        // Test creating a test user
        let user = try createTestUser(displayName: "Infrastructure Test User", appleUserIdHash: "infra_test_hash_123456789")
        
        XCTAssertEqual(user.displayName, "Infrastructure Test User")
        XCTAssertEqual(user.appleUserIdHash, "infra_test_hash_123456789")
        XCTAssertTrue(user.isFullyValid)
        
        // Verify it was saved to database
        try assertRecordCount(UserProfile.self, expectedCount: 1)
    }
    
    func testCreateTestMembership() throws {
        // Test creating a test membership
        let membership = try createTestMembership(role: .adult)
        
        XCTAssertEqual(membership.role, .adult)
        XCTAssertEqual(membership.status, .active)
        XCTAssertTrue(membership.isFullyValid)
        XCTAssertNotNil(membership.family)
        XCTAssertNotNil(membership.user)
        
        // Verify all records were created
        try assertRecordCount(Family.self, expectedCount: 1)
        try assertRecordCount(UserProfile.self, expectedCount: 1)
        try assertRecordCount(Membership.self, expectedCount: 1)
    }
    
    // MARK: - TestDataFactory Tests
    
    @MainActor func testValidFamilyCreation() {
        let family = TestDataFactory.createValidFamily(name: "Factory Test Family", code: "FACT123", createdByUserId: UUID())
        
        XCTAssertEqual(family.name, "Factory Test Family")
        XCTAssertEqual(family.code, "FACT123")
        XCTAssertTrue(family.isFullyValid)
    }
    
    @MainActor func testInvalidFamilyCreation() {
        let invalidNameFamily = TestDataFactory.createInvalidFamily(invalidField: .name)
        let invalidCodeFamily = TestDataFactory.createInvalidFamily(invalidField: .code)
        
        XCTAssertFalse(invalidNameFamily.isNameValid)
        XCTAssertFalse(invalidCodeFamily.isCodeValid)
    }
    
    @MainActor func testValidUserCreation() {
        let user = TestDataFactory.createValidUserProfile(displayName: "Factory Test User", appleUserIdHash: "factory_test_hash_123456789")
        
        XCTAssertEqual(user.displayName, "Factory Test User")
        XCTAssertEqual(user.appleUserIdHash, "factory_test_hash_123456789")
        XCTAssertTrue(user.isFullyValid)
    }
    
    @MainActor func testInvalidUserCreation() {
        let invalidNameUser = TestDataFactory.createInvalidUserProfile(invalidField: .displayName)
        let invalidHashUser = TestDataFactory.createInvalidUserProfile(invalidField: .appleUserIdHash)
        
        XCTAssertFalse(invalidNameUser.isDisplayNameValid)
        XCTAssertFalse(invalidHashUser.isAppleUserIdHashValid)
    }
    
    @MainActor func testBulkDataCreation() {
        let families = TestDataFactory.createBulkFamilies(count: 5)
        let users = TestDataFactory.createBulkUsers(count: 5)
        
        XCTAssertEqual(families.count, 5)
        XCTAssertEqual(users.count, 5)
        
        // Verify all families have unique codes
        let codes = families.map { $0.code }
        let uniqueCodes = Set(codes)
        XCTAssertEqual(codes.count, uniqueCodes.count, "All family codes should be unique")
        
        // Verify all users have unique hashes
        let hashes = users.map { $0.appleUserIdHash }
        let uniqueHashes = Set(hashes)
        XCTAssertEqual(hashes.count, uniqueHashes.count, "All user hashes should be unique")
    }
    
    @MainActor func testFamilyWithMembersCreation() {
        let (family, users, memberships) = TestDataFactory.createFamilyWithMembers(memberCount: 3)
        
        XCTAssertEqual(users.count, 3)
        XCTAssertEqual(memberships.count, 3)
        
        // First member should be parent admin
        XCTAssertEqual(memberships[0].role, .parentAdmin)
        
        // Other members should be kids
        for i in 1..<memberships.count {
            XCTAssertEqual(memberships[i].role, .kid)
        }
        
        // All memberships should reference the same family
        for membership in memberships {
            XCTAssertEqual(membership.family?.id, family.id)
        }
    }
    
    // MARK: - PerformanceTestUtilities Tests
    
    func testPerformanceMeasurement() throws {
        let (result, metrics) = try PerformanceTestUtilities.measureDatabaseOperation(
            operation: {
                return "Test operation completed"
            },
            expectedMaxDuration: 1.0,
            description: "Test Performance Measurement"
        )
        
        XCTAssertEqual(result, "Test operation completed")
        XCTAssertEqual(metrics.operationName, "Test Performance Measurement")
        XCTAssertTrue(metrics.passed, "Performance test should pass with 1 second threshold")
        XCTAssertLessThanOrEqual(metrics.duration, 1.0)
    }
    
    func testAsyncPerformanceMeasurement() async throws {
        let (result, metrics) = try await PerformanceTestUtilities.measureAsyncDatabaseOperation(
            operation: {
                // Simulate async work
                try await Task.sleep(nanoseconds: 10_000_000) // 10ms
                return "Async test completed"
            },
            expectedMaxDuration: 1.0,
            description: "Test Async Performance Measurement"
        )
        
        XCTAssertEqual(result, "Async test completed")
        XCTAssertEqual(metrics.operationName, "Test Async Performance Measurement")
        XCTAssertTrue(metrics.passed, "Async performance test should pass")
    }
    
    func testBatchOperationMeasurement() throws {
        let (result, metrics) = try PerformanceTestUtilities.measureBatchOperation(
            operation: {
                return Array(1...10).map { "Item \($0)" }
            },
            expectedMaxDuration: 1.0,
            description: "Test Batch Operation"
        )
        
        XCTAssertEqual(result.count, 10)
        XCTAssertEqual(metrics.recordCount, 10)
        XCTAssertTrue(metrics.passed, "Batch operation should pass")
    }
    
    func testMemoryValidation() throws {
        let metrics = try PerformanceTestUtilities.validateMemoryUsage(
            during: {
                // Create some test data that should use minimal memory
                _ = TestDataFactory.createValidFamily()
                _ = TestDataFactory.createValidUserProfile()
            },
            maxMemoryIncrease: 10_485_760, // 10MB - generous limit for test
            description: "Test Memory Validation"
        )
        
        XCTAssertTrue(metrics.passed, "Memory validation should pass with generous limit")
        XCTAssertLessThanOrEqual(metrics.memoryIncrease, 10_485_760)
    }
    
    @MainActor func testPerformanceBenchmarks() {
        // Test that benchmarks are properly defined
        let createFamilyBenchmark = DatabasePerformanceBenchmarks.createFamily
        XCTAssertEqual(createFamilyBenchmark.operationName, "Create Family")
        XCTAssertEqual(createFamilyBenchmark.maxDuration, 0.010)
        
        let fetchBenchmark = DatabasePerformanceBenchmarks.fetchFamilyByCode
        XCTAssertEqual(fetchBenchmark.operationName, "Fetch Family by Code")
        XCTAssertEqual(fetchBenchmark.maxDuration, 0.005)
        
        // Test that all benchmarks are available
        let allBenchmarks = DatabasePerformanceBenchmarks.all
        XCTAssertGreaterThan(allBenchmarks.count, 0, "Should have predefined benchmarks")
    }
    
    @MainActor func testScalabilityBenchmarks() {
        let scalabilityBenchmarks = ScalabilityBenchmarks.all
        XCTAssertGreaterThan(scalabilityBenchmarks.count, 0, "Should have scalability benchmarks")
        
        let fetch10Benchmark = ScalabilityBenchmarks.fetch10Families
        XCTAssertEqual(fetch10Benchmark.operationName, "Fetch 10 Families")
        XCTAssertEqual(fetch10Benchmark.maxDuration, 0.010)
    }
    
    func testPerformanceReportGeneration() throws {
        // Create some test metrics
        let metrics1 = PerformanceMetrics(
            operationName: "Test Op 1",
            duration: 0.005,
            memoryUsage: 1000,
            recordCount: 1,
            passed: true,
            threshold: 0.010
        )
        
        let metrics2 = PerformanceMetrics(
            operationName: "Test Op 2",
            duration: 0.015,
            memoryUsage: 2000,
            recordCount: 1,
            passed: false,
            threshold: 0.010
        )
        
        let report = PerformanceTestUtilities.generatePerformanceReport(metrics: [metrics1, metrics2])
        
        XCTAssertEqual(report.totalOperations, 2)
        XCTAssertEqual(report.passedOperations, 1)
        XCTAssertEqual(report.failedOperations, 1)
        XCTAssertEqual(report.totalDuration, 0.020, accuracy: 0.001)
        XCTAssertEqual(report.totalMemoryUsage, 3000)
        XCTAssertEqual(report.successRate, 0.5, accuracy: 0.01)
    }
}