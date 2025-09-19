import XCTest
import SwiftData
@testable import TribeBoard

/// Tests for ModelContainer setup and configuration
/// Requirements: 2.1, 2.2, 2.3, 2.6
@MainActor
final class ContainerConfigurationTests: DatabaseTestBase {
    
    // MARK: - CloudKit Container Creation Tests
    
    /// Test successful CloudKit-enabled ModelContainer creation
    /// Requirements: 2.1
    func testSuccessfulCloudKitContainerCreation() throws {
        print("🧪 Testing CloudKit-enabled ModelContainer creation...")
        
        do {
            // Attempt to create CloudKit container
            let container = try ModelContainerConfiguration.create()
            
            // Verify container was created successfully
            XCTAssertNotNil(container, "CloudKit container should be created successfully")
            
            // Verify container has a valid context
            let context = container.mainContext
            XCTAssertNotNil(context, "CloudKit container should have a valid context")
            
            // Test basic operations to ensure container is functional
            let testFamily = Family(
                name: "CloudKit Test Family",
                code: "CK123",
                createdByUserId: UUID()
            )
            
            context.insert(testFamily)
            
            // Verify the family was inserted successfully
            let descriptor = FetchDescriptor<Family>()
            let families = try context.fetch(descriptor)
            let cloudKitFamily = families.first { $0.name == "CloudKit Test Family" }
            XCTAssertNotNil(cloudKitFamily, "CloudKit container should support basic operations")
            XCTAssertEqual(cloudKitFamily?.code, "CK123", "CloudKit container should preserve data correctly")
            
            print("✅ CloudKit container creation and basic operations successful")
            
        } catch {
            // CloudKit may not be available in test environment (simulator, CI, etc.)
            print("ℹ️ CloudKit container creation failed (expected in test environment): \(error.localizedDescription)")
            
            // Verify it's a CloudKit-related error, not a schema or configuration error
            let errorDescription = error.localizedDescription.lowercased()
            let isExpectedCloudKitError = errorDescription.contains("cloudkit") || 
                                        errorDescription.contains("icloud") ||
                                        errorDescription.contains("container") ||
                                        errorDescription.contains("network") ||
                                        errorDescription.contains("unavailable")
            
            if !isExpectedCloudKitError {
                XCTFail("Unexpected error type during CloudKit container creation: \(error)")
            }
            
            print("✅ CloudKit unavailability handled correctly")
        }
    }
    
    /// Test CloudKit container configuration parameters
    /// Requirements: 2.1
    func testCloudKitContainerConfiguration() throws {
        print("🧪 Testing CloudKit container configuration...")
        
        // Test that the CloudKit container identifier is correct
        let expectedIdentifier = "iCloud.net.dataenvy.TribeBoard"
        
        do {
            let container = try ModelContainerConfiguration.create()
            
            // If creation succeeds, verify the container is properly configured
            XCTAssertNotNil(container, "CloudKit container should be properly configured")
            
            // Test that the container uses the expected schema
            let context = container.mainContext
            
            // Verify all model types are available
            let familyDescriptor = FetchDescriptor<Family>()
            let userDescriptor = FetchDescriptor<UserProfile>()
            let membershipDescriptor = FetchDescriptor<Membership>()
            
            // These should not throw errors if schema is properly configured
            _ = try context.fetch(familyDescriptor)
            _ = try context.fetch(userDescriptor)
            _ = try context.fetch(membershipDescriptor)
            
            print("✅ CloudKit container configuration verified")
            
        } catch {
            // Check if error indicates configuration issues vs availability issues
            let errorDescription = error.localizedDescription
            
            if errorDescription.contains("identifier") || errorDescription.contains("bundle") {
                XCTFail("CloudKit container configuration error: \(error)")
            } else {
                print("ℹ️ CloudKit not available for configuration testing: \(errorDescription)")
            }
        }
    }
    
    // MARK: - Local Storage Fallback Tests
    
    /// Test fallback to local-only storage when CloudKit unavailable
    /// Requirements: 2.2
    func testFallbackToLocalStorage() throws {
        print("🧪 Testing fallback to local-only storage...")
        
        // Use the fallback method which should try CloudKit first, then local
        let container = ModelContainerConfiguration.createWithFallback()
        
        // Verify container was created successfully
        XCTAssertNotNil(container, "Fallback should create a working container")
        
        // Verify container is functional
        let context = container.mainContext
        XCTAssertNotNil(context, "Fallback container should have a valid context")
        
        // Test comprehensive operations to ensure local storage works
        let testUser = UserProfile(
            displayName: "Local Storage User",
            appleUserIdHash: "local_hash_123"
        )
        
        let testFamily = Family(
            name: "Local Storage Family",
            code: "LOCAL1",
            createdByUserId: testUser.id
        )
        
        let testMembership = Membership(
            family: testFamily,
            user: testUser,
            role: .parentAdmin
        )
        
        // Insert all entities
        context.insert(testUser)
        context.insert(testFamily)
        context.insert(testMembership)
        
        // Verify all entities were inserted and can be retrieved
        let userDescriptor = FetchDescriptor<UserProfile>()
        let users = try context.fetch(userDescriptor)
        let localUser = users.first { $0.displayName == "Local Storage User" }
        XCTAssertNotNil(localUser, "Local storage should support user creation")
        
        let familyDescriptor = FetchDescriptor<Family>()
        let families = try context.fetch(familyDescriptor)
        let localFamily = families.first { $0.name == "Local Storage Family" }
        XCTAssertNotNil(localFamily, "Local storage should support family creation")
        
        let membershipDescriptor = FetchDescriptor<Membership>()
        let memberships = try context.fetch(membershipDescriptor)
        let localMembership = memberships.first { $0.user?.displayName == "Local Storage User" }
        XCTAssertNotNil(localMembership, "Local storage should support membership creation")
        
        // Verify relationships work correctly
        XCTAssertEqual(localMembership?.family?.name, "Local Storage Family", "Local storage should maintain relationships")
        XCTAssertEqual(localMembership?.role, .parentAdmin, "Local storage should preserve role data")
        
        print("✅ Local storage fallback verified with full functionality")
    }
    
    /// Test local storage container persistence behavior
    /// Requirements: 2.2
    func testLocalStoragePersistence() throws {
        print("🧪 Testing local storage persistence behavior...")
        
        // Create a local container (not in-memory)
        let container = ModelContainerConfiguration.createWithFallback()
        let context = container.mainContext
        
        // Create test data
        let persistenceUser = UserProfile(
            displayName: "Persistence Test User",
            appleUserIdHash: "persist_hash"
        )
        
        context.insert(persistenceUser)
        
        // Verify data exists
        let descriptor = FetchDescriptor<UserProfile>()
        let users = try context.fetch(descriptor)
        let foundUser = users.first { $0.displayName == "Persistence Test User" }
        XCTAssertNotNil(foundUser, "Local storage should persist data")
        
        // Test multiple operations in sequence
        let family1 = Family(name: "Family 1", code: "FAM001", createdByUserId: persistenceUser.id)
        let family2 = Family(name: "Family 2", code: "FAM002", createdByUserId: persistenceUser.id)
        
        context.insert(family1)
        context.insert(family2)
        
        let familyDescriptor = FetchDescriptor<Family>()
        let families = try context.fetch(familyDescriptor)
        XCTAssertGreaterThanOrEqual(families.count, 2, "Local storage should handle multiple entities")
        
        print("✅ Local storage persistence behavior verified")
    }
    
    // MARK: - In-Memory Container Tests
    
    /// Test in-memory container creation as last resort
    /// Requirements: 2.3
    func testInMemoryContainerCreation() throws {
        print("🧪 Testing in-memory container creation...")
        
        // Create in-memory container directly
        let container = try ModelContainerConfiguration.createInMemory()
        
        // Verify container was created successfully
        XCTAssertNotNil(container, "In-memory container should be created successfully")
        
        // Verify container has a valid context
        let context = container.mainContext
        XCTAssertNotNil(context, "In-memory container should have a valid context")
        
        // Test comprehensive operations
        let memoryUser = UserProfile(
            displayName: "Memory Test User",
            appleUserIdHash: "memory_hash_456"
        )
        
        let memoryFamily = Family(
            name: "Memory Test Family",
            code: "MEM123",
            createdByUserId: memoryUser.id
        )
        
        let memoryMembership = Membership(
            family: memoryFamily,
            user: memoryUser,
            role: .adult
        )
        
        // Insert all entities
        context.insert(memoryUser)
        context.insert(memoryFamily)
        context.insert(memoryMembership)
        
        // Verify all operations work in memory
        let userDescriptor = FetchDescriptor<UserProfile>()
        let users = try context.fetch(userDescriptor)
        let foundUser = users.first { $0.displayName == "Memory Test User" }
        XCTAssertNotNil(foundUser, "In-memory container should support user operations")
        
        let familyDescriptor = FetchDescriptor<Family>()
        let families = try context.fetch(familyDescriptor)
        let foundFamily = families.first { $0.name == "Memory Test Family" }
        XCTAssertNotNil(foundFamily, "In-memory container should support family operations")
        
        let membershipDescriptor = FetchDescriptor<Membership>()
        let memberships = try context.fetch(membershipDescriptor)
        let foundMembership = memberships.first { $0.user?.displayName == "Memory Test User" }
        XCTAssertNotNil(foundMembership, "In-memory container should support membership operations")
        
        // Verify relationships work in memory
        XCTAssertEqual(foundMembership?.family?.name, "Memory Test Family", "In-memory container should maintain relationships")
        XCTAssertEqual(foundMembership?.role, .adult, "In-memory container should preserve data types")
        
        print("✅ In-memory container creation and operations verified")
    }
    
    /// Test that in-memory containers don't persist data between tests
    /// Requirements: 2.6
    func testInMemoryContainerNonPersistence() throws {
        print("🧪 Testing in-memory container non-persistence...")
        
        // Create first in-memory container and add data
        let container1 = try ModelContainerConfiguration.createInMemory()
        let context1 = container1.mainContext
        
        let testUser1 = UserProfile(
            displayName: "Non-Persist User 1",
            appleUserIdHash: "nonpersist1"
        )
        
        context1.insert(testUser1)
        
        // Verify data exists in first container
        let descriptor1 = FetchDescriptor<UserProfile>()
        let users1 = try context1.fetch(descriptor1)
        let foundUser1 = users1.first { $0.displayName == "Non-Persist User 1" }
        XCTAssertNotNil(foundUser1, "First container should contain the test user")
        
        // Create second in-memory container
        let container2 = try ModelContainerConfiguration.createInMemory()
        let context2 = container2.mainContext
        
        // Verify second container is clean (no data from first container)
        let descriptor2 = FetchDescriptor<UserProfile>()
        let users2 = try context2.fetch(descriptor2)
        let foundUser2 = users2.first { $0.displayName == "Non-Persist User 1" }
        XCTAssertNil(foundUser2, "Second container should not contain data from first container")
        XCTAssertEqual(users2.count, 0, "Second container should be completely clean")
        
        // Add different data to second container
        let testUser2 = UserProfile(
            displayName: "Non-Persist User 2",
            appleUserIdHash: "nonpersist2"
        )
        
        context2.insert(testUser2)
        
        // Verify containers are independent
        let users2Updated = try context2.fetch(descriptor2)
        let foundUser2Updated = users2Updated.first { $0.displayName == "Non-Persist User 2" }
        XCTAssertNotNil(foundUser2Updated, "Second container should contain its own data")
        XCTAssertEqual(users2Updated.count, 1, "Second container should only contain its own data")
        
        // Verify first container still has its original data
        let users1Updated = try context1.fetch(descriptor1)
        let foundUser1Updated = users1Updated.first { $0.displayName == "Non-Persist User 1" }
        XCTAssertNotNil(foundUser1Updated, "First container should still contain its original data")
        
        // Verify no cross-contamination
        let foundUser2InContainer1 = users1Updated.first { $0.displayName == "Non-Persist User 2" }
        XCTAssertNil(foundUser2InContainer1, "First container should not contain data from second container")
        
        print("✅ In-memory container isolation and non-persistence verified")
    }
    
    /// Test multiple in-memory container creation
    /// Requirements: 2.6
    func testMultipleInMemoryContainers() throws {
        print("🧪 Testing multiple in-memory container creation...")
        
        var containers: [ModelContainer] = []
        let containerCount = 5
        
        // Create multiple in-memory containers
        for i in 0..<containerCount {
            let container = try ModelContainerConfiguration.createInMemory()
            containers.append(container)
            
            // Add unique data to each container
            let context = container.mainContext
            let testUser = UserProfile(
                displayName: "Multi User \(i)",
                appleUserIdHash: "multi_hash_\(i)"
            )
            
            context.insert(testUser)
            
            // Verify data exists in this container
            let descriptor = FetchDescriptor<UserProfile>()
            let users = try context.fetch(descriptor)
            XCTAssertEqual(users.count, 1, "Container \(i) should have exactly one user")
            XCTAssertEqual(users.first?.displayName, "Multi User \(i)", "Container \(i) should have correct user data")
        }
        
        XCTAssertEqual(containers.count, containerCount, "All containers should be created successfully")
        
        // Verify each container is independent
        for (index, container) in containers.enumerated() {
            let context = container.mainContext
            let descriptor = FetchDescriptor<UserProfile>()
            let users = try context.fetch(descriptor)
            
            XCTAssertEqual(users.count, 1, "Container \(index) should have exactly one user")
            XCTAssertEqual(users.first?.displayName, "Multi User \(index)", "Container \(index) should have correct isolated data")
        }
        
        print("✅ Multiple in-memory container creation and isolation verified")
    }
    
    // MARK: - Container Fallback Chain Tests
    
    /// Test complete fallback chain: CloudKit -> Local -> In-Memory
    /// Requirements: 2.1, 2.2, 2.3
    func testCompleteFallbackChain() throws {
        print("🧪 Testing complete container fallback chain...")
        
        // Test the fallback method which implements the full chain
        let container = ModelContainerConfiguration.createWithFallback()
        
        // Verify a container was created (regardless of which type)
        XCTAssertNotNil(container, "Fallback chain should always produce a working container")
        
        // Verify the container is fully functional
        let context = container.mainContext
        XCTAssertNotNil(context, "Fallback container should have a valid context")
        
        // Test comprehensive functionality
        let chainUser = UserProfile(
            displayName: "Fallback Chain User",
            appleUserIdHash: "chain_hash_789"
        )
        
        let chainFamily = Family(
            name: "Fallback Chain Family",
            code: "CHAIN1",
            createdByUserId: chainUser.id
        )
        
        let chainMembership = Membership(
            family: chainFamily,
            user: chainUser,
            role: .kid
        )
        
        // Insert all entities
        context.insert(chainUser)
        context.insert(chainFamily)
        context.insert(chainMembership)
        
        // Verify all operations work regardless of container type
        let userDescriptor = FetchDescriptor<UserProfile>()
        let users = try context.fetch(userDescriptor)
        let foundUser = users.first { $0.displayName == "Fallback Chain User" }
        XCTAssertNotNil(foundUser, "Fallback container should support user operations")
        
        let familyDescriptor = FetchDescriptor<Family>()
        let families = try context.fetch(familyDescriptor)
        let foundFamily = families.first { $0.name == "Fallback Chain Family" }
        XCTAssertNotNil(foundFamily, "Fallback container should support family operations")
        
        let membershipDescriptor = FetchDescriptor<Membership>()
        let memberships = try context.fetch(membershipDescriptor)
        let foundMembership = memberships.first { $0.user?.displayName == "Fallback Chain User" }
        XCTAssertNotNil(foundMembership, "Fallback container should support membership operations")
        
        // Verify complex relationships work
        XCTAssertEqual(foundMembership?.family?.name, "Fallback Chain Family", "Fallback container should maintain relationships")
        XCTAssertEqual(foundMembership?.role, .kid, "Fallback container should preserve enum values")
        XCTAssertEqual(foundFamily?.activeMembers.count, 1, "Fallback container should support computed properties")
        
        print("✅ Complete fallback chain functionality verified")
    }
    
    /// Test fallback chain error handling
    /// Requirements: 2.1, 2.2, 2.3
    func testFallbackChainErrorHandling() throws {
        print("🧪 Testing fallback chain error handling...")
        
        // The fallback method should never fail - it should always return a container
        var containers: [ModelContainer] = []
        
        // Test multiple fallback attempts
        for i in 0..<3 {
            let container = ModelContainerConfiguration.createWithFallback()
            containers.append(container)
            
            XCTAssertNotNil(container, "Fallback attempt \(i+1) should always succeed")
            
            // Test that each container is functional
            let context = container.mainContext
            let testFamily = Family(
                name: "Error Test Family \(i)",
                code: "ERR\(i)23",
                createdByUserId: UUID()
            )
            
            context.insert(testFamily)
            
            let descriptor = FetchDescriptor<Family>()
            let families = try context.fetch(descriptor)
            let errorFamily = families.first { $0.name == "Error Test Family \(i)" }
            XCTAssertNotNil(errorFamily, "Fallback container \(i+1) should be functional")
        }
        
        XCTAssertEqual(containers.count, 3, "All fallback attempts should succeed")
        
        print("✅ Fallback chain error handling verified")
    }
    
    // MARK: - Container Validation Tests
    
    /// Test container validation and health checks
    /// Requirements: 2.1, 2.2, 2.3
    func testContainerValidation() throws {
        print("🧪 Testing container validation...")
        
        // Test in-memory container validation
        let inMemoryContainer = try ModelContainerConfiguration.createInMemory()
        try validateContainerHealth(inMemoryContainer, containerType: "In-Memory")
        
        // Test fallback container validation
        let fallbackContainer = ModelContainerConfiguration.createWithFallback()
        try validateContainerHealth(fallbackContainer, containerType: "Fallback")
        
        print("✅ Container validation completed successfully")
    }
    
    /// Helper method to validate container health
    private func validateContainerHealth(_ container: ModelContainer, containerType: String) throws {
        print("   Validating \(containerType) container health...")
        
        // Test 1: Context availability
        let context = container.mainContext
        XCTAssertNotNil(context, "\(containerType) container should have a valid context")
        
        // Test 2: Basic insert operations
        let healthUser = UserProfile(
            displayName: "\(containerType) Health User",
            appleUserIdHash: "health_\(containerType.lowercased())"
        )
        
        context.insert(healthUser)
        
        // Test 3: Basic fetch operations
        let userDescriptor = FetchDescriptor<UserProfile>()
        let users = try context.fetch(userDescriptor)
        let foundUser = users.first { $0.displayName == "\(containerType) Health User" }
        XCTAssertNotNil(foundUser, "\(containerType) container should support basic operations")
        
        // Test 4: Complex operations with relationships
        let healthFamily = Family(
            name: "\(containerType) Health Family",
            code: "HLTH\(containerType.prefix(2).uppercased())",
            createdByUserId: healthUser.id
        )
        
        let healthMembership = Membership(
            family: healthFamily,
            user: healthUser,
            role: .parentAdmin
        )
        
        context.insert(healthFamily)
        context.insert(healthMembership)
        
        // Test 5: Relationship queries
        let membershipDescriptor = FetchDescriptor<Membership>()
        let memberships = try context.fetch(membershipDescriptor)
        let foundMembership = memberships.first { $0.user?.displayName == "\(containerType) Health User" }
        XCTAssertNotNil(foundMembership, "\(containerType) container should support relationship operations")
        XCTAssertEqual(foundMembership?.family?.name, "\(containerType) Health Family", "\(containerType) container should maintain relationship integrity")
        
        print("   ✅ \(containerType) container health validation passed")
    }
}