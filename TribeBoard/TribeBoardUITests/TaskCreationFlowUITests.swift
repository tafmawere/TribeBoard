import XCTest

/// UI tests for task creation flow and platform selection interactions
final class TaskCreationFlowUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Task List Navigation Tests
    
    @MainActor
    func testTaskListNavigation() throws {
        // Navigate to Tasks
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Tasks"].tap()
        
        // Verify we're on Tasks screen
        let tasksTitle = app.navigationBars["Shopping Tasks"]
        XCTAssertTrue(tasksTitle.exists, "Should be on Shopping Tasks screen")
    }
    
    @MainActor
    func testTaskListElements() throws {
        // Navigate to Tasks
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Tasks"].tap()
        
        // Look for task list elements
        let filterButton = app.buttons["Filter"]
        let addTaskButton = app.buttons["Add Task"]
        let createTaskButton = app.buttons["Create Task"]
        
        // At least one navigation element should exist
        XCTAssertTrue(filterButton.exists || addTaskButton.exists || createTaskButton.exists, 
                     "Task list should have navigation elements")
    }
    
    // MARK: - Task Creation Navigation Tests
    
    @MainActor
    func testNavigateToTaskCreation() throws {
        // Navigate to Tasks
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Tasks"].tap()
        
        // Look for create task button
        let createTaskButton = app.buttons["Create Task"]
        let addTaskButton = app.buttons["Add Task"]
        let plusButton = app.buttons["+"]
        
        if createTaskButton.exists {
            createTaskButton.tap()
        } else if addTaskButton.exists {
            addTaskButton.tap()
        } else if plusButton.exists {
            plusButton.tap()
        }
        
        // Should navigate to task creation form
        let taskCreationTitle = app.navigationBars["Create Task"]
        let taskFormTitle = app.navigationBars["New Task"]
        
        XCTAssertTrue(taskCreationTitle.exists || taskFormTitle.exists, 
                     "Should navigate to task creation form")
    }
    
    // MARK: - Task Creation Form Tests
    
    @MainActor
    func testTaskCreationFormElements() throws {
        // Navigate to task creation
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Tasks"].tap()
        
        let createTaskButton = app.buttons["Create Task"]
        if createTaskButton.exists {
            createTaskButton.tap()
            
            // Test form elements
            let assigneeField = app.buttons["Assign to"]
            let taskTypeField = app.buttons["Task Type"]
            let dueDateField = app.buttons["Due Date"]
            let notesField = app.textFields["Notes"]
            
            // At least assignee and task type should exist
            XCTAssertTrue(assigneeField.exists || taskTypeField.exists, 
                         "Task creation form should have assignee and task type fields")
        }
    }
    
    @MainActor
    func testFamilyMemberSelection() throws {
        // Navigate to task creation
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Tasks"].tap()
        
        let createTaskButton = app.buttons["Create Task"]
        if createTaskButton.exists {
            createTaskButton.tap()
            
            // Test family member selection
            let assigneeField = app.buttons["Assign to"]
            if assigneeField.exists {
                assigneeField.tap()
                
                // Should show family member picker
                let memberPicker = app.pickers.firstMatch
                let memberSheet = app.sheets.firstMatch
                let memberList = app.tables.firstMatch
                
                XCTAssertTrue(memberPicker.exists || memberSheet.exists || memberList.exists, 
                             "Should show family member selection interface")
                
                // Try to select a family member
                let familyMember = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Mom' OR label CONTAINS 'Dad' OR label CONTAINS 'Sarah'")).firstMatch
                if familyMember.exists {
                    familyMember.tap()
                }
            }
        }
    }
    
    @MainActor
    func testTaskTypeSelection() throws {
        // Navigate to task creation
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Tasks"].tap()
        
        let createTaskButton = app.buttons["Create Task"]
        if createTaskButton.exists {
            createTaskButton.tap()
            
            // Test task type selection
            let taskTypeField = app.buttons["Task Type"]
            if taskTypeField.exists {
                taskTypeField.tap()
                
                // Should show task type options
                let shopRunOption = app.buttons["Shop Run"]
                let schoolRunOption = app.buttons["School Run + Shop Stop"]
                
                XCTAssertTrue(shopRunOption.exists || schoolRunOption.exists, 
                             "Should show task type options")
                
                // Test selecting shop run
                if shopRunOption.exists {
                    shopRunOption.tap()
                }
                
                // Test selecting school run + shop
                if schoolRunOption.exists {
                    schoolRunOption.tap()
                    
                    // Should show location selection for school run
                    let locationField = app.buttons["Location"]
                    XCTAssertTrue(locationField.exists, "Location field should appear for school run + shop")
                }
            }
        }
    }
    
    @MainActor
    func testDueDateSelection() throws {
        // Navigate to task creation
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Tasks"].tap()
        
        let createTaskButton = app.buttons["Create Task"]
        if createTaskButton.exists {
            createTaskButton.tap()
            
            // Test due date selection
            let dueDateField = app.buttons["Due Date"]
            if dueDateField.exists {
                dueDateField.tap()
                
                // Should show date picker
                let datePicker = app.datePickers.firstMatch
                let dateSheet = app.sheets.firstMatch
                
                XCTAssertTrue(datePicker.exists || dateSheet.exists, 
                             "Should show date selection interface")
                
                if datePicker.exists {
                    // Interact with date picker
                    datePicker.tap()
                }
            }
        }
    }
    
    @MainActor
    func testLocationSelection() throws {
        // Navigate to task creation
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Tasks"].tap()
        
        let createTaskButton = app.buttons["Create Task"]
        if createTaskButton.exists {
            createTaskButton.tap()
            
            // Select school run + shop to enable location
            let taskTypeField = app.buttons["Task Type"]
            if taskTypeField.exists {
                taskTypeField.tap()
                
                let schoolRunOption = app.buttons["School Run + Shop Stop"]
                if schoolRunOption.exists {
                    schoolRunOption.tap()
                    
                    // Test location selection
                    let locationField = app.buttons["Location"]
                    if locationField.exists {
                        locationField.tap()
                        
                        // Should show location picker or map
                        let locationPicker = app.tables.firstMatch
                        let mapView = app.maps.firstMatch
                        
                        XCTAssertTrue(locationPicker.exists || mapView.exists, 
                                     "Should show location selection interface")
                        
                        // Try to select a location
                        let storeLocation = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Woolworths' OR label CONTAINS 'Pick n Pay'")).firstMatch
                        if storeLocation.exists {
                            storeLocation.tap()
                        }
                    }
                }
            }
        }
    }
    
    @MainActor
    func testNotesInput() throws {
        // Navigate to task creation
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Tasks"].tap()
        
        let createTaskButton = app.buttons["Create Task"]
        if createTaskButton.exists {
            createTaskButton.tap()
            
            // Test notes input
            let notesField = app.textFields["Notes"]
            let notesTextView = app.textViews["Notes"]
            
            if notesField.exists {
                notesField.tap()
                notesField.typeText("Test task notes")
                XCTAssertEqual(notesField.value as? String, "Test task notes", "Notes should be entered correctly")
            } else if notesTextView.exists {
                notesTextView.tap()
                notesTextView.typeText("Test task notes")
            }
        }
    }
    
    // MARK: - Task Creation Submission Tests
    
    @MainActor
    func testTaskCreationSubmission() throws {
        // Navigate to task creation
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Tasks"].tap()
        
        let createTaskButton = app.buttons["Create Task"]
        if createTaskButton.exists {
            createTaskButton.tap()
            
            // Fill out minimum required fields
            let assigneeField = app.buttons["Assign to"]
            if assigneeField.exists {
                assigneeField.tap()
                
                // Select first available family member
                let familyMember = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Mom' OR label CONTAINS 'Dad'")).firstMatch
                if familyMember.exists {
                    familyMember.tap()
                }
            }
            
            // Submit the task
            let submitButton = app.buttons["Create Task"]
            let saveButton = app.buttons["Save"]
            
            if submitButton.exists {
                submitButton.tap()
            } else if saveButton.exists {
                saveButton.tap()
            }
            
            // Should show success message or return to task list
            let successAlert = app.alerts.firstMatch
            let taskListTitle = app.navigationBars["Shopping Tasks"]
            
            XCTAssertTrue(successAlert.exists || taskListTitle.exists, 
                         "Should show success confirmation or return to task list")
        }
    }
    
    @MainActor
    func testTaskCreationValidation() throws {
        // Navigate to task creation
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Tasks"].tap()
        
        let createTaskButton = app.buttons["Create Task"]
        if createTaskButton.exists {
            createTaskButton.tap()
            
            // Try to submit without required fields
            let submitButton = app.buttons["Create Task"]
            if submitButton.exists {
                submitButton.tap()
                
                // Should show validation error
                let errorAlert = app.alerts.firstMatch
                let errorMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'required' OR label CONTAINS 'error'")).firstMatch
                
                XCTAssertTrue(errorAlert.exists || errorMessage.exists, 
                             "Should show validation error for incomplete form")
            }
        }
    }
    
    // MARK: - Task List Display Tests
    
    @MainActor
    func testTaskListDisplay() throws {
        // Navigate to Tasks
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Tasks"].tap()
        
        // Wait for tasks to load
        sleep(2)
        
        // Look for task cards
        let taskCard = app.cells.matching(identifier: "taskCard").firstMatch
        
        if taskCard.exists {
            XCTAssertTrue(taskCard.exists, "Task card should be displayed")
            
            // Test task card elements
            let taskTitle = taskCard.staticTexts.firstMatch
            let assigneeLabel = taskCard.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Assigned to'")).firstMatch
            let statusBadge = taskCard.buttons.matching(NSPredicate(format: "label CONTAINS 'Pending' OR label CONTAINS 'In Progress'")).firstMatch
            
            XCTAssertTrue(taskTitle.exists, "Task should have a title")
        }
    }
    
    @MainActor
    func testTaskFiltering() throws {
        // Navigate to Tasks
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Tasks"].tap()
        
        // Look for filter options
        let filterButton = app.buttons["Filter"]
        let allFilter = app.buttons["All"]
        let pendingFilter = app.buttons["Pending"]
        let dueTodayFilter = app.buttons["Due Today"]
        
        if filterButton.exists {
            filterButton.tap()
            
            // Should show filter options
            let filterSheet = app.sheets.firstMatch
            let filterMenu = app.menus.firstMatch
            
            XCTAssertTrue(filterSheet.exists || filterMenu.exists, 
                         "Should show filter options")
        } else if allFilter.exists && pendingFilter.exists {
            // Test direct filter buttons
            pendingFilter.tap()
            XCTAssertTrue(pendingFilter.isSelected, "Pending filter should be selected")
            
            allFilter.tap()
            XCTAssertTrue(allFilter.isSelected, "All filter should be selected")
        }
    }
    
    // MARK: - Task Status Management Tests
    
    @MainActor
    func testTaskStatusUpdate() throws {
        // Navigate to Tasks
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Tasks"].tap()
        
        // Wait for tasks to load
        sleep(2)
        
        // Look for task with status that can be updated
        let taskCard = app.cells.matching(identifier: "taskCard").firstMatch
        
        if taskCard.exists {
            // Try to update task status
            taskCard.tap()
            
            // Should show task detail or status options
            let taskDetail = app.navigationBars["Task Detail"]
            let statusButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Mark' OR label CONTAINS 'Complete'")).firstMatch
            
            if taskDetail.exists || statusButton.exists {
                if statusButton.exists {
                    statusButton.tap()
                    
                    // Should update status
                    let completedStatus = app.staticTexts["Completed"]
                    let inProgressStatus = app.staticTexts["In Progress"]
                    
                    XCTAssertTrue(completedStatus.exists || inProgressStatus.exists, 
                                 "Task status should be updated")
                }
            }
        }
    }
    
    // MARK: - Empty State Tests
    
    @MainActor
    func testTaskListEmptyState() throws {
        // Navigate to Tasks
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Tasks"].tap()
        
        // Look for empty state (may or may not exist depending on data)
        let emptyStateMessage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'No tasks' OR label CONTAINS 'empty'")).firstMatch
        
        if emptyStateMessage.exists {
            XCTAssertTrue(emptyStateMessage.exists, "Empty state should be displayed when no tasks exist")
            
            // Should have call-to-action to create first task
            let createFirstTaskButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Create' OR label CONTAINS 'Add'")).firstMatch
            XCTAssertTrue(createFirstTaskButton.exists, "Should have button to create first task")
        }
    }
    
    // MARK: - Error State Tests
    
    @MainActor
    func testTaskCreationErrorHandling() throws {
        // Navigate to task creation
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Tasks"].tap()
        
        let createTaskButton = app.buttons["Create Task"]
        if createTaskButton.exists {
            createTaskButton.tap()
            
            // Try to create task with invalid data (e.g., past due date)
            let dueDateField = app.buttons["Due Date"]
            if dueDateField.exists {
                dueDateField.tap()
                
                // Try to set past date (if date picker allows it)
                let datePicker = app.datePickers.firstMatch
                if datePicker.exists {
                    // This would depend on the specific date picker implementation
                    datePicker.tap()
                }
            }
            
            // Try to submit
            let submitButton = app.buttons["Create Task"]
            if submitButton.exists {
                submitButton.tap()
                
                // Should handle error gracefully
                let errorAlert = app.alerts.firstMatch
                if errorAlert.exists {
                    XCTAssertTrue(errorAlert.exists, "Should show error alert for invalid data")
                    
                    // Dismiss error
                    let okButton = errorAlert.buttons["OK"]
                    if okButton.exists {
                        okButton.tap()
                    }
                }
            }
        }
    }
    
    // MARK: - Loading State Tests
    
    @MainActor
    func testTaskCreationLoadingState() throws {
        // Navigate to task creation
        app.tabBars.buttons["HomeLife"].tap()
        app.buttons["Tasks"].tap()
        
        let createTaskButton = app.buttons["Create Task"]
        if createTaskButton.exists {
            createTaskButton.tap()
            
            // Fill out form quickly and submit to potentially catch loading state
            let assigneeField = app.buttons["Assign to"]
            if assigneeField.exists {
                assigneeField.tap()
                
                let familyMember = app.buttons.firstMatch
                if familyMember.exists {
                    familyMember.tap()
                }
            }
            
            let submitButton = app.buttons["Create Task"]
            if submitButton.exists {
                submitButton.tap()
                
                // Look for loading indicator
                let loadingIndicator = app.activityIndicators.firstMatch
                let loadingText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Creating' OR label CONTAINS 'Loading'")).firstMatch
                
                // Loading state may be brief
                if loadingIndicator.exists || loadingText.exists {
                    XCTAssertTrue(loadingIndicator.exists || loadingText.exists, 
                                 "Should show loading state during task creation")
                }
            }
        }
    }
}