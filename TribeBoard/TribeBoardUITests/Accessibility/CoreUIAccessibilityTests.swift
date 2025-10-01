import XCTest
@testable import TribeBoard

/// Comprehensive accessibility tests for core UI components
/// Tests navigation, family dashboard, task management, and other main interface elements
/// for VoiceOver compatibility, Dynamic Type support, and accessibility compliance
final class CoreUIAccessibilityTests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--mock-authenticated-user")
        app.launchForAccessibilityTesting()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Navigation and Tab Bar Accessibility Tests
    
    func testMainNavigationAccessibility() throws {
        // Wait for main navigation to appear
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5))
        
        // Get all tab bar buttons
        let tabButtons = tabBar.buttons
        XCTAssertGreaterThan(tabButtons.count, 0, "Tab bar should have navigation buttons")
        
        // Validate each tab button accessibility
        let expectedTabLabels = ["Family", "Tasks", "School Run", "Calendar", "Settings"]
        
        for i in 0..<min(tabButtons.count, expectedTabLabels.count) {
            let tabButton = tabButtons.element(boundBy: i)
            let expectedLabel = expectedTabLabels[i]
            
            AccessibilityTestHelpers.validateVoiceOverElement(
                tabButton,
                expectedLabel: expectedLabel,
                expectedTraits: .button
            )
            
            AccessibilityTestHelpers.validateTouchTargetSize(tabButton)
            AccessibilityTestHelpers.validateColorContrast(tabButton)
        }
        
        // Test tab navigation order
        let allTabButtons = Array(0..<tabButtons.count).map { tabButtons.element(boundBy: $0) }
        AccessibilityTestHelpers.validateVoiceOverNavigationOrder(allTabButtons)
        
        // Test tab selection accessibility
        for i in 0..<min(tabButtons.count, 3) { // Test first 3 tabs
            let tabButton = tabButtons.element(boundBy: i)
            AccessibilityTestHelpers.validateVoiceOverFocus(tabButton)
            tabButton.tap()
            
            // Verify tab selection is announced
            XCTAssertTrue(tabButton.isSelected, "Tab should be selected after tapping")
        }
    }
    
    func testNavigationBarAccessibility() throws {
        // Navigate to a screen with navigation bar
        let familyTab = app.tabBars.buttons["Family"]
        XCTAssertTrue(familyTab.waitForExistence(timeout: 5))
        familyTab.tap()
        
        // Test navigation bar elements
        let navigationBar = app.navigationBars.firstMatch
        if navigationBar.exists {
            let backButton = navigationBar.buttons.firstMatch
            let titleElement = navigationBar.staticTexts.firstMatch
            
            if backButton.exists {
                AccessibilityTestHelpers.validateVoiceOverElement(
                    backButton,
                    expectedLabel: "Back",
                    expectedTraits: .button
                )
                AccessibilityTestHelpers.validateTouchTargetSize(backButton)
            }
            
            if titleElement.exists {
                AccessibilityTestHelpers.validateTextReadability(titleElement)
                AccessibilityTestHelpers.validateColorContrast(titleElement)
            }
        }
    }
    
    func testFloatingNavigationAccessibility() throws {
        // Test floating bottom navigation if present
        let floatingNav = app.otherElements["Floating Navigation"]
        if floatingNav.waitForExistence(timeout: 3) {
            let navButtons = floatingNav.buttons
            
            for i in 0..<navButtons.count {
                let button = navButtons.element(boundBy: i)
                AccessibilityTestHelpers.validateTouchTargetSize(button)
                AccessibilityTestHelpers.validateColorContrast(button)
                XCTAssertTrue(button.isAccessibilityElement, "Floating nav button should be accessible")
            }
            
            // Validate floating navigation doesn't interfere with main content accessibility
            let mainContent = app.otherElements["Main Content"]
            if mainContent.exists {
                XCTAssertTrue(mainContent.isAccessibilityElement, "Main content should remain accessible with floating navigation")
            }
        }
    }
    
    // MARK: - Family Dashboard Accessibility Tests
    
    func testFamilyDashboardAccessibility() throws {
        // Navigate to family dashboard
        let familyTab = app.tabBars.buttons["Family"]
        XCTAssertTrue(familyTab.waitForExistence(timeout: 5))
        familyTab.tap()
        
        // Test family dashboard header
        let dashboardTitle = app.staticTexts["Family Dashboard"]
        if dashboardTitle.waitForExistence(timeout: 3) {
            AccessibilityTestHelpers.validateVoiceOverElement(
                dashboardTitle,
                expectedLabel: "Family Dashboard",
                expectedTraits: .header
            )
            AccessibilityTestHelpers.validateTextReadability(dashboardTitle)
        }
        
        // Test family member cards
        let memberCards = app.collectionViews.cells
        if memberCards.count > 0 {
            for i in 0..<min(memberCards.count, 3) { // Test first 3 member cards
                let memberCard = memberCards.element(boundBy: i)
                
                AccessibilityTestHelpers.validateTouchTargetSize(memberCard)
                AccessibilityTestHelpers.validateColorContrast(memberCard)
                
                // Test member card content accessibility
                let memberName = memberCard.staticTexts.firstMatch
                if memberName.exists {
                    AccessibilityTestHelpers.validateTextReadability(memberName)
                }
                
                let memberRole = memberCard.staticTexts.element(boundBy: 1)
                if memberRole.exists {
                    AccessibilityTestHelpers.validateTextReadability(memberRole)
                }
            }
        }
        
        // Test family action buttons
        let addMemberButton = app.buttons["Add Family Member"]
        if addMemberButton.exists {
            AccessibilityTestHelpers.validateVoiceOverElement(
                addMemberButton,
                expectedLabel: "Add Family Member",
                expectedTraits: .button
            )
            AccessibilityTestHelpers.validateTouchTargetSize(addMemberButton)
        }
        
        let familySettingsButton = app.buttons["Family Settings"]
        if familySettingsButton.exists {
            AccessibilityTestHelpers.validateVoiceOverElement(
                familySettingsButton,
                expectedLabel: "Family Settings",
                expectedTraits: .button
            )
            AccessibilityTestHelpers.validateTouchTargetSize(familySettingsButton)
        }
    }
    
    func testFamilyCreationAccessibility() throws {
        // Navigate to family creation
        let familyTab = app.tabBars.buttons["Family"]
        familyTab.tap()
        
        let createFamilyButton = app.buttons["Create Family"]
        if createFamilyButton.waitForExistence(timeout: 3) {
            createFamilyButton.tap()
            
            // Test family creation form accessibility
            let familyNameField = app.textFields["Family Name"]
            if familyNameField.waitForExistence(timeout: 3) {
                AccessibilityTestHelpers.validateVoiceOverElement(
                    familyNameField,
                    expectedLabel: "Family Name",
                    expectedTraits: .textField
                )
                AccessibilityTestHelpers.validateTouchTargetSize(familyNameField)
                
                // Test form validation accessibility
                let createButton = app.buttons["Create"]
                if createButton.exists {
                    AccessibilityTestHelpers.validateTouchTargetSize(createButton)
                    
                    // Test validation error accessibility
                    createButton.tap() // Trigger validation error
                    
                    let errorMessage = app.staticTexts["Family name is required"]
                    if errorMessage.waitForExistence(timeout: 2) {
                        AccessibilityTestHelpers.validateVoiceOverElement(
                            errorMessage,
                            expectedLabel: "Family name is required",
                            expectedTraits: .staticText
                        )
                        AccessibilityTestHelpers.validateTextReadability(errorMessage)
                    }
                }
            }
        }
    }
    
    // MARK: - Task Management Accessibility Tests
    
    func testTaskListAccessibility() throws {
        // Navigate to tasks
        let tasksTab = app.tabBars.buttons["Tasks"]
        XCTAssertTrue(tasksTab.waitForExistence(timeout: 5))
        tasksTab.tap()
        
        // Test task list header
        let tasksTitle = app.staticTexts["Tasks"]
        if tasksTitle.waitForExistence(timeout: 3) {
            AccessibilityTestHelpers.validateVoiceOverElement(
                tasksTitle,
                expectedLabel: "Tasks",
                expectedTraits: .header
            )
        }
        
        // Test task cards
        let taskCards = app.collectionViews.cells
        if taskCards.count > 0 {
            for i in 0..<min(taskCards.count, 3) { // Test first 3 task cards
                let taskCard = taskCards.element(boundBy: i)
                
                AccessibilityTestHelpers.validateTouchTargetSize(taskCard)
                AccessibilityTestHelpers.validateColorContrast(taskCard)
                
                // Test task card content
                let taskTitle = taskCard.staticTexts.firstMatch
                if taskTitle.exists {
                    AccessibilityTestHelpers.validateTextReadability(taskTitle)
                }
                
                let taskStatus = taskCard.buttons.firstMatch
                if taskStatus.exists {
                    AccessibilityTestHelpers.validateTouchTargetSize(taskStatus)
                    XCTAssertTrue(taskStatus.isAccessibilityElement, "Task status should be accessible")
                }
            }
        }
        
        // Test add task button
        let addTaskButton = app.buttons["Add Task"]
        if addTaskButton.exists {
            AccessibilityTestHelpers.validateVoiceOverElement(
                addTaskButton,
                expectedLabel: "Add Task",
                expectedTraits: .button
            )
            AccessibilityTestHelpers.validateTouchTargetSize(addTaskButton)
        }
        
        // Test task filter options
        let filterButton = app.buttons["Filter Tasks"]
        if filterButton.exists {
            AccessibilityTestHelpers.validateTouchTargetSize(filterButton)
            filterButton.tap()
            
            // Test filter sheet accessibility
            let filterSheet = app.sheets.firstMatch
            if filterSheet.waitForExistence(timeout: 2) {
                let filterOptions = filterSheet.buttons
                for i in 0..<filterOptions.count {
                    let option = filterOptions.element(boundBy: i)
                    AccessibilityTestHelpers.validateTouchTargetSize(option)
                    XCTAssertTrue(option.isAccessibilityElement, "Filter option should be accessible")
                }
            }
        }
    }
    
    func testTaskCreationAccessibility() throws {
        // Navigate to task creation
        let tasksTab = app.tabBars.buttons["Tasks"]
        tasksTab.tap()
        
        let addTaskButton = app.buttons["Add Task"]
        if addTaskButton.waitForExistence(timeout: 3) {
            addTaskButton.tap()
            
            // Test task creation form
            let taskTitleField = app.textFields["Task Title"]
            if taskTitleField.waitForExistence(timeout: 3) {
                AccessibilityTestHelpers.validateVoiceOverElement(
                    taskTitleField,
                    expectedLabel: "Task Title",
                    expectedTraits: .textField
                )
                AccessibilityTestHelpers.validateTouchTargetSize(taskTitleField)
            }
            
            let taskDescriptionField = app.textViews["Task Description"]
            if taskDescriptionField.exists {
                AccessibilityTestHelpers.validateVoiceOverElement(
                    taskDescriptionField,
                    expectedLabel: "Task Description",
                    expectedTraits: .textField
                )
                AccessibilityTestHelpers.validateTouchTargetSize(taskDescriptionField)
            }
            
            // Test task priority selection
            let prioritySegmentedControl = app.segmentedControls["Priority"]
            if prioritySegmentedControl.exists {
                AccessibilityTestHelpers.validateTouchTargetSize(prioritySegmentedControl)
                
                let priorityButtons = prioritySegmentedControl.buttons
                for i in 0..<priorityButtons.count {
                    let button = priorityButtons.element(boundBy: i)
                    AccessibilityTestHelpers.validateTouchTargetSize(button)
                }
            }
            
            // Test save button
            let saveButton = app.buttons["Save Task"]
            if saveButton.exists {
                AccessibilityTestHelpers.validateTouchTargetSize(saveButton)
                AccessibilityTestHelpers.validateVoiceOverElement(
                    saveButton,
                    expectedLabel: "Save Task",
                    expectedTraits: .button
                )
            }
        }
    }
    
    // MARK: - School Run Interface Accessibility Tests
    
    func testSchoolRunDashboardAccessibility() throws {
        // Navigate to school run
        let schoolRunTab = app.tabBars.buttons["School Run"]
        if schoolRunTab.waitForExistence(timeout: 5) {
            schoolRunTab.tap()
            
            // Test school run dashboard header
            let dashboardTitle = app.staticTexts["School Run"]
            if dashboardTitle.waitForExistence(timeout: 3) {
                AccessibilityTestHelpers.validateVoiceOverElement(
                    dashboardTitle,
                    expectedLabel: "School Run",
                    expectedTraits: .header
                )
            }
            
            // Test active run card
            let activeRunCard = app.otherElements["Active Run Card"]
            if activeRunCard.exists {
                AccessibilityTestHelpers.validateTouchTargetSize(activeRunCard)
                AccessibilityTestHelpers.validateColorContrast(activeRunCard)
                
                let runStatus = activeRunCard.staticTexts.firstMatch
                if runStatus.exists {
                    AccessibilityTestHelpers.validateTextReadability(runStatus)
                }
                
                let runActions = activeRunCard.buttons
                for i in 0..<runActions.count {
                    let action = runActions.element(boundBy: i)
                    AccessibilityTestHelpers.validateTouchTargetSize(action)
                }
            }
            
            // Test scheduled runs list
            let scheduledRunsList = app.tables.firstMatch
            if scheduledRunsList.exists {
                let runCells = scheduledRunsList.cells
                for i in 0..<min(runCells.count, 3) {
                    let cell = runCells.element(boundBy: i)
                    AccessibilityTestHelpers.validateTouchTargetSize(cell)
                    AccessibilityTestHelpers.validateColorContrast(cell)
                }
            }
            
            // Test schedule new run button
            let scheduleButton = app.buttons["Schedule New Run"]
            if scheduleButton.exists {
                AccessibilityTestHelpers.validateVoiceOverElement(
                    scheduleButton,
                    expectedLabel: "Schedule New Run",
                    expectedTraits: .button
                )
                AccessibilityTestHelpers.validateTouchTargetSize(scheduleButton)
            }
        }
    }
    
    func testSchoolRunSchedulingAccessibility() throws {
        // Navigate to school run scheduling
        let schoolRunTab = app.tabBars.buttons["School Run"]
        if schoolRunTab.waitForExistence(timeout: 5) {
            schoolRunTab.tap()
            
            let scheduleButton = app.buttons["Schedule New Run"]
            if scheduleButton.waitForExistence(timeout: 3) {
                scheduleButton.tap()
                
                // Test scheduling form accessibility
                let routeField = app.textFields["Route Name"]
                if routeField.waitForExistence(timeout: 3) {
                    AccessibilityTestHelpers.validateVoiceOverElement(
                        routeField,
                        expectedLabel: "Route Name",
                        expectedTraits: .textField
                    )
                    AccessibilityTestHelpers.validateTouchTargetSize(routeField)
                }
                
                let timeField = app.textFields["Departure Time"]
                if timeField.exists {
                    AccessibilityTestHelpers.validateTouchTargetSize(timeField)
                }
                
                let datePicker = app.datePickers.firstMatch
                if datePicker.exists {
                    AccessibilityTestHelpers.validateTouchTargetSize(datePicker)
                    XCTAssertTrue(datePicker.isAccessibilityElement, "Date picker should be accessible")
                }
                
                // Test stop configuration
                let addStopButton = app.buttons["Add Stop"]
                if addStopButton.exists {
                    AccessibilityTestHelpers.validateTouchTargetSize(addStopButton)
                    AccessibilityTestHelpers.validateVoiceOverElement(
                        addStopButton,
                        expectedLabel: "Add Stop",
                        expectedTraits: .button
                    )
                }
            }
        }
    }
    
    // MARK: - Settings and Profile Accessibility Tests
    
    func testSettingsScreenAccessibility() throws {
        // Navigate to settings
        let settingsTab = app.tabBars.buttons["Settings"]
        if settingsTab.waitForExistence(timeout: 5) {
            settingsTab.tap()
            
            // Test settings list accessibility
            let settingsList = app.tables.firstMatch
            if settingsList.waitForExistence(timeout: 3) {
                let settingsCells = settingsList.cells
                
                for i in 0..<min(settingsCells.count, 5) { // Test first 5 settings
                    let cell = settingsCells.element(boundBy: i)
                    AccessibilityTestHelpers.validateTouchTargetSize(cell)
                    AccessibilityTestHelpers.validateColorContrast(cell)
                    
                    let cellTitle = cell.staticTexts.firstMatch
                    if cellTitle.exists {
                        AccessibilityTestHelpers.validateTextReadability(cellTitle)
                    }
                }
            }
            
            // Test profile section
            let profileSection = app.otherElements["Profile Section"]
            if profileSection.exists {
                let profileImage = profileSection.images.firstMatch
                if profileImage.exists {
                    AccessibilityTestHelpers.validateVoiceOverElement(
                        profileImage,
                        expectedLabel: "Profile Picture",
                        expectedTraits: .image
                    )
                }
                
                let profileName = profileSection.staticTexts.firstMatch
                if profileName.exists {
                    AccessibilityTestHelpers.validateTextReadability(profileName)
                }
            }
        }
    }
    
    // MARK: - Comprehensive Core UI Accessibility Tests
    
    func testOverallUIAccessibilityCompliance() throws {
        // Test each main screen for comprehensive accessibility
        let mainTabs = ["Family", "Tasks", "School Run", "Settings"]
        
        for tabName in mainTabs {
            let tab = app.tabBars.buttons[tabName]
            if tab.exists {
                tab.tap()
                
                // Wait for screen to load
                Thread.sleep(forTimeInterval: 1.0)
                
                // Get all interactive elements on the screen
                let buttons = app.buttons
                let textFields = app.textFields
                let links = app.links
                
                // Test all buttons
                for i in 0..<min(buttons.count, 10) { // Limit to first 10 for performance
                    let button = buttons.element(boundBy: i)
                    if button.exists && button.isHittable {
                        AccessibilityTestHelpers.validateAccessibilityCompliance(
                            button,
                            shouldSupportDynamicType: true
                        )
                    }
                }
                
                // Test all text fields
                for i in 0..<textFields.count {
                    let textField = textFields.element(boundBy: i)
                    if textField.exists {
                        AccessibilityTestHelpers.validateAccessibilityCompliance(
                            textField,
                            shouldSupportDynamicType: true
                        )
                    }
                }
                
                // Test all links
                for i in 0..<links.count {
                    let link = links.element(boundBy: i)
                    if link.exists {
                        AccessibilityTestHelpers.validateAccessibilityCompliance(link)
                    }
                }
            }
        }
    }
    
    func testDynamicTypeAcrossAllScreens() throws {
        // Test Dynamic Type support across all main screens
        let mainTabs = ["Family", "Tasks", "School Run", "Settings"]
        
        for tabName in mainTabs {
            let tab = app.tabBars.buttons[tabName]
            if tab.exists {
                tab.tap()
                Thread.sleep(forTimeInterval: 0.5)
                
                // Test text elements on this screen
                let staticTexts = app.staticTexts
                for i in 0..<min(staticTexts.count, 5) { // Test first 5 text elements
                    let textElement = staticTexts.element(boundBy: i)
                    if textElement.exists && textElement.isHittable {
                        AccessibilityTestHelpers.validateDynamicTypeSupport(
                            app: app,
                            textElement: textElement
                        )
                    }
                }
            }
        }
    }
    
    func testColorContrastAcrossAllScreens() throws {
        // Test color contrast across all main screens
        let mainTabs = ["Family", "Tasks", "School Run", "Settings"]
        
        for tabName in mainTabs {
            let tab = app.tabBars.buttons[tabName]
            if tab.exists {
                tab.tap()
                Thread.sleep(forTimeInterval: 0.5)
                
                // Test key visual elements
                let allElements = [
                    app.buttons.allElementsBoundByIndex,
                    app.staticTexts.allElementsBoundByIndex,
                    app.textFields.allElementsBoundByIndex
                ].flatMap { $0 }
                
                for element in allElements.prefix(10) { // Test first 10 elements
                    if element.exists && element.isHittable {
                        AccessibilityTestHelpers.validateColorContrast(element)
                    }
                }
                
                // Test high contrast mode compatibility
                AccessibilityTestHelpers.validateHighContrastMode(
                    app: app,
                    element: tab
                )
            }
        }
    }
}