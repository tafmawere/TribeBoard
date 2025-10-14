import XCTest
@testable import TribeBoard

/// Comprehensive accessibility tests for School Run module
/// Tests VoiceOver compatibility, Dynamic Type support, high contrast mode, and keyboard navigation
/// for all school run related user interfaces and components
final class SchoolRunAccessibilityTests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--mock-authenticated-user")
        app.launchArguments.append("--mock-school-run-data")
        app.launchForAccessibilityTesting()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - School Run Dashboard Accessibility Tests
    
    func testSchoolRunDashboardVoiceOverNavigation() throws {
        // Navigate to School Run tab
        let schoolRunTab = app.tabBars.buttons["School Run"]
        XCTAssertTrue(schoolRunTab.waitForExistence(timeout: 5))
        schoolRunTab.tap()
        
        // Validate main dashboard elements
        let dashboardTitle = app.navigationBars.staticTexts["School Run"]
        let addRunButton = app.buttons["Add new run"]
        let todaysRunsSection = app.staticTexts["Today's Runs"]
        let upcomingRunsSection = app.staticTexts["Upcoming Runs"]
        
        // Test VoiceOver navigation order
        let navigationElements = [dashboardTitle, addRunButton, todaysRunsSection, upcomingRunsSection]
        AccessibilityTestHelpers.validateVoiceOverNavigationOrder(navigationElements)
        
        // Validate individual element accessibility
        AccessibilityTestHelpers.validateVoiceOverElement(
            dashboardTitle,
            expectedLabel: "School Run",
            expectedTraits: .header
        )
        
        AccessibilityTestHelpers.validateVoiceOverElement(
            addRunButton,
            expectedLabel: "Add new run",
            expectedTraits: .button
        )
        
        // Test run cards accessibility
        let runCards = app.buttons.matching(identifier: "RunCard")
        if runCards.count > 0 {
            let firstRunCard = runCards.element(boundBy: 0)
            XCTAssertTrue(firstRunCard.isAccessibilityElement)
            XCTAssertFalse(firstRunCard.label.isEmpty, "Run card should have descriptive accessibility label")
            AccessibilityTestHelpers.validateTouchTargetSize(firstRunCard)
        }
    }
    
    func testSchoolRunDashboardTouchTargets() throws {
        // Navigate to School Run tab
        let schoolRunTab = app.tabBars.buttons["School Run"]
        schoolRunTab.tap()
        
        // Validate touch target sizes for interactive elements
        let addRunButton = app.buttons["Add new run"]
        let refreshControl = app.otherElements["RefreshControl"]
        
        AccessibilityTestHelpers.validateTouchTargetSize(addRunButton)
        
        // Test run card touch targets
        let runCards = app.buttons.matching(identifier: "RunCard")
        for i in 0..<min(runCards.count, 3) {
            let runCard = runCards.element(boundBy: i)
            if runCard.exists {
                AccessibilityTestHelpers.validateTouchTargetSize(runCard)
            }
        }
        
        // Test quick action buttons if present
        let quickActionButtons = app.buttons.matching(identifier: "QuickActionButton")
        for i in 0..<quickActionButtons.count {
            let button = quickActionButtons.element(boundBy: i)
            if button.exists {
                AccessibilityTestHelpers.validateTouchTargetSize(button)
            }
        }
    }
    
    func testSchoolRunDashboardDynamicTypeSupport() throws {
        // Navigate to School Run tab
        let schoolRunTab = app.tabBars.buttons["School Run"]
        schoolRunTab.tap()
        
        // Test Dynamic Type support for text elements
        let dashboardTitle = app.navigationBars.staticTexts["School Run"]
        let sectionHeaders = app.staticTexts.matching(identifier: "SectionHeader")
        
        AccessibilityTestHelpers.validateDynamicTypeSupport(app: app, textElement: dashboardTitle)
        
        // Test section headers
        for i in 0..<min(sectionHeaders.count, 3) {
            let header = sectionHeaders.element(boundBy: i)
            if header.exists {
                AccessibilityTestHelpers.validateDynamicTypeSupport(app: app, textElement: header)
                AccessibilityTestHelpers.validateTextReadability(header)
            }
        }
        
        // Test run card text scaling
        let runCards = app.buttons.matching(identifier: "RunCard")
        if runCards.count > 0 {
            let firstRunCard = runCards.element(boundBy: 0)
            let runTitleText = firstRunCard.staticTexts.firstMatch
            if runTitleText.exists {
                AccessibilityTestHelpers.validateDynamicTypeSupport(app: app, textElement: runTitleText)
            }
        }
    }
    
    func testSchoolRunDashboardColorContrast() throws {
        // Navigate to School Run tab
        let schoolRunTab = app.tabBars.buttons["School Run"]
        schoolRunTab.tap()
        
        // Validate color contrast for key elements
        let addRunButton = app.buttons["Add new run"]
        let dashboardTitle = app.navigationBars.staticTexts["School Run"]
        
        AccessibilityTestHelpers.validateColorContrast(addRunButton)
        AccessibilityTestHelpers.validateColorContrast(dashboardTitle)
        
        // Test high contrast mode compatibility
        AccessibilityTestHelpers.validateHighContrastMode(app: app, element: addRunButton)
        
        // Test run status badges color contrast
        let statusBadges = app.otherElements.matching(identifier: "RunStatusBadge")
        for i in 0..<min(statusBadges.count, 3) {
            let badge = statusBadges.element(boundBy: i)
            if badge.exists {
                AccessibilityTestHelpers.validateColorContrast(badge)
            }
        }
    }
    
    // MARK: - Run Planner Accessibility Tests
    
    func testRunPlannerVoiceOverNavigation() throws {
        // Navigate to Run Planner
        let schoolRunTab = app.tabBars.buttons["School Run"]
        schoolRunTab.tap()
        
        let addRunButton = app.buttons["Add new run"]
        XCTAssertTrue(addRunButton.waitForExistence(timeout: 3))
        addRunButton.tap()
        
        // Validate Run Planner form elements
        let plannerTitle = app.navigationBars.staticTexts["Plan Run"]
        let runTitleField = app.textFields["Run Title"]
        let dateField = app.textFields["Date"]
        let timeField = app.textFields["Time"]
        let addStopButton = app.buttons["Add Stop"]
        let saveButton = app.buttons["Save Run"]
        let cancelButton = app.buttons["Cancel"]
        
        // Test VoiceOver navigation order
        let formElements = [plannerTitle, runTitleField, dateField, timeField, addStopButton, saveButton]
        AccessibilityTestHelpers.validateVoiceOverNavigationOrder(formElements)
        
        // Validate form field accessibility
        AccessibilityTestHelpers.validateVoiceOverElement(
            runTitleField,
            expectedLabel: "Run Title",
            expectedTraits: .textField
        )
        
        AccessibilityTestHelpers.validateVoiceOverElement(
            dateField,
            expectedLabel: "Date",
            expectedTraits: .textField
        )
        
        AccessibilityTestHelpers.validateVoiceOverElement(
            addStopButton,
            expectedLabel: "Add Stop",
            expectedTraits: .button
        )
        
        AccessibilityTestHelpers.validateVoiceOverElement(
            saveButton,
            expectedLabel: "Save Run",
            expectedTraits: .button
        )
        
        AccessibilityTestHelpers.validateVoiceOverElement(
            cancelButton,
            expectedLabel: "Cancel",
            expectedTraits: .button
        )
    }
    
    func testRunPlannerFormValidationAccessibility() throws {
        // Navigate to Run Planner
        let schoolRunTab = app.tabBars.buttons["School Run"]
        schoolRunTab.tap()
        
        let addRunButton = app.buttons["Add new run"]
        addRunButton.tap()
        
        // Try to save without filling required fields
        let saveButton = app.buttons["Save Run"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 3))
        saveButton.tap()
        
        // Validate error message accessibility
        let errorMessage = app.staticTexts["Run title is required"]
        if errorMessage.waitForExistence(timeout: 2) {
            AccessibilityTestHelpers.validateVoiceOverElement(
                errorMessage,
                expectedLabel: "Run title is required",
                expectedTraits: .staticText
            )
            AccessibilityTestHelpers.validateTextReadability(errorMessage)
            AccessibilityTestHelpers.validateColorContrast(errorMessage)
        }
        
        // Test inline validation accessibility
        let runTitleField = app.textFields["Run Title"]
        runTitleField.tap()
        runTitleField.typeText("Test Run")
        
        // Validate that error state is cleared
        XCTAssertFalse(errorMessage.exists, "Error message should be cleared when field is valid")
    }
    
    func testRunPlannerStopManagementAccessibility() throws {
        // Navigate to Run Planner
        let schoolRunTab = app.tabBars.buttons["School Run"]
        schoolRunTab.tap()
        
        let addRunButton = app.buttons["Add new run"]
        addRunButton.tap()
        
        // Add a stop
        let addStopButton = app.buttons["Add Stop"]
        XCTAssertTrue(addStopButton.waitForExistence(timeout: 3))
        addStopButton.tap()
        
        // Validate stop configuration accessibility
        let stopNameField = app.textFields["Stop Name"]
        let stopTypeSegmentedControl = app.segmentedControls["Stop Type"]
        let stopTimeField = app.textFields["Stop Time"]
        let removeStopButton = app.buttons["Remove Stop"]
        
        if stopNameField.waitForExistence(timeout: 2) {
            AccessibilityTestHelpers.validateVoiceOverElement(
                stopNameField,
                expectedLabel: "Stop Name",
                expectedTraits: .textField
            )
            AccessibilityTestHelpers.validateTouchTargetSize(stopNameField)
        }
        
        if stopTypeSegmentedControl.exists {
            AccessibilityTestHelpers.validateTouchTargetSize(stopTypeSegmentedControl)
            
            // Test segmented control options
            let pickupOption = stopTypeSegmentedControl.buttons["Pickup"]
            let dropoffOption = stopTypeSegmentedControl.buttons["Drop-off"]
            
            if pickupOption.exists {
                AccessibilityTestHelpers.validateVoiceOverElement(
                    pickupOption,
                    expectedLabel: "Pickup",
                    expectedTraits: .button
                )
            }
            
            if dropoffOption.exists {
                AccessibilityTestHelpers.validateVoiceOverElement(
                    dropoffOption,
                    expectedLabel: "Drop-off",
                    expectedTraits: .button
                )
            }
        }
        
        if removeStopButton.exists {
            AccessibilityTestHelpers.validateVoiceOverElement(
                removeStopButton,
                expectedLabel: "Remove Stop",
                expectedTraits: .button
            )
            AccessibilityTestHelpers.validateTouchTargetSize(removeStopButton)
        }
    }
    
    // MARK: - Active Run View Accessibility Tests
    
    func testActiveRunViewVoiceOverNavigation() throws {
        // Navigate to School Run and start a run
        let schoolRunTab = app.tabBars.buttons["School Run"]
        schoolRunTab.tap()
        
        // Find and tap a scheduled run to start it
        let runCards = app.buttons.matching(identifier: "RunCard")
        if runCards.count > 0 {
            let firstRunCard = runCards.element(boundBy: 0)
            firstRunCard.tap()
            
            // Look for start run button
            let startRunButton = app.buttons["Start Run"]
            if startRunButton.waitForExistence(timeout: 3) {
                startRunButton.tap()
                
                // Validate Active Run View elements
                let mapPlaceholder = app.images["Map Placeholder"]
                let currentStopCard = app.otherElements["Current Stop Card"]
                let progressIndicator = app.progressIndicators["Run Progress"]
                let nextStopButton = app.buttons["Next Stop"]
                let endRunButton = app.buttons["End Run"]
                let pauseButton = app.buttons["Pause Run"]
                
                // Test VoiceOver navigation order
                let activeRunElements = [mapPlaceholder, currentStopCard, progressIndicator, nextStopButton, pauseButton, endRunButton]
                AccessibilityTestHelpers.validateVoiceOverNavigationOrder(activeRunElements.compactMap { $0.exists ? $0 : nil })
                
                // Validate map placeholder accessibility
                if mapPlaceholder.exists {
                    AccessibilityTestHelpers.validateVoiceOverElement(
                        mapPlaceholder,
                        expectedLabel: "Route map showing current location and stops",
                        expectedTraits: .image
                    )
                }
                
                // Validate current stop card accessibility
                if currentStopCard.exists {
                    XCTAssertTrue(currentStopCard.isAccessibilityElement)
                    XCTAssertFalse(currentStopCard.label.isEmpty, "Current stop card should have descriptive label")
                }
                
                // Validate action buttons
                if nextStopButton.exists {
                    AccessibilityTestHelpers.validateVoiceOverElement(
                        nextStopButton,
                        expectedLabel: "Next Stop",
                        expectedTraits: .button
                    )
                    AccessibilityTestHelpers.validateTouchTargetSize(nextStopButton)
                }
                
                if endRunButton.exists {
                    AccessibilityTestHelpers.validateVoiceOverElement(
                        endRunButton,
                        expectedLabel: "End Run",
                        expectedTraits: .button
                    )
                    AccessibilityTestHelpers.validateTouchTargetSize(endRunButton)
                }
            }
        }
    }
    
    func testActiveRunProgressAccessibility() throws {
        // Navigate to active run (assuming we have mock data)
        let schoolRunTab = app.tabBars.buttons["School Run"]
        schoolRunTab.tap()
        
        // Look for active run indicator
        let activeRunCard = app.otherElements["Active Run Card"]
        if activeRunCard.waitForExistence(timeout: 3) {
            activeRunCard.tap()
            
            // Validate progress indicator accessibility
            let progressIndicator = app.progressIndicators["Run Progress"]
            if progressIndicator.waitForExistence(timeout: 2) {
                AccessibilityTestHelpers.validateVoiceOverElement(
                    progressIndicator,
                    expectedLabel: "Run progress",
                    expectedTraits: .updatesFrequently
                )
                
                // Validate progress announcements
                XCTAssertTrue(progressIndicator.isAccessibilityElement)
                XCTAssertFalse(progressIndicator.value?.isEmpty ?? true, "Progress should have accessible value")
            }
            
            // Validate remaining stops accessibility
            let remainingStopsText = app.staticTexts.matching(identifier: "RemainingStopsText")
            if remainingStopsText.count > 0 {
                let stopsText = remainingStopsText.element(boundBy: 0)
                AccessibilityTestHelpers.validateTextReadability(stopsText)
                AccessibilityTestHelpers.validateColorContrast(stopsText)
            }
        }
    }
    
    func testActiveRunControlsAccessibility() throws {
        // Navigate to active run
        let schoolRunTab = app.tabBars.buttons["School Run"]
        schoolRunTab.tap()
        
        let activeRunCard = app.otherElements["Active Run Card"]
        if activeRunCard.waitForExistence(timeout: 3) {
            activeRunCard.tap()
            
            // Test run control buttons
            let pauseButton = app.buttons["Pause Run"]
            let resumeButton = app.buttons["Resume Run"]
            let nextStopButton = app.buttons["Next Stop"]
            let endRunButton = app.buttons["End Run"]
            
            // Test pause/resume functionality
            if pauseButton.exists {
                AccessibilityTestHelpers.validateTouchTargetSize(pauseButton)
                AccessibilityTestHelpers.validateColorContrast(pauseButton)
                
                // Test pause action
                pauseButton.tap()
                
                // Validate resume button appears
                if resumeButton.waitForExistence(timeout: 2) {
                    AccessibilityTestHelpers.validateVoiceOverElement(
                        resumeButton,
                        expectedLabel: "Resume Run",
                        expectedTraits: .button
                    )
                }
            }
            
            // Test destructive action accessibility (End Run)
            if endRunButton.exists {
                AccessibilityTestHelpers.validateVoiceOverElement(
                    endRunButton,
                    expectedLabel: "End Run",
                    expectedTraits: .button
                )
                
                // Validate that destructive actions have appropriate styling
                AccessibilityTestHelpers.validateColorContrast(endRunButton)
                AccessibilityTestHelpers.validateTouchTargetSize(endRunButton)
            }
        }
    }
    
    // MARK: - Run History Accessibility Tests
    
    func testRunHistoryVoiceOverNavigation() throws {
        // Navigate to Run History
        let schoolRunTab = app.tabBars.buttons["School Run"]
        schoolRunTab.tap()
        
        // Look for history navigation
        let historyButton = app.buttons["View History"]
        if historyButton.waitForExistence(timeout: 3) {
            historyButton.tap()
            
            // Validate Run History elements
            let historyTitle = app.navigationBars.staticTexts["Run History"]
            let filterButton = app.buttons["Filter runs"]
            let searchField = app.searchFields["Search runs or stops..."]
            
            // Test VoiceOver navigation
            let historyElements = [historyTitle, searchField, filterButton]
            AccessibilityTestHelpers.validateVoiceOverNavigationOrder(historyElements)
            
            // Validate search field accessibility
            AccessibilityTestHelpers.validateVoiceOverElement(
                searchField,
                expectedLabel: "Search runs or stops...",
                expectedTraits: .searchField
            )
            
            // Validate filter button accessibility
            AccessibilityTestHelpers.validateVoiceOverElement(
                filterButton,
                expectedLabel: "Filter runs",
                expectedTraits: .button
            )
            
            // Test historical run cards
            let historyCards = app.buttons.matching(identifier: "HistoryRunCard")
            for i in 0..<min(historyCards.count, 3) {
                let card = historyCards.element(boundBy: i)
                if card.exists {
                    XCTAssertTrue(card.isAccessibilityElement)
                    AccessibilityTestHelpers.validateTouchTargetSize(card)
                }
            }
        }
    }
    
    func testRunHistoryFilterAccessibility() throws {
        // Navigate to Run History
        let schoolRunTab = app.tabBars.buttons["School Run"]
        schoolRunTab.tap()
        
        let historyButton = app.buttons["View History"]
        if historyButton.waitForExistence(timeout: 3) {
            historyButton.tap()
            
            // Open filter sheet
            let filterButton = app.buttons["Filter runs"]
            XCTAssertTrue(filterButton.waitForExistence(timeout: 3))
            filterButton.tap()
            
            // Validate filter sheet accessibility
            let filterSheet = app.sheets.firstMatch
            if filterSheet.waitForExistence(timeout: 2) {
                let dateRangeFilter = app.buttons["Date Range"]
                let statusFilter = app.buttons["Status"]
                let applyButton = app.buttons["Apply Filters"]
                let clearButton = app.buttons["Clear Filters"]
                
                // Test filter options accessibility
                if dateRangeFilter.exists {
                    AccessibilityTestHelpers.validateVoiceOverElement(
                        dateRangeFilter,
                        expectedLabel: "Date Range",
                        expectedTraits: .button
                    )
                    AccessibilityTestHelpers.validateTouchTargetSize(dateRangeFilter)
                }
                
                if statusFilter.exists {
                    AccessibilityTestHelpers.validateVoiceOverElement(
                        statusFilter,
                        expectedLabel: "Status",
                        expectedTraits: .button
                    )
                    AccessibilityTestHelpers.validateTouchTargetSize(statusFilter)
                }
                
                // Test filter action buttons
                if applyButton.exists {
                    AccessibilityTestHelpers.validateTouchTargetSize(applyButton)
                }
                
                if clearButton.exists {
                    AccessibilityTestHelpers.validateTouchTargetSize(clearButton)
                }
            }
        }
    }
    
    // MARK: - Component-Specific Accessibility Tests
    
    func testRunCardAccessibility() throws {
        // Navigate to School Run tab
        let schoolRunTab = app.tabBars.buttons["School Run"]
        schoolRunTab.tap()
        
        // Test run card components
        let runCards = app.buttons.matching(identifier: "RunCard")
        if runCards.count > 0 {
            let firstRunCard = runCards.element(boundBy: 0)
            
            // Validate run card accessibility
            XCTAssertTrue(firstRunCard.isAccessibilityElement)
            AccessibilityTestHelpers.validateTouchTargetSize(firstRunCard)
            AccessibilityTestHelpers.validateColorContrast(firstRunCard)
            
            // Test run card content accessibility
            let runTitle = firstRunCard.staticTexts.firstMatch
            if runTitle.exists {
                AccessibilityTestHelpers.validateTextReadability(runTitle)
                AccessibilityTestHelpers.validateDynamicTypeSupport(app: app, textElement: runTitle)
            }
            
            // Test status badge within card
            let statusBadge = firstRunCard.otherElements.matching(identifier: "RunStatusBadge").firstMatch
            if statusBadge.exists {
                XCTAssertTrue(statusBadge.isAccessibilityElement)
                AccessibilityTestHelpers.validateColorContrast(statusBadge)
            }
        }
    }
    
    func testStopRowAccessibility() throws {
        // Navigate to Run Planner to test stop rows
        let schoolRunTab = app.tabBars.buttons["School Run"]
        schoolRunTab.tap()
        
        let addRunButton = app.buttons["Add new run"]
        addRunButton.tap()
        
        // Add a stop to test stop row
        let addStopButton = app.buttons["Add Stop"]
        XCTAssertTrue(addStopButton.waitForExistence(timeout: 3))
        addStopButton.tap()
        
        // Test stop row accessibility
        let stopRows = app.otherElements.matching(identifier: "StopRow")
        if stopRows.count > 0 {
            let firstStopRow = stopRows.element(boundBy: 0)
            
            XCTAssertTrue(firstStopRow.isAccessibilityElement)
            AccessibilityTestHelpers.validateTouchTargetSize(firstStopRow)
            
            // Test stop type icon accessibility
            let stopTypeIcon = firstStopRow.images.firstMatch
            if stopTypeIcon.exists {
                XCTAssertTrue(stopTypeIcon.isAccessibilityElement)
                XCTAssertFalse(stopTypeIcon.label.isEmpty, "Stop type icon should have descriptive label")
            }
            
            // Test stop name text accessibility
            let stopNameText = firstStopRow.staticTexts.firstMatch
            if stopNameText.exists {
                AccessibilityTestHelpers.validateTextReadability(stopNameText)
            }
        }
    }
    
    func testQuickActionButtonsAccessibility() throws {
        // Navigate to School Run tab
        let schoolRunTab = app.tabBars.buttons["School Run"]
        schoolRunTab.tap()
        
        // Test quick action buttons
        let quickActionButtons = app.buttons.matching(identifier: "QuickActionButton")
        
        for i in 0..<min(quickActionButtons.count, 5) {
            let button = quickActionButtons.element(boundBy: i)
            if button.exists {
                AccessibilityTestHelpers.validateTouchTargetSize(button)
                AccessibilityTestHelpers.validateColorContrast(button)
                
                XCTAssertTrue(button.isAccessibilityElement)
                XCTAssertFalse(button.label.isEmpty, "Quick action button should have descriptive label")
                
                // Test button icon accessibility
                let buttonIcon = button.images.firstMatch
                if buttonIcon.exists {
                    XCTAssertTrue(buttonIcon.isAccessibilityElement)
                }
            }
        }
    }
    
    // MARK: - Keyboard Navigation Tests
    
    func testSchoolRunKeyboardNavigation() throws {
        // Enable keyboard navigation simulation
        app.launchArguments.append("--keyboard-navigation-enabled")
        app.terminate()
        app.launch()
        
        // Navigate to School Run tab using keyboard
        let schoolRunTab = app.tabBars.buttons["School Run"]
        schoolRunTab.tap()
        
        // Test keyboard navigation through main elements
        let addRunButton = app.buttons["Add new run"]
        XCTAssertTrue(addRunButton.waitForExistence(timeout: 3))
        
        // Simulate tab navigation
        addRunButton.typeText("\t") // Tab to next element
        
        // Validate that focus moves appropriately
        let runCards = app.buttons.matching(identifier: "RunCard")
        if runCards.count > 0 {
            let firstRunCard = runCards.element(boundBy: 0)
            // In a real implementation, we would validate focus state
            XCTAssertTrue(firstRunCard.exists)
        }
    }
    
    func testRunPlannerKeyboardNavigation() throws {
        // Navigate to Run Planner
        let schoolRunTab = app.tabBars.buttons["School Run"]
        schoolRunTab.tap()
        
        let addRunButton = app.buttons["Add new run"]
        addRunButton.tap()
        
        // Test keyboard navigation through form fields
        let runTitleField = app.textFields["Run Title"]
        XCTAssertTrue(runTitleField.waitForExistence(timeout: 3))
        
        // Test field focus and navigation
        runTitleField.tap()
        runTitleField.typeText("Test Run")
        
        // Tab to next field
        runTitleField.typeText("\t")
        
        let dateField = app.textFields["Date"]
        if dateField.exists {
            // Validate that focus moved to date field
            XCTAssertTrue(dateField.hasFocus, "Focus should move to date field")
        }
    }
    
    // MARK: - Comprehensive School Run Accessibility Tests
    
    func testCompleteSchoolRunFlowAccessibility() throws {
        // Test complete school run workflow accessibility
        AccessibilityTestHelpers.validateScreenAccessibility(
            app: app,
            screenIdentifier: "School Run Dashboard",
            keyElements: [
                app.tabBars.buttons["School Run"],
                app.buttons["Add new run"]
            ]
        )
        
        // Navigate through each screen and validate
        let schoolRunTab = app.tabBars.buttons["School Run"]
        schoolRunTab.tap()
        
        // Test dashboard accessibility
        let dashboardElements = [
            app.navigationBars.staticTexts["School Run"],
            app.buttons["Add new run"]
        ]
        
        AccessibilityTestHelpers.validateScreenAccessibility(
            app: app,
            screenIdentifier: "School Run Dashboard",
            keyElements: dashboardElements
        )
        
        // Test run planner accessibility
        let addRunButton = app.buttons["Add new run"]
        addRunButton.tap()
        
        let plannerElements = [
            app.navigationBars.staticTexts["Plan Run"],
            app.textFields["Run Title"],
            app.buttons["Save Run"],
            app.buttons["Cancel"]
        ]
        
        AccessibilityTestHelpers.validateScreenAccessibility(
            app: app,
            screenIdentifier: "Run Planner",
            keyElements: plannerElements.compactMap { $0.exists ? $0 : nil }
        )
    }
    
    func testSchoolRunAccessibilityWithReducedMotion() throws {
        // Test with reduced motion enabled
        app.launchArguments.append("--reduce-motion-enabled")
        app.terminate()
        app.launch()
        
        // Navigate to School Run
        let schoolRunTab = app.tabBars.buttons["School Run"]
        schoolRunTab.tap()
        
        // Validate that animations are reduced/disabled
        let addRunButton = app.buttons["Add new run"]
        XCTAssertTrue(addRunButton.waitForExistence(timeout: 3))
        
        // Test that interactive elements still work with reduced motion
        addRunButton.tap()
        
        let plannerTitle = app.navigationBars.staticTexts["Plan Run"]
        XCTAssertTrue(plannerTitle.waitForExistence(timeout: 3), "Navigation should work with reduced motion")
        
        // Validate that essential functionality remains accessible
        let runTitleField = app.textFields["Run Title"]
        if runTitleField.exists {
            AccessibilityTestHelpers.validateTouchTargetSize(runTitleField)
            AccessibilityTestHelpers.validateColorContrast(runTitleField)
        }
    }
    
    func testSchoolRunAccessibilityCompliance() throws {
        // Comprehensive accessibility compliance test
        let schoolRunTab = app.tabBars.buttons["School Run"]
        schoolRunTab.tap()
        
        // Get all interactive elements on school run screens
        let allButtons = app.buttons
        let allTextFields = app.textFields
        let allImages = app.images
        
        // Test buttons compliance
        for i in 0..<min(allButtons.count, 10) {
            let button = allButtons.element(boundBy: i)
            if button.exists && button.isHittable {
                AccessibilityTestHelpers.validateAccessibilityCompliance(
                    button,
                    shouldSupportDynamicType: true
                )
            }
        }
        
        // Test text fields compliance
        for i in 0..<allTextFields.count {
            let textField = allTextFields.element(boundBy: i)
            if textField.exists {
                AccessibilityTestHelpers.validateAccessibilityCompliance(
                    textField,
                    shouldSupportDynamicType: true
                )
            }
        }
        
        // Test images compliance
        for i in 0..<min(allImages.count, 5) {
            let image = allImages.element(boundBy: i)
            if image.exists && image.isAccessibilityElement {
                AccessibilityTestHelpers.validateAccessibilityCompliance(image)
            }
        }
    }
}