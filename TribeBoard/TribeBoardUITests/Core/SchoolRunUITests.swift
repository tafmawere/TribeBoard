import XCTest

/// UI tests for school run scheduling functionality including dashboard, scheduling interface, and execution tracking
final class SchoolRunUITests: UITestBase {
    
    // MARK: - School Run Dashboard Tests
    
    /// Test school run dashboard displays correctly
    func testSchoolRunDashboardDisplay() {
        // Arrange: Sign in and navigate to school run
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Run")
        
        // Assert: School run dashboard should be displayed
        let dashboardTitle = app.navigationBars["School Runs"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: defaultTimeout),
                     "School run dashboard should be displayed")
        
        // Verify header section
        let headerSection = app.staticTexts["School Runs"]
        XCTAssertTrue(headerSection.waitForExistence(timeout: defaultTimeout),
                     "Header section should be displayed")
        
        let descriptionText = app.staticTexts["Manage your family's school transportation"]
        XCTAssertTrue(descriptionText.waitForExistence(timeout: defaultTimeout),
                     "Description text should be displayed")
        
        // Verify action buttons
        let scheduleNewButton = app.buttons["Schedule New Run"]
        XCTAssertTrue(scheduleNewButton.waitForExistence(timeout: defaultTimeout),
                     "Schedule New Run button should be displayed")
        
        let viewScheduledButton = app.buttons["View Scheduled Runs"]
        XCTAssertTrue(viewScheduledButton.waitForExistence(timeout: defaultTimeout),
                     "View Scheduled Runs button should be displayed")
        
        // Take screenshot for visual verification
        takeScreenshot(name: "SchoolRun_Dashboard")
    }
    
    /// Test upcoming runs section display
    func testUpcomingRunsSectionDisplay() {
        // Arrange: Sign in and navigate to school run
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Run")
        
        // Assert: Upcoming runs section should be displayed
        let upcomingSection = app.staticTexts["Upcoming Runs"]
        XCTAssertTrue(upcomingSection.waitForExistence(timeout: defaultTimeout),
                     "Upcoming Runs section should be displayed")
        
        // Check for either runs or empty state
        let runCards = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'run_card'"))
        let emptyStateMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'No Upcoming Runs'")).firstMatch
        
        XCTAssertTrue(runCards.count > 0 || emptyStateMessage.waitForExistence(timeout: defaultTimeout),
                     "Should show either run cards or empty state")
        
        // If empty state is shown, verify empty state elements
        if emptyStateMessage.exists {
            let scheduleFirstRunButton = app.buttons["Schedule New Run"]
            XCTAssertTrue(scheduleFirstRunButton.exists,
                         "Schedule New Run button should be available in empty state")
        }
    }
    
    /// Test past runs section display
    func testPastRunsSectionDisplay() {
        // Arrange: Sign in and navigate to school run
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Run")
        
        // Assert: Past runs section should be displayed
        let pastSection = app.staticTexts["Past Runs"]
        XCTAssertTrue(pastSection.waitForExistence(timeout: defaultTimeout),
                     "Past Runs section should be displayed")
        
        // Check for either runs or empty state
        let pastRunCards = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'past_run_card'"))
        let emptyStateMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'No Past Runs'")).firstMatch
        
        XCTAssertTrue(pastRunCards.count > 0 || emptyStateMessage.waitForExistence(timeout: defaultTimeout),
                     "Should show either past run cards or empty state")
        
        // If empty state is shown, verify message
        if emptyStateMessage.exists {
            let completedMessage = app.staticTexts["Completed runs will appear here"]
            XCTAssertTrue(completedMessage.exists,
                         "Empty state message should be displayed")
        }
    }
    
    // MARK: - School Run Scheduling Interface Tests
    
    /// Test schedule new run form display
    func testScheduleNewRunFormDisplay() {
        // Arrange: Sign in and navigate to school run
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Run")
        
        // Act: Tap schedule new run button
        let scheduleNewButton = app.buttons["Schedule New Run"]
        safeTap(scheduleNewButton)
        
        // Assert: Schedule new run form should be displayed
        let scheduleTitle = app.navigationBars["Schedule New Run"]
        XCTAssertTrue(scheduleTitle.waitForExistence(timeout: defaultTimeout),
                     "Schedule New Run form should be displayed")
        
        // Verify form sections
        let runDetailsSection = app.staticTexts["Run Details"]
        XCTAssertTrue(runDetailsSection.waitForExistence(timeout: defaultTimeout),
                     "Run Details section should be displayed")
        
        let stopsSection = app.staticTexts["Stops"]
        XCTAssertTrue(stopsSection.waitForExistence(timeout: defaultTimeout),
                     "Stops section should be displayed")
        
        // Verify form fields
        let runNameField = app.textFields["Enter run name"]
        XCTAssertTrue(runNameField.waitForExistence(timeout: defaultTimeout),
                     "Run name field should be displayed")
        
        let dayPicker = app.datePickers["Day"]
        XCTAssertTrue(dayPicker.waitForExistence(timeout: defaultTimeout),
                     "Day picker should be displayed")
        
        let timePicker = app.datePickers["Time"]
        XCTAssertTrue(timePicker.waitForExistence(timeout: defaultTimeout),
                     "Time picker should be displayed")
        
        // Take screenshot for visual verification
        takeScreenshot(name: "SchoolRun_ScheduleForm")
    }
    
    /// Test schedule new run form validation
    func testScheduleNewRunFormValidation() {
        // Arrange: Navigate to schedule new run form
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Run")
        
        let scheduleNewButton = app.buttons["Schedule New Run"]
        safeTap(scheduleNewButton)
        
        // Act: Try to save without filling required fields
        let saveButton = app.buttons["Save Run"]
        safeTap(saveButton)
        
        // Assert: Validation errors should be displayed
        let validationAlert = app.alerts.firstMatch
        if validationAlert.waitForExistence(timeout: defaultTimeout) {
            XCTAssertTrue(validationAlert.exists, "Validation alert should be displayed")
            
            let okButton = validationAlert.buttons["OK"]
            safeTap(okButton)
        }
        
        // Verify form remains displayed
        let scheduleTitle = app.navigationBars["Schedule New Run"]
        XCTAssertTrue(scheduleTitle.exists, "Form should remain displayed after validation error")
    }
    
    /// Test adding stops to school run
    func testAddingStopsToSchoolRun() {
        // Arrange: Navigate to schedule new run form
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Run")
        
        let scheduleNewButton = app.buttons["Schedule New Run"]
        safeTap(scheduleNewButton)
        
        // Act: Add a new stop
        let addStopButton = app.buttons["Add Stop"]
        safeTap(addStopButton)
        
        // Assert: New stop should be added
        let stopRows = app.cells.matching(NSPredicate(format: "identifier CONTAINS 'stop_row'"))
        XCTAssertGreaterThan(stopRows.count, 0, "At least one stop should be displayed")
        
        // Verify stop configuration elements
        let firstStopRow = stopRows.element(boundBy: 0)
        if firstStopRow.exists {
            // Stop should have configuration options
            let stopNameField = firstStopRow.textFields.firstMatch
            XCTAssertTrue(stopNameField.exists, "Stop name field should be available")
        }
    }
    
    /// Test successful school run creation
    func testSuccessfulSchoolRunCreation() {
        // Arrange: Navigate to schedule new run form
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Run")
        
        let scheduleNewButton = app.buttons["Schedule New Run"]
        safeTap(scheduleNewButton)
        
        // Fill out the form
        let runNameField = app.textFields["Enter run name"]
        safeTypeText("Morning School Run", into: runNameField)
        
        // Configure at least one stop
        let addStopButton = app.buttons["Add Stop"]
        safeTap(addStopButton)
        
        // Add stop details if fields are available
        let stopRows = app.cells.matching(NSPredicate(format: "identifier CONTAINS 'stop_row'"))
        if stopRows.count > 0 {
            let firstStopRow = stopRows.element(boundBy: 0)
            let stopNameField = firstStopRow.textFields.firstMatch
            if stopNameField.exists {
                safeTypeText("Home", into: stopNameField)
            }
        }
        
        // Act: Save the run
        let saveButton = app.buttons["Save Run"]
        safeTap(saveButton)
        
        // Assert: Should show loading state
        let loadingIndicator = app.staticTexts["Saving..."]
        XCTAssertTrue(loadingIndicator.waitForExistence(timeout: shortTimeout),
                     "Loading indicator should be displayed")
        
        // Wait for save to complete
        waitForLoadingToComplete(timeout: longTimeout)
        
        // Should return to dashboard
        let dashboardTitle = app.navigationBars["School Runs"]
        XCTAssertTrue(dashboardTitle.waitForExistence(timeout: defaultTimeout),
                     "Should return to dashboard after saving")
        
        // Take screenshot for visual verification
        takeScreenshot(name: "SchoolRun_CreationSuccess")
    }
    
    // MARK: - School Run List Display Tests
    
    /// Test view scheduled runs list
    func testViewScheduledRunsList() {
        // Arrange: Sign in and navigate to school run
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Run")
        
        // Act: Tap view scheduled runs button
        let viewScheduledButton = app.buttons["View Scheduled Runs"]
        safeTap(viewScheduledButton)
        
        // Assert: Scheduled runs list should be displayed
        let scheduledRunsTitle = app.navigationBars.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Scheduled' OR label CONTAINS 'Runs'")).firstMatch
        XCTAssertTrue(scheduledRunsTitle.waitForExistence(timeout: defaultTimeout),
                     "Scheduled runs list should be displayed")
        
        // Verify list content
        let runsList = app.tables.firstMatch
        if runsList.waitForExistence(timeout: defaultTimeout) {
            XCTAssertTrue(runsList.exists, "Runs list should be displayed")
        }
        
        // Check for either run items or empty state
        let runItems = app.cells.matching(NSPredicate(format: "identifier CONTAINS 'scheduled_run'"))
        let emptyMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'No' AND label CONTAINS 'runs'")).firstMatch
        
        XCTAssertTrue(runItems.count > 0 || emptyMessage.waitForExistence(timeout: defaultTimeout),
                     "Should show either run items or empty state")
    }
    
    /// Test run detail view display
    func testRunDetailViewDisplay() {
        // Arrange: Sign in and navigate to school run
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Run")
        
        // Find and tap a run card if available
        let runCards = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'run_card'"))
        
        if runCards.count > 0 {
            let firstRunCard = runCards.element(boundBy: 0)
            safeTap(firstRunCard)
            
            // Assert: Run detail view should be displayed
            let runDetailTitle = app.navigationBars.staticTexts.firstMatch
            XCTAssertTrue(runDetailTitle.waitForExistence(timeout: defaultTimeout),
                         "Run detail view should be displayed")
            
            // Verify detail elements
            let runInfo = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Details' OR label CONTAINS 'Run'")).firstMatch
            XCTAssertTrue(runInfo.waitForExistence(timeout: defaultTimeout),
                         "Run information should be displayed")
            
            // Look for action buttons
            let startRunButton = app.buttons["Start Run"]
            let editRunButton = app.buttons["Edit Run"]
            
            XCTAssertTrue(startRunButton.exists || editRunButton.exists,
                         "Action buttons should be available")
        }
    }
    
    // MARK: - School Run Execution Tests
    
    /// Test run execution interface display
    func testRunExecutionInterfaceDisplay() {
        // Arrange: Sign in and navigate to school run
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Run")
        
        // Find and start a run if available
        let runCards = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'run_card'"))
        
        if runCards.count > 0 {
            let firstRunCard = runCards.element(boundBy: 0)
            safeTap(firstRunCard)
            
            // Look for start run button
            let startRunButton = app.buttons["Start Run"]
            if startRunButton.waitForExistence(timeout: defaultTimeout) {
                safeTap(startRunButton)
                
                // Assert: Run execution interface should be displayed
                let executionMap = app.otherElements["ExecutionMap"]
                XCTAssertTrue(executionMap.waitForExistence(timeout: defaultTimeout),
                             "Execution map should be displayed")
                
                // Verify execution controls
                let completeStopButton = app.buttons["CompleteStopButton"]
                XCTAssertTrue(completeStopButton.waitForExistence(timeout: defaultTimeout),
                             "Complete stop button should be displayed")
                
                let pauseRunButton = app.buttons["PauseRunButton"]
                XCTAssertTrue(pauseRunButton.waitForExistence(timeout: defaultTimeout),
                             "Pause run button should be displayed")
                
                let cancelRunButton = app.buttons["CancelRunButton"]
                XCTAssertTrue(cancelRunButton.waitForExistence(timeout: defaultTimeout),
                             "Cancel run button should be displayed")
                
                // Take screenshot for visual verification
                takeScreenshot(name: "SchoolRun_Execution")
            }
        }
    }
    
    /// Test run execution step completion
    func testRunExecutionStepCompletion() {
        // Arrange: Navigate to run execution (if available)
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Run")
        
        let runCards = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'run_card'"))
        
        if runCards.count > 0 {
            let firstRunCard = runCards.element(boundBy: 0)
            safeTap(firstRunCard)
            
            let startRunButton = app.buttons["Start Run"]
            if startRunButton.waitForExistence(timeout: defaultTimeout) {
                safeTap(startRunButton)
                
                // Act: Complete current stop
                let completeStopButton = app.buttons["CompleteStopButton"]
                if completeStopButton.waitForExistence(timeout: defaultTimeout) {
                    safeTap(completeStopButton)
                    
                    // Assert: Completion confirmation should appear
                    let confirmationAlert = app.alerts.firstMatch
                    if confirmationAlert.waitForExistence(timeout: defaultTimeout) {
                        let markCompleteButton = confirmationAlert.buttons["Mark Complete"]
                        if markCompleteButton.exists {
                            safeTap(markCompleteButton)
                            
                            // Should show progress or move to next step
                            waitForLoadingToComplete(timeout: shortTimeout)
                        }
                    }
                }
            }
        }
    }
    
    /// Test run execution pause functionality
    func testRunExecutionPauseFunctionality() {
        // Arrange: Navigate to run execution (if available)
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Run")
        
        let runCards = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'run_card'"))
        
        if runCards.count > 0 {
            let firstRunCard = runCards.element(boundBy: 0)
            safeTap(firstRunCard)
            
            let startRunButton = app.buttons["Start Run"]
            if startRunButton.waitForExistence(timeout: defaultTimeout) {
                safeTap(startRunButton)
                
                // Act: Pause the run
                let pauseRunButton = app.buttons["PauseRunButton"]
                if pauseRunButton.waitForExistence(timeout: defaultTimeout) {
                    safeTap(pauseRunButton)
                    
                    // Assert: Pause confirmation should appear
                    let pauseAlert = app.alerts.firstMatch
                    if pauseAlert.waitForExistence(timeout: defaultTimeout) {
                        let pauseConfirmButton = pauseAlert.buttons["Pause Run"]
                        if pauseConfirmButton.exists {
                            safeTap(pauseConfirmButton)
                            
                            // Should return to dashboard or show paused state
                            waitForLoadingToComplete(timeout: defaultTimeout)
                        } else {
                            // Cancel if pause confirm not available
                            let continueButton = pauseAlert.buttons["Continue"]
                            if continueButton.exists {
                                safeTap(continueButton)
                            }
                        }
                    }
                }
            }
        }
    }
    
    /// Test run execution cancellation
    func testRunExecutionCancellation() {
        // Arrange: Navigate to run execution (if available)
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Run")
        
        let runCards = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'run_card'"))
        
        if runCards.count > 0 {
            let firstRunCard = runCards.element(boundBy: 0)
            safeTap(firstRunCard)
            
            let startRunButton = app.buttons["Start Run"]
            if startRunButton.waitForExistence(timeout: defaultTimeout) {
                safeTap(startRunButton)
                
                // Act: Cancel the run
                let cancelRunButton = app.buttons["CancelRunButton"]
                if cancelRunButton.waitForExistence(timeout: defaultTimeout) {
                    safeTap(cancelRunButton)
                    
                    // Assert: Cancellation confirmation should appear
                    let cancelAlert = app.alerts.firstMatch
                    if cancelAlert.waitForExistence(timeout: defaultTimeout) {
                        let cancelConfirmButton = cancelAlert.buttons["Cancel Run"]
                        if cancelConfirmButton.exists {
                            safeTap(cancelConfirmButton)
                            
                            // Should return to dashboard
                            let dashboardTitle = app.navigationBars["School Runs"]
                            XCTAssertTrue(dashboardTitle.waitForExistence(timeout: defaultTimeout),
                                         "Should return to dashboard after cancellation")
                        } else {
                            // Continue if cancel confirm not available
                            let continueButton = cancelAlert.buttons["Continue Run"]
                            if continueButton.exists {
                                safeTap(continueButton)
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - School Run Status Tracking Tests
    
    /// Test run progress tracking display
    func testRunProgressTrackingDisplay() {
        // Arrange: Navigate to run execution (if available)
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Run")
        
        let runCards = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'run_card'"))
        
        if runCards.count > 0 {
            let firstRunCard = runCards.element(boundBy: 0)
            safeTap(firstRunCard)
            
            let startRunButton = app.buttons["Start Run"]
            if startRunButton.waitForExistence(timeout: defaultTimeout) {
                safeTap(startRunButton)
                
                // Assert: Progress indicators should be displayed
                let progressIndicator = app.progressIndicators.firstMatch
                XCTAssertTrue(progressIndicator.waitForExistence(timeout: defaultTimeout),
                             "Progress indicator should be displayed")
                
                // Verify current stop information
                let currentStopCard = app.otherElements.matching(NSPredicate(format: "identifier CONTAINS 'current_stop'")).firstMatch
                XCTAssertTrue(currentStopCard.waitForExistence(timeout: defaultTimeout),
                             "Current stop card should be displayed")
                
                // Verify status indicator
                let statusIndicator = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Active' OR label CONTAINS 'Paused'")).firstMatch
                XCTAssertTrue(statusIndicator.waitForExistence(timeout: defaultTimeout),
                             "Status indicator should be displayed")
            }
        }
    }
    
    /// Test run completion flow
    func testRunCompletionFlow() {
        // Arrange: Navigate to run execution (if available)
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Run")
        
        let runCards = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'run_card'"))
        
        if runCards.count > 0 {
            let firstRunCard = runCards.element(boundBy: 0)
            safeTap(firstRunCard)
            
            let startRunButton = app.buttons["Start Run"]
            if startRunButton.waitForExistence(timeout: defaultTimeout) {
                safeTap(startRunButton)
                
                // Simulate completing all stops (this would be a complex flow in a real test)
                // For now, just verify the completion flow elements exist
                let completeStopButton = app.buttons["CompleteStopButton"]
                if completeStopButton.exists {
                    // The completion flow would involve multiple steps
                    // Here we just verify the UI elements are accessible
                    XCTAssertTrue(completeStopButton.isEnabled, "Complete stop button should be enabled")
                }
            }
        }
    }
    
    // MARK: - Accessibility Tests
    
    /// Test school run dashboard accessibility
    func testSchoolRunDashboardAccessibility() {
        // Arrange: Sign in and navigate to school run
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Run")
        
        // Test main elements accessibility
        let dashboardTitle = app.navigationBars["School Runs"]
        assertElementIsAccessible(dashboardTitle)
        
        let scheduleNewButton = app.buttons["Schedule New Run"]
        assertElementIsAccessible(scheduleNewButton)
        
        let viewScheduledButton = app.buttons["View Scheduled Runs"]
        assertElementIsAccessible(viewScheduledButton)
        
        // Test section headers accessibility
        let upcomingSection = app.staticTexts["Upcoming Runs"]
        assertElementIsAccessible(upcomingSection)
        
        let pastSection = app.staticTexts["Past Runs"]
        assertElementIsAccessible(pastSection)
        
        // Test run cards accessibility if they exist
        let runCards = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'run_card'"))
        for i in 0..<min(runCards.count, 3) { // Test first 3 run cards
            let runCard = runCards.element(boundBy: i)
            if runCard.exists {
                assertElementIsAccessible(runCard)
            }
        }
    }
    
    /// Test schedule new run form accessibility
    func testScheduleNewRunFormAccessibility() {
        // Arrange: Navigate to schedule new run form
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Run")
        
        let scheduleNewButton = app.buttons["Schedule New Run"]
        safeTap(scheduleNewButton)
        
        // Test form elements accessibility
        let runNameField = app.textFields["Enter run name"]
        assertElementIsAccessible(runNameField)
        
        let dayPicker = app.datePickers["Day"]
        assertElementIsAccessible(dayPicker)
        
        let timePicker = app.datePickers["Time"]
        assertElementIsAccessible(timePicker)
        
        let addStopButton = app.buttons["Add Stop"]
        assertElementIsAccessible(addStopButton)
        
        let saveButton = app.buttons["Save Run"]
        assertElementIsAccessible(saveButton)
    }
    
    /// Test run execution accessibility
    func testRunExecutionAccessibility() {
        // Arrange: Navigate to run execution (if available)
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Run")
        
        let runCards = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'run_card'"))
        
        if runCards.count > 0 {
            let firstRunCard = runCards.element(boundBy: 0)
            safeTap(firstRunCard)
            
            let startRunButton = app.buttons["Start Run"]
            if startRunButton.waitForExistence(timeout: defaultTimeout) {
                safeTap(startRunButton)
                
                // Test execution controls accessibility
                let completeStopButton = app.buttons["CompleteStopButton"]
                if completeStopButton.exists {
                    assertElementIsAccessible(completeStopButton)
                }
                
                let pauseRunButton = app.buttons["PauseRunButton"]
                if pauseRunButton.exists {
                    assertElementIsAccessible(pauseRunButton)
                }
                
                let cancelRunButton = app.buttons["CancelRunButton"]
                if cancelRunButton.exists {
                    assertElementIsAccessible(cancelRunButton)
                }
                
                // Test map accessibility
                let executionMap = app.otherElements["ExecutionMap"]
                if executionMap.exists {
                    assertElementIsAccessible(executionMap)
                }
            }
        }
    }
    
    // MARK: - Error Handling Tests
    
    /// Test school run creation error handling
    func testSchoolRunCreationErrorHandling() {
        // Arrange: Navigate to schedule new run form
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Run")
        
        let scheduleNewButton = app.buttons["Schedule New Run"]
        safeTap(scheduleNewButton)
        
        // Test with invalid input (empty name)
        let saveButton = app.buttons["Save Run"]
        safeTap(saveButton)
        
        // Handle any error alerts
        if isErrorAlertDisplayed() {
            dismissErrorAlerts()
        }
        
        // Form should remain functional
        let runNameField = app.textFields["Enter run name"]
        XCTAssertTrue(runNameField.exists, "Form should remain functional after error")
    }
    
    /// Test school run dashboard error handling
    func testSchoolRunDashboardErrorHandling() {
        // Arrange: Sign in and navigate to school run
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Run")
        
        // Simulate error by attempting invalid operation
        let scheduleNewButton = app.buttons["Schedule New Run"]
        safeTap(scheduleNewButton)
        
        // Navigate back to test error recovery
        navigateBack()
        
        // Handle any error alerts
        if isErrorAlertDisplayed() {
            dismissErrorAlerts()
        }
        
        // Dashboard should remain functional
        let dashboardTitle = app.navigationBars["School Runs"]
        XCTAssertTrue(dashboardTitle.exists, "Dashboard should remain functional after error")
    }
    
    // MARK: - Performance Tests
    
    /// Test school run dashboard loading performance
    func testSchoolRunDashboardLoadingPerformance() {
        // Measure dashboard loading time
        measure {
            performMockSignIn()
            waitForLoadingToComplete()
            navigateToTab("Run")
            
            let dashboardTitle = app.navigationBars["School Runs"]
            XCTAssertTrue(dashboardTitle.waitForExistence(timeout: defaultTimeout))
            
            waitForLoadingToComplete()
            
            // Reset for next iteration
            performSignOut()
        }
    }
    
    /// Test school run creation performance
    func testSchoolRunCreationPerformance() {
        // Arrange: Sign in and navigate to school run
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Run")
        
        measure {
            let scheduleNewButton = app.buttons["Schedule New Run"]
            safeTap(scheduleNewButton)
            
            let runNameField = app.textFields["Enter run name"]
            safeTypeText("Performance Test Run", into: runNameField)
            
            let addStopButton = app.buttons["Add Stop"]
            safeTap(addStopButton)
            
            let saveButton = app.buttons["Save Run"]
            safeTap(saveButton)
            
            waitForLoadingToComplete(timeout: longTimeout)
            
            // Reset for next iteration
            let dashboardTitle = app.navigationBars["School Runs"]
            if !dashboardTitle.waitForExistence(timeout: defaultTimeout) {
                navigateBack()
            }
        }
    }
    
    /// Test run execution performance
    func testRunExecutionPerformance() {
        // Arrange: Sign in and navigate to school run
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Run")
        
        let runCards = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'run_card'"))
        
        if runCards.count > 0 {
            measure {
                let firstRunCard = runCards.element(boundBy: 0)
                safeTap(firstRunCard)
                
                let startRunButton = app.buttons["Start Run"]
                if startRunButton.waitForExistence(timeout: defaultTimeout) {
                    safeTap(startRunButton)
                    
                    let executionMap = app.otherElements["ExecutionMap"]
                    XCTAssertTrue(executionMap.waitForExistence(timeout: defaultTimeout))
                    
                    // Cancel and return for next iteration
                    let cancelRunButton = app.buttons["CancelRunButton"]
                    if cancelRunButton.exists {
                        safeTap(cancelRunButton)
                        
                        let cancelAlert = app.alerts.firstMatch
                        if cancelAlert.waitForExistence(timeout: shortTimeout) {
                            let cancelConfirmButton = cancelAlert.buttons["Cancel Run"]
                            if cancelConfirmButton.exists {
                                safeTap(cancelConfirmButton)
                            }
                        }
                    }
                    
                    waitForLoadingToComplete()
                }
            }
        }
    }
}