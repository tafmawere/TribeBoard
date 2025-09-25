import XCTest
import SwiftData
@testable import TribeBoard

/// Tests for database scalability validation under various load conditions
@MainActor
final class LoadTests: DatabaseTestBase {
    
    // MARK: - Scalability Tests for Different Data Sizes
    
    /// Test fetching all families with 10 families meets timing benchmarks
    func testFetch10FamiliesPerformance() async throws {
        print("📊 Testing fetch performance with 10 families...")
        
        // Setup: Create 10 families
        let families = try (1...10).map { i in
            try createTestFamily(
                name: "Load Test Family \(i)",
                code: "LOAD\(String(format: "%02d", i))"
            )
        }
        
        let (fetchedFamilies, metrics) = try PerformanceTestUtilities.measureBatchOperation(
            operation: {
                return try fetchAllRecords(Family.self)
            },
            expectedMaxDuration: ScalabilityBenchmarks.fetch10Families.maxDuration,
            description: ScalabilityBenchmarks.fetch10Families.operationName
        )
        
        // Validate the operation succeeded
        XCTAssertEqual(fetchedFamilies.count, 10)
        
        // Verify all families are present
        let fetchedCodes = Set(fetchedFamilies.compactMap { $0.code })
        let expectedCodes = Set(families.map { $0.code })
        XCTAssertEqual(fetchedCodes, expectedCodes)
        
        // Assert performance meets benchmark
        PerformanceTestUtilities.assertPerformance(metrics)
        PerformanceTestUtilities.validateAgainstBenchmark(metrics, benchmark: ScalabilityBenchmarks.fetch10Families)
        
        print("✅ Fetch 10 families performance test passed")
    }
    
    /// Test fetching all families with 100 families meets timing benchmarks
    func testFetch100FamiliesPerformance() async throws {
        print("📊 Testing fetch performance with 100 families...")
        
        // Setup: Create 100 families in batches for better performance
        var families: [Family] = []
        for i in 1...100 {
            let family = Family(
                name: "Load Test Family \(i)",
                code: String(format: "LD%03d", i),
                createdByUserId: UUID()
            )
            testContext.insert(family)
            families.append(family)
        }
        try testContext.save()
        
        let (fetchedFamilies, metrics) = try PerformanceTestUtilities.measureBatchOperation(
            operation: {
                return try fetchAllRecords(Family.self)
            },
            expectedMaxDuration: ScalabilityBenchmarks.fetch100Families.maxDuration,
            description: ScalabilityBenchmarks.fetch100Families.operationName
        )
        
        // Validate the operation succeeded
        XCTAssertEqual(fetchedFamilies.count, 100)
        
        // Verify database state
        try assertRecordCount(Family.self, expectedCount: 100)
        
        // Assert performance meets benchmark
        PerformanceTestUtilities.assertPerformance(metrics)
        PerformanceTestUtilities.validateAgainstBenchmark(metrics, benchmark: ScalabilityBenchmarks.fetch100Families)
        
        print("✅ Fetch 100 families performance test passed")
    }
    
    /// Test fetching all families with 1000 families meets timing benchmarks
    func testFetch1000FamiliesPerformance() async throws {
        print("📊 Testing fetch performance with 1000 families...")
        
        // Setup: Create 1000 families in batches
        print("🏗️ Creating 1000 families for load test...")
        var families: [Family] = []
        
        // Create in batches of 100 to avoid memory issues
        for batch in 0..<10 {
            for i in 1...100 {
                let familyNumber = batch * 100 + i
                let family = Family(
                    name: "Load Test Family \(familyNumber)",
                    code: String(format: "LT%04d", familyNumber),
                    createdByUserId: UUID()
                )
                testContext.insert(family)
                families.append(family)
            }
            
            // Save every 100 families
            try testContext.save()
            
            if batch % 2 == 0 {
                print("   Created \((batch + 1) * 100) families...")
            }
        }
        
        print("✅ 1000 families created successfully")
        
        let (fetchedFamilies, metrics) = try PerformanceTestUtilities.measureBatchOperation(
            operation: {
                return try fetchAllRecords(Family.self)
            },
            expectedMaxDuration: ScalabilityBenchmarks.fetch1000Families.maxDuration,
            description: ScalabilityBenchmarks.fetch1000Families.operationName
        )
        
        // Validate the operation succeeded
        XCTAssertEqual(fetchedFamilies.count, 1000)
        
        // Verify database state
        try assertRecordCount(Family.self, expectedCount: 1000)
        
        // Assert performance meets benchmark
        PerformanceTestUtilities.assertPerformance(metrics)
        PerformanceTestUtilities.validateAgainstBenchmark(metrics, benchmark: ScalabilityBenchmarks.fetch1000Families)
        
        print("✅ Fetch 1000 families performance test passed")
    }
    
    // MARK: - Family Member Query Performance Tests
    
    /// Test querying family members with 10 members per family
    func testQuery10MembersPerFamilyPerformance() async throws {
        print("👥 Testing query performance with 10 members per family...")
        
        // Setup: Create 1 family with 10 members
        let testFamily = try createTestFamily(name: "10 Member Family", code: "MEM10F", createdByUserId: UUID())
        
        var users: [UserProfile] = []
        var memberships: [Membership] = []
        
        for i in 1...10 {
            let user = UserProfile(
                displayName: "Member \(i)",
                appleUserIdHash: "member_\(i)_hash_\(UUID().uuidString.prefix(10))"
            )
            testContext.insert(user)
            users.append(user)
            
            let membership = Membership(family: testFamily, user: user, role: .kid)
            testContext.insert(membership)
            memberships.append(membership)
        }
        
        try testContext.save()
        
        let (fetchedMemberships, metrics) = try PerformanceTestUtilities.measureBatchOperation(
            operation: {
                let predicate = #Predicate<Membership> { membership in
                    membership.family?.id == testFamily.id && membership.status == .active
                }
                return try fetchRecords(Membership.self, predicate: predicate)
            },
            expectedMaxDuration: ScalabilityBenchmarks.query10MembersPerFamily.maxDuration,
            description: ScalabilityBenchmarks.query10MembersPerFamily.operationName
        )
        
        // Validate the operation succeeded
        XCTAssertEqual(fetchedMemberships.count, 10)
        
        // Verify all memberships belong to the correct family
        for membership in fetchedMemberships {
            XCTAssertEqual(membership.family?.id, testFamily.id)
            XCTAssertEqual(membership.status, .active)
            XCTAssertTrue(membership.isFullyValid)
        }
        
        // Assert performance meets benchmark
        PerformanceTestUtilities.assertPerformance(metrics)
        PerformanceTestUtilities.validateAgainstBenchmark(metrics, benchmark: ScalabilityBenchmarks.query10MembersPerFamily)
        
        print("✅ Query 10 members per family performance test passed")
    }
    
    /// Test querying family members with 50 members per family
    func testQuery50MembersPerFamilyPerformance() async throws {
        print("👥 Testing query performance with 50 members per family...")
        
        // Setup: Create 1 family with 50 members
        let testFamily = try createTestFamily(name: "50 Member Family", code: "MEM50F", createdByUserId: UUID())
        
        var users: [UserProfile] = []
        var memberships: [Membership] = []
        
        for i in 1...50 {
            let user = UserProfile(
                displayName: "Member \(i)",
                appleUserIdHash: "member_\(i)_hash_\(UUID().uuidString.prefix(10))"
            )
            testContext.insert(user)
            users.append(user)
            
            let membership = Membership(family: testFamily, user: user, role: .kid)
            testContext.insert(membership)
            memberships.append(membership)
        }
        
        try testContext.save()
        
        let (fetchedMemberships, metrics) = try PerformanceTestUtilities.measureBatchOperation(
            operation: {
                let predicate = #Predicate<Membership> { membership in
                    membership.family?.id == testFamily.id && membership.status == .active
                }
                return try fetchRecords(Membership.self, predicate: predicate)
            },
            expectedMaxDuration: ScalabilityBenchmarks.query50MembersPerFamily.maxDuration,
            description: ScalabilityBenchmarks.query50MembersPerFamily.operationName
        )
        
        // Validate the operation succeeded
        XCTAssertEqual(fetchedMemberships.count, 50)
        
        // Verify all memberships belong to the correct family
        for membership in fetchedMemberships {
            XCTAssertEqual(membership.family?.id, testFamily.id)
            XCTAssertEqual(membership.status, .active)
            XCTAssertTrue(membership.isFullyValid)
        }
        
        // Assert performance meets benchmark
        PerformanceTestUtilities.assertPerformance(metrics)
        PerformanceTestUtilities.validateAgainstBenchmark(metrics, benchmark: ScalabilityBenchmarks.query50MembersPerFamily)
        
        print("✅ Query 50 members per family performance test passed")
    }
    
    // MARK: - Concurrent Operations Performance Tests
    
    /// Test that concurrent family creation operations maintain performance and data consistency
    func testConcurrentFamilyCreationPerformance() async throws {
        print("🔄 Testing concurrent family creation performance...")
        
        let concurrentOperationCount = 10
        let familiesPerOperation = 5
        let totalExpectedFamilies = concurrentOperationCount * familiesPerOperation
        
        let (results, metrics) = try PerformanceTestUtilities.measureAsyncDatabaseOperation(
            operation: {
                // Create concurrent tasks for family creation
                let tasks = (1...concurrentOperationCount).map { taskIndex in
                    Task {
                        var taskFamilies: [Family] = []
                        for i in 1...familiesPerOperation {
                            let familyNumber = (taskIndex - 1) * familiesPerOperation + i
                            let family = try dataService.createFamily(
                                name: "Concurrent Family \(familyNumber)",
                                code: String(format: "CON%03d", familyNumber),
                                createdByUserId: UUID()
                            )
                            taskFamilies.append(family)
                        }
                        return taskFamilies
                    }
                }
                
                // Wait for all tasks to complete
                var allFamilies: [Family] = []
                for task in tasks {
                    let taskFamilies = try await task.value
                    allFamilies.append(contentsOf: taskFamilies)
                }
                
                return allFamilies
            },
            expectedMaxDuration: 1.0, // 1 second for concurrent operations
            description: "Concurrent Family Creation (\(concurrentOperationCount) tasks × \(familiesPerOperation) families)"
        )
        
        // Validate the operation succeeded
        XCTAssertEqual(results.count, totalExpectedFamilies)
        
        // Verify all families were created with unique codes
        let familyCodes = Set(results.map { $0.code })
        XCTAssertEqual(familyCodes.count, totalExpectedFamilies, "All family codes should be unique")
        
        // Verify database state
        try assertRecordCount(Family.self, expectedCount: totalExpectedFamilies)
        
        // Verify all families are valid
        for family in results {
            XCTAssertTrue(family.isFullyValid)
            XCTAssertTrue(family.name.hasPrefix("Concurrent Family"))
            XCTAssertTrue(family.code.hasPrefix("CON"))
        }
        
        // Assert performance meets expectations
        PerformanceTestUtilities.assertPerformance(metrics)
        
        print("✅ Concurrent family creation performance test passed")
    }
    
    /// Test that concurrent membership creation operations maintain performance and data consistency
    func testConcurrentMembershipCreationPerformance() async throws {
        print("🤝 Testing concurrent membership creation performance...")
        
        // Setup: Create families and users for concurrent membership creation
        let familyCount = 5
        let userCount = 10
        
        let families = try (1...familyCount).map { i in
            try createTestFamily(name: "Concurrent Family \(i)", code: "CFAM\(i)", createdByUserId: UUID())
        }
        
        let users = try (1...userCount).map { i in
            try createTestUser(displayName: "Concurrent User \(i)", appleUserIdHash: "concurrent_user_\(i)_\(UUID().uuidString.prefix(10))")
        }
        
        let concurrentOperationCount = 5
        let membershipsPerOperation = 10
        let totalExpectedMemberships = concurrentOperationCount * membershipsPerOperation
        
        let (results, metrics) = try PerformanceTestUtilities.measureAsyncDatabaseOperation(
            operation: {
                // Create concurrent tasks for membership creation
                let tasks = (1...concurrentOperationCount).map { taskIndex in
                    Task {
                        var taskMemberships: [Membership] = []
                        for i in 1...membershipsPerOperation {
                            let family = families[(taskIndex + i - 1) % familyCount]
                            let user = users[(taskIndex + i - 1) % userCount]
                            
                            let membership = Membership(family: family, user: user, role: .kid)
                            testContext.insert(membership)
                            taskMemberships.append(membership)
                        }
                        try testContext.save()
                        return taskMemberships
                    }
                }
                
                // Wait for all tasks to complete
                var allMemberships: [Membership] = []
                for task in tasks {
                    let taskMemberships = try await task.value
                    allMemberships.append(contentsOf: taskMemberships)
                }
                
                return allMemberships
            },
            expectedMaxDuration: 1.0, // 1 second for concurrent operations
            description: "Concurrent Membership Creation (\(concurrentOperationCount) tasks × \(membershipsPerOperation) memberships)"
        )
        
        // Validate the operation succeeded
        XCTAssertEqual(results.count, totalExpectedMemberships)
        
        // Verify database state
        try assertRecordCount(Membership.self, expectedCount: totalExpectedMemberships)
        
        // Verify all memberships are valid
        for membership in results {
            XCTAssertTrue(membership.isFullyValid)
            XCTAssertNotNil(membership.family)
            XCTAssertNotNil(membership.user)
            XCTAssertEqual(membership.status, .active)
            XCTAssertEqual(membership.role, .kid)
        }
        
        // Assert performance meets expectations
        PerformanceTestUtilities.assertPerformance(metrics)
        
        print("✅ Concurrent membership creation performance test passed")
    }
    
    // MARK: - Memory Usage During Large Operations
    
    /// Test that memory usage stays within established limits during large family fetch operations
    func testMemoryUsageDuringLargeFamilyFetch() async throws {
        print("🧠 Testing memory usage during large family fetch operations...")
        
        // Setup: Create 500 families
        print("🏗️ Creating 500 families for memory test...")
        for i in 1...500 {
            let family = Family(
                name: "Memory Test Family \(i)",
                code: String(format: "MEM%03d", i),
                createdByUserId: UUID()
            )
            testContext.insert(family)
            
            if i % 100 == 0 {
                try testContext.save()
                print("   Created \(i) families...")
            }
        }
        try testContext.save()
        print("✅ 500 families created successfully")
        
        // Test memory usage during fetch
        let memoryMetrics = try PerformanceTestUtilities.validateMemoryUsage(
            during: {
                let families = try fetchAllRecords(Family.self)
                XCTAssertEqual(families.count, 500)
                
                // Access properties to ensure they're loaded
                for family in families {
                    _ = family.name
                    _ = family.code
                    _ = family.isFullyValid
                }
            },
            maxMemoryIncrease: 15_728_640, // 15MB
            description: "Large Family Fetch (500 records)"
        )
        
        // Assert memory usage is within limits
        PerformanceTestUtilities.assertMemoryUsage(memoryMetrics)
        
        print("✅ Memory usage during large family fetch test passed")
    }
    
    /// Test that memory usage stays within established limits during large membership query operations
    func testMemoryUsageDuringLargeMembershipQuery() async throws {
        print("🧠 Testing memory usage during large membership query operations...")
        
        // Setup: Create 10 families with 20 members each (200 total memberships)
        print("🏗️ Creating 10 families with 20 members each...")
        
        var allFamilies: [Family] = []
        var allUsers: [UserProfile] = []
        var allMemberships: [Membership] = []
        
        for familyIndex in 1...10 {
            let family = Family(
                name: "Memory Family \(familyIndex)",
                code: "MEMF\(String(format: "%02d", familyIndex))",
                createdByUserId: UUID()
            )
            testContext.insert(family)
            allFamilies.append(family)
            
            for userIndex in 1...20 {
                let globalUserIndex = (familyIndex - 1) * 20 + userIndex
                let user = UserProfile(
                    displayName: "Memory User \(globalUserIndex)",
                    appleUserIdHash: "memory_user_\(globalUserIndex)_\(UUID().uuidString.prefix(8))"
                )
                testContext.insert(user)
                allUsers.append(user)
                
                let membership = Membership(family: family, user: user, role: .kid)
                testContext.insert(membership)
                allMemberships.append(membership)
            }
            
            if familyIndex % 3 == 0 {
                try testContext.save()
                print("   Created \(familyIndex) families with \(familyIndex * 20) total memberships...")
            }
        }
        try testContext.save()
        print("✅ 10 families with 200 total memberships created successfully")
        
        // Test memory usage during membership queries
        let memoryMetrics = try PerformanceTestUtilities.validateMemoryUsage(
            during: {
                // Query memberships for each family
                for family in allFamilies {
                    let predicate = #Predicate<Membership> { membership in
                        membership.family?.id == family.id && membership.status == .active
                    }
                    let memberships = try fetchRecords(Membership.self, predicate: predicate)
                    XCTAssertEqual(memberships.count, 20)
                    
                    // Access properties to ensure they're loaded
                    for membership in memberships {
                        _ = membership.role
                        _ = membership.status
                        _ = membership.family?.name
                        _ = membership.user?.displayName
                    }
                }
            },
            maxMemoryIncrease: 20_971_520, // 20MB
            description: "Large Membership Query (10 families × 20 members)"
        )
        
        // Assert memory usage is within limits
        PerformanceTestUtilities.assertMemoryUsage(memoryMetrics)
        
        print("✅ Memory usage during large membership query test passed")
    }
    
    // MARK: - Comprehensive Load Test Report
    
    /// Test that generates a comprehensive load test performance report
    func testGenerateLoadTestPerformanceReport() async throws {
        print("📊 Generating comprehensive load test performance report...")
        
        var allMetrics: [PerformanceMetrics] = []
        
        // Test small dataset performance
        let families10 = try (1...10).map { i in
            try createTestFamily(name: "Report Family \(i)", code: "RPT\(String(format: "%02d", i))")
        }
        
        let (_, fetch10Metrics) = try PerformanceTestUtilities.measureBatchOperation(
            operation: {
                return try fetchAllRecords(Family.self)
            },
            expectedMaxDuration: ScalabilityBenchmarks.fetch10Families.maxDuration,
            description: "Load Test: Fetch 10 Families"
        )
        allMetrics.append(fetch10Metrics)
        
        // Test medium dataset performance
        for i in 11...50 {
            let family = Family(
                name: "Report Family \(i)",
                code: "RPT\(String(format: "%02d", i))",
                createdByUserId: UUID()
            )
            testContext.insert(family)
        }
        try testContext.save()
        
        let (_, fetch50Metrics) = try PerformanceTestUtilities.measureBatchOperation(
            operation: {
                return try fetchAllRecords(Family.self)
            },
            expectedMaxDuration: 0.025, // 25ms for 50 families
            description: "Load Test: Fetch 50 Families"
        )
        allMetrics.append(fetch50Metrics)
        
        // Test membership query performance
        let testFamily = families10.first!
        for i in 1...10 {
            let user = UserProfile(
                displayName: "Report User \(i)",
                appleUserIdHash: "report_user_\(i)_\(UUID().uuidString.prefix(8))"
            )
            testContext.insert(user)
            
            let membership = Membership(family: testFamily, user: user, role: .kid)
            testContext.insert(membership)
        }
        try testContext.save()
        
        let (_, membershipQueryMetrics) = try PerformanceTestUtilities.measureBatchOperation(
            operation: {
                let predicate = #Predicate<Membership> { membership in
                    membership.family?.id == testFamily.id && membership.status == .active
                }
                return try fetchRecords(Membership.self, predicate: predicate)
            },
            expectedMaxDuration: ScalabilityBenchmarks.query10MembersPerFamily.maxDuration,
            description: "Load Test: Query 10 Members"
        )
        allMetrics.append(membershipQueryMetrics)
        
        // Generate comprehensive report
        let report = PerformanceTestUtilities.generatePerformanceReport(metrics: allMetrics)
        
        // Validate report
        XCTAssertEqual(report.totalOperations, 3)
        XCTAssertGreaterThan(report.successRate, 0.0)
        XCTAssertLessThanOrEqual(report.successRate, 1.0)
        
        // All load tests should pass
        XCTAssertEqual(report.passedOperations, 3, "All load test operations should meet performance benchmarks")
        XCTAssertEqual(report.failedOperations, 0, "No load test operations should fail performance benchmarks")
        
        print("✅ Load test performance report generated successfully")
        print("📊 Load Test Report Summary: \(report.passedOperations)/\(report.totalOperations) operations passed (\(String(format: "%.1f", report.successRate * 100))%)")
        print("📊 Total Duration: \(String(format: "%.3f", report.totalDuration))s")
        print("📊 Total Memory Usage: \(ByteCountFormatter().string(fromByteCount: Int64(report.totalMemoryUsage)))")
    }
}