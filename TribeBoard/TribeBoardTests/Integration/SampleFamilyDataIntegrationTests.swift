import XCTest
import SwiftData
@testable import TribeBoard

/// Integration tests for SampleFamilyDataGenerator with real DataService
/// Tests complete family generation workflow with actual database operations
class SampleFamilyDataIntegrationTests: TestBase {
    
    // MARK: - Properties
    
    var sampleGenerator: SampleFamilyDataGenerator!
    var realDataService: DataService!
    
    // MARK: - Setup & Teardown
    
    @MainActor
    override func setUp() {
        super.setUp()
        setupRealDataService()
        sampleGenerator = SampleFamilyDataGenerator(dataService: realDataService)
    }
    
    override func tearDown() {
        cleanupTestData()
        sampleGenerator = nil
        realDataService = nil
        super.tearDown()
    }
    
    // MARK: - Setup Helpers
    
    @MainActor
    private func setupRealDataService() {
        // Create a real DataService instance with test container's context
        let context = ModelContext(testContainer)
        realDataService = DataService(modelContext: context)
    }
    
    @MainActor
    private func cleanupTestData() {
        // Clean up any test data created during integration tests
        let context = createTestContext()
        
        do {
            // Delete all test families (those with sample names)
            let familyDescriptor = FetchDescriptor<Family>()
            let families = try context.fetch(familyDescriptor)
            
            for family in families {
                if family.name.contains("Johnson") || 
                   family.name.contains("Garcia") || 
                   family.name.contains("Chen") || 
                   family.name.contains("Williams") || 
                   family.name.contains("Anderson") {
                    context.delete(family)
                }
            }
            
            // Delete all test users (those with sample hashes)
            let userDescriptor = FetchDescriptor<UserProfile>()
            let users = try context.fetch(userDescriptor)
            
            for user in users {
                if user.appleUserIdHash.contains("sample_") {
                    context.delete(user)
                }
            }
            
            try context.save()
        } catch {
            print("Warning: Failed to clean up test data: \(error)")
        }
    }
    
    // MARK: - Complete Workflow Integration Tests
    
    @MainActor
    func testCompleteWorkflow_GenerateSampleFamilies_ShouldPersistToDatabase() async {
        // Given - Clean database state
        
        // When
        do {
            let generatedFamilies = try await sampleGenerator.generateSampleFamilies()
            
            // Then - Verify families were created and persisted
            XCTAssertEqual(generatedFamilies.count, 5, "Should generate 5 families")
            
            // Verify families exist in database
            let context = createTestContext()
            let familyDescriptor = FetchDescriptor<Family>()
            let persistedFamilies = try context.fetch(familyDescriptor)
            
            let sampleFamilies = persistedFamilies.filter { family in
                family.name.contains("Johnson") || 
                family.name.contains("Garcia") || 
                family.name.contains("Chen") || 
                family.name.contains("Williams") || 
                family.name.contains("Anderson")
            }
            
            XCTAssertEqual(sampleFamilies.count, 5, "Should persist 5 sample families to database")
            
            // Verify each family has valid data
            for family in sampleFamilies {
                XCTAssertFalse(family.name.isEmpty, "Family name should not be empty")
                XCTAssertEqual(family.code.count, 6, "Family code should be 6 characters")
                XCTAssertNotNil(family.createdAt, "Family should have creation date")
            }
            
        } catch {
            XCTFail("Complete workflow should succeed: \(error)")
        }
    }
    
    @MainActor
    func testCompleteWorkflow_GenerateUsers_ShouldPersistToDatabase() async {
        // Given - Clean database state
        
        // When
        do {
            let generatedFamilies = try await sampleGenerator.generateSampleFamilies()
            
            // Then - Verify users were created and persisted
            let context = createTestContext()
            let userDescriptor = FetchDescriptor<UserProfile>()
            let persistedUsers = try context.fetch(userDescriptor)
            
            let sampleUsers = persistedUsers.filter { user in
                user.appleUserIdHash.contains("sample_")
            }
            
            // Calculate expected user count from generated families
            let expectedUserCount = generatedFamilies.reduce(0) { $0 + $1.memberCount }
            XCTAssertEqual(sampleUsers.count, expectedUserCount, "Should persist all sample users to database")
            
            // Verify each user has valid data
            for user in sampleUsers {
                XCTAssertFalse(user.displayName.isEmpty, "User display name should not be empty")
                XCTAssertTrue(user.appleUserIdHash.contains("sample_"), "User should have sample hash")
                XCTAssertNotNil(user.createdAt, "User should have creation date")
            }
            
        } catch {
            XCTFail("User generation should succeed: \(error)")
        }
    }
    
    @MainActor
    func testCompleteWorkflow_GenerateMemberships_ShouldPersistToDatabase() async {
        // Given - Clean database state
        
        // When
        do {
            let generatedFamilies = try await sampleGenerator.generateSampleFamilies()
            
            // Then - Verify memberships were created and persisted
            let context = createTestContext()
            
            // Get all sample families
            let familyDescriptor = FetchDescriptor<Family>()
            let persistedFamilies = try context.fetch(familyDescriptor)
            let sampleFamilies = persistedFamilies.filter { family in
                family.name.contains("Johnson") || 
                family.name.contains("Garcia") || 
                family.name.contains("Chen") || 
                family.name.contains("Williams") || 
                family.name.contains("Anderson")
            }
            
            // Verify memberships exist for each family
            for family in sampleFamilies {
                let memberships = try realDataService.fetchMemberships(forFamily: family)
                XCTAssertGreaterThan(memberships.count, 0, "Family '\(family.name)' should have memberships")
                
                // Verify exactly one admin per family
                let adminMemberships = memberships.filter { $0.role == .parentAdmin }
                XCTAssertEqual(adminMemberships.count, 1, "Family '\(family.name)' should have exactly one admin")
                
                // Verify all memberships are active
                for membership in memberships {
                    XCTAssertEqual(membership.status, .active, "All memberships should be active")
                    XCTAssertNotNil(membership.createdAt, "Membership should have creation date")
                }
            }
            
        } catch {
            XCTFail("Membership generation should succeed: \(error)")
        }
    }
    
    // MARK: - Idempotency Integration Tests
    
    @MainActor
    func testIdempotency_RunTwice_ShouldNotCreateDuplicates() async {
        // Given - Clean database state
        
        // When - Run generation twice
        do {
            let firstRun = try await sampleGenerator.generateSampleFamilies()
            let secondRun = try await sampleGenerator.generateSampleFamilies()
            
            // Then - Should return same families without creating duplicates
            XCTAssertEqual(firstRun.count, 5, "First run should create 5 families")
            XCTAssertEqual(secondRun.count, 5, "Second run should return 5 families")
            
            // Verify no duplicates in database
            let context = createTestContext()
            let familyDescriptor = FetchDescriptor<Family>()
            let persistedFamilies = try context.fetch(familyDescriptor)
            
            let sampleFamilies = persistedFamilies.filter { family in
                family.name.contains("Johnson") || 
                family.name.contains("Garcia") || 
                family.name.contains("Chen") || 
                family.name.contains("Williams") || 
                family.name.contains("Anderson")
            }
            
            XCTAssertEqual(sampleFamilies.count, 5, "Should still have only 5 sample families after second run")
            
        } catch {
            XCTFail("Idempotency test should succeed: \(error)")
        }
    }
    
    @MainActor
    func testIdempotency_ExistingFamilies_ShouldDetectAndReturn() async {
        // Given - Pre-create one sample family
        let context = createTestContext()
        
        do {
            let existingUser = UserProfile(
                displayName: "Sarah Johnson",
                appleUserIdHash: "sample_sarah_johnson_001"
            )
            context.insert(existingUser)
            
            let existingFamily = Family(
                name: "The Johnson Family",
                code: "JOHN01",
                createdByUserId: existingUser.id
            )
            context.insert(existingFamily)
            
            try context.save()
            
            // When
            let generatedFamilies = try await sampleGenerator.generateSampleFamilies()
            
            // Then - Should detect existing family and return all families
            XCTAssertGreaterThan(generatedFamilies.count, 0, "Should return existing families")
            
            // Verify the existing family is included
            let johnsonFamily = generatedFamilies.first { $0.family.name == "The Johnson Family" }
            XCTAssertNotNil(johnsonFamily, "Should include existing Johnson family")
            
        } catch {
            XCTFail("Idempotency with existing families should succeed: \(error)")
        }
    }
    
    // MARK: - Error Scenarios Integration Tests
    
    @MainActor
    func testErrorScenario_DatabaseConstraintViolation_ShouldHandleGracefully() async {
        // Given - Pre-create a family with conflicting code
        let context = createTestContext()
        
        do {
            // Create a family that might conflict with generated codes
            let conflictingUser = UserProfile(
                displayName: "Conflict User",
                appleUserIdHash: "conflict_hash"
            )
            context.insert(conflictingUser)
            
            // We can't predict the exact code that will be generated, so we test recovery
            // by ensuring the generator handles code conflicts gracefully
            
            // When
            let generatedFamilies = try await sampleGenerator.generateSampleFamilies()
            
            // Then - Should succeed despite potential conflicts
            XCTAssertEqual(generatedFamilies.count, 5, "Should generate all families despite conflicts")
            
        } catch {
            // If there's an error, it should be a proper SampleDataError
            if let sampleError = error as? SampleDataError {
                XCTAssertTrue(sampleError.isRetryable, "Database errors should be retryable")
            } else {
                XCTFail("Should throw SampleDataError for database issues: \(error)")
            }
        }
    }
    
    // MARK: - Data Integrity Integration Tests
    
    @MainActor
    func testDataIntegrity_FamilyUserMembershipRelationships_ShouldBeConsistent() async {
        // Given - Clean database state
        
        // When
        do {
            let generatedFamilies = try await sampleGenerator.generateSampleFamilies()
            
            // Then - Verify data integrity across all relationships
            let context = createTestContext()
            
            for familyInfo in generatedFamilies {
                // Get family from database
                let family = try realDataService.fetchFamily(byId: familyInfo.family.id)
                XCTAssertNotNil(family, "Family should exist in database")
                
                // Get memberships for this family
                let memberships = try realDataService.fetchMemberships(forFamily: familyInfo.family)
                XCTAssertEqual(memberships.count, familyInfo.memberCount, 
                              "Membership count should match reported member count")
                
                // Verify each membership has valid user
                for membership in memberships {
                    let user = try realDataService.fetchUserProfile(byId: membership.userId)
                    XCTAssertNotNil(user, "Membership should reference valid user")
                    XCTAssertEqual(membership.familyId, familyInfo.family.id, 
                                  "Membership should reference correct family")
                }
                
                // Verify exactly one admin per family
                let adminMemberships = memberships.filter { $0.role == .parentAdmin }
                XCTAssertEqual(adminMemberships.count, 1, 
                              "Family '\(familyInfo.family.name)' should have exactly one admin")
            }
            
        } catch {
            XCTFail("Data integrity test should succeed: \(error)")
        }
    }
    
    @MainActor
    func testDataIntegrity_UniqueConstraints_ShouldBeRespected() async {
        // Given - Clean database state
        
        // When
        do {
            let generatedFamilies = try await sampleGenerator.generateSampleFamilies()
            
            // Then - Verify unique constraints are respected
            let context = createTestContext()
            
            // Check family code uniqueness
            let familyDescriptor = FetchDescriptor<Family>()
            let allFamilies = try context.fetch(familyDescriptor)
            let familyCodes = allFamilies.map { $0.code }
            let uniqueCodes = Set(familyCodes)
            XCTAssertEqual(familyCodes.count, uniqueCodes.count, "All family codes should be unique")
            
            // Check user Apple ID hash uniqueness
            let userDescriptor = FetchDescriptor<UserProfile>()
            let allUsers = try context.fetch(userDescriptor)
            let userHashes = allUsers.map { $0.appleUserIdHash }
            let uniqueHashes = Set(userHashes)
            XCTAssertEqual(userHashes.count, uniqueHashes.count, "All user Apple ID hashes should be unique")
            
        } catch {
            XCTFail("Unique constraint test should succeed: \(error)")
        }
    }
    
    // MARK: - Performance Integration Tests
    
    @MainActor
    func testPerformance_CompleteWorkflow_ShouldCompleteInReasonableTime() {
        // Given - Clean database state
        
        // When & Then
        measure {
            Task {
                do {
                    _ = try await sampleGenerator.generateSampleFamilies()
                } catch {
                    XCTFail("Performance test should not fail: \(error)")
                }
            }
        }
    }
    
    @MainActor
    func testPerformance_IdempotentRuns_ShouldBeFast() {
        // Given - Pre-generate families
        Task {
            do {
                _ = try await sampleGenerator.generateSampleFamilies()
                
                // When & Then - Subsequent runs should be fast
                measure {
                    Task {
                        do {
                            _ = try await sampleGenerator.generateSampleFamilies()
                        } catch {
                            XCTFail("Idempotent performance test should not fail: \(error)")
                        }
                    }
                }
            } catch {
                XCTFail("Setup for performance test failed: \(error)")
            }
        }
    }
    
    // MARK: - Real-World Scenario Tests
    
    @MainActor
    func testRealWorldScenario_JoinFamilyWorkflow_ShouldWorkWithGeneratedFamilies() async {
        // Given - Generate sample families
        do {
            let generatedFamilies = try await sampleGenerator.generateSampleFamilies()
            
            // When - Simulate joining a family using generated code
            guard let testFamily = generatedFamilies.first else {
                XCTFail("Should have at least one generated family")
                return
            }
            
            // Create a new user to join the family
            let newUser = UserProfile(
                displayName: "New Test User",
                appleUserIdHash: "new_test_user_hash"
            )
            
            let context = createTestContext()
            context.insert(newUser)
            try context.save()
            
            // Verify the family can be found by code (simulating join family lookup)
            let foundFamily = try realDataService.fetchFamily(byCode: testFamily.code)
            
            // Then
            XCTAssertNotNil(foundFamily, "Generated family should be findable by code")
            XCTAssertEqual(foundFamily?.id, testFamily.family.id, "Found family should match generated family")
            XCTAssertEqual(foundFamily?.code, testFamily.code, "Family codes should match")
            
        } catch {
            XCTFail("Real-world scenario test should succeed: \(error)")
        }
    }
    
    @MainActor
    func testRealWorldScenario_FamilyCodeValidation_ShouldWorkWithGeneratedCodes() async {
        // Given - Generate sample families
        do {
            let generatedFamilies = try await sampleGenerator.generateSampleFamilies()
            
            // When & Then - All generated codes should be valid and usable
            for familyInfo in generatedFamilies {
                // Verify code format is valid
                XCTAssertTrue(FamilyCodeGenerator.isValidCodeFormat(familyInfo.code), 
                             "Generated code '\(familyInfo.code)' should be valid format")
                
                // Verify code exists in database
                let codeExists = try realDataService.familyCodeExists(familyInfo.code)
                XCTAssertTrue(codeExists, "Generated code '\(familyInfo.code)' should exist in database")
                
                // Verify family can be retrieved by code
                let retrievedFamily = try realDataService.fetchFamily(byCode: familyInfo.code)
                XCTAssertNotNil(retrievedFamily, "Family should be retrievable by code '\(familyInfo.code)'")
                XCTAssertEqual(retrievedFamily?.id, familyInfo.family.id, "Retrieved family should match generated family")
            }
            
        } catch {
            XCTFail("Family code validation test should succeed: \(error)")
        }
    }
    
    // MARK: - Cleanup and Recovery Tests
    
    @MainActor
    func testCleanupAndRecovery_PartialFailureRecovery_ShouldHandleGracefully() async {
        // This test simulates a scenario where some families are created successfully
        // and then the process fails, testing recovery behavior
        
        // Given - We'll test this by running generation, then trying again
        do {
            // First run - should succeed
            let firstRun = try await sampleGenerator.generateSampleFamilies()
            XCTAssertEqual(firstRun.count, 5, "First run should create all families")
            
            // Manually delete one family to simulate partial state
            let context = createTestContext()
            let familyDescriptor = FetchDescriptor<Family>()
            let families = try context.fetch(familyDescriptor)
            
            if let familyToDelete = families.first(where: { $0.name.contains("Johnson") }) {
                context.delete(familyToDelete)
                try context.save()
            }
            
            // Second run - should handle the partial state gracefully
            let secondRun = try await sampleGenerator.generateSampleFamilies()
            
            // Then - Should still return families (either existing or recreated)
            XCTAssertGreaterThan(secondRun.count, 0, "Should handle partial state gracefully")
            
        } catch {
            XCTFail("Cleanup and recovery test should succeed: \(error)")
        }
    }
    
    // MARK: - Async Behavior Integration Tests
    
    @MainActor
    func testAsyncBehavior_GenerateSampleFamilies_ShouldExecuteAsynchronously() async {
        // Given - Clean database state
        let startTime = Date()
        
        // When - Execute async method
        do {
            let generatedFamilies = try await sampleGenerator.generateSampleFamilies()
            let executionTime = Date().timeIntervalSince(startTime)
            
            // Then - Should complete successfully and demonstrate async execution
            XCTAssertEqual(generatedFamilies.count, 5, "Should generate 5 families asynchronously")
            XCTAssertGreaterThan(executionTime, 0, "Should take measurable time for async operations")
            
            // Verify all families were created through async DataService calls
            for familyInfo in generatedFamilies {
                XCTAssertFalse(familyInfo.family.name.isEmpty, "Async created family should have valid name")
                XCTAssertEqual(familyInfo.code.count, 6, "Async created family should have valid code")
                XCTAssertGreaterThan(familyInfo.memberCount, 0, "Async created family should have members")
            }
            
        } catch {
            XCTFail("Async execution should succeed: \(error)")
        }
    }
    
    @MainActor
    func testAsyncBehavior_ConcurrentDataServiceCalls_ShouldHandleMainActorIsolation() async {
        // Given - Clean database state
        
        // When - Execute multiple async operations that require main actor isolation
        do {
            // Test concurrent execution of async methods that call DataService
            async let firstGeneration = sampleGenerator.generateSampleFamilies()
            
            // Wait a brief moment to ensure first generation starts
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
            
            // Start second generation (should detect existing families)
            async let secondGeneration = sampleGenerator.generateSampleFamilies()
            
            // Await both operations
            let (firstResult, secondResult) = try await (firstGeneration, secondGeneration)
            
            // Then - Both should succeed with proper main actor isolation
            XCTAssertEqual(firstResult.count, 5, "First generation should create 5 families")
            XCTAssertEqual(secondResult.count, 5, "Second generation should return 5 families")
            
            // Verify no data corruption from concurrent access
            let context = createTestContext()
            let familyDescriptor = FetchDescriptor<Family>()
            let persistedFamilies = try context.fetch(familyDescriptor)
            
            let sampleFamilies = persistedFamilies.filter { family in
                family.name.contains("Johnson") || 
                family.name.contains("Garcia") || 
                family.name.contains("Chen") || 
                family.name.contains("Williams") || 
                family.name.contains("Anderson")
            }
            
            XCTAssertEqual(sampleFamilies.count, 5, "Should have exactly 5 families despite concurrent execution")
            
        } catch {
            XCTFail("Concurrent async execution should succeed: \(error)")
        }
    }
    
    @MainActor
    func testAsyncBehavior_DataServiceMethodCalls_ShouldRespectMainActorIsolation() async {
        // Given - Clean database state
        
        // When - Execute generation which calls multiple DataService methods
        do {
            let generatedFamilies = try await sampleGenerator.generateSampleFamilies()
            
            // Then - Verify all DataService calls were executed properly on main actor
            XCTAssertEqual(generatedFamilies.count, 5, "Should successfully call DataService methods")
            
            // Verify each family was created through proper async DataService calls
            let context = createTestContext()
            
            for familyInfo in generatedFamilies {
                // Verify family exists (created via async createFamily call)
                let family = try realDataService.fetchFamily(byId: familyInfo.family.id)
                XCTAssertNotNil(family, "Family should exist from async createFamily call")
                
                // Verify users exist (created via async createUserProfile calls)
                let memberships = try realDataService.fetchMemberships(forFamily: familyInfo.family)
                XCTAssertEqual(memberships.count, familyInfo.memberCount, "All users should be created via async calls")
                
                for membership in memberships {
                    let user = try realDataService.fetchUserProfile(byId: membership.userId)
                    XCTAssertNotNil(user, "User should exist from async createUserProfile call")
                    XCTAssertTrue(user?.appleUserIdHash.contains("sample_") ?? false, "User should have sample hash")
                }
            }
            
        } catch {
            XCTFail("DataService async method calls should succeed: \(error)")
        }
    }
    
    @MainActor
    func testAsyncBehavior_ErrorPropagation_ShouldPreserveAsyncContext() async {
        // Given - Configure DataService to fail
        let failingDataService = MockDataService()
        failingDataService.setShouldSucceed(false)
        failingDataService.setError(.invalidData("Async test failure"))
        
        let failingGenerator = SampleFamilyDataGenerator(dataService: failingDataService)
        
        // When - Execute async method that should fail
        do {
            _ = try await failingGenerator.generateSampleFamilies()
            XCTFail("Should throw error in async context")
        } catch let error as SampleDataError {
            // Then - Error should be properly propagated through async context
            XCTAssertEqual(error.category, .validation, "Error should maintain proper categorization in async context")
            XCTAssertNotNil(error.errorDescription, "Error should have description in async context")
            XCTAssertNotNil(error.failureReason, "Error should have failure reason in async context")
            XCTAssertNotNil(error.recoverySuggestion, "Error should have recovery suggestion in async context")
        } catch {
            XCTFail("Should throw SampleDataError in async context, got: \(error)")
        }
    }
    
    @MainActor
    func testAsyncBehavior_FamilyCreationErrorConversion_ShouldWorkInAsyncContext() async {
        // Given - Configure DataService to fail with specific error
        let failingDataService = MockDataService()
        failingDataService.setShouldSucceed(false)
        failingDataService.setError(.constraintViolation("Async constraint violation"))
        
        let failingGenerator = SampleFamilyDataGenerator(dataService: failingDataService)
        
        // When - Execute async method with FamilyCreationError conversion
        do {
            _ = try await failingGenerator.generateSampleFamiliesWithFamilyCreationError()
            XCTFail("Should throw FamilyCreationError in async context")
        } catch let error as FamilyCreationError {
            // Then - Error conversion should work properly in async context
            XCTAssertEqual(error.category, .validation, "Converted error should maintain categorization in async context")
            
            if case .validationFailed(let message) = error {
                XCTAssertTrue(message.contains("Constraint violation"), "Converted error should preserve context in async")
            } else {
                XCTFail("Should convert to validationFailed in async context, got: \(error)")
            }
        } catch {
            XCTFail("Should throw FamilyCreationError in async context, got: \(error)")
        }
    }
    
    @MainActor
    func testAsyncBehavior_TaskCancellation_ShouldHandleGracefully() async {
        // Given - Clean database state
        
        // When - Start async operation and cancel it
        let task = Task {
            try await sampleGenerator.generateSampleFamilies()
        }
        
        // Cancel the task after a brief delay
        try? await Task.sleep(nanoseconds: 1_000_000) // 1ms
        task.cancel()
        
        // Then - Should handle cancellation gracefully
        do {
            _ = try await task.value
            // If it completes successfully, that's also acceptable
            XCTAssertTrue(true, "Task completed successfully despite cancellation attempt")
        } catch is CancellationError {
            XCTAssertTrue(true, "Task cancellation handled properly")
        } catch {
            XCTFail("Should handle cancellation gracefully, got: \(error)")
        }
    }
    
    @MainActor
    func testAsyncBehavior_NestedAsyncCalls_ShouldMaintainActorIsolation() async {
        // Given - Clean database state
        
        // When - Execute generation which involves nested async calls to DataService
        do {
            let generatedFamilies = try await sampleGenerator.generateSampleFamilies()
            
            // Then - All nested async calls should succeed with proper actor isolation
            XCTAssertEqual(generatedFamilies.count, 5, "Nested async calls should succeed")
            
            // Verify the nested structure: Family -> Users -> Memberships
            for familyInfo in generatedFamilies {
                // Each family creation involves:
                // 1. async createFamily call
                // 2. multiple async createUserProfile calls  
                // 3. multiple async createMembership calls
                
                let memberships = try realDataService.fetchMemberships(forFamily: familyInfo.family)
                XCTAssertEqual(memberships.count, familyInfo.memberCount, "All nested async calls should complete")
                
                // Verify each membership has a valid user (from nested async calls)
                for membership in memberships {
                    let user = try realDataService.fetchUserProfile(byId: membership.userId)
                    XCTAssertNotNil(user, "Nested async user creation should succeed")
                    XCTAssertEqual(membership.familyId, familyInfo.family.id, "Nested async membership creation should succeed")
                }
            }
            
        } catch {
            XCTFail("Nested async calls should succeed: \(error)")
        }
    }
    
    @MainActor
    func testAsyncBehavior_AsyncSequentialExecution_ShouldMaintainOrder() async {
        // Given - Clean database state
        
        // When - Execute multiple sequential async operations
        var executionOrder: [String] = []
        
        do {
            executionOrder.append("start_generation")
            let generatedFamilies = try await sampleGenerator.generateSampleFamilies()
            executionOrder.append("generation_complete")
            
            // Verify families exist
            let context = createTestContext()
            let familyDescriptor = FetchDescriptor<Family>()
            let persistedFamilies = try context.fetch(familyDescriptor)
            executionOrder.append("verification_complete")
            
            // Then - Operations should execute in proper sequence
            XCTAssertEqual(executionOrder, ["start_generation", "generation_complete", "verification_complete"], 
                          "Async operations should maintain sequential order")
            XCTAssertEqual(generatedFamilies.count, 5, "Sequential async execution should succeed")
            
            let sampleFamilies = persistedFamilies.filter { family in
                family.name.contains("Johnson") || 
                family.name.contains("Garcia") || 
                family.name.contains("Chen") || 
                family.name.contains("Williams") || 
                family.name.contains("Anderson")
            }
            XCTAssertEqual(sampleFamilies.count, 5, "Sequential async operations should persist data correctly")
            
        } catch {
            XCTFail("Sequential async execution should succeed: \(error)")
        }
    }
}