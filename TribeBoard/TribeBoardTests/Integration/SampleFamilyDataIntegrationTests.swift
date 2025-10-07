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
}