import XCTest
@testable import TribeBoard

/// Comprehensive tests for SchoolRunValidation utilities
final class SchoolRunValidationTests: XCTestCase {
    
    // MARK: - Run Validation Tests
    
    func testValidateCompleteRun() {
        let calendar = Calendar.current
        let baseDate = Date()
        
        // Test valid run
        let validStops = [
            RunStop(name: "Home", time: baseDate, note: "", type: .pickup),
            RunStop(name: "School", time: calendar.date(byAdding: .minute, value: 15, to: baseDate)!, note: "", type: .dropoff)
        ]
        
        let validResult = SchoolRunValidation.validateRun(
            title: "Morning School Run",
            date: baseDate,
            stops: validStops
        )
        
        XCTAssertTrue(validResult.isValid)
        XCTAssertTrue(validResult.errors.isEmpty)
        
        // Test invalid run
        let invalidResult = SchoolRunValidation.validateRun(
            title: "",
            date: calendar.date(byAdding: .day, value: -1, to: baseDate)!,
            stops: []
        )
        
        XCTAssertFalse(invalidResult.isValid)
        XCTAssertFalse(invalidResult.errors.isEmpty)
        XCTAssertTrue(invalidResult.hasCriticalErrors == false) // These are validation errors, not critical
    }
    
    // MARK: - Title Validation Tests
    
    func testValidateTitle() {
        // Test empty title
        XCTAssertNotNil(SchoolRunValidation.validateTitle(""))
        
        // Test whitespace-only title
        XCTAssertNotNil(SchoolRunValidation.validateTitle("   "))
        
        // Test too short title
        XCTAssertNotNil(SchoolRunValidation.validateTitle("AB"))
        
        // Test too long title
        let longTitle = String(repeating: "A", count: 51)
        XCTAssertNotNil(SchoolRunValidation.validateTitle(longTitle))
        
        // Test title with invalid characters
        XCTAssertNotNil(SchoolRunValidation.validateTitle("Title\u{0001}"))
        
        // Test title with multiple spaces
        XCTAssertNotNil(SchoolRunValidation.validateTitle("Title  with  spaces"))
        
        // Test valid titles
        XCTAssertNil(SchoolRunValidation.validateTitle("Morning School Run"))
        XCTAssertNil(SchoolRunValidation.validateTitle("ABC"))
        XCTAssertNil(SchoolRunValidation.validateTitle("Run with numbers 123"))
        XCTAssertNil(SchoolRunValidation.validateTitle("Run with punctuation!"))
    }
    
    // MARK: - Date Validation Tests
    
    func testValidateDate() {
        let calendar = Calendar.current
        let today = Date()
        
        // Test past date
        let pastDate = calendar.date(byAdding: .day, value: -1, to: today)!
        XCTAssertNotNil(SchoolRunValidation.validateDate(pastDate))
        
        // Test far future date
        let farFutureDate = calendar.date(byAdding: .day, value: 400, to: today)!
        XCTAssertNotNil(SchoolRunValidation.validateDate(farFutureDate))
        
        // Test valid dates
        XCTAssertNil(SchoolRunValidation.validateDate(today))
        
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!
        XCTAssertNil(SchoolRunValidation.validateDate(tomorrow))
        
        let oneMonthLater = calendar.date(byAdding: .month, value: 1, to: today)!
        XCTAssertNil(SchoolRunValidation.validateDate(oneMonthLater))
    }
    
    // MARK: - Stops Validation Tests
    
    func testValidateStops() {
        let calendar = Calendar.current
        let baseDate = Date()
        
        // Test empty stops
        let emptyErrors = SchoolRunValidation.validateStops([], runDate: baseDate)
        XCTAssertTrue(emptyErrors.contains { $0 == .insufficientStops })
        
        // Test too many stops
        let tooManyStops = (0..<15).map { index in
            RunStop(
                name: "Stop \(index)",
                time: calendar.date(byAdding: .minute, value: index * 10, to: baseDate)!,
                note: "",
                type: .pickup
            )
        }
        let tooManyErrors = SchoolRunValidation.validateStops(tooManyStops, runDate: baseDate)
        XCTAssertTrue(tooManyErrors.contains { case .invalidStopData(let message) = $0; return message.contains("Maximum") })
        
        // Test valid stops
        let validStops = [
            RunStop(name: "Home", time: baseDate, note: "", type: .pickup),
            RunStop(name: "School", time: calendar.date(byAdding: .minute, value: 15, to: baseDate)!, note: "", type: .dropoff)
        ]
        let validErrors = SchoolRunValidation.validateStops(validStops, runDate: baseDate)
        XCTAssertTrue(validErrors.isEmpty)
        
        // Test duplicate names
        let duplicateStops = [
            RunStop(name: "Home", time: baseDate, note: "", type: .pickup),
            RunStop(name: "Home", time: calendar.date(byAdding: .minute, value: 15, to: baseDate)!, note: "", type: .dropoff)
        ]
        let duplicateErrors = SchoolRunValidation.validateStops(duplicateStops, runDate: baseDate)
        XCTAssertTrue(duplicateErrors.contains { $0 == .duplicateStopNames })
    }
    
    func testValidateStopTiming() {
        let calendar = Calendar.current
        let baseDate = Date()
        
        // Test stops too close together
        let closeStops = [
            RunStop(name: "Home", time: baseDate, note: "", type: .pickup),
            RunStop(name: "School", time: calendar.date(byAdding: .minute, value: 2, to: baseDate)!, note: "", type: .dropoff)
        ]
        let closeErrors = SchoolRunValidation.validateStopTiming(closeStops, runDate: baseDate)
        XCTAssertTrue(closeErrors.contains { case .stopTimeConflict = $0; return true; default: return false })
        
        // Test run too long
        let longStops = [
            RunStop(name: "Start", time: baseDate, note: "", type: .pickup),
            RunStop(name: "End", time: calendar.date(byAdding: .hour, value: 10, to: baseDate)!, note: "", type: .dropoff)
        ]
        let longErrors = SchoolRunValidation.validateStopTiming(longStops, runDate: baseDate)
        XCTAssertTrue(longErrors.contains { case .invalidStopTiming(let message) = $0; return message.contains("8 hours") })
        
        // Test valid timing
        let validStops = [
            RunStop(name: "Home", time: baseDate, note: "", type: .pickup),
            RunStop(name: "School", time: calendar.date(byAdding: .minute, value: 15, to: baseDate)!, note: "", type: .dropoff)
        ]
        let validErrors = SchoolRunValidation.validateStopTiming(validStops, runDate: baseDate)
        XCTAssertTrue(validErrors.isEmpty)
    }
    
    // MARK: - Individual Stop Validation Tests
    
    func testValidateStop() {
        let baseDate = Date()
        
        // Test empty name
        let emptyNameStop = RunStop(name: "", time: baseDate, note: "", type: .pickup)
        XCTAssertNotNil(SchoolRunValidation.validateStop(emptyNameStop, index: 0, runDate: baseDate))
        
        // Test too long name
        let longNameStop = RunStop(name: String(repeating: "A", count: 31), time: baseDate, note: "", type: .pickup)
        XCTAssertNotNil(SchoolRunValidation.validateStop(longNameStop, index: 0, runDate: baseDate))
        
        // Test too long note
        let longNoteStop = RunStop(name: "Home", time: baseDate, note: String(repeating: "A", count: 101), type: .pickup)
        XCTAssertNotNil(SchoolRunValidation.validateStop(longNoteStop, index: 0, runDate: baseDate))
        
        // Test different day
        let calendar = Calendar.current
        let differentDay = calendar.date(byAdding: .day, value: 1, to: baseDate)!
        let differentDayStop = RunStop(name: "Home", time: differentDay, note: "", type: .pickup)
        XCTAssertNotNil(SchoolRunValidation.validateStop(differentDayStop, index: 0, runDate: baseDate))
        
        // Test very early time
        let earlyTime = calendar.date(bySettingHour: 3, minute: 0, second: 0, of: baseDate)!
        let earlyStop = RunStop(name: "Home", time: earlyTime, note: "", type: .pickup)
        XCTAssertNotNil(SchoolRunValidation.validateStop(earlyStop, index: 0, runDate: baseDate))
        
        // Test very late time
        let lateTime = calendar.date(bySettingHour: 23, minute: 30, second: 0, of: baseDate)!
        let lateStop = RunStop(name: "Home", time: lateTime, note: "", type: .pickup)
        XCTAssertNotNil(SchoolRunValidation.validateStop(lateStop, index: 0, runDate: baseDate))
        
        // Test valid stop
        let validTime = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: baseDate)!
        let validStop = RunStop(name: "Home", time: validTime, note: "Pick up Emma", type: .pickup)
        XCTAssertNil(SchoolRunValidation.validateStop(validStop, index: 0, runDate: baseDate))
    }
    
    // MARK: - Warning Generation Tests
    
    func testGenerateWarnings() {
        let calendar = Calendar.current
        let baseDate = Date()
        
        // Test future date warning
        let futureDate = calendar.date(byAdding: .weekOfYear, value: 2, to: baseDate)!
        let futureWarnings = SchoolRunValidation.generateWarnings(
            title: "Test Run",
            date: futureDate,
            stops: [RunStop(name: "Home", time: futureDate, note: "", type: .pickup)]
        )
        XCTAssertTrue(futureWarnings.contains { $0.contains("week in advance") })
        
        // Test weekend warning
        let saturday = calendar.nextDate(after: baseDate, matching: DateComponents(weekday: 7), matchingPolicy: .nextTime)!
        let weekendWarnings = SchoolRunValidation.generateWarnings(
            title: "Test Run",
            date: saturday,
            stops: [RunStop(name: "Home", time: saturday, note: "", type: .pickup)]
        )
        XCTAssertTrue(weekendWarnings.contains { $0.contains("weekend") })
        
        // Test single stop warning
        let singleStopWarnings = SchoolRunValidation.generateWarnings(
            title: "Test Run",
            date: baseDate,
            stops: [RunStop(name: "Home", time: baseDate, note: "", type: .pickup)]
        )
        XCTAssertTrue(singleStopWarnings.contains { $0.contains("only one stop") })
        
        // Test early start warning
        let earlyTime = calendar.date(bySettingHour: 6, minute: 0, second: 0, of: baseDate)!
        let earlyWarnings = SchoolRunValidation.generateWarnings(
            title: "Test Run",
            date: baseDate,
            stops: [RunStop(name: "Home", time: earlyTime, note: "", type: .pickup)]
        )
        XCTAssertTrue(earlyWarnings.contains { $0.contains("very early") })
        
        // Test mixed stop types warning
        let mixedStops = [
            RunStop(name: "Home", time: baseDate, note: "", type: .pickup),
            RunStop(name: "School", time: calendar.date(byAdding: .minute, value: 15, to: baseDate)!, note: "", type: .dropoff)
        ]
        let mixedWarnings = SchoolRunValidation.generateWarnings(
            title: "Test Run",
            date: baseDate,
            stops: mixedStops
        )
        XCTAssertTrue(mixedWarnings.contains { $0.contains("both pickup and drop-off") })
    }
    
    // MARK: - Real-time Validation Tests
    
    func testValidateTitleRealTime() {
        // Test empty
        XCTAssertEqual(SchoolRunValidation.validateTitleRealTime(""), .empty)
        
        // Test too short
        let shortState = SchoolRunValidation.validateTitleRealTime("AB")
        if case .tooShort(let current, let required) = shortState {
            XCTAssertEqual(current, 2)
            XCTAssertEqual(required, 3)
        } else {
            XCTFail("Expected tooShort state")
        }
        
        // Test too long
        let longTitle = String(repeating: "A", count: 51)
        let longState = SchoolRunValidation.validateTitleRealTime(longTitle)
        if case .tooLong(let current, let maximum) = longState {
            XCTAssertEqual(current, 51)
            XCTAssertEqual(maximum, 50)
        } else {
            XCTFail("Expected tooLong state")
        }
        
        // Test valid
        XCTAssertEqual(SchoolRunValidation.validateTitleRealTime("Valid Title"), .valid)
    }
    
    func testValidateStopNameRealTime() {
        // Test empty
        XCTAssertEqual(SchoolRunValidation.validateStopNameRealTime(""), .empty)
        XCTAssertFalse(SchoolRunValidation.validateStopNameRealTime("").isValid)
        
        // Test too long
        let longName = String(repeating: "A", count: 31)
        let longState = SchoolRunValidation.validateStopNameRealTime(longName)
        if case .tooLong(let current, let maximum) = longState {
            XCTAssertEqual(current, 31)
            XCTAssertEqual(maximum, 30)
        } else {
            XCTFail("Expected tooLong state")
        }
        XCTAssertFalse(longState.isValid)
        
        // Test valid
        let validState = SchoolRunValidation.validateStopNameRealTime("Home")
        XCTAssertEqual(validState, .valid)
        XCTAssertTrue(validState.isValid)
    }
    
    // MARK: - Validation Helper Tests
    
    func testHasTimeConflict() {
        let calendar = Calendar.current
        let baseTime = Date()
        
        let stop1 = RunStop(name: "Stop1", time: baseTime, note: "", type: .pickup)
        let stop2 = RunStop(name: "Stop2", time: calendar.date(byAdding: .minute, value: 2, to: baseTime)!, note: "", type: .dropoff)
        let stop3 = RunStop(name: "Stop3", time: calendar.date(byAdding: .minute, value: 10, to: baseTime)!, note: "", type: .dropoff)
        
        // Test conflict (less than 5 minutes apart)
        XCTAssertTrue(SchoolRunValidation.hasTimeConflict(stop1, stop2))
        
        // Test no conflict (more than 5 minutes apart)
        XCTAssertFalse(SchoolRunValidation.hasTimeConflict(stop1, stop3))
    }
    
    func testSuggestNextStopTime() {
        let calendar = Calendar.current
        let baseDate = Date()
        
        // Test with no existing stops
        let emptyStopsSuggestion = SchoolRunValidation.suggestNextStopTime(after: [], baseDate: baseDate)
        let expectedEmpty = calendar.date(byAdding: .minute, value: 15, to: baseDate)!
        XCTAssertEqual(emptyStopsSuggestion.timeIntervalSince(expectedEmpty), 0, accuracy: 1)
        
        // Test with existing stops
        let existingStops = [
            RunStop(name: "Home", time: baseDate, note: "", type: .pickup),
            RunStop(name: "School", time: calendar.date(byAdding: .minute, value: 20, to: baseDate)!, note: "", type: .dropoff)
        ]
        let suggestion = SchoolRunValidation.suggestNextStopTime(after: existingStops, baseDate: baseDate)
        let expected = calendar.date(byAdding: .minute, value: 35, to: baseDate)! // 20 + 15
        XCTAssertEqual(suggestion.timeIntervalSince(expected), 0, accuracy: 1)
    }
    
    func testValidateStopOrder() {
        let stops = [
            RunStop(name: "Home", time: Date(), note: "", type: .pickup),
            RunStop(name: "School", time: Date(), note: "", type: .dropoff),
            RunStop(name: "Park", time: Date(), note: "", type: .pickup),
            RunStop(name: "Library", time: Date(), note: "", type: .dropoff)
        ]
        
        let suggestions = SchoolRunValidation.validateStopOrder(stops)
        XCTAssertTrue(suggestions.contains { $0.contains("optimizing stop order") })
    }
    
    // MARK: - Validation Result Tests
    
    func testValidationResult() {
        let errors = [
            SchoolRunError.invalidRunTitle("Test error"),
            SchoolRunError.duplicateStopNames
        ]
        let warnings = ["Test warning"]
        
        let result = ValidationResult(isValid: false, errors: errors, warnings: warnings)
        
        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.errors.count, 2)
        XCTAssertEqual(result.warnings.count, 1)
        XCTAssertEqual(result.errorMessages.count, 2)
        XCTAssertNotNil(result.firstErrorMessage)
        XCTAssertFalse(result.hasCriticalErrors)
        
        let validationErrors = result.errors(for: .validation)
        XCTAssertEqual(validationErrors.count, 2)
    }
    
    // MARK: - Performance Tests
    
    func testValidationPerformance() {
        let calendar = Calendar.current
        let baseDate = Date()
        
        // Create a large number of stops for performance testing
        let stops = (0..<100).map { index in
            RunStop(
                name: "Stop \(index)",
                time: calendar.date(byAdding: .minute, value: index * 10, to: baseDate)!,
                note: "Note for stop \(index)",
                type: index % 2 == 0 ? .pickup : .dropoff
            )
        }
        
        measure {
            _ = SchoolRunValidation.validateRun(
                title: "Performance Test Run",
                date: baseDate,
                stops: stops
            )
        }
    }
    
    func testRealTimeValidationPerformance() {
        let titles = (0..<1000).map { "Test Title \($0)" }
        
        measure {
            for title in titles {
                _ = SchoolRunValidation.validateTitleRealTime(title)
            }
        }
    }
}