import XCTest
import SwiftData
@testable import TribeBoard

/// Tests for database operation timing validation
@MainActor
final class DatabasePerformanceTests: DatabaseTestBase {
    
    // MARK: - Single Operation Performance Tests
    
    /// Test that single family creation completes within 10ms benchmark
    func testSingleFamilyCreationPerformance() async throws {
        print("🏠 Testing single family creation performance...")
        
        let (family, metrics) = try PerformanceTestUtilities.measureDatabaseOperation(
            operation: {
                return try dataService.createFamily(
                    name: "Performance Test Family",
                    code: "PERF123",
                    createdByUserId: UUID()
                )
            },
            expectedMaxDuration: DatabasePerformanceBenchmarks.createFamily.maxDuration,
            description: DatabasePerformanceBenchmarks.createFamily.operationName
        )
        
        // Validate the operation succeeded
        XCTAssertNotNil(family)
        XCTAssertEqual(family.name, "Performance Test Family")
        XCTAssertEqual(family.code, "PERF123")
        XCTAssertTrue(family.isFullyValid)
        
        // Assert performance meets benchmark
        PerformanceTestUtilities.assertPerformance(metrics)
        PerformanceTestUtilities.validateAgainstBenchmark(metrics, benchmark: DatabasePerformanceBenchmarks.createFamily)
        
        print("✅ Single family creation performance test passed")
    }
    
    /// Test that family fetch by code completes within 5ms benchmark
    func testFamilyFetchByCodePerformance() async throws {
        print("🔍 Testing family fetch by code performance...")
        
        // Setup: Create a family to fetch
        let testFamily = try createTestFamily(name: "Fetch Test Family", code: "FETCH01", createdByUserId: UUID())
        
        let (fetchedFamily, metrics) = try PerformanceTestUtilities.measureDatabaseOperation(
            operation: {
                return try dataService.fetchFamily(byCode: "FETCH01")
            },
            expectedMaxDuration: DatabasePerformanceBenchmarks.fetchFamilyByCode.maxDuration,
            description: DatabasePerformanceBenchmarks.fetchFamilyByCode.operationName
        )
        
        // Validate the operation succeeded
        XCTAssertNotNil(fetchedFamily)
        XCTAssertEqual(fetchedFamily?.id, testFamily.id)
        XCTAssertEqual(fetchedFamily?.name, "Fetch Test Family")
        XCTAssertEqual(fetchedFamily?.code, "FETCH01")
        
        // Assert performance meets benchmark
        PerformanceTestUtilities.assertPerformance(metrics)
        PerformanceTestUtilities.validateAgainstBenchmark(metrics, benchmark: DatabasePerformanceBenchmarks.fetchFamilyByCode)
        
        print("✅ Family fetch by code performance test passed")
    }
    
    /// Test that membership creation completes within 15ms benchmark
    func testMembershipCreationPerformance() async throws {
        print("🤝 Testing membership creation performance...")
        
        // Setup: Create family and user
        let testFamily = try createTestFamily(name: "Membership Test Family", code: "MEMB123", createdByUserId: UUID())
        let testUser = try createTestUser(displayName: "Membership Test User")
        
        let (membership, metrics) = try PerformanceTestUtilities.measureDatabaseOperation(
            operation: {
                return try dataService.createMembership(
                    familyId: testFamily.id,
                    userId: testUser.id,
                    role: .kid
                )
            },
            expectedMaxDuration: DatabasePerformanceBenchmarks.createMembership.maxDuration,
            description: DatabasePerformanceBenchmarks.createMembership.operationName
        )
        
        // Validate the operation succeeded
        XCTAssertNotNil(membership)
        XCTAssertEqual(membership.family?.id, testFamily.id)
        XCTAssertEqual(membership.user?.id, testUser.id)
        XCTAssertEqual(membership.role, .kid)
        XCTAssertEqual(membership.status, .active)
        XCTAssertTrue(membership.isFullyValid)
        
        // Assert performance meets benchmark
        PerformanceTestUtilities.assertPerformance(metrics)
        PerformanceTestUtilities.validateAgainstBenchmark(metrics, benchmark: DatabasePerformanceBenchmarks.createMembership)
        
        print("✅ Membership creation performance test passed")
    }
    
    // MARK: - Batch Operation Performance Tests
    
    /// Test that batch family creation (100 records) completes within 500ms benchmark
    func testBatchFamilyCreationPerformance() async throws {
        print("📦 Testing batch family creation performance (100 families)...")
        
        let (families, metrics) = try PerformanceTestUtilities.measureBatchOperation(
            operation: {
                var createdFamilies: [Family] = []
                
                for i in 1...100 {
                    let family = try dataService.createFamily(
                        name: "Batch Family \(i)",
                        code: String(format: "BAT%03d", i),
                        createdByUserId: UUID()
                    )
                    createdFamilies.append(family)
                }
                
                return createdFamilies
            },
            expectedMaxDuration: DatabasePerformanceBenchmarks.batchOperations.maxDuration,
            description: DatabasePerformanceBenchmarks.batchOperations.operationName
        )
        
        // Validate the operation succeeded
        XCTAssertEqual(families.count, 100)
        
        // Verify all families were created correctly
        for (index, family) in families.enumerated() {
            let expectedName = "Batch Family \(index + 1)"
            let expectedCode = String(format: "BAT%03d", index + 1)
            
            XCTAssertEqual(family.name, expectedName)
            XCTAssertEqual(family.code, expectedCode)
            XCTAssertTrue(family.isFullyValid)
        }
        
        // Verify database state
        try assertRecordCount(Family.self, expectedCount: 100)
        
        // Assert performance meets benchmark
        PerformanceTestUtilities.assertPerformance(metrics)
        PerformanceTestUtilities.validateAgainstBenchmark(metrics, benchmark: DatabasePerformanceBenchmarks.batchOperations)
        
        print("✅ Batch family creation performance test passed")
    }
    
    /// Test that batch user creation (100 records) completes within 500ms benchmark
    func testBatchUserCreationPerformance() async throws {
        print("👥 Testing batch user creation performance (100 users)...")
        
        let (users, metrics) = try PerformanceTestUtilities.measureBatchOperation(
            operation: {
                var createdUsers: [UserProfile] = []
                
                for i in 1...100 {
                    let user = UserProfile(
                        displayName: "Batch User \(i)",
                        appleUserIdHash: "batch_hash_\(String(format: "%03d", i))_\(UUID().uuidString.prefix(10))"
                    )
                    testContext.insert(user)
                    createdUsers.append(user)
                }
                
                try testContext.save()
                return createdUsers
            },
            expectedMaxDuration: DatabasePerformanceBenchmarks.batchOperations.maxDuration,
            description: "Batch User Creation (100 records)"
        )
        
        // Validate the operation succeeded
        XCTAssertEqual(users.count, 100)
        
        // Verify all users were created correctly
        for (index, user) in users.enumerated() {
            let expectedName = "Batch User \(index + 1)"
            
            XCTAssertEqual(user.displayName, expectedName)
            XCTAssertTrue(user.appleUserIdHash.hasPrefix("batch_hash_"))
            XCTAssertTrue(user.isFullyValid)
        }
        
        // Verify database state
        try assertRecordCount(UserProfile.self, expectedCount: 100)
        
        // Assert performance meets benchmark
        PerformanceTestUtilities.assertPerformance(metrics)
        
        print("✅ Batch user creation performance test passed")
    }
    
    /// Test that batch membership creation (100 records) completes within 500ms benchmark
    func testBatchMembershipCreationPerformance() async throws {
        print("🤝 Testing batch membership creation performance (100 memberships)...")
        
        // Setup: Create families and users for memberships
        let families = try (1...10).map { i in
            try createTestFamily(name: "Family \(i)", code: "FAM\(String(format: "%02d", i))")
        }
        
        let users = try (1...10).map { i in
            try createTestUser(displayName: "User \(i)", appleUserIdHash: "user_hash_\(i)_\(UUID().uuidString.prefix(10))")
        }
        
        let (memberships, metrics) = try PerformanceTestUtilities.measureBatchOperation(
            operation: {
                var createdMemberships: [Membership] = []
                
                // Create 10 memberships per family (10 families × 10 users = 100 memberships)
                for family in families {
                    for user in users {
                        let membership = Membership(family: family, user: user, role: .kid)
                        testContext.insert(membership)
                        createdMemberships.append(membership)
                    }
                }
                
                try testContext.save()
                return createdMemberships
            },
            expectedMaxDuration: DatabasePerformanceBenchmarks.batchOperations.maxDuration,
            description: "Batch Membership Creation (100 records)"
        )
        
        // Validate the operation succeeded
        XCTAssertEqual(memberships.count, 100)
        
        // Verify all memberships were created correctly
        for membership in memberships {
            XCTAssertNotNil(membership.family)
            XCTAssertNotNil(membership.user)
            XCTAssertEqual(membership.role, .kid)
            XCTAssertEqual(membership.status, .active)
            XCTAssertTrue(membership.isFullyValid)
        }
        
        // Verify database state
        try assertRecordCount(Membership.self, expectedCount: 100)
        
        // Assert performance meets benchmark
        PerformanceTestUtilities.assertPerformance(metrics)
        
        print("✅ Batch membership creation performance test passed")
    }
    
    // MARK: - Query Performance Tests
    
    /// Test that fetching family by ID completes within performance expectations
    func testFetchFamilyByIdPerformance() async throws {
        print("🔍 Testing fetch family by ID performance...")
        
        // Setup: Create a family to fetch
        let testFamily = try createTestFamily(name: "ID Fetch Test", code: "IDFETCH", createdByUserId: UUID())
        
        let (fetchedFamily, metrics) = try PerformanceTestUtilities.measureDatabaseOperation(
            operation: {
                return try dataService.fetchFamily(byId: testFamily.id)
            },
            expectedMaxDuration: 0.005, // 5ms
            description: "Fetch Family by ID"
        )
        
        // Validate the operation succeeded
        XCTAssertNotNil(fetchedFamily)
        XCTAssertEqual(fetchedFamily?.id, testFamily.id)
        XCTAssertEqual(fetchedFamily?.name, "ID Fetch Test")
        
        // Assert performance meets expectations
        PerformanceTestUtilities.assertPerformance(metrics)
        
        print("✅ Fetch family by ID performance test passed")
    }
    
    /// Test that fetching user by Apple ID hash completes within performance expectations
    func testFetchUserByAppleIdHashPerformance() async throws {
        print("👤 Testing fetch user by Apple ID hash performance...")
        
        // Setup: Create a user to fetch
        let testUser = try createTestUser(displayName: "Hash Fetch Test", appleUserIdHash: "hash_fetch_test_123456789")
        
        let (fetchedUser, metrics) = try PerformanceTestUtilities.measureDatabaseOperation(
            operation: {
                return try dataService.fetchUserProfile(byAppleUserIdHash: "hash_fetch_test_123456789")
            },
            expectedMaxDuration: 0.005, // 5ms
            description: "Fetch User by Apple ID Hash"
        )
        
        // Validate the operation succeeded
        XCTAssertNotNil(fetchedUser)
        XCTAssertEqual(fetchedUser?.id, testUser.id)
        XCTAssertEqual(fetchedUser?.displayName, "Hash Fetch Test")
        
        // Assert performance meets expectations
        PerformanceTestUtilities.assertPerformance(metrics)
        
        print("✅ Fetch user by Apple ID hash performance test passed")
    }
    
    // MARK: - Complex Operation Performance Tests
    
    /// Test that generating unique family code completes within performance expectations
    func testGenerateUniqueFamilyCodePerformance() async throws {
        print("🎲 Testing generate unique family code performance...")
        
        // Setup: Create some existing families to ensure uniqueness checking
        for i in 1...10 {
            _ = try createTestFamily(name: "Existing Family \(i)", code: "EXIST\(i)", createdByUserId: UUID())
        }
        
        let (uniqueCode, metrics) = try PerformanceTestUtilities.measureDatabaseOperation(
            operation: {
                return try dataService.generateUniqueFamilyCode()
            },
            expectedMaxDuration: 0.020, // 20ms (allows for uniqueness checking)
            description: "Generate Unique Family Code"
        )
        
        // Validate the operation succeeded
        XCTAssertFalse(uniqueCode.isEmpty)
        XCTAssertTrue(uniqueCode.count >= 6)
        XCTAssertTrue(uniqueCode.count <= 8)
        
        // Verify the code is actually unique
        let existingFamily = try dataService.fetchFamily(byCode: uniqueCode)
        XCTAssertNil(existingFamily, "Generated code should be unique")
        
        // Assert performance meets expectations
        PerformanceTestUtilities.assertPerformance(metrics)
        
        print("✅ Generate unique family code performance test passed")
    }
    
    /// Test that updating membership role completes within performance expectations
    func testUpdateMembershipRolePerformance() async throws {
        print("🔄 Testing update membership role performance...")
        
        // Setup: Create family, user, and membership
        let testFamily = try createTestFamily(name: "Role Update Family", code: "ROLEUPD", createdByUserId: UUID())
        let testUser = try createTestUser(displayName: "Role Update User")
        let testMembership = try createTestMembership(family: testFamily, user: testUser, role: .kid)
        
        let (updatedMembership, metrics) = try PerformanceTestUtilities.measureDatabaseOperation(
            operation: {
                return try dataService.updateMembershipRole(
                    membershipId: testMembership.id,
                    newRole: .parent
                )
            },
            expectedMaxDuration: 0.015, // 15ms
            description: "Update Membership Role"
        )
        
        // Validate the operation succeeded
        XCTAssertNotNil(updatedMembership)
        XCTAssertEqual(updatedMembership.role, .parent)
        XCTAssertEqual(updatedMembership.id, testMembership.id)
        
        // Assert performance meets expectations
        PerformanceTestUtilities.assertPerformance(metrics)
        
        print("✅ Update membership role performance test passed")
    }
    
    // MARK: - Performance Report Generation
    
    /// Test that generates a comprehensive performance report for all basic operations
    func testGenerateBasicOperationsPerformanceReport() async throws {
        print("📊 Generating basic operations performance report...")
        
        var allMetrics: [PerformanceMetrics] = []
        
        // Test family creation
        let (_, familyMetrics) = try PerformanceTestUtilities.measureDatabaseOperation(
            operation: {
                return try dataService.createFamily(
                    name: "Report Test Family",
                    code: "REPORT1",
                    createdByUserId: UUID()
                )
            },
            expectedMaxDuration: DatabasePerformanceBenchmarks.createFamily.maxDuration,
            description: DatabasePerformanceBenchmarks.createFamily.operationName
        )
        allMetrics.append(familyMetrics)
        
        // Test user creation
        let testUser = UserProfile(displayName: "Report Test User", appleUserIdHash: "report_test_hash_123456789")
        let (_, userMetrics) = try PerformanceTestUtilities.measureDatabaseOperation(
            operation: {
                testContext.insert(testUser)
                try testContext.save()
                return testUser
            },
            expectedMaxDuration: 0.010, // 10ms
            description: "Create User Profile"
        )
        allMetrics.append(userMetrics)
        
        // Test family fetch
        let (_, fetchMetrics) = try PerformanceTestUtilities.measureDatabaseOperation(
            operation: {
                return try dataService.fetchFamily(byCode: "REPORT1")
            },
            expectedMaxDuration: DatabasePerformanceBenchmarks.fetchFamilyByCode.maxDuration,
            description: DatabasePerformanceBenchmarks.fetchFamilyByCode.operationName
        )
        allMetrics.append(fetchMetrics)
        
        // Generate performance report
        let report = PerformanceTestUtilities.generatePerformanceReport(metrics: allMetrics)
        
        // Validate report
        XCTAssertEqual(report.totalOperations, 3)
        XCTAssertEqual(report.passedOperations + report.failedOperations, report.totalOperations)
        XCTAssertGreaterThan(report.successRate, 0.0)
        XCTAssertLessThanOrEqual(report.successRate, 1.0)
        
        // All operations should pass for this test
        XCTAssertEqual(report.passedOperations, 3, "All basic operations should meet performance benchmarks")
        XCTAssertEqual(report.failedOperations, 0, "No operations should fail performance benchmarks")
        
        print("✅ Basic operations performance report generated successfully")
        print("📊 Report Summary: \(report.passedOperations)/\(report.totalOperations) operations passed (\(String(format: "%.1f", report.successRate * 100))%)")
    }
}