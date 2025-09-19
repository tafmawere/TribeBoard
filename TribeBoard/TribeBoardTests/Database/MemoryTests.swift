import XCTest
import SwiftData
@testable import TribeBoard

/// Tests for memory usage validation during database operations
@MainActor
final class MemoryTests: DatabaseTestBase {
    
    // MARK: - Memory Leak Detection Tests
    
    /// Test that single family creation doesn't cause significant memory leaks
    func testSingleFamilyCreationMemoryUsage() async throws {
        print("🧠 Testing memory usage for single family creation...")
        
        let memoryMetrics = try PerformanceTestUtilities.validateMemoryUsage(
            during: {
                let family = try dataService.createFamily(
                    name: "Memory Test Family",
                    code: "MEM001",
                    createdByUserId: UUID()
                )
                
                // Verify the family was created
                XCTAssertNotNil(family)
                XCTAssertTrue(family.isFullyValid)
                
                // Access properties to ensure they're loaded in memory
                _ = family.name
                _ = family.code
                _ = family.createdByUserId
                _ = family.createdAt
                _ = family.isFullyValid
            },
            maxMemoryIncrease: 1_048_576, // 1MB
            description: "Single Family Creation Memory Usage"
        )
        
        // Assert memory usage is within acceptable limits
        PerformanceTestUtilities.assertMemoryUsage(memoryMetrics)
        
        print("✅ Single family creation memory usage test passed")
    }
    
    /// Test that single user profile creation doesn't cause significant memory leaks
    func testSingleUserCreationMemoryUsage() async throws {
        print("🧠 Testing memory usage for single user creation...")
        
        let memoryMetrics = try PerformanceTestUtilities.validateMemoryUsage(
            during: {
                let user = UserProfile(
                    displayName: "Memory Test User",
                    appleUserIdHash: "memory_test_hash_123456789"
                )
                testContext.insert(user)
                try testContext.save()
                
                // Verify the user was created
                XCTAssertTrue(user.isFullyValid)
                
                // Access properties to ensure they're loaded in memory
                _ = user.displayName
                _ = user.appleUserIdHash
                _ = user.createdAt
                _ = user.isFullyValid
                _ = user.activeMemberships
            },
            maxMemoryIncrease: 1_048_576, // 1MB
            description: "Single User Creation Memory Usage"
        )
        
        // Assert memory usage is within acceptable limits
        PerformanceTestUtilities.assertMemoryUsage(memoryMetrics)
        
        print("✅ Single user creation memory usage test passed")
    }
    
    /// Test that single membership creation doesn't cause significant memory leaks
    func testSingleMembershipCreationMemoryUsage() async throws {
        print("🧠 Testing memory usage for single membership creation...")
        
        // Setup: Create family and user first
        let testFamily = try createTestFamily(name: "Memory Family", code: "MEMFAM")
        let testUser = try createTestUser(displayName: "Memory User")
        
        let memoryMetrics = try PerformanceTestUtilities.validateMemoryUsage(
            during: {
                let membership = try dataService.createMembership(
                    familyId: testFamily.id,
                    userId: testUser.id,
                    role: .kid
                )
                
                // Verify the membership was created
                XCTAssertNotNil(membership)
                XCTAssertTrue(membership.isFullyValid)
                
                // Access properties to ensure they're loaded in memory
                _ = membership.role
                _ = membership.status
                _ = membership.createdAt
                _ = membership.family?.name
                _ = membership.user?.displayName
                _ = membership.userDisplayName
                _ = membership.familyName
            },
            maxMemoryIncrease: 1_048_576, // 1MB
            description: "Single Membership Creation Memory Usage"
        )
        
        // Assert memory usage is within acceptable limits
        PerformanceTestUtilities.assertMemoryUsage(memoryMetrics)
        
        print("✅ Single membership creation memory usage test passed")
    }
    
    // MARK: - Bulk Operations Memory Usage Tests
    
    /// Test memory usage during bulk family creation stays within limits
    func testBulkFamilyCreationMemoryUsage() async throws {
        print("🧠 Testing memory usage for bulk family creation (100 families)...")
        
        let memoryMetrics = try PerformanceTestUtilities.validateMemoryUsage(
            during: {
                var families: [Family] = []
                
                for i in 1...100 {
                    let family = try dataService.createFamily(
                        name: "Bulk Memory Family \(i)",
                        code: String(format: "BMF%03d", i),
                        createdByUserId: UUID()
                    )
                    families.append(family)
                }
                
                // Verify all families were created
                XCTAssertEqual(families.count, 100)
                
                // Access properties to ensure they're loaded in memory
                for family in families {
                    _ = family.name
                    _ = family.code
                    _ = family.isFullyValid
                }
            },
            maxMemoryIncrease: 10_485_760, // 10MB
            description: "Bulk Family Creation Memory Usage (100 records)"
        )
        
        // Assert memory usage is within acceptable limits
        PerformanceTestUtilities.assertMemoryUsage(memoryMetrics)
        
        print("✅ Bulk family creation memory usage test passed")
    }
    
    /// Test memory usage during bulk user creation stays within limits
    func testBulkUserCreationMemoryUsage() async throws {
        print("🧠 Testing memory usage for bulk user creation (100 users)...")
        
        let memoryMetrics = try PerformanceTestUtilities.validateMemoryUsage(
            during: {
                var users: [UserProfile] = []
                
                for i in 1...100 {
                    let user = UserProfile(
                        displayName: "Bulk Memory User \(i)",
                        appleUserIdHash: "bulk_memory_user_\(i)_\(UUID().uuidString.prefix(10))"
                    )
                    testContext.insert(user)
                    users.append(user)
                }
                
                try testContext.save()
                
                // Verify all users were created
                XCTAssertEqual(users.count, 100)
                
                // Access properties to ensure they're loaded in memory
                for user in users {
                    _ = user.displayName
                    _ = user.appleUserIdHash
                    _ = user.isFullyValid
                }
            },
            maxMemoryIncrease: 10_485_760, // 10MB
            description: "Bulk User Creation Memory Usage (100 records)"
        )
        
        // Assert memory usage is within acceptable limits
        PerformanceTestUtilities.assertMemoryUsage(memoryMetrics)
        
        print("✅ Bulk user creation memory usage test passed")
    }
    
    /// Test memory usage during bulk membership creation stays within limits
    func testBulkMembershipCreationMemoryUsage() async throws {
        print("🧠 Testing memory usage for bulk membership creation (100 memberships)...")
        
        // Setup: Create 10 families and 10 users
        let families = try (1...10).map { i in
            try createTestFamily(name: "Memory Family \(i)", code: "MF\(String(format: "%02d", i))")
        }
        
        let users = try (1...10).map { i in
            try createTestUser(displayName: "Memory User \(i)", appleUserIdHash: "memory_user_\(i)_\(UUID().uuidString.prefix(8))")
        }
        
        let memoryMetrics = try PerformanceTestUtilities.validateMemoryUsage(
            during: {
                var memberships: [Membership] = []
                
                // Create 10 memberships per family (10 × 10 = 100 total)
                for family in families {
                    for user in users {
                        let membership = Membership(family: family, user: user, role: .kid)
                        testContext.insert(membership)
                        memberships.append(membership)
                    }
                }
                
                try testContext.save()
                
                // Verify all memberships were created
                XCTAssertEqual(memberships.count, 100)
                
                // Access properties to ensure they're loaded in memory
                for membership in memberships {
                    _ = membership.role
                    _ = membership.status
                    _ = membership.family?.name
                    _ = membership.user?.displayName
                    _ = membership.isFullyValid
                }
            },
            maxMemoryIncrease: 15_728_640, // 15MB
            description: "Bulk Membership Creation Memory Usage (100 records)"
        )
        
        // Assert memory usage is within acceptable limits
        PerformanceTestUtilities.assertMemoryUsage(memoryMetrics)
        
        print("✅ Bulk membership creation memory usage test passed")
    }
    
    // MARK: - Query Operations Memory Usage Tests
    
    /// Test memory usage during large fetch operations stays within limits
    func testLargeFetchOperationMemoryUsage() async throws {
        print("🧠 Testing memory usage for large fetch operations...")
        
        // Setup: Create 200 families
        print("🏗️ Creating 200 families for memory test...")
        for i in 1...200 {
            let family = Family(
                name: "Fetch Memory Family \(i)",
                code: String(format: "FMF%03d", i),
                createdByUserId: UUID()
            )
            testContext.insert(family)
            
            if i % 50 == 0 {
                try testContext.save()
                print("   Created \(i) families...")
            }
        }
        try testContext.save()
        print("✅ 200 families created successfully")
        
        let memoryMetrics = try PerformanceTestUtilities.validateMemoryUsage(
            during: {
                // Fetch all families
                let families = try fetchAllRecords(Family.self)
                XCTAssertEqual(families.count, 200)
                
                // Access properties to ensure they're loaded in memory
                for family in families {
                    _ = family.name
                    _ = family.code
                    _ = family.createdByUserId
                    _ = family.isFullyValid
                    _ = family.hasParentAdmin
                    _ = family.activeMembers
                }
                
                // Perform additional queries to test memory usage
                let familiesWithSpecificPrefix = families.filter { $0.name.hasPrefix("Fetch Memory Family 1") }
                XCTAssertGreaterThan(familiesWithSpecificPrefix.count, 0)
                
                // Test computed properties
                for family in familiesWithSpecificPrefix {
                    _ = family.memberships
                }
            },
            maxMemoryIncrease: 25_165_824, // 24MB
            description: "Large Fetch Operation Memory Usage (200 families)"
        )
        
        // Assert memory usage is within acceptable limits
        PerformanceTestUtilities.assertMemoryUsage(memoryMetrics)
        
        print("✅ Large fetch operation memory usage test passed")
    }
    
    /// Test memory usage during complex relationship queries stays within limits
    func testComplexRelationshipQueryMemoryUsage() async throws {
        print("🧠 Testing memory usage for complex relationship queries...")
        
        // Setup: Create 5 families with 10 members each
        print("🏗️ Creating 5 families with 10 members each...")
        var allFamilies: [Family] = []
        var allUsers: [UserProfile] = []
        var allMemberships: [Membership] = []
        
        for familyIndex in 1...5 {
            let family = Family(
                name: "Relationship Family \(familyIndex)",
                code: "RF\(String(format: "%02d", familyIndex))",
                createdByUserId: UUID()
            )
            testContext.insert(family)
            allFamilies.append(family)
            
            for userIndex in 1...10 {
                let globalUserIndex = (familyIndex - 1) * 10 + userIndex
                let user = UserProfile(
                    displayName: "Relationship User \(globalUserIndex)",
                    appleUserIdHash: "rel_user_\(globalUserIndex)_\(UUID().uuidString.prefix(8))"
                )
                testContext.insert(user)
                allUsers.append(user)
                
                let membership = Membership(family: family, user: user, role: .kid)
                testContext.insert(membership)
                allMemberships.append(membership)
            }
        }
        try testContext.save()
        print("✅ 5 families with 50 total memberships created successfully")
        
        let memoryMetrics = try PerformanceTestUtilities.validateMemoryUsage(
            during: {
                // Perform complex relationship queries
                for family in allFamilies {
                    // Query family memberships
                    let familyMemberships = try fetchRecords(Membership.self, predicate: #Predicate { membership in
                        membership.family?.id == family.id && membership.status == .active
                    })
                    XCTAssertEqual(familyMemberships.count, 10)
                    
                    // Access relationship properties
                    for membership in familyMemberships {
                        _ = membership.family?.name
                        _ = membership.user?.displayName
                        _ = membership.userDisplayName
                        _ = membership.familyName
                        _ = membership.canChangeRole
                    }
                    
                    // Test family computed properties
                    _ = family.hasParentAdmin
                    _ = family.activeMembers
                    _ = family.memberships
                }
                
                // Query users and their memberships
                for user in allUsers {
                    let userMemberships = try fetchRecords(Membership.self, predicate: #Predicate { membership in
                        membership.user?.id == user.id && membership.status == .active
                    })
                    XCTAssertEqual(userMemberships.count, 1)
                    
                    // Access user computed properties
                    _ = user.activeMemberships
                    _ = user.memberships
                }
            },
            maxMemoryIncrease: 20_971_520, // 20MB
            description: "Complex Relationship Query Memory Usage (5 families × 10 members)"
        )
        
        // Assert memory usage is within acceptable limits
        PerformanceTestUtilities.assertMemoryUsage(memoryMetrics)
        
        print("✅ Complex relationship query memory usage test passed")
    }
    
    // MARK: - Test Cleanup Memory Validation
    
    /// Test that test cleanup properly releases all allocated memory
    func testCleanupMemoryRelease() async throws {
        print("🧹 Testing that test cleanup properly releases allocated memory...")
        
        let initialMemory = getCurrentMemoryUsage()
        print("📊 Initial memory usage: \(formatBytes(initialMemory))")
        
        // Create a significant amount of test data
        print("🏗️ Creating test data for cleanup test...")
        var families: [Family] = []
        var users: [UserProfile] = []
        var memberships: [Membership] = []
        
        for i in 1...50 {
            let family = Family(
                name: "Cleanup Test Family \(i)",
                code: String(format: "CLN%03d", i),
                createdByUserId: UUID()
            )
            testContext.insert(family)
            families.append(family)
            
            for j in 1...5 {
                let userIndex = (i - 1) * 5 + j
                let user = UserProfile(
                    displayName: "Cleanup User \(userIndex)",
                    appleUserIdHash: "cleanup_user_\(userIndex)_\(UUID().uuidString.prefix(8))"
                )
                testContext.insert(user)
                users.append(user)
                
                let membership = Membership(family: family, user: user, role: .kid)
                testContext.insert(membership)
                memberships.append(membership)
            }
        }
        
        try testContext.save()
        
        let afterCreationMemory = getCurrentMemoryUsage()
        let creationMemoryIncrease = afterCreationMemory - initialMemory
        print("📊 Memory after creation: \(formatBytes(afterCreationMemory)) (increase: \(formatBytes(creationMemoryIncrease)))")
        
        // Verify data was created
        try assertRecordCount(Family.self, expectedCount: 50)
        try assertRecordCount(UserProfile.self, expectedCount: 250)
        try assertRecordCount(Membership.self, expectedCount: 250)
        
        // Access all data to ensure it's loaded in memory
        for family in families {
            _ = family.name
            _ = family.code
            _ = family.isFullyValid
            _ = family.hasParentAdmin
            _ = family.activeMembers
        }
        
        for user in users {
            _ = user.displayName
            _ = user.appleUserIdHash
            _ = user.isFullyValid
            _ = user.activeMemberships
        }
        
        for membership in memberships {
            _ = membership.role
            _ = membership.status
            _ = membership.family?.name
            _ = membership.user?.displayName
            _ = membership.isFullyValid
        }
        
        let afterAccessMemory = getCurrentMemoryUsage()
        let accessMemoryIncrease = afterAccessMemory - afterCreationMemory
        print("📊 Memory after accessing data: \(formatBytes(afterAccessMemory)) (additional increase: \(formatBytes(accessMemoryIncrease)))")
        
        // Manually clean up the data (simulating tearDown)
        print("🧹 Manually cleaning up test data...")
        
        // Delete all memberships first (due to relationships)
        let allMemberships = try fetchAllRecords(Membership.self)
        for membership in allMemberships {
            testContext.delete(membership)
        }
        
        // Delete all families
        let allFamilies = try fetchAllRecords(Family.self)
        for family in allFamilies {
            testContext.delete(family)
        }
        
        // Delete all users
        let allUsers = try fetchAllRecords(UserProfile.self)
        for user in allUsers {
            testContext.delete(user)
        }
        
        // Save changes
        try testContext.save()
        
        // Clear local references
        families.removeAll()
        users.removeAll()
        memberships.removeAll()
        
        // Verify cleanup
        try assertDatabaseIsClean()
        
        let afterCleanupMemory = getCurrentMemoryUsage()
        let cleanupMemoryDecrease = afterAccessMemory - afterCleanupMemory
        print("📊 Memory after cleanup: \(formatBytes(afterCleanupMemory)) (decrease: \(formatBytes(cleanupMemoryDecrease)))")
        
        // Assert that memory was properly released
        // Allow for some memory overhead, but significant memory should be released
        let finalMemoryIncrease = afterCleanupMemory - initialMemory
        let maxAllowedIncrease = 5_242_880 // 5MB tolerance for test overhead
        
        XCTAssertLessThan(
            finalMemoryIncrease,
            maxAllowedIncrease,
            "Memory should be properly released after cleanup. Final increase: \(formatBytes(finalMemoryIncrease)), allowed: \(formatBytes(maxAllowedIncrease))"
        )
        
        print("✅ Test cleanup memory release validation passed")
        print("📊 Final memory increase from initial: \(formatBytes(finalMemoryIncrease)) (within \(formatBytes(maxAllowedIncrease)) tolerance)")
    }
    
    // MARK: - Memory Stress Tests
    
    /// Test memory usage under stress conditions with rapid allocation and deallocation
    func testMemoryStressWithRapidAllocationDeallocation() async throws {
        print("🧠 Testing memory usage under stress with rapid allocation/deallocation...")
        
        let memoryMetrics = try PerformanceTestUtilities.validateMemoryUsage(
            during: {
                // Perform multiple cycles of allocation and deallocation
                for cycle in 1...5 {
                    print("   Stress cycle \(cycle)/5...")
                    
                    // Allocate data
                    var cycleFamilies: [Family] = []
                    for i in 1...20 {
                        let family = Family(
                            name: "Stress Family \(cycle)-\(i)",
                            code: "STR\(cycle)\(String(format: "%02d", i))",
                            createdByUserId: UUID()
                        )
                        testContext.insert(family)
                        cycleFamilies.append(family)
                    }
                    try testContext.save()
                    
                    // Access data to load in memory
                    for family in cycleFamilies {
                        _ = family.name
                        _ = family.code
                        _ = family.isFullyValid
                    }
                    
                    // Deallocate data
                    for family in cycleFamilies {
                        testContext.delete(family)
                    }
                    try testContext.save()
                    
                    // Clear references
                    cycleFamilies.removeAll()
                }
                
                // Verify all data was cleaned up
                try assertDatabaseIsClean()
            },
            maxMemoryIncrease: 10_485_760, // 10MB
            description: "Memory Stress Test (5 cycles × 20 families)"
        )
        
        // Assert memory usage is within acceptable limits
        PerformanceTestUtilities.assertMemoryUsage(memoryMetrics)
        
        print("✅ Memory stress test with rapid allocation/deallocation passed")
    }
    
    // MARK: - Private Helper Methods
    
    /// Gets current memory usage in bytes
    private func getCurrentMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
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
    
    /// Formats bytes into human-readable string
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}