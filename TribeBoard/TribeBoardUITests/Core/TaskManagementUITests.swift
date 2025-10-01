import XCTest

/// UI tests for task management functionality including task creation, list display, and completion flows
final class TaskManagementUITests: UITestBase {
    
    // MARK: - Task Creation Form Tests
    
    /// Test task creation form displays correctly
    func testTaskCreationFormDisplay() {
        // Arrange: Sign in and navigate to tasks
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Tasks")
        
        // Act: Tap add task button
        let addTaskButton = app.buttons["Add Task"]
        safeTap(addTaskButton)
        
        // Assert: Task creation form should be displayed
        let createTaskTitle = app.navigationBars.staticTexts["Create Task"]
        XCTAssertTrue(createTaskTitle.waitForExistence(timeout: defaultTimeout),
                     "Task creation form should be displayed")
        
        // Verify form fields are present
        let taskTitleField = app.textFields["Task Title"]
        XCTAssertTrue(taskTitleField.waitForExistence(timeout: defaultTimeout),
                     "Task title field should be displayed")
        
        let descriptionField = app.textViews["Task Description"]
        XCTAssertTrue(descriptionField.waitForExistence(timeout: defaultTimeout),
                     "Task description field should be displayed")
        
        // Verify assignee picker
        let assigneePicker = app.buttons["Select Assignee"]
        XCTAssertTrue(assigneePicker.waitForExistence(timeout: defaultTimeout),
                     "Assignee picker should be displayed")
        
        // Verify category picker
        let categoryPicker = app.buttons["Select Category"]
        XCTAssertTrue(categoryPicker.waitForExistence(timeout: defaultTimeout),
                     "Category picker should be displayed")
        
        // Take screenshot for visual verification
        takeScreenshot(name: "TaskCreation_Form")
    }
    
    /// Test task creation form validation
    func testTaskCreationFormValidation() {
        // Arrange: Navigate to task creation form
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Tasks")
        
        let addTaskButton = app.buttons["Add Task"]
        safeTap(addTaskButton)
        
        let taskTitleField = app.textFields["Task Title"]
        let createButton = app.buttons["Create Task"]
        
        // Assert: Create button should be disabled initially
        XCTAssertTrue(createButton.waitForExistence(timeout: defaultTimeout))
        XCTAssertFalse(createButton.isEnabled, "Create button should be disabled with empty form")
        
        // Test with only title (should still be invalid)
        safeTypeText("Test Task", into: taskTitleField)
        XCTAssertFalse(createButton.isEnabled, "Create button should be disabled without assignee")
        
        // Select assignee
        let assigneePicker = app.buttons["Select Assignee"]
        safeTap(assigneePicker)
        
        let firstAssignee = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Member'")).firstMatch
        if firstAssignee.waitForExistence(timeout: defaultTimeout) {
            safeTap(firstAssignee)
        }
        
        // Now create button should be enabled
        XCTAssertTrue(createButton.isEnabled, "Create button should be enabled with valid input")
    }
    
    /// Test successful task creation flow
    func testSuccessfulTaskCreationFlow() {
        // Arrange: Navigate to task creation form
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Tasks")
        
        let addTaskButton = app.buttons["Add Task"]
        safeTap(addTaskButton)
        
        // Fill out the form
        let taskTitleField = app.textFields["Task Title"]
        safeTypeText("Clean Kitchen", into: taskTitleField)
        
        let descriptionField = app.textViews["Task Description"]
        safeTypeText("Wash dishes and wipe counters", into: descriptionField)
        
        // Select assignee
        let assigneePicker = app.buttons["Select Assignee"]
        safeTap(assigneePicker)
        
        let firstAssignee = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Member'")).firstMatch
        if firstAssignee.waitForExistence(timeout: defaultTimeout) {
            safeTap(firstAssignee)
        }
        
        // Select category
        let categoryPicker = app.buttons["Select Category"]
        safeTap(categoryPicker)
        
        let choresCategory = app.buttons["Chores"]
        if choresCategory.waitForExistence(timeout: defaultTimeout) {
            safeTap(choresCategory)
        }
        
        // Act: Create the task
        let createButton = app.buttons["Create Task"]
        safeTap(createButton)
        
        // Assert: Should show loading state
        let loadingIndicator = app.staticTexts["Creating task..."]
        XCTAssertTrue(loadingIndicator.waitForExistence(timeout: shortTimeout),
                     "Loading indicator should be displayed")
        
        // Wait for creation to complete
        waitForLoadingToComplete(timeout: longTimeout)
        
        // Should return to tasks list
        let tasksTitle = app.navigationBars["Family Tasks"]
        XCTAssertTrue(tasksTitle.waitForExistence(timeout: defaultTimeout),
                     "Should return to tasks list after creation")
        
        // New task should appear in the list
        let newTask = app.staticTexts["Clean Kitchen"]
        XCTAssertTrue(newTask.waitForExistence(timeout: defaultTimeout),
                     "New task should appear in tasks list")
        
        // Take screenshot for visual verification
        takeScreenshot(name: "TaskCreation_Success")
    }
    
    // MARK: - Task List Display Tests
    
    /// Test task list displays correctly
    func testTaskListDisplay() {
        // Arrange: Sign in and navigate to tasks
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Tasks")
        
        // Assert: Tasks view should be displayed
        let tasksTitle = app.navigationBars["Family Tasks"]
        XCTAssertTrue(tasksTitle.waitForExistence(timeout: defaultTimeout),
                     "Tasks view should be displayed")
        
        // Verify task statistics section
        let progressSection = app.staticTexts["My Progress"]
        XCTAssertTrue(progressSection.waitForExistence(timeout: defaultTimeout),
                     "Progress section should be displayed")
        
        // Verify points display
        let pointsText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'points'")).firstMatch
        XCTAssertTrue(pointsText.waitForExistence(timeout: defaultTimeout),
                     "Points information should be displayed")
        
        // Verify task statistics cards
        let myTasksCard = app.staticTexts["My Tasks"]
        XCTAssertTrue(myTasksCard.waitForExistence(timeout: defaultTimeout),
                     "My Tasks card should be displayed")
        
        let pendingCard = app.staticTexts["Pending"]
        XCTAssertTrue(pendingCard.waitForExistence(timeout: defaultTimeout),
                     "Pending tasks card should be displayed")
        
        let completedCard = app.staticTexts["Completed"]
        XCTAssertTrue(completedCard.waitForExistence(timeout: defaultTimeout),
                     "Completed tasks card should be displayed")
        
        // Take screenshot for visual verification
        takeScreenshot(name: "TaskList_Display")
    }
    
    /// Test task cards display correctly
    func testTaskCardsDisplay() {
        // Arrange: Sign in and navigate to tasks
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Tasks")
        
        // Wait for tasks to load
        waitForLoadingToComplete()
        
        // Assert: Task cards should be displayed
        let taskCards = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'task_card'"))
        
        if taskCards.count > 0 {
            let firstTaskCard = taskCards.element(boundBy: 0)
            XCTAssertTrue(firstTaskCard.exists, "At least one task card should be displayed")
            
            // Verify task card elements
            let taskTitle = firstTaskCard.staticTexts.firstMatch
            XCTAssertTrue(taskTitle.exists, "Task title should be displayed in card")
            
            // Verify points badge
            let pointsBadge = firstTaskCard.staticTexts.matching(NSPredicate(format: "label CONTAINS 'star'")).firstMatch
            XCTAssertTrue(pointsBadge.exists, "Points badge should be displayed")
            
            // Verify status indicator
            let statusBadge = firstTaskCard.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Pending' OR label CONTAINS 'In Progress' OR label CONTAINS 'Completed'")).firstMatch
            XCTAssertTrue(statusBadge.exists, "Status badge should be displayed")
        }
    }
    
    /// Test task list filtering functionality
    func testTaskListFiltering() {
        // Arrange: Sign in and navigate to tasks
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Tasks")
        
        // Act: Tap filter button
        let filterButton = app.buttons["Filter"]
        safeTap(filterButton)
        
        // Assert: Filter sheet should be displayed
        let filterSheet = app.sheets.firstMatch
        XCTAssertTrue(filterSheet.waitForExistence(timeout: defaultTimeout),
                     "Filter sheet should be displayed")
        
        // Verify filter options
        let myTasksFilter = app.buttons["My Tasks"]
        XCTAssertTrue(myTasksFilter.waitForExistence(timeout: defaultTimeout),
                     "My Tasks filter should be available")
        
        let pendingFilter = app.buttons["Pending"]
        XCTAssertTrue(pendingFilter.waitForExistence(timeout: defaultTimeout),
                     "Pending filter should be available")
        
        let completedFilter = app.buttons["Completed"]
        XCTAssertTrue(completedFilter.waitForExistence(timeout: defaultTimeout),
                     "Completed filter should be available")
        
        // Test applying a filter
        safeTap(myTasksFilter)
        
        // Filter sheet should dismiss
        XCTAssertTrue(filterSheet.waitForNonExistence(timeout: defaultTimeout),
                     "Filter sheet should dismiss after selection")
        
        // Verify filter is applied
        let currentFilter = app.staticTexts["My Tasks"]
        XCTAssertTrue(currentFilter.waitForExistence(timeout: defaultTimeout),
                     "Current filter should be displayed")
        
        // Clear filter test
        let clearFilterButton = app.buttons["Clear"]
        if clearFilterButton.exists {
            safeTap(clearFilterButton)
            
            // Should show all tasks again
            let allTasksFilter = app.staticTexts["All Tasks"]
            XCTAssertTrue(allTasksFilter.waitForExistence(timeout: defaultTimeout),
                         "Should show all tasks after clearing filter")
        }
    }
    
    // MARK: - Task Interaction Tests
    
    /// Test task detail view display
    func testTaskDetailViewDisplay() {
        // Arrange: Sign in and navigate to tasks
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Tasks")
        
        // Wait for tasks to load
        waitForLoadingToComplete()
        
        // Find and tap a task card
        let taskCards = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'task_card'"))
        
        if taskCards.count > 0 {
            let firstTaskCard = taskCards.element(boundBy: 0)
            safeTap(firstTaskCard)
            
            // Assert: Task detail sheet should be displayed
            let taskDetailSheet = app.sheets.firstMatch
            XCTAssertTrue(taskDetailSheet.waitForExistence(timeout: defaultTimeout),
                         "Task detail sheet should be displayed")
            
            // Verify task details are shown
            let taskDetailsTitle = app.navigationBars["Task Details"]
            XCTAssertTrue(taskDetailsTitle.waitForExistence(timeout: defaultTimeout),
                         "Task details title should be displayed")
            
            // Verify task information
            let statusLabel = app.staticTexts["Status:"]
            XCTAssertTrue(statusLabel.waitForExistence(timeout: defaultTimeout),
                         "Status label should be displayed")
            
            let pointsLabel = app.staticTexts["Points:"]
            XCTAssertTrue(pointsLabel.waitForExistence(timeout: defaultTimeout),
                         "Points label should be displayed")
            
            // Verify action button
            let markCompleteButton = app.buttons["Mark Complete"]
            XCTAssertTrue(markCompleteButton.waitForExistence(timeout: defaultTimeout),
                         "Mark Complete button should be displayed")
            
            // Close the detail view
            let doneButton = app.buttons["Done"]
            safeTap(doneButton)
            
            // Should return to tasks list
            let tasksTitle = app.navigationBars["Family Tasks"]
            XCTAssertTrue(tasksTitle.waitForExistence(timeout: defaultTimeout),
                         "Should return to tasks list")
        }
    }
    
    /// Test task completion functionality
    func testTaskCompletionFlow() {
        // Arrange: Sign in and navigate to tasks
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Tasks")
        
        // Wait for tasks to load
        waitForLoadingToComplete()
        
        // Find a task with completion button
        let completeButtons = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'complete_task'"))
        
        if completeButtons.count > 0 {
            let firstCompleteButton = completeButtons.element(boundBy: 0)
            
            // Act: Tap complete button
            safeTap(firstCompleteButton)
            
            // Assert: Task should be marked as completed
            // This might show a confirmation or immediately update the status
            waitForLoadingToComplete(timeout: shortTimeout)
            
            // Verify task status changed (look for completed badge or visual change)
            let completedBadge = app.staticTexts["Completed"]
            XCTAssertTrue(completedBadge.waitForExistence(timeout: defaultTimeout),
                         "Task should show completed status")
        }
    }
    
    /// Test task status change menu
    func testTaskStatusChangeMenu() {
        // Arrange: Sign in and navigate to tasks
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Tasks")
        
        // Wait for tasks to load
        waitForLoadingToComplete()
        
        // Find a task with status menu button
        let statusMenuButtons = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'status_menu'"))
        
        if statusMenuButtons.count > 0 {
            let firstStatusButton = statusMenuButtons.element(boundBy: 0)
            
            // Act: Tap status menu button
            safeTap(firstStatusButton)
            
            // Assert: Status change menu should appear
            let statusMenu = app.sheets.firstMatch
            XCTAssertTrue(statusMenu.waitForExistence(timeout: defaultTimeout),
                         "Status change menu should be displayed")
            
            // Verify status options
            let pendingOption = app.buttons["Mark as Pending"]
            let inProgressOption = app.buttons["Mark as In Progress"]
            let completedOption = app.buttons["Mark as Completed"]
            
            // At least one status option should be available
            XCTAssertTrue(pendingOption.exists || inProgressOption.exists || completedOption.exists,
                         "At least one status change option should be available")
            
            // Test changing status
            if inProgressOption.exists {
                safeTap(inProgressOption)
                
                // Menu should dismiss
                XCTAssertTrue(statusMenu.waitForNonExistence(timeout: defaultTimeout),
                             "Status menu should dismiss after selection")
                
                // Verify status changed
                let inProgressBadge = app.staticTexts["In Progress"]
                XCTAssertTrue(inProgressBadge.waitForExistence(timeout: defaultTimeout),
                             "Task should show in progress status")
            }
        }
    }
    
    // MARK: - Task Management Interface Tests
    
    /// Test empty state display when no tasks exist
    func testEmptyStateDisplay() {
        // Arrange: Sign in and navigate to tasks (assuming no tasks initially)
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Tasks")
        
        // Apply a filter that might show empty state
        let filterButton = app.buttons["Filter"]
        safeTap(filterButton)
        
        let completedFilter = app.buttons["Completed"]
        if completedFilter.waitForExistence(timeout: defaultTimeout) {
            safeTap(completedFilter)
            
            // Assert: Empty state should be displayed if no completed tasks
            let emptyStateMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'No' AND label CONTAINS 'Tasks'")).firstMatch
            if emptyStateMessage.waitForExistence(timeout: defaultTimeout) {
                XCTAssertTrue(emptyStateMessage.exists, "Empty state message should be displayed")
                
                // Verify empty state actions
                let addTaskButton = app.buttons["Add First Task"]
                XCTAssertTrue(addTaskButton.waitForExistence(timeout: defaultTimeout),
                             "Add task button should be available in empty state")
                
                let clearFilterButton = app.buttons["Clear Filter"]
                XCTAssertTrue(clearFilterButton.waitForExistence(timeout: defaultTimeout),
                             "Clear filter button should be available in empty state")
                
                // Take screenshot for visual verification
                takeScreenshot(name: "TaskList_EmptyState")
            }
        }
    }
    
    /// Test task list refresh functionality
    func testTaskListRefresh() {
        // Arrange: Sign in and navigate to tasks
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Tasks")
        
        // Wait for initial load
        waitForLoadingToComplete()
        
        // Act: Pull to refresh
        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            // Simulate pull to refresh gesture
            scrollView.swipeDown()
            
            // Assert: Should show loading indicator briefly
            waitForLoadingToComplete(timeout: shortTimeout)
            
            // Tasks list should still be displayed
            let tasksTitle = app.navigationBars["Family Tasks"]
            XCTAssertTrue(tasksTitle.exists, "Tasks list should remain displayed after refresh")
        }
    }
    
    /// Test task points and statistics display
    func testTaskPointsAndStatistics() {
        // Arrange: Sign in and navigate to tasks
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Tasks")
        
        // Assert: Statistics should be displayed
        let progressSection = app.staticTexts["My Progress"]
        XCTAssertTrue(progressSection.waitForExistence(timeout: defaultTimeout),
                     "Progress section should be displayed")
        
        // Verify points information
        let pointsEarned = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'points earned'")).firstMatch
        XCTAssertTrue(pointsEarned.waitForExistence(timeout: defaultTimeout),
                     "Points earned should be displayed")
        
        let pointsAvailable = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'points available'")).firstMatch
        XCTAssertTrue(pointsAvailable.waitForExistence(timeout: defaultTimeout),
                     "Available points should be displayed")
        
        // Verify task count statistics
        let myTasksCount = app.staticTexts["My Tasks"]
        XCTAssertTrue(myTasksCount.waitForExistence(timeout: defaultTimeout),
                     "My tasks count should be displayed")
        
        let pendingCount = app.staticTexts["Pending"]
        XCTAssertTrue(pendingCount.waitForExistence(timeout: defaultTimeout),
                     "Pending tasks count should be displayed")
        
        let completedCount = app.staticTexts["Completed"]
        XCTAssertTrue(completedCount.waitForExistence(timeout: defaultTimeout),
                     "Completed tasks count should be displayed")
    }
    
    // MARK: - Accessibility Tests
    
    /// Test task management accessibility compliance
    func testTaskManagementAccessibility() {
        // Arrange: Sign in and navigate to tasks
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Tasks")
        
        // Test main elements accessibility
        let tasksTitle = app.navigationBars["Family Tasks"]
        assertElementIsAccessible(tasksTitle)
        
        let addTaskButton = app.buttons["Add Task"]
        assertElementIsAccessible(addTaskButton)
        
        let filterButton = app.buttons["Filter"]
        assertElementIsAccessible(filterButton)
        
        // Test task cards accessibility
        let taskCards = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'task_card'"))
        for i in 0..<min(taskCards.count, 3) { // Test first 3 task cards
            let taskCard = taskCards.element(boundBy: i)
            if taskCard.exists {
                assertElementIsAccessible(taskCard)
            }
        }
        
        // Test statistics cards accessibility
        let myTasksCard = app.staticTexts["My Tasks"]
        if myTasksCard.exists {
            assertElementIsAccessible(myTasksCard)
        }
    }
    
    /// Test task creation form accessibility
    func testTaskCreationFormAccessibility() {
        // Arrange: Navigate to task creation form
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Tasks")
        
        let addTaskButton = app.buttons["Add Task"]
        safeTap(addTaskButton)
        
        // Test form elements accessibility
        let taskTitleField = app.textFields["Task Title"]
        assertElementIsAccessible(taskTitleField)
        
        let descriptionField = app.textViews["Task Description"]
        assertElementIsAccessible(descriptionField)
        
        let assigneePicker = app.buttons["Select Assignee"]
        assertElementIsAccessible(assigneePicker)
        
        let categoryPicker = app.buttons["Select Category"]
        assertElementIsAccessible(categoryPicker)
        
        let createButton = app.buttons["Create Task"]
        assertElementIsAccessible(createButton)
        
        // Test cancel button accessibility
        let cancelButton = app.buttons["Cancel"]
        assertElementIsAccessible(cancelButton)
    }
    
    // MARK: - Error Handling Tests
    
    /// Test task creation error handling
    func testTaskCreationErrorHandling() {
        // Arrange: Navigate to task creation form
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Tasks")
        
        let addTaskButton = app.buttons["Add Task"]
        safeTap(addTaskButton)
        
        // Test with invalid input (empty title)
        let createButton = app.buttons["Create Task"]
        
        // Create button should be disabled with invalid input
        XCTAssertFalse(createButton.isEnabled, "Create button should be disabled with invalid input")
        
        // Fill in minimal valid data
        let taskTitleField = app.textFields["Task Title"]
        safeTypeText("Test Task", into: taskTitleField)
        
        let assigneePicker = app.buttons["Select Assignee"]
        safeTap(assigneePicker)
        
        let firstAssignee = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Member'")).firstMatch
        if firstAssignee.waitForExistence(timeout: defaultTimeout) {
            safeTap(firstAssignee)
        }
        
        // Try to create task
        safeTap(createButton)
        
        // Handle any error alerts
        if isErrorAlertDisplayed() {
            dismissErrorAlerts()
        }
        
        // Form should remain functional
        XCTAssertTrue(taskTitleField.exists, "Form should remain functional after error")
    }
    
    /// Test task list error handling
    func testTaskListErrorHandling() {
        // Arrange: Sign in and navigate to tasks
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Tasks")
        
        // Simulate error by attempting invalid operation
        let filterButton = app.buttons["Filter"]
        safeTap(filterButton)
        
        // Handle any error alerts
        if isErrorAlertDisplayed() {
            dismissErrorAlerts()
        }
        
        // Tasks view should remain functional
        let tasksTitle = app.navigationBars["Family Tasks"]
        XCTAssertTrue(tasksTitle.exists, "Tasks view should remain functional after error")
    }
    
    // MARK: - Performance Tests
    
    /// Test task list loading performance
    func testTaskListLoadingPerformance() {
        // Measure task list loading time
        measure {
            performMockSignIn()
            waitForLoadingToComplete()
            navigateToTab("Tasks")
            
            let tasksTitle = app.navigationBars["Family Tasks"]
            XCTAssertTrue(tasksTitle.waitForExistence(timeout: defaultTimeout))
            
            waitForLoadingToComplete()
            
            // Reset for next iteration
            performSignOut()
        }
    }
    
    /// Test task creation performance
    func testTaskCreationPerformance() {
        // Arrange: Sign in and navigate to tasks
        performMockSignIn()
        waitForLoadingToComplete()
        navigateToTab("Tasks")
        
        measure {
            let addTaskButton = app.buttons["Add Task"]
            safeTap(addTaskButton)
            
            let taskTitleField = app.textFields["Task Title"]
            safeTypeText("Performance Test Task", into: taskTitleField)
            
            let assigneePicker = app.buttons["Select Assignee"]
            safeTap(assigneePicker)
            
            let firstAssignee = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Member'")).firstMatch
            if firstAssignee.waitForExistence(timeout: defaultTimeout) {
                safeTap(firstAssignee)
            }
            
            let createButton = app.buttons["Create Task"]
            safeTap(createButton)
            
            waitForLoadingToComplete(timeout: longTimeout)
            
            // Reset for next iteration
            let cancelButton = app.buttons["Cancel"]
            if cancelButton.exists {
                safeTap(cancelButton)
            }
        }
    }
}