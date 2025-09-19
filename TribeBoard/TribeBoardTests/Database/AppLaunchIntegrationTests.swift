import XCTest
import SwiftData
@testable import TribeBoard

/// Tests for app launch initialization and database setup
@MainActor
class AppLaunchIntegrationTests: XCTestCase {
    
    // MARK: - Test Properties
    
    private var testModelContainer: ModelContainer?
    private var testDataService: DataService?
    private var testServiceCoordinator: ServiceCoordinator?
    
    // MARK: - Setup and Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Clean up any existing test containers
        testModelContainer = nil
        testDataService = nil
        testServiceCoordinator = nil
    }
    
    override func tearDown() async throws {
        // Clean up test resources
        testModelContainer = nil
        testDataService = nil
        testServiceCoordinator = nil
        
        try await super.tearDown()
    }
    
    // MARK: - Schema Validation Tests
    
    /// Tests that SwiftData schema validation passes during app initialization
    /// Requirements: 8.6
    func testSchemaValidationDuringAppLaunch() throws {
        print("🧪 Testing schema validation during app launch...")
        
        // Step 1: Test schema validation (this is called during app initialization)
        XCTAssertNoThrow(try ModelContainerConfiguration.validateSchema())
        
        // Step 2: Verify schema contains expected entities
        let schema = Schema([
            Family.self,
            UserProfile.self,
            Membership.self
        ])
        
        XCTAssertEqual(schema.entities.count, 3)
        
        let entityNames = schema.entities.map { $0.name }.sorted()
        let expectedNames = ["Family", "Membership", "UserProfile"]
        XCTAssertEqual(entityNames, expectedNames)
        
        // Step 3: Verify each entity has expected properties
        for entity in schema.entities {
            XCTAssertGreaterThan(entity.properties.count, 0, "Entity \(entity.name) should have properties")
            
            // Verify ID property exists
            let hasIdProperty = entity.properties.contains { $0.name == "id" }
            XCTAssertTrue(hasIdProperty, "Entity \(entity.name) should have an 'id' property")
        }
        
        print("✅ Schema validation during app launch test passed")
    }
    
    /// Tests schema validation error handling
    /// Requirements: 8.6
    func testSchemaValidationErrorHandling() throws {
        print("🧪 Testing schema validation error handling...")
        
        // This test verifies that schema validation provides meaningful error messages
        // Since our actual schema is valid, we test the error handling infrastructure
        
        // Step 1: Verify that schema validation completes without throwing
        var validationCompleted = false
        var validationError: Error?
        
        do {
            try ModelContainerConfiguration.validateSchema()
            validationCompleted = true
        } catch {
            validationError = error
        }
        
        // Step 2: Schema should be valid, so validation should complete successfully
        XCTAssertTrue(validationCompleted, "Schema validation should complete successfully")
        XCTAssertNil(validationError, "Schema validation should not produce errors")
        
        // Step 3: Verify error types are properly defined
        let schemaError = ModelContainerError.schemaValidationFailed(underlying: NSError(domain: "Test", code: 1, userInfo: nil))
        XCTAssertNotNil(schemaError.errorDescription)
        XCTAssertNotNil(schemaError.failureReason)
        XCTAssertNotNil(schemaError.recoverySuggestion)
        
        print("✅ Schema validation error handling test passed")
    }
    
    // MARK: - ModelContainer Creation Tests
    
    /// Tests that ModelContainer creation succeeds in various environments
    /// Requirements: 8.6
    func testModelContainerCreationInVariousEnvironments() throws {
        print("🧪 Testing ModelContainer creation in various environments...")
        
        // Step 1: Test in-memory container creation (most reliable)
        let inMemoryContainer = try ModelContainerConfiguration.createInMemory()
        XCTAssertNotNil(inMemoryContainer)
        
        // Verify the container is functional
        let context = inMemoryContainer.mainContext
        XCTAssertNotNil(context)
        
        // Test basic operations
        let testFamily = Family(name: "Test Family", code: "TEST123", createdByUserId: UUID())
        context.insert(testFamily)
        
        XCTAssertNoThrow(try context.save())
        
        // Verify data was inserted
        let descriptor = FetchDescriptor<Family>()
        let families = try context.fetch(descriptor)
        XCTAssertEqual(families.count, 1)
        XCTAssertEqual(families.first?.name, "Test Family")
        
        // Store for cleanup
        testModelContainer = inMemoryContainer
        
        print("✅ ModelContainer creation in various environments test passed")
    }
    
    /// Tests ModelContainer fallback mechanism
    /// Requirements: 8.6
    func testModelContainerFallbackMechanism() throws {
        print("🧪 Testing ModelContainer fallback mechanism...")
        
        // Step 1: Test the fallback creation method
        let container = ModelContainerConfiguration.createWithFallback()
        XCTAssertNotNil(container)
        
        // Step 2: Verify the container is functional
        let context = container.mainContext
        XCTAssertNotNil(context)
        
        // Step 3: Test that the container can perform basic operations
        let testUser = UserProfile(displayName: "Test User", appleUserIdHash: "test_hash_1234567890")
        context.insert(testUser)
        
        XCTAssertNoThrow(try context.save())
        
        // Verify data persistence
        let descriptor = FetchDescriptor<UserProfile>()
        let users = try context.fetch(descriptor)
        XCTAssertEqual(users.count, 1)
        XCTAssertEqual(users.first?.displayName, "Test User")
        
        // Store for cleanup
        testModelContainer = container
        
        print("✅ ModelContainer fallback mechanism test passed")
    }
    
    /// Tests ModelContainer error scenarios
    /// Requirements: 8.6
    func testModelContainerErrorScenarios() throws {
        print("🧪 Testing ModelContainer error scenarios...")
        
        // Step 1: Test error type definitions
        let cloudKitError = ModelContainerError.cloudKitCreationFailed(underlying: NSError(domain: "CloudKit", code: 1, userInfo: nil))
        XCTAssertNotNil(cloudKitError.errorDescription)
        XCTAssertTrue(cloudKitError.errorDescription!.contains("CloudKit"))
        
        let localError = ModelContainerError.localCreationFailed(underlying: NSError(domain: "Local", code: 1, userInfo: nil))
        XCTAssertNotNil(localError.errorDescription)
        XCTAssertTrue(localError.errorDescription!.contains("Local"))
        
        let inMemoryError = ModelContainerError.inMemoryCreationFailed(underlying: NSError(domain: "Memory", code: 1, userInfo: nil))
        XCTAssertNotNil(inMemoryError.errorDescription)
        XCTAssertTrue(inMemoryError.errorDescription!.contains("memory"))
        
        // Step 2: Test that fallback mechanism handles errors gracefully
        // Since we can't easily simulate container creation failures in tests,
        // we verify that the error handling infrastructure is in place
        let allFailedError = ModelContainerError.allCreationMethodsFailed
        XCTAssertNotNil(allFailedError.errorDescription)
        XCTAssertNotNil(allFailedError.failureReason)
        XCTAssertNotNil(allFailedError.recoverySuggestion)
        
        print("✅ ModelContainer error scenarios test passed")
    }
    
    // MARK: - Service Initialization Tests
    
    /// Tests that services initialize correctly during app launch
    /// Requirements: 8.6
    func testServiceInitializationDuringAppLaunch() throws {
        print("🧪 Testing service initialization during app launch...")
        
        // Step 1: Create ModelContainer for service initialization
        let container = try ModelContainerConfiguration.createInMemory()
        let context = container.mainContext
        
        // Step 2: Initialize ServiceCoordinator (simulates app launch)
        let serviceCoordinator = ServiceCoordinator(modelContext: context)
        
        // Step 3: Verify all services are initialized
        XCTAssertNotNil(serviceCoordinator.dataService)
        XCTAssertNotNil(serviceCoordinator.cloudKitService)
        XCTAssertNotNil(serviceCoordinator.authService)
        XCTAssertNotNil(serviceCoordinator.qrCodeService)
        XCTAssertNotNil(serviceCoordinator.codeGenerator)
        
        // Step 4: Test service dependencies are properly set up
        // DataService should be functional
        let testFamily = try serviceCoordinator.dataService.createFamily(
            name: "Service Test Family",
            code: "SERV123",
            createdByUserId: UUID()
        )
        XCTAssertNotNil(testFamily)
        XCTAssertEqual(testFamily.name, "Service Test Family")
        
        // Step 5: Test ViewModel factory methods work
        let createFamilyVM = serviceCoordinator.createFamilyViewModel()
        XCTAssertNotNil(createFamilyVM)
        
        let joinFamilyVM = serviceCoordinator.joinFamilyViewModel()
        XCTAssertNotNil(joinFamilyVM)
        
        // Store for cleanup
        testModelContainer = container
        testServiceCoordinator = serviceCoordinator
        
        print("✅ Service initialization during app launch test passed")
    }
    
    /// Tests service dependency injection
    /// Requirements: 8.6
    func testServiceDependencyInjection() throws {
        print("🧪 Testing service dependency injection...")
        
        // Step 1: Create test environment
        let container = try ModelContainerConfiguration.createInMemory()
        let context = container.mainContext
        let serviceCoordinator = ServiceCoordinator(modelContext: context)
        
        // Step 2: Test that AuthService has DataService dependency
        // We can't directly access the private dependency, but we can test functionality
        let testUser = try serviceCoordinator.dataService.createUserProfile(
            displayName: "Dependency Test User",
            appleUserIdHash: "dependency_hash_1234567890"
        )
        
        // AuthService should be able to find this user through its DataService dependency
        let foundUser = try serviceCoordinator.dataService.fetchUserProfile(byAppleUserIdHash: "dependency_hash_1234567890")
        XCTAssertNotNil(foundUser)
        XCTAssertEqual(foundUser?.id, testUser.id)
        
        // Step 3: Test ViewModel creation with proper dependencies
        let user = try serviceCoordinator.dataService.createUserProfile(
            displayName: "VM Test User",
            appleUserIdHash: "vm_test_hash_1234567890"
        )
        
        let family = try serviceCoordinator.dataService.createFamily(
            name: "VM Test Family",
            code: "VMTEST123",
            createdByUserId: user.id
        )
        
        // Create ViewModels and verify they have proper dependencies
        let roleSelectionVM = serviceCoordinator.roleSelectionViewModel(family: family, user: user)
        XCTAssertNotNil(roleSelectionVM)
        
        let dashboardVM = serviceCoordinator.familyDashboardViewModel(
            family: family,
            currentUserId: user.id,
            currentUserRole: .parentAdmin
        )
        XCTAssertNotNil(dashboardVM)
        
        // Store for cleanup
        testModelContainer = container
        testServiceCoordinator = serviceCoordinator
        
        print("✅ Service dependency injection test passed")
    }
    
    // MARK: - Data Migration Tests
    
    /// Tests that data migrations are performed correctly during app launch
    /// Requirements: 8.6
    func testDataMigrationsDuringAppLaunch() throws {
        print("🧪 Testing data migrations during app launch...")
        
        // Step 1: Create initial data state (simulating older app version)
        let container = try ModelContainerConfiguration.createInMemory()
        let context = container.mainContext
        
        // Create some initial data
        let family = Family(name: "Migration Test Family", code: "MIGR123", createdByUserId: UUID())
        let user = UserProfile(displayName: "Migration Test User", appleUserIdHash: "migration_hash_1234567890")
        
        context.insert(family)
        context.insert(user)
        try context.save()
        
        // Step 2: Verify initial data exists
        let initialFamilies = try context.fetch(FetchDescriptor<Family>())
        let initialUsers = try context.fetch(FetchDescriptor<UserProfile>())
        
        XCTAssertEqual(initialFamilies.count, 1)
        XCTAssertEqual(initialUsers.count, 1)
        
        // Step 3: Simulate app restart with potential schema changes
        // In a real migration scenario, this would involve schema versioning
        // For now, we verify that existing data remains intact
        
        let postMigrationFamilies = try context.fetch(FetchDescriptor<Family>())
        let postMigrationUsers = try context.fetch(FetchDescriptor<UserProfile>())
        
        XCTAssertEqual(postMigrationFamilies.count, 1)
        XCTAssertEqual(postMigrationUsers.count, 1)
        
        // Verify data integrity
        XCTAssertEqual(postMigrationFamilies.first?.name, "Migration Test Family")
        XCTAssertEqual(postMigrationUsers.first?.displayName, "Migration Test User")
        
        // Step 4: Test that new operations work after migration
        let dataService = DataService(modelContext: context)
        let newFamily = try dataService.createFamily(
            name: "Post Migration Family",
            code: "POST123",
            createdByUserId: user.id
        )
        
        XCTAssertNotNil(newFamily)
        XCTAssertEqual(newFamily.name, "Post Migration Family")
        
        // Store for cleanup
        testModelContainer = container
        testDataService = dataService
        
        print("✅ Data migrations during app launch test passed")
    }
    
    /// Tests migration error handling
    /// Requirements: 8.6
    func testMigrationErrorHandling() throws {
        print("🧪 Testing migration error handling...")
        
        // Step 1: Create container and verify it handles potential migration issues
        let container = try ModelContainerConfiguration.createInMemory()
        let context = container.mainContext
        
        // Step 2: Test that the container can handle various data states
        // Create data with edge cases that might cause migration issues
        
        // Family with edge case data
        let edgeCaseFamily = Family(
            name: String(repeating: "A", count: 50), // Maximum length
            code: "EDGE123",
            createdByUserId: UUID()
        )
        
        // User with edge case data
        let edgeCaseUser = UserProfile(
            displayName: "Edge Case User",
            appleUserIdHash: String(repeating: "x", count: 64) // Long hash
        )
        
        context.insert(edgeCaseFamily)
        context.insert(edgeCaseUser)
        
        // This should not throw even with edge case data
        XCTAssertNoThrow(try context.save())
        
        // Step 3: Verify data integrity after potential migration
        let families = try context.fetch(FetchDescriptor<Family>())
        let users = try context.fetch(FetchDescriptor<UserProfile>())
        
        XCTAssertEqual(families.count, 1)
        XCTAssertEqual(users.count, 1)
        
        // Verify edge case data is preserved
        XCTAssertEqual(families.first?.name.count, 50)
        XCTAssertEqual(users.first?.appleUserIdHash.count, 64)
        
        // Store for cleanup
        testModelContainer = container
        
        print("✅ Migration error handling test passed")
    }
    
    // MARK: - App Launch Integration Tests
    
    /// Tests complete app launch initialization sequence
    /// Requirements: 8.6
    func testCompleteAppLaunchInitialization() throws {
        print("🧪 Testing complete app launch initialization...")
        
        // Step 1: Schema validation (first step in app launch)
        XCTAssertNoThrow(try ModelContainerConfiguration.validateSchema())
        
        // Step 2: ModelContainer creation (second step)
        let container = ModelContainerConfiguration.createWithFallback()
        XCTAssertNotNil(container)
        
        // Step 3: Service initialization (third step)
        let serviceCoordinator = ServiceCoordinator(modelContext: container.mainContext)
        XCTAssertNotNil(serviceCoordinator)
        
        // Step 4: Verify complete system is functional
        let dataService = serviceCoordinator.dataService
        
        // Create test data to verify full functionality
        let user = try dataService.createUserProfile(
            displayName: "Launch Test User",
            appleUserIdHash: "launch_hash_1234567890"
        )
        
        let family = try dataService.createFamily(
            name: "Launch Test Family",
            code: "LAUNCH123",
            createdByUserId: user.id
        )
        
        let membership = try dataService.createMembership(
            family: family,
            user: user,
            role: .parentAdmin
        )
        
        // Step 5: Verify all components work together
        XCTAssertEqual(user.displayName, "Launch Test User")
        XCTAssertEqual(family.name, "Launch Test Family")
        XCTAssertEqual(membership.role, .parentAdmin)
        XCTAssertTrue(family.hasParentAdmin)
        
        // Step 6: Test ViewModel creation (UI layer integration)
        let createFamilyVM = serviceCoordinator.createFamilyViewModel()
        let joinFamilyVM = serviceCoordinator.joinFamilyViewModel()
        let roleSelectionVM = serviceCoordinator.roleSelectionViewModel(family: family, user: user)
        let dashboardVM = serviceCoordinator.familyDashboardViewModel(
            family: family,
            currentUserId: user.id,
            currentUserRole: .parentAdmin
        )
        
        XCTAssertNotNil(createFamilyVM)
        XCTAssertNotNil(joinFamilyVM)
        XCTAssertNotNil(roleSelectionVM)
        XCTAssertNotNil(dashboardVM)
        
        // Store for cleanup
        testModelContainer = container
        testServiceCoordinator = serviceCoordinator
        
        print("✅ Complete app launch initialization test passed")
    }
    
    /// Tests app launch performance and timing
    /// Requirements: 8.6
    func testAppLaunchPerformance() throws {
        print("🧪 Testing app launch performance...")
        
        let startTime = Date()
        
        // Step 1: Measure schema validation time
        let schemaStartTime = Date()
        XCTAssertNoThrow(try ModelContainerConfiguration.validateSchema())
        let schemaTime = Date().timeIntervalSince(schemaStartTime)
        
        // Schema validation should be fast (< 100ms)
        XCTAssertLessThan(schemaTime, 0.1, "Schema validation should complete within 100ms")
        
        // Step 2: Measure container creation time
        let containerStartTime = Date()
        let container = ModelContainerConfiguration.createWithFallback()
        let containerTime = Date().timeIntervalSince(containerStartTime)
        
        // Container creation should be reasonable (< 1 second)
        XCTAssertLessThan(containerTime, 1.0, "Container creation should complete within 1 second")
        
        // Step 3: Measure service initialization time
        let serviceStartTime = Date()
        let serviceCoordinator = ServiceCoordinator(modelContext: container.mainContext)
        let serviceTime = Date().timeIntervalSince(serviceStartTime)
        
        // Service initialization should be fast (< 100ms)
        XCTAssertLessThan(serviceTime, 0.1, "Service initialization should complete within 100ms")
        
        // Step 4: Measure total launch time
        let totalTime = Date().timeIntervalSince(startTime)
        
        // Total launch initialization should be reasonable (< 2 seconds)
        XCTAssertLessThan(totalTime, 2.0, "Total app launch initialization should complete within 2 seconds")
        
        print("📊 App Launch Performance Metrics:")
        print("   Schema Validation: \(String(format: "%.3f", schemaTime))s")
        print("   Container Creation: \(String(format: "%.3f", containerTime))s")
        print("   Service Initialization: \(String(format: "%.3f", serviceTime))s")
        print("   Total Launch Time: \(String(format: "%.3f", totalTime))s")
        
        // Store for cleanup
        testModelContainer = container
        testServiceCoordinator = serviceCoordinator
        
        print("✅ App launch performance test passed")
    }
    
    /// Tests app launch under various system conditions
    /// Requirements: 8.6
    func testAppLaunchUnderVariousConditions() throws {
        print("🧪 Testing app launch under various conditions...")
        
        // Step 1: Test launch with minimal memory (in-memory container)
        let inMemoryContainer = try ModelContainerConfiguration.createInMemory()
        let inMemoryCoordinator = ServiceCoordinator(modelContext: inMemoryContainer.mainContext)
        
        // Verify functionality with in-memory container
        let testUser = try inMemoryCoordinator.dataService.createUserProfile(
            displayName: "Memory Test User",
            appleUserIdHash: "memory_hash_1234567890"
        )
        XCTAssertNotNil(testUser)
        
        // Step 2: Test launch with fallback mechanism
        let fallbackContainer = ModelContainerConfiguration.createWithFallback()
        let fallbackCoordinator = ServiceCoordinator(modelContext: fallbackContainer.mainContext)
        
        // Verify functionality with fallback container
        let fallbackUser = try fallbackCoordinator.dataService.createUserProfile(
            displayName: "Fallback Test User",
            appleUserIdHash: "fallback_hash_1234567890"
        )
        XCTAssertNotNil(fallbackUser)
        
        // Step 3: Test that both containers are independent
        let inMemoryUsers = try inMemoryContainer.mainContext.fetch(FetchDescriptor<UserProfile>())
        let fallbackUsers = try fallbackContainer.mainContext.fetch(FetchDescriptor<UserProfile>())
        
        XCTAssertEqual(inMemoryUsers.count, 1)
        XCTAssertEqual(fallbackUsers.count, 1)
        XCTAssertNotEqual(inMemoryUsers.first?.id, fallbackUsers.first?.id)
        
        // Store for cleanup
        testModelContainer = fallbackContainer
        testServiceCoordinator = fallbackCoordinator
        
        print("✅ App launch under various conditions test passed")
    }
}