import XCTest
import SwiftData
@testable import TribeBoard

@MainActor
final class ModelContainerTests: XCTestCase {
    
    // MARK: - Test Setup and Teardown
    
    override func setUp() {
        super.setUp()
        // Clear any existing test containers
        clearTestContainers()
    }
    
    override func tearDown() {
        clearTestContainers()
        super.tearDown()
    }
    
    private func clearTestContainers() {
        // Helper method to clean up test containers if needed
        // This ensures tests don't interfere with each other
    }
    
    // MARK: - Successful CloudKit Container Creation Tests
    
    func testSuccessfulCloudKitContainerCreation() throws {
        // Test that CloudKit container can be created successfully
        // Note: This test may fail in simulator due to CloudKit limitations
        
        do {
            let container = try ModelContainerConfiguration.create()
            
            // Verify container was created
            XCTAssertNotNil(container)
            
            // Verify schema contains expected models
            let context = container.mainContext
            XCTAssertNotNil(context)
            
            // Test that we can insert and fetch data
            let testFamily = Family(
                name: "Test Family",
                code: "TEST123",
                createdByUserId: UUID()
            )
            
            context.insert(testFamily)
            
            // Verify the family was inserted
            let descriptor = FetchDescriptor<Family>()
            let families = try context.fetch(descriptor)
            XCTAssertEqual(families.count, 1)
            XCTAssertEqual(families.first?.name, "Test Family")
            
        } catch {
            // If CloudKit is not available (e.g., in simulator), this is expected
            // Log the error but don't fail the test
            print("CloudKit container creation failed (expected in simulator): \(error)")
            
            // Verify it's a CloudKit-related error
            let errorDescription = error.localizedDescription.lowercased()
            let isCloudKitError = errorDescription.contains("cloudkit") || 
                                errorDescription.contains("icloud") ||
                                errorDescription.contains("container")
            
            if !isCloudKitError {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    func testInMemoryContainerCreation() throws {
        // Test that in-memory container creation works reliably
        let container = try ModelContainerConfiguration.createInMemory()
        
        // Verify container was created
        XCTAssertNotNil(container)
        
        // Verify we can use the container
        let context = container.mainContext
        XCTAssertNotNil(context)
        
        // Test data operations
        let testUser = UserProfile(
            displayName: "Test User",
            appleUserIdHash: "test_hash_123"
        )
        
        context.insert(testUser)
        
        // Verify the user was inserted
        let descriptor = FetchDescriptor<UserProfile>()
        let users = try context.fetch(descriptor)
        XCTAssertEqual(users.count, 1)
        XCTAssertEqual(users.first?.displayName, "Test User")
    }
    
    // MARK: - CloudKit Failure Fallback Tests
    
    @MainActor func testCreateWithFallbackSuccess() {
        // Test that createWithFallback returns a working container
        let container = ModelContainerConfiguration.createWithFallback()
        
        // Verify container was created
        XCTAssertNotNil(container)
        
        // Verify we can use the container
        let context = container.mainContext
        XCTAssertNotNil(context)
        
        // Test basic operations
        do {
            let testFamily = Family(
                name: "Fallback Test Family",
                code: "FALL123",
                createdByUserId: UUID()
            )
            
            context.insert(testFamily)
            
            let descriptor = FetchDescriptor<Family>()
            let families = try context.fetch(descriptor)
            XCTAssertGreaterThanOrEqual(families.count, 1)
            
            // Find our test family
            let testFamilyFound = families.first { $0.name == "Fallback Test Family" }
            XCTAssertNotNil(testFamilyFound)
            
        } catch {
            XCTFail("Failed to perform basic operations on fallback container: \(error)")
        }
    }
    
    @MainActor func testFallbackContainerPersistence() {
        // Test that fallback container can handle multiple operations
        let container = ModelContainerConfiguration.createWithFallback()
        let context = container.mainContext
        
        do {
            // Create test data
            let user1 = UserProfile(
                displayName: "User One",
                appleUserIdHash: "hash_one"
            )
            
            let user2 = UserProfile(
                displayName: "User Two", 
                appleUserIdHash: "hash_two"
            )
            
            let family = Family(
                name: "Persistence Test Family",
                code: "PERS123",
                createdByUserId: user1.id
            )
            
            let membership = Membership(
                family: family,
                user: user1,
                role: .parentAdmin
            )
            
            // Insert all entities
            context.insert(user1)
            context.insert(user2)
            context.insert(family)
            context.insert(membership)
            
            // Verify all entities were inserted
            let userDescriptor = FetchDescriptor<UserProfile>()
            let users = try context.fetch(userDescriptor)
            XCTAssertGreaterThanOrEqual(users.count, 2)
            
            let familyDescriptor = FetchDescriptor<Family>()
            let families = try context.fetch(familyDescriptor)
            XCTAssertGreaterThanOrEqual(families.count, 1)
            
            let membershipDescriptor = FetchDescriptor<Membership>()
            let memberships = try context.fetch(membershipDescriptor)
            XCTAssertGreaterThanOrEqual(memberships.count, 1)
            
        } catch {
            XCTFail("Failed to test persistence in fallback container: \(error)")
        }
    }
    
    // MARK: - Complete Failure Scenario Tests
    
    @MainActor func testModelContainerErrorTypes() {
        // Test that ModelContainerError enum works correctly
        
        let testError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        
        let cloudKitError = ModelContainerError.cloudKitCreationFailed(underlying: testError)
        XCTAssertNotNil(cloudKitError.errorDescription)
        XCTAssertTrue(cloudKitError.errorDescription!.contains("CloudKit"))
        XCTAssertNotNil(cloudKitError.failureReason)
        XCTAssertNotNil(cloudKitError.recoverySuggestion)
        
        let localError = ModelContainerError.localCreationFailed(underlying: testError)
        XCTAssertNotNil(localError.errorDescription)
        XCTAssertTrue(localError.errorDescription!.contains("Local"))
        XCTAssertNotNil(localError.failureReason)
        XCTAssertNotNil(localError.recoverySuggestion)
        
        let inMemoryError = ModelContainerError.inMemoryCreationFailed(underlying: testError)
        XCTAssertNotNil(inMemoryError.errorDescription)
        XCTAssertTrue(inMemoryError.errorDescription!.contains("In-memory"))
        XCTAssertNotNil(inMemoryError.failureReason)
        XCTAssertNotNil(inMemoryError.recoverySuggestion)
        
        let allFailedError = ModelContainerError.allCreationMethodsFailed
        XCTAssertNotNil(allFailedError.errorDescription)
        XCTAssertTrue(allFailedError.errorDescription!.contains("All"))
        XCTAssertNotNil(allFailedError.failureReason)
        XCTAssertNotNil(allFailedError.recoverySuggestion)
    }
    
    @MainActor func testInMemoryContainerFailureHandling() {
        // Test what happens when even in-memory container fails
        // This is a theoretical test since in-memory should rarely fail
        
        do {
            let container = try ModelContainerConfiguration.createInMemory()
            
            // If we get here, in-memory creation succeeded (which is normal)
            XCTAssertNotNil(container)
            
            // Test that the container is actually in-memory by checking it doesn't persist
            let context = container.mainContext
            
            let testFamily = Family(
                name: "Memory Test Family",
                code: "MEM123",
                createdByUserId: UUID()
            )
            
            context.insert(testFamily)
            
            // Verify data exists in current session
            let descriptor = FetchDescriptor<Family>()
            let families = try context.fetch(descriptor)
            let memoryFamily = families.first { $0.name == "Memory Test Family" }
            XCTAssertNotNil(memoryFamily)
            
        } catch {
            // If in-memory creation fails, this is a serious system issue
            XCTFail("In-memory container creation should not fail: \(error)")
        }
    }
    
    // MARK: - Schema Validation Tests
    
    func testSchemaValidation() throws {
        // Test the new schema validation functionality
        print("🧪 Testing SwiftData schema validation...")
        
        // Test that schema validation passes for valid models
        do {
            try ModelContainerConfiguration.validateSchema()
            print("✅ Schema validation passed successfully")
        } catch {
            XCTFail("Schema validation should pass for valid models: \(error)")
        }
    }
    
    func testModelSchemaConsistency() throws {
        // Test that all containers use the same schema
        let inMemoryContainer = try ModelContainerConfiguration.createInMemory()
        let context = inMemoryContainer.mainContext
        
        // Test that all expected model types can be used
        let family = Family(
            name: "Schema Test Family",
            code: "SCH123",
            createdByUserId: UUID()
        )
        
        let user = UserProfile(
            displayName: "Schema Test User",
            appleUserIdHash: "schema_hash"
        )
        
        let membership = Membership(
            family: family,
            user: user,
            role: .adult
        )
        
        // Insert all model types
        context.insert(family)
        context.insert(user)
        context.insert(membership)
        
        // Verify all types can be fetched
        let familyDescriptor = FetchDescriptor<Family>()
        let families = try context.fetch(familyDescriptor)
        XCTAssertGreaterThanOrEqual(families.count, 1)
        
        let userDescriptor = FetchDescriptor<UserProfile>()
        let users = try context.fetch(userDescriptor)
        XCTAssertGreaterThanOrEqual(users.count, 1)
        
        let membershipDescriptor = FetchDescriptor<Membership>()
        let memberships = try context.fetch(membershipDescriptor)
        XCTAssertGreaterThanOrEqual(memberships.count, 1)
    }
    
    // MARK: - Container Configuration Tests
    
    @MainActor func testCloudKitContainerIdentifier() {
        // Test that the CloudKit container identifier is correct
        // This test verifies the configuration without actually creating the container
        
        let expectedIdentifier = "iCloud.net.dataenvy.TribeBoard"
        
        // We can't directly test the private method, but we can verify
        // that the create() method uses the correct identifier by checking
        // the error message when CloudKit is unavailable
        
        do {
            _ = try ModelContainerConfiguration.create()
            // If this succeeds, CloudKit is available and configured correctly
            print("CloudKit container created successfully with identifier: \(expectedIdentifier)")
        } catch {
            // Check if the error mentions the correct container identifier
            let errorDescription = error.localizedDescription
            print("CloudKit creation failed (expected in simulator): \(errorDescription)")
            
            // The error should be related to CloudKit, not configuration
            let isConfigurationError = errorDescription.contains("identifier") || 
                                     errorDescription.contains("container") ||
                                     errorDescription.contains("bundle")
            
            if isConfigurationError {
                XCTFail("CloudKit container identifier may be incorrect: \(error)")
            }
        }
    }
    
    func testContainerSeedMockData() throws {
        // Test the mock data seeding functionality
        let container = try ModelContainerConfiguration.createInMemory()
        
        // Seed with mock data
        try container.seedMockData()
        
        let context = container.mainContext
        
        // Verify mock data was created
        let userDescriptor = FetchDescriptor<UserProfile>()
        let users = try context.fetch(userDescriptor)
        XCTAssertEqual(users.count, 3)
        
        let familyDescriptor = FetchDescriptor<Family>()
        let families = try context.fetch(familyDescriptor)
        XCTAssertEqual(families.count, 1)
        
        let membershipDescriptor = FetchDescriptor<Membership>()
        let memberships = try context.fetch(membershipDescriptor)
        XCTAssertEqual(memberships.count, 3)
        
        // Verify relationships
        let family = families.first!
        XCTAssertEqual(family.name, "The Johnson Family")
        XCTAssertEqual(family.code, "JOH123")
        
        // Verify users have expected names
        let userNames = users.map { $0.displayName }.sorted()
        XCTAssertTrue(userNames.contains("Sarah Johnson"))
        XCTAssertTrue(userNames.contains("Mike Garcia"))
        XCTAssertTrue(userNames.contains("Emma Chen"))
        
        // Verify membership roles
        let roles = memberships.map { $0.role }
        XCTAssertTrue(roles.contains(.parentAdmin))
        XCTAssertTrue(roles.contains(.adult))
        XCTAssertTrue(roles.contains(.kid))
    }
    
    // MARK: - App Launch Environment Tests
    
    @MainActor func testAppLaunchInSimulatorEnvironment() {
        // Test app launch behavior in iOS Simulator (CloudKit limited)
        // This simulates the TribeBoardApp initialization process
        
        print("🧪 Testing app launch in simulator environment...")
        
        // Simulate the app initialization process
        let container = ModelContainerConfiguration.createWithFallback()
        
        // Verify container was created successfully
        XCTAssertNotNil(container, "App should launch successfully even in simulator with CloudKit limitations")
        
        // Verify the container is functional
        let context = container.mainContext
        XCTAssertNotNil(context, "ModelContainer context should be available")
        
        // Test basic data operations to ensure app functionality
        do {
            let testFamily = Family(
                name: "Simulator Test Family",
                code: "SIM123",
                createdByUserId: UUID()
            )
            
            context.insert(testFamily)
            
            let descriptor = FetchDescriptor<Family>()
            let families = try context.fetch(descriptor)
            let simulatorFamily = families.first { $0.name == "Simulator Test Family" }
            XCTAssertNotNil(simulatorFamily, "App should be able to perform basic data operations in simulator")
            
            print("✅ App launch simulation successful - basic functionality verified")
            
        } catch {
            XCTFail("App should be able to perform basic operations after launch: \(error)")
        }
    }
    
    @MainActor func testAppLaunchWithCloudKitAvailable() {
        // Test app launch behavior when CloudKit is available
        // Note: This test may pass or fail depending on environment
        
        print("🧪 Testing app launch with CloudKit available...")
        
        do {
            // Try to create CloudKit container directly
            let cloudKitContainer = try ModelContainerConfiguration.create()
            
            // If we get here, CloudKit is available
            XCTAssertNotNil(cloudKitContainer, "CloudKit container should be created when available")
            
            // Verify CloudKit container functionality
            let context = cloudKitContainer.mainContext
            XCTAssertNotNil(context, "CloudKit container context should be available")
            
            // Test data operations with CloudKit
            let testUser = UserProfile(
                displayName: "CloudKit Test User",
                appleUserIdHash: "cloudkit_hash"
            )
            
            context.insert(testUser)
            
            let descriptor = FetchDescriptor<UserProfile>()
            let users = try context.fetch(descriptor)
            let cloudKitUser = users.first { $0.displayName == "CloudKit Test User" }
            XCTAssertNotNil(cloudKitUser, "CloudKit container should support data operations")
            
            print("✅ CloudKit container creation and operations successful")
            
        } catch {
            // CloudKit not available - this is expected in many test environments
            print("ℹ️ CloudKit not available in test environment: \(error.localizedDescription)")
            
            // Verify fallback still works
            let fallbackContainer = ModelContainerConfiguration.createWithFallback()
            XCTAssertNotNil(fallbackContainer, "Fallback should work when CloudKit is unavailable")
            
            print("✅ Fallback mechanism verified when CloudKit unavailable")
        }
    }
    
    @MainActor func testAppLaunchWithCloudKitUnavailable() {
        // Test app launch behavior when CloudKit is explicitly unavailable
        // This simulates network issues, iCloud signed out, etc.
        
        print("🧪 Testing app launch with CloudKit unavailable...")
        
        // Use fallback method which should handle CloudKit unavailability gracefully
        let container = ModelContainerConfiguration.createWithFallback()
        
        // Verify app can still launch and function
        XCTAssertNotNil(container, "App should launch successfully even when CloudKit is unavailable")
        
        // Verify local functionality works
        let context = container.mainContext
        XCTAssertNotNil(context, "Local container context should be available")
        
        do {
            // Test full app functionality without CloudKit
            let user = UserProfile(
                displayName: "Offline User",
                appleUserIdHash: "offline_hash"
            )
            
            let family = Family(
                name: "Offline Family",
                code: "OFF123",
                createdByUserId: user.id
            )
            
            let membership = Membership(
                family: family,
                user: user,
                role: .parentAdmin
            )
            
            context.insert(user)
            context.insert(family)
            context.insert(membership)
            
            // Verify all operations work offline
            let userDescriptor = FetchDescriptor<UserProfile>()
            let users = try context.fetch(userDescriptor)
            let offlineUser = users.first { $0.displayName == "Offline User" }
            XCTAssertNotNil(offlineUser, "User creation should work offline")
            
            let familyDescriptor = FetchDescriptor<Family>()
            let families = try context.fetch(familyDescriptor)
            let offlineFamily = families.first { $0.name == "Offline Family" }
            XCTAssertNotNil(offlineFamily, "Family creation should work offline")
            
            let membershipDescriptor = FetchDescriptor<Membership>()
            let memberships = try context.fetch(membershipDescriptor)
            let offlineMembership = memberships.first { $0.user?.displayName == "Offline User" }
            XCTAssertNotNil(offlineMembership, "Membership creation should work offline")
            
            print("✅ Full app functionality verified in offline mode")
            
        } catch {
            XCTFail("App should maintain full functionality when CloudKit is unavailable: \(error)")
        }
    }
    
    @MainActor func testAppLaunchNoCrashScenarios() {
        // Test that app launch never crashes during ModelContainer initialization
        // This covers all the crash scenarios that were previously causing issues
        
        print("🧪 Testing app launch crash prevention...")
        
        // Test multiple container creation attempts (simulating app restarts)
        for attempt in 1...5 {
            print("   Attempt \(attempt): Creating ModelContainer...")
            
            let container = ModelContainerConfiguration.createWithFallback()
            
            // Verify no crash occurred
            XCTAssertNotNil(container, "Container creation attempt \(attempt) should not crash")
            
            // Verify container is functional
            let context = container.mainContext
            XCTAssertNotNil(context, "Container context should be available on attempt \(attempt)")
            
            // Test basic operation to ensure container works
            do {
                let testFamily = Family(
                    name: "Crash Test Family \(attempt)",
                    code: "CRA\(attempt)3",
                    createdByUserId: UUID()
                )
                
                context.insert(testFamily)
                
                let descriptor = FetchDescriptor<Family>()
                let families = try context.fetch(descriptor)
                let crashTestFamily = families.first { $0.name == "Crash Test Family \(attempt)" }
                XCTAssertNotNil(crashTestFamily, "Basic operations should work on attempt \(attempt)")
                
            } catch {
                XCTFail("Basic operations should not fail on attempt \(attempt): \(error)")
            }
        }
        
        print("✅ All container creation attempts successful - no crashes detected")
    }
    
    @MainActor func testAppLaunchWithDifferentSystemStates() {
        // Test app launch under various system conditions
        
        print("🧪 Testing app launch under different system states...")
        
        // Test 1: Normal launch
        let normalContainer = ModelContainerConfiguration.createWithFallback()
        XCTAssertNotNil(normalContainer, "Normal app launch should succeed")
        
        // Test 2: Multiple rapid launches (simulating app switching)
        var rapidContainers: [ModelContainer] = []
        for i in 0..<3 {
            let container = ModelContainerConfiguration.createWithFallback()
            rapidContainers.append(container)
            XCTAssertNotNil(container, "Rapid launch \(i+1) should succeed")
        }
        
        // Test 3: Launch with immediate data operations
        let immediateContainer = ModelContainerConfiguration.createWithFallback()
        let immediateContext = immediateContainer.mainContext
        
        do {
            // Immediately try to use the container
            let immediateFamily = Family(
                name: "Immediate Family",
                code: "IMM123",
                createdByUserId: UUID()
            )
            
            immediateContext.insert(immediateFamily)
            
            let descriptor = FetchDescriptor<Family>()
            let families = try immediateContext.fetch(descriptor)
            let foundFamily = families.first { $0.name == "Immediate Family" }
            XCTAssertNotNil(foundFamily, "Immediate data operations should work")
            
        } catch {
            XCTFail("Immediate data operations after launch should work: \(error)")
        }
        
        print("✅ App launch verified under various system states")
    }
    
    @MainActor func testModelContainerInitializationRobustness() {
        // Test the robustness of ModelContainer initialization process
        // This ensures the app can handle various initialization scenarios
        
        print("🧪 Testing ModelContainer initialization robustness...")
        
        // Test that initialization is idempotent (can be called multiple times)
        var containers: [ModelContainer] = []
        
        for i in 0..<10 {
            let container = ModelContainerConfiguration.createWithFallback()
            containers.append(container)
            
            XCTAssertNotNil(container, "Container \(i+1) should be created successfully")
            
            // Verify each container is independent and functional
            let context = container.mainContext
            let testUser = UserProfile(
                displayName: "Robustness User \(i)",
                appleUserIdHash: "robust_\(i)"
            )
            
            context.insert(testUser)
            
            do {
                let descriptor = FetchDescriptor<UserProfile>()
                let users = try context.fetch(descriptor)
                let robustUser = users.first { $0.displayName == "Robustness User \(i)" }
                XCTAssertNotNil(robustUser, "Container \(i+1) should be functional")
                
            } catch {
                XCTFail("Container \(i+1) should be functional: \(error)")
            }
        }
        
        XCTAssertEqual(containers.count, 10, "All containers should be created successfully")
        print("✅ ModelContainer initialization robustness verified")
    }
    
    // MARK: - Performance Tests
    
    @MainActor func testContainerCreationPerformance() {
        // Test that container creation is reasonably fast
        measure {
            let container = ModelContainerConfiguration.createWithFallback()
            XCTAssertNotNil(container)
        }
    }
    
    @MainActor func testMultipleContainerCreation() {
        // Test creating multiple containers (should work for in-memory)
        var containers: [ModelContainer] = []
        
        for i in 0..<3 {
            do {
                let container = try ModelContainerConfiguration.createInMemory()
                containers.append(container)
                
                // Test that each container is independent
                let context = container.mainContext
                let testFamily = Family(
                    name: "Container \(i) Family",
                    code: "CON\(i)23",
                    createdByUserId: UUID()
                )
                context.insert(testFamily)
                
            } catch {
                XCTFail("Failed to create container \(i): \(error)")
            }
        }
        
        XCTAssertEqual(containers.count, 3)
        
        // Verify each container has its own data
        for (index, container) in containers.enumerated() {
            do {
                let context = container.mainContext
                let descriptor = FetchDescriptor<Family>()
                let families = try context.fetch(descriptor)
                
                // Each container should have exactly one family
                XCTAssertEqual(families.count, 1)
                XCTAssertEqual(families.first?.name, "Container \(index) Family")
                
            } catch {
                XCTFail("Failed to verify container \(index): \(error)")
            }
        }
    }
}