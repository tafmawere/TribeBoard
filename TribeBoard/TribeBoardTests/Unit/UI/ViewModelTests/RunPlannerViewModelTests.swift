import XCTest
@testable import TribeBoard

@MainActor
class RunPlannerViewModelTests: XCTestCase {
    
    var viewModel: RunPlannerViewModel!
    var mockManager: SchoolRunManager!
    
    override func setUp() {
        super.setUp()
        // Use in-memory UserDefaults for testing
        let testDefaults = UserDefaults(suiteName: "RunPlannerViewModelTests")!
        testDefaults.removePersistentDomain(forName: "RunPlannerViewModelTests")
        
        mockManager = SchoolRunManager(storage: testDefaults)
        viewModel = RunPlannerViewModel(manager: mockManager)
    }
    
    override func tearDown() {
        viewModel = nil
        mockManager = nil
        super.tearDown()
    }
    
    // MARK: - Form Validation Tests
    
    func testInitialFormState() {
        XCTAssertEqual(viewModel.title, "")
        XCTAssertTrue(viewModel.stops.isEmpty)
        XCTAssertFalse(viewModel.isValid)
        XCTAssertFalse(viewModel.hasUnsavedChanges)
    }
    
    func testTitleValidation() {
        // Test empty title
        viewModel.title = ""
        viewModel.validateForm()
        XCTAssertEqual(viewModel.titleError, "Title is required")
        XCTAssertFalse(viewModel.isValid)
        
        // Test short title
        viewModel.title = "AB"
        viewModel.validateForm()
        XCTAssertEqual(viewModel.titleError, "Title must be at least 3 characters")
        XCTAssertFalse(viewModel.isValid)
        
        // Test long title
        viewModel.title = String(repeating: "A", count: 51)
        viewModel.validateForm()
        XCTAssertEqual(viewModel.titleError, "Title must be less than 50 characters")
        XCTAssertFalse(viewModel.isValid)
        
        // Test valid title
        viewModel.title = "Morning School Run"
        viewModel.validateForm()
        XCTAssertNil(viewModel.titleError)
    }
    
    func testDateValidation() {
        let calendar = Calendar.current
        
        // Test past date
        viewModel.selectedDate = calendar.date(byAdding: .day, value: -1, to: Date())!
        viewModel.validateForm()
        XCTAssertEqual(viewModel.dateError, "Date cannot be in the past")
        XCTAssertFalse(viewModel.isValid)
        
        // Test future date (more than 1 year)
        viewModel.selectedDate = calendar.date(byAdding: .year, value: 2, to: Date())!
        viewModel.validateForm()
        XCTAssertEqual(viewModel.dateError, "Date cannot be more than 1 year in the future")
        XCTAssertFalse(viewModel.isValid)
        
        // Test valid date (today)
        viewModel.selectedDate = Date()
        viewModel.validateForm()
        XCTAssertNil(viewModel.dateError)
    }
    
    func testStopsValidation() {
        viewModel.title = "Test Run"
        viewModel.selectedDate = Date()
        
        // Test empty stops
        viewModel.stops = []
        viewModel.validateForm()
        XCTAssertEqual(viewModel.stopsError, "At least one stop is required")
        XCTAssertFalse(viewModel.isValid)
        
        // Test stop with empty name
        let emptyNameStop = RunStop(name: "", time: Date(), type: .pickup)
        viewModel.stops = [emptyNameStop]
        viewModel.validateForm()
        XCTAssertEqual(viewModel.stopsError, "All stops must have a name")
        XCTAssertFalse(viewModel.isValid)
        
        // Test duplicate stop names
        let stop1 = RunStop(name: "Home", time: Date(), type: .pickup)
        let stop2 = RunStop(name: "home", time: Date(), type: .dropoff) // Same name, different case
        viewModel.stops = [stop1, stop2]
        viewModel.validateForm()
        XCTAssertEqual(viewModel.stopsError, "Stop names must be unique")
        XCTAssertFalse(viewModel.isValid)
        
        // Test stops too close together (less than 5 minutes)
        let now = Date()
        let closeStop1 = RunStop(name: "Home", time: now, type: .pickup)
        let closeStop2 = RunStop(name: "School", time: now.addingTimeInterval(240), type: .dropoff) // 4 minutes later
        viewModel.stops = [closeStop1, closeStop2]
        viewModel.validateForm()
        XCTAssertEqual(viewModel.stopsError, "Stops must be at least 5 minutes apart")
        XCTAssertFalse(viewModel.isValid)
        
        // Test valid stops
        let validStop1 = RunStop(name: "Home", time: now, type: .pickup)
        let validStop2 = RunStop(name: "School", time: now.addingTimeInterval(600), type: .dropoff) // 10 minutes later
        viewModel.stops = [validStop1, validStop2]
        viewModel.validateForm()
        XCTAssertNil(viewModel.stopsError)
        XCTAssertTrue(viewModel.isValid)
    }
    
    func testCompleteFormValidation() {
        // Set up valid form
        viewModel.title = "Morning School Run"
        viewModel.selectedDate = Date()
        
        let now = Date()
        let stop1 = RunStop(name: "Home", time: now, type: .pickup)
        let stop2 = RunStop(name: "School", time: now.addingTimeInterval(600), type: .dropoff)
        viewModel.stops = [stop1, stop2]
        
        viewModel.validateForm()
        
        XCTAssertNil(viewModel.titleError)
        XCTAssertNil(viewModel.dateError)
        XCTAssertNil(viewModel.stopsError)
        XCTAssertTrue(viewModel.isValid)
    }
    
    // MARK: - Stop Management Tests
    
    func testAddStop() {
        let initialCount = viewModel.stops.count
        
        viewModel.addStop()
        
        XCTAssertEqual(viewModel.stops.count, initialCount + 1)
        
        let addedStop = viewModel.stops.last!
        XCTAssertEqual(addedStop.name, "")
        XCTAssertEqual(addedStop.type, .pickup)
        XCTAssertFalse(addedStop.isCompleted)
    }
    
    func testAddStopWithDetails() {
        let name = "Home"
        let time = Date()
        let type = RunStop.StopType.pickup
        let note = "Pick up Emma"
        
        viewModel.addStop(name: name, time: time, type: type, note: note)
        
        XCTAssertEqual(viewModel.stops.count, 1)
        
        let addedStop = viewModel.stops.first!
        XCTAssertEqual(addedStop.name, name)
        XCTAssertEqual(addedStop.time, time)
        XCTAssertEqual(addedStop.type, type)
        XCTAssertEqual(addedStop.note, note)
    }
    
    func testRemoveStopAtIndex() {
        // Add some stops first
        viewModel.addStop(name: "Home", time: Date(), type: .pickup)
        viewModel.addStop(name: "School", time: Date().addingTimeInterval(600), type: .dropoff)
        
        XCTAssertEqual(viewModel.stops.count, 2)
        
        viewModel.removeStop(at: 0)
        
        XCTAssertEqual(viewModel.stops.count, 1)
        XCTAssertEqual(viewModel.stops.first?.name, "School")
    }
    
    func testRemoveStopById() {
        // Add a stop
        viewModel.addStop(name: "Home", time: Date(), type: .pickup)
        let stopId = viewModel.stops.first!.id
        
        XCTAssertEqual(viewModel.stops.count, 1)
        
        viewModel.removeStop(id: stopId)
        
        XCTAssertEqual(viewModel.stops.count, 0)
    }
    
    func testUpdateStopAtIndex() {
        // Add a stop first
        viewModel.addStop(name: "Home", time: Date(), type: .pickup)
        
        let newName = "Updated Home"
        let newTime = Date().addingTimeInterval(300)
        let newType = RunStop.StopType.dropoff
        let newNote = "Updated note"
        
        viewModel.updateStop(at: 0, name: newName, time: newTime, type: newType, note: newNote)
        
        let updatedStop = viewModel.stops.first!
        XCTAssertEqual(updatedStop.name, newName)
        XCTAssertEqual(updatedStop.time, newTime)
        XCTAssertEqual(updatedStop.type, newType)
        XCTAssertEqual(updatedStop.note, newNote)
    }
    
    func testUpdateStopById() {
        // Add a stop first
        viewModel.addStop(name: "Home", time: Date(), type: .pickup)
        let stopId = viewModel.stops.first!.id
        
        let newName = "Updated Home"
        
        viewModel.updateStop(id: stopId, name: newName)
        
        let updatedStop = viewModel.stops.first!
        XCTAssertEqual(updatedStop.name, newName)
        XCTAssertEqual(updatedStop.id, stopId)
    }
    
    func testSortStopsByTime() {
        let now = Date()
        let laterTime = now.addingTimeInterval(600)
        let earlierTime = now.addingTimeInterval(-300)
        
        // Add stops in random order
        viewModel.addStop(name: "Later", time: laterTime, type: .pickup)
        viewModel.addStop(name: "Earlier", time: earlierTime, type: .pickup)
        viewModel.addStop(name: "Now", time: now, type: .pickup)
        
        viewModel.sortStopsByTime()
        
        XCTAssertEqual(viewModel.stops[0].name, "Earlier")
        XCTAssertEqual(viewModel.stops[1].name, "Now")
        XCTAssertEqual(viewModel.stops[2].name, "Later")
    }
    
    func testClearAllStops() {
        // Add some stops
        viewModel.addStop(name: "Home", time: Date(), type: .pickup)
        viewModel.addStop(name: "School", time: Date().addingTimeInterval(600), type: .dropoff)
        
        XCTAssertEqual(viewModel.stops.count, 2)
        
        viewModel.clearAllStops()
        
        XCTAssertEqual(viewModel.stops.count, 0)
    }
    
    // MARK: - Run Creation and Saving Tests
    
    func testSaveValidRun() async {
        // Set up valid form
        viewModel.title = "Morning School Run"
        viewModel.selectedDate = Date()
        
        let now = Date()
        let stop1 = RunStop(name: "Home", time: now, type: .pickup)
        let stop2 = RunStop(name: "School", time: now.addingTimeInterval(600), type: .dropoff)
        viewModel.stops = [stop1, stop2]
        
        let savedRun = await viewModel.saveRun()
        
        XCTAssertNotNil(savedRun)
        XCTAssertEqual(savedRun?.title, "Morning School Run")
        XCTAssertEqual(savedRun?.route.count, 2)
        XCTAssertEqual(savedRun?.status, .scheduled)
        
        // Verify form is cleared after save
        XCTAssertEqual(viewModel.title, "")
        XCTAssertTrue(viewModel.stops.isEmpty)
        XCTAssertFalse(viewModel.hasUnsavedChanges)
    }
    
    func testSaveInvalidRun() async {
        // Set up invalid form (no title)
        viewModel.title = ""
        viewModel.selectedDate = Date()
        
        let savedRun = await viewModel.saveRun()
        
        XCTAssertNil(savedRun)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.errorMessage, "Please fix validation errors before saving")
    }
    
    func testValidateAndSave() async {
        // Set up valid form
        viewModel.title = "Test Run"
        viewModel.selectedDate = Date()
        
        let now = Date()
        let stop = RunStop(name: "Home", time: now, type: .pickup)
        viewModel.stops = [stop]
        
        let savedRun = await viewModel.validateAndSave()
        
        XCTAssertNotNil(savedRun)
        XCTAssertTrue(viewModel.isValid)
    }
    
    // MARK: - Form Management Tests
    
    func testClearForm() {
        // Set up form with data
        viewModel.title = "Test Run"
        viewModel.selectedDate = Date().addingTimeInterval(3600)
        viewModel.addStop(name: "Home", time: Date(), type: .pickup)
        viewModel.errorMessage = "Test error"
        
        viewModel.clearForm()
        
        XCTAssertEqual(viewModel.title, "")
        XCTAssertTrue(viewModel.stops.isEmpty)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.hasUnsavedChanges)
    }
    
    func testLoadRun() {
        let existingRun = SchoolRun(
            title: "Existing Run",
            date: Date().addingTimeInterval(3600),
            route: [
                RunStop(name: "Home", time: Date(), type: .pickup),
                RunStop(name: "School", time: Date().addingTimeInterval(600), type: .dropoff)
            ]
        )
        
        viewModel.loadRun(existingRun)
        
        XCTAssertEqual(viewModel.title, "Existing Run")
        XCTAssertEqual(viewModel.selectedDate, existingRun.date)
        XCTAssertEqual(viewModel.stops.count, 2)
        XCTAssertEqual(viewModel.stops[0].name, "Home")
        XCTAssertEqual(viewModel.stops[1].name, "School")
    }
    
    // MARK: - Computed Properties Tests
    
    func testHasUnsavedChanges() {
        XCTAssertFalse(viewModel.hasUnsavedChanges)
        
        viewModel.title = "Test"
        XCTAssertTrue(viewModel.hasUnsavedChanges)
        
        viewModel.title = ""
        viewModel.addStop()
        XCTAssertTrue(viewModel.hasUnsavedChanges)
    }
    
    func testEstimatedDuration() {
        let now = Date()
        let stop1 = RunStop(name: "Home", time: now, type: .pickup)
        let stop2 = RunStop(name: "School", time: now.addingTimeInterval(1800), type: .dropoff) // 30 minutes later
        
        viewModel.stops = [stop1, stop2]
        
        XCTAssertEqual(viewModel.estimatedDuration, 1800) // 30 minutes in seconds
        XCTAssertEqual(viewModel.estimatedDurationText, "30m")
    }
    
    func testEstimatedDurationWithHours() {
        let now = Date()
        let stop1 = RunStop(name: "Home", time: now, type: .pickup)
        let stop2 = RunStop(name: "School", time: now.addingTimeInterval(3900), type: .dropoff) // 1 hour 5 minutes later
        
        viewModel.stops = [stop1, stop2]
        
        XCTAssertEqual(viewModel.estimatedDuration, 3900)
        XCTAssertEqual(viewModel.estimatedDurationText, "1h 5m")
    }
    
    func testNextAvailableTime() {
        let now = Date()
        
        // No stops - should be 15 minutes from selected date
        let expectedTime = Calendar.current.date(byAdding: .minute, value: 15, to: viewModel.selectedDate)!
        XCTAssertEqual(viewModel.nextAvailableTime.timeIntervalSince1970, expectedTime.timeIntervalSince1970, accuracy: 1)
        
        // With stops - should be 15 minutes after last stop
        let stop = RunStop(name: "Home", time: now, type: .pickup)
        viewModel.stops = [stop]
        
        let expectedNextTime = Calendar.current.date(byAdding: .minute, value: 15, to: now)!
        XCTAssertEqual(viewModel.nextAvailableTime.timeIntervalSince1970, expectedNextTime.timeIntervalSince1970, accuracy: 1)
    }
    
    func testStopTypeFiltering() {
        let pickupStop = RunStop(name: "Home", time: Date(), type: .pickup)
        let dropoffStop = RunStop(name: "School", time: Date().addingTimeInterval(600), type: .dropoff)
        
        viewModel.stops = [pickupStop, dropoffStop]
        
        XCTAssertEqual(viewModel.pickupStops.count, 1)
        XCTAssertEqual(viewModel.dropoffStops.count, 1)
        XCTAssertTrue(viewModel.hasMixedStopTypes)
        
        XCTAssertEqual(viewModel.pickupStops.first?.name, "Home")
        XCTAssertEqual(viewModel.dropoffStops.first?.name, "School")
    }
    
    func testRunSummary() {
        // Test with no stops
        XCTAssertEqual(viewModel.runSummary, "0 stops")
        
        // Test with mixed stop types
        let pickupStop = RunStop(name: "Home", time: Date(), type: .pickup)
        let dropoffStop = RunStop(name: "School", time: Date().addingTimeInterval(600), type: .dropoff)
        viewModel.stops = [pickupStop, dropoffStop]
        
        let summary = viewModel.runSummary
        XCTAssertTrue(summary.contains("2 stops"))
        XCTAssertTrue(summary.contains("1 pickup, 1 dropoff"))
        XCTAssertTrue(summary.contains("10m")) // Duration
    }
    
    // MARK: - Error Handling Tests
    
    func testStopValidationErrors() {
        let stop = RunStop(name: "", time: Date(), type: .pickup)
        viewModel.stops = [stop]
        
        let errors = viewModel.getStopValidationErrors(for: stop.id)
        
        XCTAssertTrue(errors.contains("Stop name is required"))
    }
    
    func testStopNameTooLong() {
        let longName = String(repeating: "A", count: 31)
        let stop = RunStop(name: longName, time: Date(), type: .pickup)
        viewModel.stops = [stop]
        
        let errors = viewModel.getStopValidationErrors(for: stop.id)
        
        XCTAssertTrue(errors.contains("Stop name must be less than 30 characters"))
    }
    
    func testClearErrors() {
        viewModel.errorMessage = "Test error"
        viewModel.titleError = "Title error"
        viewModel.dateError = "Date error"
        viewModel.stopsError = "Stops error"
        
        viewModel.clearErrors()
        
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.titleError)
        XCTAssertNil(viewModel.dateError)
        XCTAssertNil(viewModel.stopsError)
    }
    
    // MARK: - Date Validation Edge Cases
    
    func testIsDateValid() {
        let calendar = Calendar.current
        
        // Test today (should be valid)
        viewModel.selectedDate = Date()
        XCTAssertTrue(viewModel.isDateValid)
        
        // Test yesterday (should be invalid)
        viewModel.selectedDate = calendar.date(byAdding: .day, value: -1, to: Date())!
        XCTAssertFalse(viewModel.isDateValid)
        
        // Test tomorrow (should be valid)
        viewModel.selectedDate = calendar.date(byAdding: .day, value: 1, to: Date())!
        XCTAssertTrue(viewModel.isDateValid)
        
        // Test 1 year from now (should be valid)
        viewModel.selectedDate = calendar.date(byAdding: .year, value: 1, to: Date())!
        XCTAssertTrue(viewModel.isDateValid)
        
        // Test more than 1 year from now (should be invalid)
        viewModel.selectedDate = calendar.date(byAdding: .day, value: 366, to: Date())!
        XCTAssertFalse(viewModel.isDateValid)
    }
}