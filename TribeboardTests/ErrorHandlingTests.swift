//
//  ErrorHandlingTests.swift
//  TribeboardTests
//
//  Created by Kiro on 2026/02/04.
//

import XCTest
@testable import Tribeboard

@MainActor
class ErrorHandlingTests: XCTestCase {
    
    var errorHandlingService: ErrorHandlingService!
    var logger: PrivacyPreservingLogger!
    var firebaseService: MockFirebaseRunService!
    
    override func setUp() async throws {
        try await super.setUp()
        errorHandlingService = ErrorHandlingService()
        logger = PrivacyPreservingLogger()
        firebaseService = MockFirebaseRunService()
    }
    
    override func tearDown() async throws {
        errorHandlingService = nil
        logger = nil
        firebaseService = nil
        try await super.tearDown()
    }
    
    // MARK: - Error Handling Tests
    
    func testStateTransitionErrorHandling() async throws {
        // Given
        let runId = "test-run-123"
        let error = StateTransitionError.invalidTransition(from: .completed, to: .activeEnroute)
        
        // When
        let userError = errorHandlingService.handleStateTransitionError(error, for: runId)
        
        // Then
        XCTAssertEqual(userError.title, "Action Failed")
        XCTAssertTrue(userError.message.contains("Cannot change from Completed to En Route"))
        XCTAssertFalse(userError.isRetryable)
        XCTAssertEqual(userError.severity, .error)
    }
    
    func testNetworkErrorWithRetry() async throws {
        // Given
        let operation = NetworkOperation(
            type: .driverAction,
            runId: "test-run",
            description: "Test operation"
        )
        let networkError = URLError(.timedOut)
        var retryCount = 0
        
        // When
        await errorHandlingService.handleNetworkError(networkError, operation: operation) {
            retryCount += 1
            if retryCount < 2 {
                throw networkError
            }
            // Success on second attempt
        }
        
        // Then
        XCTAssertEqual(retryCount, 2)
        XCTAssertNil(errorHandlingService.currentError)
    }
    
    func testMaintainStateOnFailure() async throws {
        // Given
        let initialState = "initial_state"
        let expectedError = NSError(domain: "TestError", code: 123)
        
        // When
        let resultState = await errorHandlingService.maintainStateOnFailure(
            currentState: initialState,
            operation: {
                throw expectedError
            },
            fallbackMessage: "Test operation failed"
        )
        
        // Then
        XCTAssertEqual(resultState, initialState)
        XCTAssertNotNil(errorHandlingService.currentError)
    }
    
    // MARK: - Privacy-Preserving Logging Tests
    
    func testEmailSanitization() async throws {
        // Given
        let testEmail = "user@example.com"
        let additionalInfo = ["userEmail": testEmail]
        
        // When
        logger.logError(
            NSError(domain: "TestDomain", code: 123),
            context: .system,
            additionalInfo: additionalInfo
        )
        
        // Then
        let logs = logger.getLogEntries(limit: 1)
        XCTAssertFalse(logs.isEmpty)
        
        let logData = logs.first!.sanitizedData
        XCTAssertEqual(logData["userEmail"] as? String, "[REDACTED]")
    }
    
    func testPhoneNumberSanitization() async throws {
        // Given
        let message = "User called from 555-123-4567"
        
        // When
        logger.logInfo(message: message, context: .system)
        
        // Then
        let logs = logger.getLogEntries(limit: 1)
        XCTAssertFalse(logs.isEmpty)
        
        let sanitizedMessage = logs.first!.message
        XCTAssertTrue(sanitizedMessage.contains("[PHONE]"))
        XCTAssertFalse(sanitizedMessage.contains("555-123-4567"))
    }
    
    func testCoordinateSanitization() async throws {
        // Given
        let message = "User location: 37.7749,-122.4194"
        
        // When
        logger.logInfo(message: message, context: .locationServices)
        
        // Then
        let logs = logger.getLogEntries(limit: 1)
        XCTAssertFalse(logs.isEmpty)
        
        let sanitizedMessage = logs.first!.message
        XCTAssertTrue(sanitizedMessage.contains("[COORDINATES]"))
        XCTAssertFalse(sanitizedMessage.contains("37.7749"))
    }
    
    func testSensitiveDataRedaction() async throws {
        // Given
        let sensitiveData = [
            "password": "secret123",
            "authToken": "abc123xyz",
            "apiKey": "sk_live_123"
        ]
        
        // When
        logger.logError(
            NSError(domain: "TestDomain", code: 123),
            context: .authentication,
            additionalInfo: sensitiveData
        )
        
        // Then
        let logs = logger.getLogEntries(limit: 1)
        XCTAssertFalse(logs.isEmpty)
        
        let logData = logs.first!.sanitizedData
        XCTAssertEqual(logData["password"] as? String, "[REDACTED]")
        XCTAssertEqual(logData["authToken"] as? String, "[REDACTED]")
        XCTAssertEqual(logData["apiKey"] as? String, "[REDACTED]")
    }
    
    func testLogExport() async throws {
        // Given
        logger.logError(
            NSError(domain: "TestDomain", code: 123),
            context: .system,
            additionalInfo: ["testData": "value"]
        )
        logger.logWarning(message: "Test warning", context: .system)
        logger.logInfo(message: "Test info", context: .system)
        
        // When
        let exportedLogs = logger.exportSanitizedLogs()
        
        // Then
        XCTAssertTrue(exportedLogs.contains("TribeBoard Error Log Export"))
        XCTAssertTrue(exportedLogs.contains("Privacy Level: Full Sanitization"))
        XCTAssertTrue(exportedLogs.contains("[ERROR]"))
        XCTAssertTrue(exportedLogs.contains("[WARNING]"))
        XCTAssertTrue(exportedLogs.contains("[INFO]"))
    }
    
    // MARK: - Error Statistics Tests
    
    func testErrorStatistics() async throws {
        // Given
        let runId = "test-run"
        let error1 = StateTransitionError.invalidState("Test error 1")
        let error2 = StateTransitionError.passengerNotFound("passenger-123")
        
        // When
        _ = errorHandlingService.handleStateTransitionError(error1, for: runId)
        _ = errorHandlingService.handleStateTransitionError(error2, for: runId)
        
        // Then
        let stats = errorHandlingService.getErrorStatistics()
        XCTAssertGreaterThanOrEqual(stats.totalErrors, 2)
        XCTAssertGreaterThanOrEqual(stats.stateTransitionErrors, 2)
    }
    
    func testLoggingStatistics() async throws {
        // Given
        logger.logError(NSError(domain: "Test", code: 1), context: .system)
        logger.logWarning(message: "Test warning", context: .system)
        logger.logInfo(message: "Test info", context: .system)
        
        // When
        let stats = logger.getLoggingStatistics()
        
        // Then
        XCTAssertGreaterThanOrEqual(stats.totalEntries, 3)
        XCTAssertGreaterThanOrEqual(stats.errorCount, 1)
        XCTAssertGreaterThanOrEqual(stats.warningCount, 1)
    }
    
    // MARK: - Integration Tests
    
    func testErrorHandlingCoordinator() async throws {
        // Given
        let coordinator = ErrorHandlingCoordinator(firebaseService: firebaseService)
        let error = StateTransitionError.invalidTransition(from: .scheduled, to: .completed)
        let context = ErrorContext(
            type: .stateTransition(runId: "test-run"),
            additionalInfo: ["testKey": "testValue"]
        )
        
        // When
        await coordinator.handleError(error, context: context)
        
        // Then
        XCTAssertNotNil(coordinator.currentError)
        
        let stats = coordinator.getErrorStatistics()
        XCTAssertNotNil(stats.errorHandling)
        XCTAssertNotNil(stats.logging)
    }
    
    func testPrivacyCompliantReportGeneration() async throws {
        // Given
        let integration = ErrorLoggingIntegration(firebaseService: firebaseService)
        
        // Log some test errors
        integration.logStateTransitionError(
            runId: "test-run",
            runTitle: "Test Run",
            driverName: "John Doe",
            error: .invalidState("Test error")
        )
        
        // When
        let report = integration.exportPrivacyCompliantReport()
        
        // Then
        XCTAssertNotNil(report.generatedAt)
        XCTAssertEqual(report.privacyLevel, "Full Sanitization - No PII Exposed")
        XCTAssertFalse(report.complianceNotes.isEmpty)
        XCTAssertTrue(report.sanitizedLogs.contains("Privacy Level: Full Sanitization"))
    }
}