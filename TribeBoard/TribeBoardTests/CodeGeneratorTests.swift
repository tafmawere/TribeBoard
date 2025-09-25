import XCTest
@testable import TribeBoard

final class CodeGeneratorTests: XCTestCase {
    
    var codeGenerator: CodeGenerator!
    var customConfigGenerator: CodeGenerator!
    
    override func setUp() {
        super.setUp()
        codeGenerator = CodeGenerator()
        
        // Create generator with custom config for testing
        let testConfig = CodeGenerationConfig(
            maxRetries: 5,
            baseDelay: 0.01, // Very short delay for tests
            maxDelay: 0.1,
            backoffMultiplier: 1.5,
            enableLocalFallback: true,
            enableRemoteFallback: true
        )
        customConfigGenerator = CodeGenerator(config: testConfig)
    }
    
    override func tearDown() {
        codeGenerator = nil
        customConfigGenerator = nil
        super.tearDown()
    }
    
    // MARK: - Random Code Generation Tests
    
    @MainActor func testGenerateRandomCode_DefaultLength() {
        let code = codeGenerator.generateRandomCode()
        
        XCTAssertEqual(code.count, 6, "Default code length should be 6")
        XCTAssertTrue(codeGenerator.isValidCodeFormat(code), "Generated code should be valid format")
    }
    
    @MainActor func testGenerateRandomCode_CustomLength() {
        let customGenerator = CodeGenerator(codeLength: 8)
        let code = customGenerator.generateRandomCode()
        
        XCTAssertEqual(code.count, 8, "Custom code length should be 8")
        XCTAssertTrue(customGenerator.isValidCodeFormat(code), "Generated code should be valid format")
    }
    
    @MainActor func testGenerateRandomCode_OnlyAllowedCharacters() {
        let code = codeGenerator.generateRandomCode()
        let allowedCharacters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        
        for character in code {
            XCTAssertTrue(allowedCharacters.contains(character), "Code should only contain allowed characters")
        }
    }
    
    @MainActor func testGenerateRandomCode_Uniqueness() {
        let codes = Set((0..<100).map { _ in codeGenerator.generateRandomCode() })
        
        // With 36^6 possible combinations, 100 codes should be unique
        XCTAssertEqual(codes.count, 100, "Generated codes should be unique")
    }
    
    // MARK: - Code Format Validation Tests
    
    @MainActor func testIsValidCodeFormat_ValidCodes() {
        let validCodes = ["ABC123", "HELLO1", "TEST123", "FAMILY01"]
        
        for code in validCodes {
            XCTAssertTrue(codeGenerator.isValidCodeFormat(code), "Code '\(code)' should be valid")
        }
    }
    
    @MainActor func testIsValidCodeFormat_InvalidLength() {
        let shortCode = "ABC12"  // 5 characters
        let longCode = "ABCDEFGHI"  // 9 characters
        
        XCTAssertFalse(codeGenerator.isValidCodeFormat(shortCode), "Short code should be invalid")
        XCTAssertFalse(codeGenerator.isValidCodeFormat(longCode), "Long code should be invalid")
    }
    
    @MainActor func testIsValidCodeFormat_InvalidCharacters() {
        let invalidCodes = ["ABC-123", "HELLO!", "test@123", "FAMILY 1"]
        
        for code in invalidCodes {
            XCTAssertFalse(codeGenerator.isValidCodeFormat(code), "Code '\(code)' should be invalid")
        }
    }
    
    @MainActor func testIsValidCodeFormat_LowercaseHandling() {
        let lowercaseCode = "abc123"
        
        XCTAssertTrue(codeGenerator.isValidCodeFormat(lowercaseCode), "Lowercase code should be valid (handled internally)")
    }
    
    // MARK: - Unique Code Generation Tests
    
    func testGenerateUniqueCode_Success() async throws {
        let expectation = XCTestExpectation(description: "Generate unique code")
        
        let uniqueCode = try await codeGenerator.generateUniqueCode { code in
            // Simulate all codes are unique
            return true
        }
        
        XCTAssertEqual(uniqueCode.count, 6, "Generated unique code should have correct length")
        XCTAssertTrue(codeGenerator.isValidCodeFormat(uniqueCode), "Generated unique code should be valid format")
        expectation.fulfill()
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testGenerateUniqueCode_CollisionDetection() async throws {
        let expectation = XCTestExpectation(description: "Handle collision detection")
        var attemptCount = 0
        
        let uniqueCode = try await codeGenerator.generateUniqueCode { code in
            attemptCount += 1
            // First 3 attempts return false (collision), 4th returns true
            return attemptCount > 3
        }
        
        XCTAssertEqual(attemptCount, 4, "Should attempt 4 times before finding unique code")
        XCTAssertTrue(codeGenerator.isValidCodeFormat(uniqueCode), "Final code should be valid")
        expectation.fulfill()
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testGenerateUniqueCode_MaxRetriesExceeded() async {
        let expectation = XCTestExpectation(description: "Max retries exceeded")
        
        do {
            _ = try await codeGenerator.generateUniqueCode { code in
                // Always return false to simulate constant collisions
                return false
            }
            XCTFail("Should throw maxRetriesExceeded error")
        } catch CodeGenerationError.maxRetriesExceeded {
            // Expected error
            expectation.fulfill()
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testGenerateUniqueCode_UniquenessCheckFailure() async {
        let expectation = XCTestExpectation(description: "Uniqueness check failure")
        
        do {
            _ = try await codeGenerator.generateUniqueCode { code in
                throw NSError(domain: "TestError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Network error"])
            }
            XCTFail("Should throw uniquenessCheckFailed error")
        } catch CodeGenerationError.uniquenessCheckFailed(let underlyingError) {
            XCTAssertEqual((underlyingError as NSError).domain, "TestError")
            expectation.fulfill()
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Enhanced Code Generation Tests
    
    func testGenerateUniqueCodeSafely_BothChecksPass() async throws {
        let expectation = XCTestExpectation(description: "Both checks pass")
        var localCheckCount = 0
        var remoteCheckCount = 0
        
        let uniqueCode = try await codeGenerator.generateUniqueCodeSafely(
            checkLocal: { code in
                localCheckCount += 1
                return true // Local check passes
            },
            checkRemote: { code in
                remoteCheckCount += 1
                return true // Remote check passes
            }
        )
        
        XCTAssertEqual(localCheckCount, 1, "Local check should be called once")
        XCTAssertEqual(remoteCheckCount, 1, "Remote check should be called once")
        XCTAssertTrue(codeGenerator.isValidCodeFormat(uniqueCode), "Generated code should be valid")
        expectation.fulfill()
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testGenerateUniqueCodeSafely_LocalCollisionRetry() async throws {
        let expectation = XCTestExpectation(description: "Local collision retry")
        var attemptCount = 0
        
        let uniqueCode = try await customConfigGenerator.generateUniqueCodeSafely(
            checkLocal: { code in
                attemptCount += 1
                return attemptCount > 2 // First 2 attempts fail, 3rd succeeds
            },
            checkRemote: { code in
                return true // Remote always passes
            }
        )
        
        XCTAssertEqual(attemptCount, 3, "Should retry until local check passes")
        XCTAssertTrue(codeGenerator.isValidCodeFormat(uniqueCode), "Final code should be valid")
        expectation.fulfill()
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testGenerateUniqueCodeSafely_RemoteCollisionRetry() async throws {
        let expectation = XCTestExpectation(description: "Remote collision retry")
        var remoteAttemptCount = 0
        
        let uniqueCode = try await customConfigGenerator.generateUniqueCodeSafely(
            checkLocal: { code in
                return true // Local always passes
            },
            checkRemote: { code in
                remoteAttemptCount += 1
                return remoteAttemptCount > 2 // First 2 attempts fail, 3rd succeeds
            }
        )
        
        XCTAssertEqual(remoteAttemptCount, 3, "Should retry until remote check passes")
        XCTAssertTrue(codeGenerator.isValidCodeFormat(uniqueCode), "Final code should be valid")
        expectation.fulfill()
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testGenerateUniqueCodeSafely_LocalFallback() async throws {
        let expectation = XCTestExpectation(description: "Local fallback when remote fails")
        
        let uniqueCode = try await codeGenerator.generateUniqueCodeSafely(
            checkLocal: { code in
                return true // Local check passes
            },
            checkRemote: { code in
                throw CloudKitError.networkUnavailable // Remote check fails
            }
        )
        
        XCTAssertTrue(codeGenerator.isValidCodeFormat(uniqueCode), "Should generate valid code with local fallback")
        expectation.fulfill()
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testGenerateUniqueCodeSafely_RemoteFallback() async throws {
        let expectation = XCTestExpectation(description: "Remote fallback when local fails")
        
        let uniqueCode = try await codeGenerator.generateUniqueCodeSafely(
            checkLocal: { code in
                throw DataServiceError.invalidData("Local storage unavailable") // Local check fails
            },
            checkRemote: { code in
                return true // Remote check passes
            }
        )
        
        XCTAssertTrue(codeGenerator.isValidCodeFormat(uniqueCode), "Should generate valid code with remote fallback")
        expectation.fulfill()
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testGenerateUniqueCodeSafely_BothChecksFail() async {
        let expectation = XCTestExpectation(description: "Both checks fail")
        
        do {
            _ = try await codeGenerator.generateUniqueCodeSafely(
                checkLocal: { code in
                    throw DataServiceError.invalidData("Local error")
                },
                checkRemote: { code in
                    throw CloudKitError.networkUnavailable
                }
            )
            XCTFail("Should throw error when both checks fail")
        } catch let error as FamilyCodeGenerationError {
            XCTAssertTrue(error == .uniquenessCheckFailed, "Should throw uniqueness check failed error")
            expectation.fulfill()
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testGenerateUniqueCodeSafely_MaxAttemptsExceeded() async {
        let expectation = XCTestExpectation(description: "Max attempts exceeded")
        
        do {
            _ = try await customConfigGenerator.generateUniqueCodeSafely(
                checkLocal: { code in
                    return false // Always collision
                },
                checkRemote: { code in
                    return false // Always collision
                }
            )
            XCTFail("Should throw max attempts exceeded error")
        } catch let error as FamilyCodeGenerationError {
            XCTAssertTrue(error == .maxAttemptsExceeded, "Should throw max attempts exceeded error")
            expectation.fulfill()
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    func testGenerateUniqueCodeSafely_ExponentialBackoff() async throws {
        let expectation = XCTestExpectation(description: "Exponential backoff timing")
        let startTime = Date()
        var attemptCount = 0
        
        do {
            _ = try await customConfigGenerator.generateUniqueCodeSafely(
                checkLocal: { code in
                    attemptCount += 1
                    if attemptCount <= 3 {
                        throw DataServiceError.invalidData("Temporary error")
                    }
                    return true
                },
                checkRemote: { code in
                    return true
                }
            )
        } catch {
            // Expected to succeed after retries
        }
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        XCTAssertGreaterThan(elapsedTime, 0.02, "Should have some delay from backoff")
        XCTAssertEqual(attemptCount, 4, "Should retry 3 times before success")
        expectation.fulfill()
        
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    // MARK: - Enhanced Format Validation Tests
    
    @MainActor func testValidateCodeFormat_DetailedValidation() {
        // Test enhanced validation method
        XCTAssertTrue(codeGenerator.validateCodeFormat("ABC123"), "Valid code should pass")
        XCTAssertFalse(codeGenerator.validateCodeFormat(""), "Empty code should fail")
        XCTAssertFalse(codeGenerator.validateCodeFormat("ABC12"), "Short code should fail")
        XCTAssertFalse(codeGenerator.validateCodeFormat("ABCDEFGHI"), "Long code should fail")
        XCTAssertFalse(codeGenerator.validateCodeFormat("ABC-123"), "Invalid characters should fail")
    }
    
    // MARK: - Configuration Tests
    
    @MainActor func testCodeGenerationConfig_DefaultValues() {
        let defaultConfig = CodeGenerationConfig.default
        
        XCTAssertEqual(defaultConfig.maxRetries, 10)
        XCTAssertEqual(defaultConfig.baseDelay, 0.1)
        XCTAssertEqual(defaultConfig.maxDelay, 5.0)
        XCTAssertEqual(defaultConfig.backoffMultiplier, 2.0)
        XCTAssertTrue(defaultConfig.enableLocalFallback)
        XCTAssertTrue(defaultConfig.enableRemoteFallback)
    }
    
    @MainActor func testCodeGenerator_CustomConfig() {
        let customConfig = CodeGenerationConfig(
            maxRetries: 3,
            baseDelay: 0.5,
            maxDelay: 2.0,
            backoffMultiplier: 1.5,
            enableLocalFallback: false,
            enableRemoteFallback: false
        )
        
        let generator = CodeGenerator(config: customConfig)
        XCTAssertNotNil(generator, "Should create generator with custom config")
    }
    
    // MARK: - Error Handling Tests
    
    @MainActor func testFamilyCodeGenerationError_Properties() {
        let errors: [FamilyCodeGenerationError] = [
            .uniquenessCheckFailed,
            .localCheckFailed(DataServiceError.invalidData("test")),
            .remoteCheckFailed(CloudKitError.networkUnavailable),
            .formatValidationFailed("test"),
            .maxAttemptsExceeded,
            .generationAlgorithmFailed
        ]
        
        for error in errors {
            XCTAssertNotNil(error.userFriendlyMessage, "Should have user-friendly message")
            XCTAssertNotNil(error.technicalDescription, "Should have technical description")
            XCTAssertNotNil(error.recoveryStrategy, "Should have recovery strategy")
            
            // Test specific properties
            switch error {
            case .uniquenessCheckFailed, .localCheckFailed, .remoteCheckFailed:
                XCTAssertTrue(error.isRetryable, "Should be retryable")
            case .formatValidationFailed, .maxAttemptsExceeded, .generationAlgorithmFailed:
                XCTAssertFalse(error.isRetryable, "Should not be retryable")
            }
        }
    }
    
    // MARK: - Backward Compatibility Tests
    
    func testLegacyGenerateUniqueCode_StillWorks() async throws {
        let expectation = XCTestExpectation(description: "Legacy method works")
        
        let uniqueCode = try await codeGenerator.generateUniqueCode { code in
            return true // Always unique
        }
        
        XCTAssertTrue(codeGenerator.isValidCodeFormat(uniqueCode), "Legacy method should still work")
        expectation.fulfill()
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    // MARK: - Enhanced Error Handling Tests
    
    func testRobustUniquenessChecking_LocalFailureRecovery() async throws {
        let expectation = XCTestExpectation(description: "Local failure recovery")
        var localAttempts = 0
        var remoteAttempts = 0
        
        let uniqueCode = try await codeGenerator.generateUniqueCodeSafely(
            checkLocal: { code in
                localAttempts += 1
                if localAttempts <= 2 {
                    throw DataServiceError.invalidData("Database temporarily unavailable")
                }
                return true // Unique after recovery
            },
            checkRemote: { code in
                remoteAttempts += 1
                return true // Always unique
            }
        )
        
        XCTAssertEqual(localAttempts, 3, "Should retry local check until success")
        XCTAssertEqual(remoteAttempts, 3, "Should call remote check for each attempt")
        XCTAssertTrue(codeGenerator.isValidCodeFormat(uniqueCode))
        expectation.fulfill()
        
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    func testRobustUniquenessChecking_RemoteFailureRecovery() async throws {
        let expectation = XCTestExpectation(description: "Remote failure recovery")
        var localAttempts = 0
        var remoteAttempts = 0
        
        let uniqueCode = try await codeGenerator.generateUniqueCodeSafely(
            checkLocal: { code in
                localAttempts += 1
                return true // Always unique locally
            },
            checkRemote: { code in
                remoteAttempts += 1
                if remoteAttempts <= 2 {
                    throw CloudKitError.networkUnavailable
                }
                return true // Unique after recovery
            }
        )
        
        XCTAssertEqual(localAttempts, 3, "Should call local check for each attempt")
        XCTAssertEqual(remoteAttempts, 3, "Should retry remote check until success")
        XCTAssertTrue(codeGenerator.isValidCodeFormat(uniqueCode))
        expectation.fulfill()
        
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    func testRobustUniquenessChecking_ComplexCollisionScenario() async throws {
        let expectation = XCTestExpectation(description: "Complex collision scenario")
        var attemptCount = 0
        let collidingCodes = Set(["CODE001", "CODE002", "CODE003"])
        
        let uniqueCode = try await customConfigGenerator.generateUniqueCodeSafely(
            checkLocal: { code in
                attemptCount += 1
                // Simulate collisions for specific codes
                return !collidingCodes.contains(code)
            },
            checkRemote: { code in
                // Remote always passes if local passes
                return !collidingCodes.contains(code)
            }
        )
        
        XCTAssertFalse(collidingCodes.contains(uniqueCode), "Should generate non-colliding code")
        XCTAssertTrue(codeGenerator.isValidCodeFormat(uniqueCode))
        expectation.fulfill()
        
        await fulfillment(of: [expectation], timeout: 2.0)
    }
    
    func testRobustUniquenessChecking_PartialFailureScenarios() async {
        let expectation = XCTestExpectation(description: "Partial failure scenarios")
        
        // Test local success, remote failure with fallback enabled
        do {
            let code1 = try await codeGenerator.generateUniqueCodeSafely(
                checkLocal: { code in true },
                checkRemote: { code in throw CloudKitError.networkUnavailable }
            )
            XCTAssertTrue(codeGenerator.isValidCodeFormat(code1))
        } catch {
            XCTFail("Should succeed with local fallback: \(error)")
        }
        
        // Test local failure, remote success with fallback enabled
        do {
            let code2 = try await codeGenerator.generateUniqueCodeSafely(
                checkLocal: { code in throw DataServiceError.invalidData("Local error") },
                checkRemote: { code in true }
            )
            XCTAssertTrue(codeGenerator.isValidCodeFormat(code2))
        } catch {
            XCTFail("Should succeed with remote fallback: \(error)")
        }
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testRobustUniquenessChecking_DisabledFallbacks() async {
        let expectation = XCTestExpectation(description: "Disabled fallbacks")
        
        let strictConfig = CodeGenerationConfig(
            maxRetries: 3,
            baseDelay: 0.01,
            maxDelay: 0.1,
            backoffMultiplier: 1.5,
            enableLocalFallback: false,
            enableRemoteFallback: false
        )
        let strictGenerator = CodeGenerator(config: strictConfig)
        
        // Should fail when local check fails and fallback is disabled
        do {
            _ = try await strictGenerator.generateUniqueCodeSafely(
                checkLocal: { code in throw DataServiceError.invalidData("Local error") },
                checkRemote: { code in true }
            )
            XCTFail("Should fail when local fallback is disabled")
        } catch let error as FamilyCodeGenerationError {
            XCTAssertEqual(error, .localCheckFailed(DataServiceError.invalidData("Local error")))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    @MainActor func testErrorHandling_DetailedErrorInformation() {
        let errors: [(FamilyCodeGenerationError, String)] = [
            (.uniquenessCheckFailed, "uniqueness"),
            (.localCheckFailed(DataServiceError.invalidData("test")), "local"),
            (.remoteCheckFailed(CloudKitError.networkUnavailable), "remote"),
            (.formatValidationFailed("invalid format"), "format"),
            (.maxAttemptsExceeded, "attempts"),
            (.generationAlgorithmFailed, "algorithm")
        ]
        
        for (error, expectedKeyword) in errors {
            XCTAssertTrue(
                error.userFriendlyMessage.lowercased().contains(expectedKeyword),
                "Error message should contain '\(expectedKeyword)': \(error.userFriendlyMessage)"
            )
            XCTAssertTrue(
                error.technicalDescription.lowercased().contains(expectedKeyword),
                "Technical description should contain '\(expectedKeyword)': \(error.technicalDescription)"
            )
        }
    }
    
    @MainActor func testErrorHandling_RecoveryStrategyConsistency() {
        let retryableErrors: [FamilyCodeGenerationError] = [
            .uniquenessCheckFailed,
            .localCheckFailed(DataServiceError.invalidData("test")),
            .remoteCheckFailed(CloudKitError.networkUnavailable)
        ]
        
        for error in retryableErrors {
            XCTAssertTrue(error.isRetryable, "Error should be retryable: \(error)")
            
            if case .automaticRetry(let delay, let maxAttempts) = error.recoveryStrategy {
                XCTAssertGreaterThan(delay, 0, "Retry delay should be positive")
                XCTAssertGreaterThan(maxAttempts, 0, "Max attempts should be positive")
            } else {
                XCTFail("Retryable error should have automatic retry strategy: \(error)")
            }
        }
        
        let nonRetryableErrors: [FamilyCodeGenerationError] = [
            .formatValidationFailed("test"),
            .maxAttemptsExceeded,
            .generationAlgorithmFailed
        ]
        
        for error in nonRetryableErrors {
            XCTAssertFalse(error.isRetryable, "Error should not be retryable: \(error)")
        }
    }
    
    func testConcurrentCodeGeneration() async {
        let expectation = XCTestExpectation(description: "Concurrent code generation")
        let concurrentCount = 10
        var generatedCodes: [String] = []
        var errors: [Error] = []
        let lock = NSLock()
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<concurrentCount {
                group.addTask {
                    do {
                        let code = try await self.codeGenerator.generateUniqueCodeSafely(
                            checkLocal: { code in
                                // Simulate some processing time
                                try await Task.sleep(nanoseconds: 1_000_000) // 1ms
                                return true
                            },
                            checkRemote: { code in
                                try await Task.sleep(nanoseconds: 1_000_000) // 1ms
                                return true
                            }
                        )
                        
                        lock.lock()
                        generatedCodes.append(code)
                        lock.unlock()
                    } catch {
                        lock.lock()
                        errors.append(error)
                        lock.unlock()
                    }
                }
            }
        }
        
        XCTAssertEqual(errors.count, 0, "No errors should occur in concurrent generation")
        XCTAssertEqual(generatedCodes.count, concurrentCount, "Should generate all codes")
        
        // All codes should be unique
        let uniqueCodes = Set(generatedCodes)
        XCTAssertEqual(uniqueCodes.count, generatedCodes.count, "All generated codes should be unique")
        
        // All codes should be valid format
        for code in generatedCodes {
            XCTAssertTrue(codeGenerator.isValidCodeFormat(code), "Code should be valid: \(code)")
        }
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 5.0)
    }
    
    func testStressTestCodeGeneration() async {
        let expectation = XCTestExpectation(description: "Stress test code generation")
        let stressCount = 100
        var successCount = 0
        var collisionCount = 0
        
        for _ in 0..<stressCount {
            do {
                _ = try await codeGenerator.generateUniqueCodeSafely(
                    checkLocal: { code in
                        // Simulate occasional collisions
                        return Int.random(in: 1...10) > 2 // 80% success rate
                    },
                    checkRemote: { code in
                        return Int.random(in: 1...10) > 1 // 90% success rate
                    }
                )
                successCount += 1
            } catch {
                if case FamilyCodeGenerationError.maxAttemptsExceeded = error {
                    collisionCount += 1
                } else {
                    XCTFail("Unexpected error in stress test: \(error)")
                }
            }
        }
        
        // Should have high success rate even with simulated collisions
        XCTAssertGreaterThan(successCount, stressCount / 2, "Should have reasonable success rate")
        
        expectation.fulfill()
        await fulfillment(of: [expectation], timeout: 10.0)
    }
    
    // MARK: - Edge Cases
    
    @MainActor func testCodeGenerator_BoundaryLengths() {
        let minGenerator = CodeGenerator(codeLength: 5) // Should clamp to 6
        let maxGenerator = CodeGenerator(codeLength: 10) // Should clamp to 8
        
        XCTAssertEqual(minGenerator.generateRandomCode().count, 6, "Should clamp minimum to 6")
        XCTAssertEqual(maxGenerator.generateRandomCode().count, 8, "Should clamp maximum to 8")
    }
    
    @MainActor func testCodeGenerator_EmptyStringValidation() {
        XCTAssertFalse(codeGenerator.isValidCodeFormat(""), "Empty string should be invalid")
    }
    
    func testGenerateUniqueCodeSafely_FormatValidationFailure() async {
        let expectation = XCTestExpectation(description: "Format validation failure")
        
        // Test that format validation is properly integrated
        do {
            let code = try await codeGenerator.generateUniqueCodeSafely(
                checkLocal: { code in
                    return true
                },
                checkRemote: { code in
                    return true
                }
            )
            // Should succeed and produce valid format
            XCTAssertTrue(codeGenerator.isValidCodeFormat(code))
            expectation.fulfill()
        } catch {
            XCTFail("Should not fail with valid generator: \(error)")
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    @MainActor func testCodeGenerator_SpecialCharacterHandling() {
        let specialCodes = ["ABC@123", "TEST#456", "FAM$789", "CODE%012"]
        
        for code in specialCodes {
            XCTAssertFalse(codeGenerator.isValidCodeFormat(code), "Code with special characters should be invalid: \(code)")
        }
    }
    
    @MainActor func testCodeGenerator_CaseInsensitivity() {
        let mixedCaseCodes = ["AbC123", "tEsT456", "FaMiLy"]
        
        for code in mixedCaseCodes {
            if code.count >= 6 && code.count <= 8 {
                XCTAssertTrue(codeGenerator.isValidCodeFormat(code), "Mixed case code should be valid: \(code)")
            }
        }
    }
    
    @MainActor func testCodeGenerator_NumericOnlyCodes() {
        let numericCodes = ["123456", "789012", "555555"]
        
        for code in numericCodes {
            XCTAssertTrue(codeGenerator.isValidCodeFormat(code), "Numeric-only code should be valid: \(code)")
        }
    }
    
    @MainActor func testCodeGenerator_AlphaOnlyCodes() {
        let alphaCodes = ["ABCDEF", "FAMILY", "TESTING"]
        
        for code in alphaCodes {
            if code.count >= 6 && code.count <= 8 {
                XCTAssertTrue(codeGenerator.isValidCodeFormat(code), "Alpha-only code should be valid: \(code)")
            }
        }
    }
}