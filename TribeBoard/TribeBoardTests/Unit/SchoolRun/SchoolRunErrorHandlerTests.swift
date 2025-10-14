import XCTest
@testable import TribeBoard

/// Comprehensive tests for SchoolRunErrorHandler
@MainActor
final class SchoolRunErrorHandlerTests: XCTestCase {
    
    var errorHandler: SchoolRunErrorHandler!
    
    override func setUp() {
        super.setUp()
        errorHandler = SchoolRunErrorHandler()
    }
    
    override func tearDown() {
        errorHandler = nil
        super.tearDown()
    }
    
    // MARK: - Error Handling Tests
    
    func testHandleValidationError() {
        // Given
        let error = SchoolRunError.invalidRunTitle("Title too short")
        
        // When
        errorHandler.handleError(error, context: "Test Context")
        
        // Then
        XCTAssertEqual(errorHandler.currentError, error)
        XCTAssertEqual(errorHandler.errorMessage, error.userFriendlyMessage)
        XCTAssertTrue(errorHandler.hasError)
    }
    
    func testHandleCriticalError() {
        // Given
        let error = SchoolRunError.dataCorruption("Database corrupted")
        
        // When
        errorHandler.handleError(error, context: "Critical Test")
        
        // Then
        XCTAssertEqual(errorHandler.currentError, error)
        XCTAssertEqual(errorHandler.errorMessage, error.userFriendlyMessage)
        XCTAssertTrue(errorHandler.showingErrorAlert)
    }
    
    func testHandleMultipleErrors() {
        // Given
        let errors = [
            SchoolRunError.invalidRunTitle("Title error"),
            SchoolRunError.duplicateStopNames,
            SchoolRunError.insufficientStops
        ]
        
        // When
        errorHandler.handleErrors(errors, context: "Multiple Errors")
        
        // Then
        XCTAssertNotNil(errorHandler.currentError)
        XCTAssertTrue(errorHandler.hasError)
        XCTAssertEqual(errorHandler.errorCount, 3)
    }
    
    func testClearError() {
        // Given
        let error = SchoolRunError.invalidRunTitle("Test error")
        errorHandler.handleError(error)
        
        // When
        errorHandler.clearError()
        
        // Then
        XCTAssertNil(errorHandler.currentError)
        XCTAssertNil(errorHandler.errorMessage)
        XCTAssertFalse(errorHandler.hasError)
        XCTAssertFalse(errorHandler.showingErrorAlert)
        XCTAssertFalse(errorHandler.showingToast)
    }
    
    func testClearAll() {
        // Given
        let error = SchoolRunError.invalidRunTitle("Test error")
        errorHandler.handleError(error)
        
        // When
        errorHandler.clearAll()
        
        // Then
        XCTAssertNil(errorHandler.currentError)
        XCTAssertEqual(errorHandler.errorCount, 0)
    }
    
    // MARK: - Validation Tests
    
    func testValidateRunTitle() {
        // Test empty title
        XCTAssertNotNil(errorHandler.validateRunTitle(""))
        
        // Test too short title
        XCTAssertNotNil(errorHandler.validateRunTitle("AB"))
        
        // Test too long title
        let longTitle = String(repeating: "A", count: 51)
        XCTAssertNotNil(errorHandler.validateRunTitle(longTitle))
        
        // Test valid title
        XCTAssertNil(errorHandler.validateRunTitle("Morning School Run"))
        
        // Test title with invalid characters
        XCTAssertNotNil(errorHandler.validateRunTitle("Title\u{0001}"))
    }
    
    func testValidateRunDate() {
        let calendar = Calendar.current
        
        // Test past date
        let pastDate = calendar.date(byAdding: .day, value: -1, to: Date())!
        XCTAssertNotNil(errorHandler.validateRunDate(pastDate))
        
        // Test future date (too far)
        let farFutureDate = calendar.date(byAdding: .year, value: 2, to: Date())!
        XCTAssertNotNil(errorHandler.validateRunDate(farFutureDate))
        
        // Test valid date (today)
        XCTAssertNil(errorHandler.validateRunDate(Date()))
        
        // Test valid date (tomorrow)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        XCTAssertNil(errorHandler.validateRunDate(tomorrow))
    }
    
    func testValidateStops() {
        let calendar = Calendar.current
        let baseDate = Date()
        
        // Test empty stops
        let emptyStopsErrors = errorHandler.validateStops([])
        XCTAssertTrue(emptyStopsErrors.contains { $0 == .insufficientStops })
        
        // Test valid stops
        let validStops = [
            RunStop(name: "Home", time: baseDate, note: "", type: .pickup),
            RunStop(name: "School", time: calendar.date(byAdding: .minute, value: 15, to: baseDate)!, note: "", type: .dropoff)
        ]
        let validStopsErrors = errorHandler.validateStops(validStops, runDate: baseDate)
        XCTAssertTrue(validStopsErrors.isEmpty)
        
        // Test duplicate stop names
        let duplicateStops = [
            RunStop(name: "Home", time: baseDate, note: "", type: .pickup),
            RunStop(name: "Home", time: calendar.date(byAdding: .minute, value: 15, to: baseDate)!, note: "", type: .dropoff)
        ]
        let duplicateErrors = errorHandler.validateStops(duplicateStops, runDate: baseDate)
        XCTAssertTrue(duplicateErrors.contains { $0 == .duplicateStopNames })
        
        // Test stops too close together
        let closeStops = [
            RunStop(name: "Home", time: baseDate, note: "", type: .pickup),
            RunStop(name: "School", time: calendar.date(byAdding: .minute, value: 2, to: baseDate)!, note: "", type: .dropoff)
        ]
        let closeErrors = errorHandler.validateStops(closeStops, runDate: baseDate)
        XCTAssertTrue(closeErrors.contains { case .stopTimeConflict = $0; return true; default: return false })
    }
    
    func testValidateStop() {
        let baseDate = Date()
        
        // Test empty stop name
        let emptyStop = RunStop(name: "", time: baseDate, note: "", type: .pickup)
        XCTAssertNotNil(errorHandler.validateStop(emptyStop, index: 0, runDate: baseDate))
        
        // Test too long stop name
        let longNameStop = RunStop(name: String(repeating: "A", count: 31), time: baseDate, note: "", type: .pickup)
        XCTAssertNotNil(errorHandler.validateStop(longNameStop, index: 0, runDate: baseDate))
        
        // Test too long note
        let longNoteStop = RunStop(name: "Home", time: baseDate, note: String(repeating: "A", count: 101), type: .pickup)
        XCTAssertNotNil(errorHandler.validateStop(longNoteStop, index: 0, runDate: baseDate))
        
        // Test valid stop
        let validStop = RunStop(name: "Home", time: baseDate, note: "Pick up Emma", type: .pickup)
        XCTAssertNil(errorHandler.validateStop(validStop, index: 0, runDate: baseDate))
    }
    
    // MARK: - Recovery Strategy Tests
    
    func testGetRecoverySuggestions() {
        // Test validation error suggestions
        let validationError = SchoolRunError.invalidRunTitle("Title too short")
        let validationSuggestions = errorHandler.getRecoverySuggestions(for: validationError)
        XCTAssertFalse(validationSuggestions.isEmpty)
        XCTAssertTrue(validationSuggestions.contains { $0.contains("3-50 characters") })
        
        // Test network error suggestions
        let networkError = SchoolRunError.networkUnavailable
        let networkSuggestions = errorHandler.getRecoverySuggestions(for: networkError)
        XCTAssertTrue(networkSuggestions.contains { $0.contains("internet connection") })
    }
    
    func testCanRetry() {
        // Test retryable error
        let retryableError = SchoolRunError.networkUnavailable
        XCTAssertTrue(errorHandler.canRetry(retryableError))
        
        // Test non-retryable error
        let nonRetryableError = SchoolRunError.invalidRunTitle("Invalid")
        XCTAssertFalse(errorHandler.canRetry(nonRetryableError))
    }
    
    func testGetRetryDelay() {
        let lowSeverityError = SchoolRunError.invalidUserInput("Test")
        let mediumSeverityError = SchoolRunError.runNotFound(UUID())
        let highSeverityError = SchoolRunError.dataCorruption("Test")
        let criticalSeverityError = SchoolRunError.storageError("Test")
        
        let lowDelay = errorHandler.getRetryDelay(for: lowSeverityError)
        let mediumDelay = errorHandler.getRetryDelay(for: mediumSeverityError)
        let highDelay = errorHandler.getRetryDelay(for: highSeverityError)
        let criticalDelay = errorHandler.getRetryDelay(for: criticalSeverityError)
        
        XCTAssertLessThanOrEqual(lowDelay, mediumDelay)
        XCTAssertLessThanOrEqual(mediumDelay, highDelay)
        XCTAssertLessThanOrEqual(highDelay, criticalDelay)
    }
    
    // MARK: - Error Pattern Analysis Tests
    
    func testAnalyzeErrorPatterns() {
        // Test with no errors
        let emptyAnalysis = errorHandler.analyzeErrorPatterns()
        XCTAssertTrue(emptyAnalysis.patterns.isEmpty)
        
        // Test with repeated validation errors
        for _ in 0..<3 {
            errorHandler.handleError(.invalidRunTitle("Test"), context: "Pattern Test")
        }
        
        let validationAnalysis = errorHandler.analyzeErrorPatterns()
        XCTAssertTrue(validationAnalysis.patterns.contains(.repeatedValidation))
        XCTAssertFalse(validationAnalysis.recommendations.isEmpty)
    }
    
    // MARK: - Error Properties Tests
    
    func testErrorProperties() {
        let validationError = SchoolRunError.invalidRunTitle("Test")
        XCTAssertEqual(validationError.category, .validation)
        XCTAssertEqual(validationError.severity, .low)
        XCTAssertFalse(validationError.isRetryable)
        XCTAssertTrue(validationError.shouldShowToUser)
        
        let networkError = SchoolRunError.networkUnavailable
        XCTAssertEqual(networkError.category, .network)
        XCTAssertEqual(networkError.severity, .high)
        XCTAssertTrue(networkError.isRetryable)
        XCTAssertTrue(networkError.shouldTriggerHaptic)
        XCTAssertEqual(networkError.hapticType, .error)
    }
    
    func testErrorEquality() {
        let error1 = SchoolRunError.invalidRunTitle("Test")
        let error2 = SchoolRunError.invalidRunTitle("Test")
        let error3 = SchoolRunError.duplicateStopNames
        
        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }
    
    // MARK: - Performance Tests
    
    func testValidationPerformance() {
        let stops = (0..<100).map { index in
            RunStop(
                name: "Stop \(index)",
                time: Date().addingTimeInterval(TimeInterval(index * 600)), // 10 minutes apart
                note: "Note for stop \(index)",
                type: index % 2 == 0 ? .pickup : .dropoff
            )
        }
        
        measure {
            _ = errorHandler.validateStops(stops, runDate: Date())
        }
    }
    
    func testErrorHandlingPerformance() {
        let errors = (0..<1000).map { _ in
            SchoolRunError.invalidRunTitle("Test error")
        }
        
        measure {
            for error in errors {
                errorHandler.handleError(error, context: "Performance Test")
            }
        }
    }
}