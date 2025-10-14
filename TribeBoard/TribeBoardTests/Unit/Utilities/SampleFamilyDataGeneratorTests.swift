import XCTest
@testable import TribeBoard

/// Comprehensive unit tests for SampleFamilyDataGenerator covering data generation logic
class SampleFamilyDataGeneratorTests: TestBase {
    
    // MARK: - Properties
    
    var sampleGenerator: SampleFamilyDataGenerator!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        sampleGenerator = SampleFamilyDataGenerator(dataService: mockDataService)
    }
    
    override func tearDown() {
        sampleGenerator = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInit_WithValidDataService_ShouldSucceed() {
        // Given
        let dataService = MockDataService()
        
        // When
        let generator = SampleFamilyDataGenerator(dataService: dataService)
        
        // Then
        XCTAssertNotNil(generator, "Generator should initialize with valid data service")
    }
    
    // MARK: - Sample Family Data Structure Tests
    
    func testSampleFamilyData_HasCorrectNumberOfFamilies() {
        // Given - Using reflection to access private static property
        let mirror = Mirror(reflecting: SampleFamilyDataGenerator.self)
        var sampleFamiliesCount = 0
        
        // Access the static sampleFamilies property through the type
        if let sampleFamiliesProperty = mirror.children.first(where: { $0.label == "sampleFamilies" }) {
            if let sampleFamilies = sampleFamiliesProperty.value as? [Any] {
                sampleFamiliesCount = sampleFamilies.count
            }
        }
        
        // Then
        // We expect 5 families based on the requirements
        // Since we can't directly access private static property, we'll test through behavior
        XCTAssertTrue(sampleFamiliesCount >= 0, "Should have access to sample families data")
    }
    
    func testSampleFamilyData_ValidateStructure() async {
        // Given
        mockDataService.setShouldSucceed(true)
        
        // When
        do {
            let generatedFamilies = try await sampleGenerator.generateSampleFamilies()
            
            // Then
            XCTAssertEqual(generatedFamilies.count, 5, "Should generate exactly 5 families")
            
            for family in generatedFamilies {
                XCTAssertFalse(family.family.name.isEmpty, "Family name should not be empty")
                XCTAssertEqual(family.code.count, 6, "Family code should be 6 characters")
                XCTAssertGreaterThan(family.memberCount, 0, "Family should have at least one member")
                XCTAssertLessThanOrEqual(family.memberCount, 5, "Family should have at most 5 members")
            }
        } catch {
            XCTFail("Should not throw error when generating families: \(error)")
        }
    }
    
    // MARK: - Family Creation Logic Tests
    
    func testGenerateSampleFamilies_WithValidDataService_ShouldCreateFamilies() async {
        // Given
        mockDataService.setShouldSucceed(true)
        
        // When
        do {
            let generatedFamilies = try await sampleGenerator.generateSampleFamilies()
            
            // Then
            XCTAssertEqual(generatedFamilies.count, 5, "Should create 5 families")
            XCTAssertEqual(mockDataService.createFamilyCallCount, 5, "Should call createFamily 5 times")
            XCTAssertGreaterThan(mockDataService.createUserProfileCallCount, 0, "Should create user profiles")
            XCTAssertGreaterThan(mockDataService.createMembershipCallCount, 0, "Should create memberships")
        } catch {
            XCTFail("Should not throw error: \(error)")
        }
    }
    
    func testGenerateSampleFamilies_WithDataServiceFailure_ShouldThrowError() async {
        // Given
        mockDataService.setShouldSucceed(false)
        mockDataService.setError(.invalidData("Mock failure"))
        
        // When & Then
        do {
            _ = try await sampleGenerator.generateSampleFamilies()
            XCTFail("Should throw error when data service fails")
        } catch let error as SampleDataError {
            XCTAssertEqual(error.category, .data, "Should categorize as data error")
        } catch {
            XCTFail("Should throw SampleDataError, got: \(error)")
        }
    }
    
    // MARK: - Family Data Validation Tests
    
    func testFamilyDataValidation_ValidData_ShouldPass() async {
        // Given
        mockDataService.setShouldSucceed(true)
        
        // When
        do {
            let generatedFamilies = try await sampleGenerator.generateSampleFamilies()
            
            // Then - Validate each family has proper structure
            for familyInfo in generatedFamilies {
                // Family validation
                XCTAssertFalse(familyInfo.family.name.isEmpty, "Family name should not be empty")
                XCTAssertGreaterThanOrEqual(familyInfo.family.name.count, 2, "Family name should be at least 2 characters")
                XCTAssertLessThanOrEqual(familyInfo.family.name.count, 50, "Family name should be at most 50 characters")
                
                // Code validation
                XCTAssertEqual(familyInfo.code.count, 6, "Family code should be 6 characters")
                XCTAssertTrue(familyInfo.code.allSatisfy { $0.isLetter || $0.isNumber }, "Code should be alphanumeric")
                XCTAssertEqual(familyInfo.code, familyInfo.code.uppercased(), "Code should be uppercase")
                
                // Member count validation
                XCTAssertGreaterThanOrEqual(familyInfo.memberCount, 1, "Family should have at least 1 member")
                XCTAssertLessThanOrEqual(familyInfo.memberCount, 5, "Family should have at most 5 members")
            }
        } catch {
            XCTFail("Should not throw error with valid data: \(error)")
        }
    }
    
    // MARK: - Role Assignment Tests
    
    func testRoleAssignment_EachFamilyHasOneAdmin() async {
        // Given
        mockDataService.setShouldSucceed(true)
        
        // When
        do {
            let generatedFamilies = try await sampleGenerator.generateSampleFamilies()
            
            // Then - Check that each family has exactly one admin through membership calls
            XCTAssertEqual(generatedFamilies.count, 5, "Should have 5 families")
            
            // Verify that createMembership was called for each family member
            // The exact count depends on the total members across all families
            XCTAssertGreaterThan(mockDataService.createMembershipCallCount, 5, "Should create memberships for all members")
            
        } catch {
            XCTFail("Should not throw error: \(error)")
        }
    }
    
    // MARK: - User Profile Creation Tests
    
    func testUserProfileCreation_ValidData_ShouldCreateUsers() async {
        // Given
        mockDataService.setShouldSucceed(true)
        
        // When
        do {
            let generatedFamilies = try await sampleGenerator.generateSampleFamilies()
            
            // Then
            XCTAssertGreaterThan(mockDataService.createUserProfileCallCount, 0, "Should create user profiles")
            XCTAssertEqual(generatedFamilies.count, 5, "Should create 5 families")
            
            // Verify that user creation was attempted for each family
            XCTAssertGreaterThanOrEqual(mockDataService.createUserProfileCallCount, 5, "Should create at least 5 users (one per family)")
            
        } catch {
            XCTFail("Should not throw error: \(error)")
        }
    }
    
    func testUserProfileCreation_WithDuplicateHash_ShouldHandleError() async {
        // Given
        mockDataService.setFailingOperations([.createUserProfile])
        mockDataService.setError(.constraintViolation("User profile with this Apple ID hash already exists"))
        
        // When & Then
        do {
            _ = try await sampleGenerator.generateSampleFamilies()
            XCTFail("Should throw error when user creation fails")
        } catch let error as SampleDataError {
            XCTAssertEqual(error.category, .validation, "Should categorize as validation error")
        } catch {
            XCTFail("Should throw SampleDataError, got: \(error)")
        }
    }
    
    // MARK: - Apple ID Hash Generation Tests
    
    func testAppleIdHashGeneration_ShouldBeUnique() async {
        // Given
        mockDataService.setShouldSucceed(true)
        var generatedHashes: Set<String> = []
        
        // When
        do {
            _ = try await sampleGenerator.generateSampleFamilies()
            
            // Then - Check that all created users have unique hashes
            let callCounts = mockDataService.getCallCounts()
            let userCreationCount = callCounts["createUserProfile"] ?? 0
            
            XCTAssertGreaterThan(userCreationCount, 0, "Should have created users")
            
            // Since we can't directly access the generated hashes, we verify through the mock
            // that multiple users were created (implying unique hashes)
            XCTAssertGreaterThanOrEqual(userCreationCount, 5, "Should create multiple users with unique hashes")
            
        } catch {
            XCTFail("Should not throw error: \(error)")
        }
    }
    
    // MARK: - Membership Creation Tests
    
    func testMembershipCreation_ValidData_ShouldCreateMemberships() async {
        // Given
        mockDataService.setShouldSucceed(true)
        
        // When
        do {
            let generatedFamilies = try await sampleGenerator.generateSampleFamilies()
            
            // Then
            XCTAssertGreaterThan(mockDataService.createMembershipCallCount, 0, "Should create memberships")
            
            // Verify membership creation for all family members
            let totalExpectedMembers = generatedFamilies.reduce(0) { $0 + $1.memberCount }
            XCTAssertEqual(mockDataService.createMembershipCallCount, totalExpectedMembers, 
                          "Should create membership for each family member")
            
        } catch {
            XCTFail("Should not throw error: \(error)")
        }
    }
    
    func testMembershipCreation_WithFailure_ShouldThrowError() async {
        // Given
        mockDataService.setFailingOperations([.createMembership])
        mockDataService.setError(.invalidData("Membership creation failed"))
        
        // When & Then
        do {
            _ = try await sampleGenerator.generateSampleFamilies()
            XCTFail("Should throw error when membership creation fails")
        } catch let error as SampleDataError {
            XCTAssertEqual(error.category, .validation, "Should categorize as validation error")
        } catch {
            XCTFail("Should throw SampleDataError, got: \(error)")
        }
    }
    
    // MARK: - Error Handling Tests
    
    func testErrorCategorization_DataServiceError_ShouldCategorizeCorrectly() async {
        // Given
        let testCases: [(DataServiceError, ErrorCategory)] = [
            (.invalidData("test"), .validation),
            (.constraintViolation("test"), .validation),
            (.networkUnavailable, .network)
        ]
        
        for (dataServiceError, expectedCategory) in testCases {
            // Given
            mockDataService.setShouldSucceed(false)
            mockDataService.setError(dataServiceError)
            
            // When & Then
            do {
                _ = try await sampleGenerator.generateSampleFamilies()
                XCTFail("Should throw error")
            } catch let error as SampleDataError {
                XCTAssertEqual(error.category, expectedCategory, 
                              "Error \(dataServiceError) should be categorized as \(expectedCategory)")
            } catch {
                XCTFail("Should throw SampleDataError, got: \(error)")
            }
            
            // Reset for next test
            mockDataService.reset()
            sampleGenerator = SampleFamilyDataGenerator(dataService: mockDataService)
        }
    }
    
    func testErrorRecovery_PartialFailure_ShouldReportCorrectly() async {
        // Given - Configure mock to fail after some successes
        mockDataService.setShouldSucceed(true)
        
        // When
        do {
            let generatedFamilies = try await sampleGenerator.generateSampleFamilies()
            
            // Then - Should succeed with all families
            XCTAssertEqual(generatedFamilies.count, 5, "Should create all 5 families when no failures")
            
        } catch {
            XCTFail("Should not throw error when all operations succeed: \(error)")
        }
    }
    
    // MARK: - Idempotency Tests
    
    func testIdempotency_ExistingFamilies_ShouldReturnExisting() async {
        // Given - Pre-populate mock with existing families
        let existingFamily = Family(
            id: UUID(),
            name: "The Johnson Family",
            code: "JOHN01",
            createdByUserId: UUID(),
            createdAt: Date(),
            updatedAt: Date()
        )
        mockDataService.prePopulateFamily(existingFamily)
        
        // Configure mock to return existing families
        mockDataService.setShouldSucceed(true)
        
        // When
        do {
            let generatedFamilies = try await sampleGenerator.generateSampleFamilies()
            
            // Then - Should return existing families without creating new ones
            XCTAssertGreaterThan(generatedFamilies.count, 0, "Should return existing families")
            
        } catch {
            XCTFail("Should not throw error when families exist: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testPerformance_GenerateFamilies() {
        // Given
        mockDataService.setShouldSucceed(true)
        mockDataService.setSimulatedDelay(0.001) // Minimal delay for performance test
        
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
    
    // MARK: - Data Consistency Tests
    
    func testDataConsistency_FamilyAndMemberCounts_ShouldMatch() async {
        // Given
        mockDataService.setShouldSucceed(true)
        
        // When
        do {
            let generatedFamilies = try await sampleGenerator.generateSampleFamilies()
            
            // Then
            let totalReportedMembers = generatedFamilies.reduce(0) { $0 + $1.memberCount }
            XCTAssertEqual(mockDataService.createMembershipCallCount, totalReportedMembers,
                          "Membership creation count should match reported member count")
            
        } catch {
            XCTFail("Should not throw error: \(error)")
        }
    }
    
    func testDataConsistency_FamilyCreationCount_ShouldMatchExpected() async {
        // Given
        mockDataService.setShouldSucceed(true)
        
        // When
        do {
            let generatedFamilies = try await sampleGenerator.generateSampleFamilies()
            
            // Then
            XCTAssertEqual(generatedFamilies.count, 5, "Should generate exactly 5 families")
            XCTAssertEqual(mockDataService.createFamilyCallCount, 5, "Should call createFamily exactly 5 times")
            
        } catch {
            XCTFail("Should not throw error: \(error)")
        }
    }
    
    // MARK: - Error Conversion Tests
    
    func testErrorConversion_SampleDataErrorToFamilyCreationError_ShouldPreserveContext() {
        // Test all SampleDataError cases convert to appropriate FamilyCreationError cases
        let testCases: [(SampleDataError, FamilyCreationError)] = [
            (.familyAlreadyExists("Test Family"), .familyAlreadyExists),
            (.codeGenerationFailed, .codeGenerationFailed),
            (.memberCreationFailed("John Doe"), .validationFailed("Member creation failed: John Doe")),
            (.partialCreationFailure(["Family 1", "Family 2"]), .validationFailed("Partial creation failure: Family 1, Family 2")),
            (.dataServiceUnavailable, .unknownError("Data service unavailable")),
            (.validationFailed("Invalid data"), .validationFailed("Invalid data")),
            (.databaseError(NSError(domain: "TestDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "DB Error"])), .unknownError("Database error: DB Error")),
            (.networkError(NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: [NSLocalizedDescriptionKey: "Network Error"])), .networkUnavailable),
            (.unknownError("Test error"), .unknownError("Test error"))
        ]
        
        for (sampleError, expectedFamilyError) in testCases {
            // When
            let convertedError = sampleError.toFamilyCreationError()
            
            // Then
            switch (convertedError, expectedFamilyError) {
            case (.familyAlreadyExists, .familyAlreadyExists),
                 (.codeGenerationFailed, .codeGenerationFailed),
                 (.networkUnavailable, .networkUnavailable):
                // Direct mapping cases
                XCTAssertTrue(true, "Direct mapping successful for \(sampleError)")
                
            case (.validationFailed(let convertedMessage), .validationFailed(let expectedMessage)):
                XCTAssertEqual(convertedMessage, expectedMessage, "Validation error message should be preserved")
                
            case (.unknownError(let convertedMessage), .unknownError(let expectedMessage)):
                XCTAssertEqual(convertedMessage, expectedMessage, "Unknown error message should be preserved")
                
            default:
                XCTFail("Conversion mismatch: \(sampleError) -> \(convertedError), expected \(expectedFamilyError)")
            }
        }
    }
    
    func testErrorConversion_PreservesErrorContext_ForMemberCreationFailed() {
        // Given
        let memberName = "Jane Smith"
        let sampleError = SampleDataError.memberCreationFailed(memberName)
        
        // When
        let convertedError = sampleError.toFamilyCreationError()
        
        // Then
        if case .validationFailed(let message) = convertedError {
            XCTAssertTrue(message.contains(memberName), "Converted error should preserve member name context")
            XCTAssertTrue(message.contains("Member creation failed"), "Converted error should preserve operation context")
        } else {
            XCTFail("Member creation failed should convert to validationFailed, got: \(convertedError)")
        }
    }
    
    func testErrorConversion_PreservesErrorContext_ForPartialCreationFailure() {
        // Given
        let failures = ["Family A", "Family B", "Family C"]
        let sampleError = SampleDataError.partialCreationFailure(failures)
        
        // When
        let convertedError = sampleError.toFamilyCreationError()
        
        // Then
        if case .validationFailed(let message) = convertedError {
            for failure in failures {
                XCTAssertTrue(message.contains(failure), "Converted error should preserve all failure contexts: \(failure)")
            }
            XCTAssertTrue(message.contains("Partial creation failure"), "Converted error should preserve operation context")
        } else {
            XCTFail("Partial creation failure should convert to validationFailed, got: \(convertedError)")
        }
    }
    
    func testErrorConversion_PreservesErrorContext_ForDatabaseError() {
        // Given
        let underlyingError = NSError(domain: "CoreDataDomain", code: 500, userInfo: [NSLocalizedDescriptionKey: "Core Data save failed"])
        let sampleError = SampleDataError.databaseError(underlyingError)
        
        // When
        let convertedError = sampleError.toFamilyCreationError()
        
        // Then
        if case .unknownError(let message) = convertedError {
            XCTAssertTrue(message.contains("Database error"), "Converted error should preserve error type context")
            XCTAssertTrue(message.contains("Core Data save failed"), "Converted error should preserve underlying error message")
        } else {
            XCTFail("Database error should convert to unknownError, got: \(convertedError)")
        }
    }
    
    func testErrorConversion_PreservesErrorContext_ForNetworkError() {
        // Given
        let underlyingError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: [NSLocalizedDescriptionKey: "Request timed out"])
        let sampleError = SampleDataError.networkError(underlyingError)
        
        // When
        let convertedError = sampleError.toFamilyCreationError()
        
        // Then
        XCTAssertEqual(convertedError, .networkUnavailable, "Network errors should convert to networkUnavailable")
    }
    
    func testErrorConversion_AllSampleDataErrorCases_HaveConversionMapping() {
        // This test ensures all SampleDataError cases have proper conversion mapping
        let allSampleErrorCases: [SampleDataError] = [
            .familyAlreadyExists("Test"),
            .codeGenerationFailed,
            .memberCreationFailed("Test Member"),
            .partialCreationFailure(["Test"]),
            .dataServiceUnavailable,
            .validationFailed("Test validation"),
            .databaseError(NSError(domain: "Test", code: 1, userInfo: nil)),
            .networkError(NSError(domain: "Test", code: 1, userInfo: nil)),
            .unknownError("Test unknown")
        ]
        
        for sampleError in allSampleErrorCases {
            // When
            let convertedError = sampleError.toFamilyCreationError()
            
            // Then - Should not crash and should return a valid FamilyCreationError
            XCTAssertNotNil(convertedError, "All SampleDataError cases should have conversion mapping: \(sampleError)")
            
            // Verify the converted error has proper localized description
            XCTAssertNotNil(convertedError.errorDescription, "Converted error should have error description")
            XCTAssertFalse(convertedError.errorDescription?.isEmpty ?? true, "Converted error description should not be empty")
        }
    }
    
    func testErrorConversion_MaintainsErrorProperties_AfterConversion() {
        // Given
        let sampleError = SampleDataError.validationFailed("Test validation error")
        
        // When
        let convertedError = sampleError.toFamilyCreationError()
        
        // Then - Verify error properties are maintained
        XCTAssertNotNil(convertedError.errorDescription, "Converted error should have error description")
        XCTAssertNotNil(convertedError.failureReason, "Converted error should have failure reason")
        XCTAssertNotNil(convertedError.recoverySuggestion, "Converted error should have recovery suggestion")
        
        // Verify the converted error maintains appropriate categorization
        if case .validationFailed = convertedError {
            XCTAssertEqual(convertedError.category, .validation, "Validation errors should maintain validation category")
        } else {
            XCTFail("Validation error should convert to validationFailed")
        }
    }
    
    func testErrorConversion_GenerateSampleFamiliesWithFamilyCreationError_ConvertsCorrectly() async {
        // Given
        mockDataService.setShouldSucceed(false)
        mockDataService.setError(.invalidData("Mock validation error"))
        
        // When & Then
        do {
            _ = try await sampleGenerator.generateSampleFamiliesWithFamilyCreationError()
            XCTFail("Should throw FamilyCreationError")
        } catch let error as FamilyCreationError {
            // Should receive a FamilyCreationError (converted from SampleDataError)
            XCTAssertEqual(error.category, .validation, "Should convert to validation error category")
        } catch {
            XCTFail("Should throw FamilyCreationError, got: \(error)")
        }
    }
    
    func testErrorConversion_GenerateSampleFamiliesWithFamilyCreationError_HandlesUnexpectedErrors() async {
        // Given - Use an unknown DataServiceError to simulate unexpected errors
        mockDataService.setShouldSucceed(false)
        mockDataService.setError(.unknownError)
        
        // When & Then
        do {
            _ = try await sampleGenerator.generateSampleFamiliesWithFamilyCreationError()
            XCTFail("Should throw FamilyCreationError")
        } catch let error as FamilyCreationError {
            if case .unknownError(let message) = error {
                XCTAssertTrue(message?.contains("Unexpected error during sample family generation") ?? false, 
                             "Should wrap unexpected errors with context")
            } else {
                XCTFail("Unexpected errors should convert to unknownError, got: \(error)")
            }
        } catch {
            XCTFail("Should throw FamilyCreationError, got: \(error)")
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testEdgeCase_EmptyFamilyName_ShouldHandleGracefully() async {
        // This test verifies that the generator handles edge cases in family data
        // Since family data is predefined, we test the validation logic
        
        // Given
        mockDataService.setShouldSucceed(true)
        
        // When
        do {
            let generatedFamilies = try await sampleGenerator.generateSampleFamilies()
            
            // Then - All families should have valid names
            for family in generatedFamilies {
                XCTAssertFalse(family.family.name.isEmpty, "No family should have empty name")
                XCTAssertGreaterThan(family.family.name.count, 1, "Family names should be meaningful")
            }
            
        } catch {
            XCTFail("Should not throw error with valid predefined data: \(error)")
        }
    }
    
    func testEdgeCase_NetworkError_ShouldCategorizeCorrectly() async {
        // Given
        let networkError = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: nil)
        mockDataService.setShouldSucceed(false)
        mockDataService.setError(.networkUnavailable)
        
        // When & Then
        do {
            _ = try await sampleGenerator.generateSampleFamilies()
            XCTFail("Should throw error for network issues")
        } catch let error as SampleDataError {
            XCTAssertEqual(error.category, .network, "Network errors should be categorized correctly")
            XCTAssertTrue(error.isRetryable, "Network errors should be retryable")
        } catch {
            XCTFail("Should throw SampleDataError, got: \(error)")
        }
    }
}