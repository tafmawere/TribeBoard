import XCTest

/// UI tests for loading state display, animations, and user experience
class LoadingStateUITests: UITestBase {
    
    // MARK: - Test Setup
    
    override func setUp() {
        super.setUp()
        
        // Configure app for loading state testing
        app.launchEnvironment["ENABLE_LOADING_SCENARIOS"] = "1"
        app.launchEnvironment["MOCK_LOADING_STATES"] = "1"
        app.launchEnvironment["EXTENDED_LOADING_TIMES"] = "1"
    }
    
    // MARK: - Loading Indicator Display Tests
    
    func testAuthenticationLoadingIndicator() {
        // Start from sign-in screen
        let signInButton = app.buttons["Sign in with Apple"]
        XCTAssertTrue(signInButton.waitForExistence(timeout: defaultTimeout))
        
        // Configure extended loading time for testing
        app.buttons["Demo Controls"].tap()
        app.buttons["Set Loading Duration"].tap()
        app.buttons["5 seconds"].tap()
        app.buttons["Done"].tap()
        
        // Initiate sign-in
        signInButton.tap()
        
        // Verify loading indicator appears
        let loadingIndicator = app.activityIndicators.firstMatch
        XCTAssertTrue(loadingIndicator.waitForExistence(timeout: shortTimeout))
        
        // Verify loading message
        let loadingMessage = app.staticTexts["Signing in..."]
        XCTAssertTrue(loadingMessage.exists)
        
        // Verify sign-in button is disabled during loading
        XCTAssertFalse(signInButton.isEnabled)
        
        // Verify loading indicator is animating
        XCTAssertTrue(loadingIndicator.exists)
        
        takeScreenshot(name: "Authentication Loading Indicator")
        
        // Wait for loading to complete
        waitForLoadingToComplete(timeout: longTimeout)
        
        // Verify loading indicator disappears
        XCTAssertTrue(loadingIndicator.waitForNonExistence(timeout: defaultTimeout))
    }
    
    func testFamilyCreationLoadingDisplay() {
        performMockSignIn()
        navigateToTab("Family")
        
        // Start family creation
        app.buttons["Create New Family"].tap()
        
        let familyNameField = app.textFields["Family Name"]
        clearAndTypeText("Test Family", into: familyNameField)
        
        // Configure extended loading for testing
        app.buttons["Demo Controls"].tap()
        app.buttons["Set Loading Duration"].tap()
        app.buttons["3 seconds"].tap()
        app.buttons["Done"].tap()
        
        // Submit form
        app.buttons["Create Family"].tap()
        
        // Verify loading overlay appears
        let loadingOverlay = app.otherElements["LoadingOverlay"]
        XCTAssertTrue(loadingOverlay.waitForExistence(timeout: shortTimeout))
        
        // Verify loading message
        let loadingMessage = app.staticTexts["Creating your family..."]
        XCTAssertTrue(loadingMessage.exists)
        
        // Verify form is disabled during loading
        let createButton = app.buttons["Create Family"]
        XCTAssertFalse(createButton.isEnabled)
        
        // Verify loading animation
        let loadingSpinner = app.activityIndicators.firstMatch
        XCTAssertTrue(loadingSpinner.exists)
        
        takeScreenshot(name: "Family Creation Loading")
        
        // Wait for completion
        waitForLoadingToComplete(timeout: longTimeout)
        
        // Verify loading overlay disappears
        XCTAssertTrue(loadingOverlay.waitForNonExistence(timeout: defaultTimeout))
    }
    
    func testDataSyncLoadingIndicators() {
        performMockSignIn()
        navigateToTab("Tasks")
        
        // Configure data sync loading scenario
        app.buttons["Demo Controls"].tap()
        app.buttons["Trigger Data Sync"].tap()
        app.buttons["Set Loading Duration"].tap()
        app.buttons["4 seconds"].tap()
        app.buttons["Done"].tap()
        
        // Trigger data refresh
        app.scrollViews.firstMatch.swipeDown()
        
        // Verify pull-to-refresh loading indicator
        let refreshIndicator = app.activityIndicators["RefreshIndicator"]
        XCTAssertTrue(refreshIndicator.waitForExistence(timeout: shortTimeout))
        
        // Verify sync status message
        let syncMessage = app.staticTexts["Syncing tasks..."]
        XCTAssertTrue(syncMessage.exists)
        
        // Verify content remains accessible during sync
        let existingTasks = app.cells.matching(identifier: "TaskCell")
        XCTAssertGreaterThan(existingTasks.count, 0)
        
        takeScreenshot(name: "Data Sync Loading")
        
        // Wait for sync completion
        waitForLoadingToComplete(timeout: longTimeout)
        
        // Verify refresh indicator disappears
        XCTAssertTrue(refreshIndicator.waitForNonExistence(timeout: defaultTimeout))
    }
    
    func testProgressIndicatorDisplay() {
        performMockSignIn()
        navigateToTab("Family")
        
        // Start a process with progress indication
        app.buttons["Import Family Data"].tap()
        
        // Configure progress loading scenario
        app.buttons["Demo Controls"].tap()
        app.buttons["Enable Progress Indicator"].tap()
        app.buttons["Set Loading Duration"].tap()
        app.buttons["6 seconds"].tap()
        app.buttons["Done"].tap()
        
        // Start import process
        app.buttons["Start Import"].tap()
        
        // Verify progress indicator appears
        let progressIndicator = app.progressIndicators.firstMatch
        XCTAssertTrue(progressIndicator.waitForExistence(timeout: shortTimeout))
        
        // Verify progress message
        let progressMessage = app.staticTexts["Importing family data..."]
        XCTAssertTrue(progressMessage.exists)
        
        // Verify progress percentage
        let progressPercentage = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '%'")).firstMatch
        XCTAssertTrue(progressPercentage.waitForExistence(timeout: shortTimeout))
        
        // Wait a moment and verify progress updates
        sleep(2)
        let updatedPercentage = progressPercentage.label
        XCTAssertFalse(updatedPercentage.isEmpty)
        
        takeScreenshot(name: "Progress Indicator Display")
        
        // Wait for completion
        waitForLoadingToComplete(timeout: longTimeout)
        
        // Verify progress indicator disappears
        XCTAssertTrue(progressIndicator.waitForNonExistence(timeout: defaultTimeout))
    }
    
    // MARK: - Loading Animation Tests
    
    func testLoadingAnimationSmoothness() {
        performMockSignIn()
        navigateToTab("Meal Plan")
        
        // Configure loading scenario
        app.buttons["Demo Controls"].tap()
        app.buttons["Set Loading Duration"].tap()
        app.buttons["5 seconds"].tap()
        app.buttons["Done"].tap()
        
        // Trigger loading
        app.buttons["Generate Meal Plan"].tap()
        
        // Verify loading animation starts
        let loadingIndicator = app.activityIndicators.firstMatch
        XCTAssertTrue(loadingIndicator.waitForExistence(timeout: shortTimeout))
        
        // Monitor animation for smoothness (basic check)
        let initialFrame = loadingIndicator.frame
        
        // Wait a moment for animation
        sleep(1)
        
        // Verify indicator is still animating
        XCTAssertTrue(loadingIndicator.exists)
        XCTAssertEqual(loadingIndicator.frame, initialFrame) // Position should remain stable
        
        takeScreenshot(name: "Loading Animation Smoothness")
        
        waitForLoadingToComplete(timeout: longTimeout)
    }
    
    func testShimmerLoadingAnimation() {
        performMockSignIn()
        navigateToTab("Family")
        
        // Configure shimmer loading scenario
        app.buttons["Demo Controls"].tap()
        app.buttons["Enable Shimmer Loading"].tap()
        app.buttons["Set Loading Duration"].tap()
        app.buttons["4 seconds"].tap()
        app.buttons["Done"].tap()
        
        // Trigger content loading
        app.buttons["Refresh Family Data"].tap()
        
        // Verify shimmer loading elements appear
        let shimmerElements = app.otherElements.matching(identifier: "ShimmerLoadingView")
        XCTAssertGreaterThan(shimmerElements.count, 0)
        
        // Verify shimmer placeholder structure
        let shimmerAvatar = app.otherElements["ShimmerAvatar"]
        let shimmerText = app.otherElements["ShimmerText"]
        
        XCTAssertTrue(shimmerAvatar.waitForExistence(timeout: shortTimeout))
        XCTAssertTrue(shimmerText.exists)
        
        takeScreenshot(name: "Shimmer Loading Animation")
        
        // Wait for real content to load
        waitForLoadingToComplete(timeout: longTimeout)
        
        // Verify shimmer elements are replaced with real content
        XCTAssertTrue(shimmerElements.firstMatch.waitForNonExistence(timeout: defaultTimeout))
    }
    
    func testPulseLoadingAnimation() {
        performMockSignIn()
        navigateToTab("Tasks")
        
        // Configure pulse loading scenario
        app.buttons["Demo Controls"].tap()
        app.buttons["Enable Pulse Loading"].tap()
        app.buttons["Set Loading Duration"].tap()
        app.buttons["3 seconds"].tap()
        app.buttons["Done"].tap()
        
        // Create new task to trigger loading
        app.buttons["Add Task"].tap()
        
        let taskNameField = app.textFields["Task Name"]
        clearAndTypeText("Test Task", into: taskNameField)
        
        app.buttons["Save Task"].tap()
        
        // Verify pulse loading animation
        let pulseLoadingView = app.otherElements["PulseLoadingView"]
        XCTAssertTrue(pulseLoadingView.waitForExistence(timeout: shortTimeout))
        
        takeScreenshot(name: "Pulse Loading Animation")
        
        waitForLoadingToComplete(timeout: longTimeout)
        
        // Verify pulse animation disappears
        XCTAssertTrue(pulseLoadingView.waitForNonExistence(timeout: defaultTimeout))
    }
    
    // MARK: - Loading State Accessibility Tests
    
    func testLoadingStateAccessibilityLabels() {
        performMockSignIn()
        navigateToTab("Family")
        
        // Configure loading scenario
        app.buttons["Demo Controls"].tap()
        app.buttons["Set Loading Duration"].tap()
        app.buttons["4 seconds"].tap()
        app.buttons["Done"].tap()
        
        // Trigger loading
        app.buttons["Load Family Members"].tap()
        
        // Verify loading indicator accessibility
        let loadingIndicator = app.activityIndicators.firstMatch
        XCTAssertTrue(loadingIndicator.waitForExistence(timeout: shortTimeout))
        
        // Verify accessibility label
        verifyAccessibilityLabel(loadingIndicator, expectedLabel: "Loading")
        
        // Verify loading message accessibility
        let loadingMessage = app.staticTexts["Loading family members..."]
        XCTAssertTrue(loadingMessage.exists)
        XCTAssertFalse(loadingMessage.label.isEmpty)
        
        // Verify loading state is announced to screen readers
        let loadingAnnouncement = app.staticTexts["Loading in progress"]
        XCTAssertTrue(loadingAnnouncement.exists)
        
        takeScreenshot(name: "Loading State Accessibility")
        
        waitForLoadingToComplete(timeout: longTimeout)
    }
    
    func testProgressIndicatorAccessibility() {
        performMockSignIn()
        navigateToTab("Settings")
        
        // Start a process with progress
        app.buttons["Export Data"].tap()
        
        // Configure progress scenario
        app.buttons["Demo Controls"].tap()
        app.buttons["Enable Progress Indicator"].tap()
        app.buttons["Set Loading Duration"].tap()
        app.buttons["5 seconds"].tap()
        app.buttons["Done"].tap()
        
        app.buttons["Start Export"].tap()
        
        // Verify progress indicator accessibility
        let progressIndicator = app.progressIndicators.firstMatch
        XCTAssertTrue(progressIndicator.waitForExistence(timeout: shortTimeout))
        
        // Verify progress value is accessible
        XCTAssertTrue(progressIndicator.value != nil)
        
        // Verify progress description
        let progressDescription = app.staticTexts["Export progress: 25% complete"]
        XCTAssertTrue(progressDescription.waitForExistence(timeout: shortTimeout))
        
        // Wait for progress update
        sleep(2)
        
        // Verify progress updates are announced
        let updatedProgress = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'progress:'")).firstMatch
        XCTAssertTrue(updatedProgress.exists)
        
        takeScreenshot(name: "Progress Indicator Accessibility")
        
        waitForLoadingToComplete(timeout: longTimeout)
    }
    
    func testLoadingStateScreenReaderSupport() {
        performMockSignIn()
        navigateToTab("Tasks")
        
        // Configure loading scenario
        app.buttons["Demo Controls"].tap()
        app.buttons["Set Loading Duration"].tap()
        app.buttons["4 seconds"].tap()
        app.buttons["Done"].tap()
        
        // Trigger loading
        app.buttons["Sync Tasks"].tap()
        
        // Verify loading elements are accessible to screen readers
        let loadingElements = [
            app.activityIndicators.firstMatch,
            app.staticTexts["Syncing tasks..."],
            app.staticTexts["Please wait while we sync your tasks"]
        ]
        
        for element in loadingElements {
            XCTAssertTrue(element.waitForExistence(timeout: shortTimeout))
            assertElementIsAccessible(element)
        }
        
        // Verify loading state doesn't interfere with existing content accessibility
        let existingContent = app.cells.matching(identifier: "TaskCell").firstMatch
        if existingContent.exists {
            assertElementIsAccessible(existingContent)
        }
        
        waitForLoadingToComplete(timeout: longTimeout)
    }
    
    // MARK: - Loading Timeout Tests
    
    func testLoadingTimeoutHandling() {
        performMockSignIn()
        navigateToTab("Family")
        
        // Configure timeout scenario
        app.buttons["Demo Controls"].tap()
        app.buttons["Enable Loading Timeout"].tap()
        app.buttons["Set Timeout Duration"].tap()
        app.buttons["10 seconds"].tap()
        app.buttons["Done"].tap()
        
        // Trigger operation that will timeout
        app.buttons["Load Large Dataset"].tap()
        
        // Verify loading indicator appears
        let loadingIndicator = app.activityIndicators.firstMatch
        XCTAssertTrue(loadingIndicator.waitForExistence(timeout: shortTimeout))
        
        // Wait for timeout to occur
        let timeoutMessage = app.staticTexts["Request timed out"]
        XCTAssertTrue(timeoutMessage.waitForExistence(timeout: 15.0))
        
        // Verify timeout error handling
        let timeoutErrorView = app.otherElements["TimeoutErrorView"]
        XCTAssertTrue(timeoutErrorView.exists)
        
        // Verify retry option is available
        let retryButton = app.buttons["Try Again"]
        XCTAssertTrue(retryButton.exists)
        XCTAssertTrue(retryButton.isEnabled)
        
        takeScreenshot(name: "Loading Timeout Handling")
        
        // Verify loading indicator is removed after timeout
        XCTAssertTrue(loadingIndicator.waitForNonExistence(timeout: defaultTimeout))
    }
    
    func testLoadingCancellation() {
        performMockSignIn()
        navigateToTab("Family")
        
        // Configure cancellable loading scenario
        app.buttons["Demo Controls"].tap()
        app.buttons["Enable Cancellable Loading"].tap()
        app.buttons["Set Loading Duration"].tap()
        app.buttons["8 seconds"].tap()
        app.buttons["Done"].tap()
        
        // Start operation
        app.buttons["Import Large File"].tap()
        
        // Verify loading with cancel option
        let loadingOverlay = app.otherElements["LoadingOverlay"]
        XCTAssertTrue(loadingOverlay.waitForExistence(timeout: shortTimeout))
        
        let cancelButton = app.buttons["Cancel"]
        XCTAssertTrue(cancelButton.exists)
        XCTAssertTrue(cancelButton.isEnabled)
        
        // Wait a moment then cancel
        sleep(2)
        cancelButton.tap()
        
        // Verify cancellation confirmation
        let cancelAlert = app.alerts["Cancel Operation"]
        XCTAssertTrue(cancelAlert.waitForExistence(timeout: shortTimeout))
        
        let confirmCancelButton = cancelAlert.buttons["Yes, Cancel"]
        confirmCancelButton.tap()
        
        // Verify loading is cancelled
        XCTAssertTrue(loadingOverlay.waitForNonExistence(timeout: defaultTimeout))
        
        // Verify cancellation message
        let cancellationMessage = app.staticTexts["Operation cancelled"]
        XCTAssertTrue(cancellationMessage.waitForExistence(timeout: shortTimeout))
        
        takeScreenshot(name: "Loading Cancellation")
    }
    
    // MARK: - Loading State User Feedback Tests
    
    func testLoadingFeedbackMessages() {
        performMockSignIn()
        navigateToTab("Settings")
        
        // Test different loading scenarios with specific feedback
        let loadingScenarios = [
            ("Backup Data", "Creating backup...", "BackupLoadingView"),
            ("Restore Data", "Restoring from backup...", "RestoreLoadingView"),
            ("Update Profile", "Saving changes...", "ProfileUpdateLoadingView")
        ]
        
        for (buttonText, expectedMessage, viewIdentifier) in loadingScenarios {
            // Configure loading scenario
            app.buttons["Demo Controls"].tap()
            app.buttons["Set Loading Duration"].tap()
            app.buttons["3 seconds"].tap()
            app.buttons["Done"].tap()
            
            // Trigger operation
            app.buttons[buttonText].tap()
            
            // Verify specific loading message
            let loadingMessage = app.staticTexts[expectedMessage]
            XCTAssertTrue(loadingMessage.waitForExistence(timeout: shortTimeout))
            
            // Verify loading view
            let loadingView = app.otherElements[viewIdentifier]
            XCTAssertTrue(loadingView.exists)
            
            // Wait for completion
            waitForLoadingToComplete(timeout: longTimeout)
            
            // Verify loading message disappears
            XCTAssertTrue(loadingMessage.waitForNonExistence(timeout: defaultTimeout))
            
            // Navigate back for next test
            navigateBack()
        }
        
        takeScreenshot(name: "Loading Feedback Messages")
    }
    
    func testLoadingStateUserGuidance() {
        performMockSignIn()
        navigateToTab("Family")
        
        // Configure extended loading with guidance
        app.buttons["Demo Controls"].tap()
        app.buttons["Enable Loading Guidance"].tap()
        app.buttons["Set Loading Duration"].tap()
        app.buttons["6 seconds"].tap()
        app.buttons["Done"].tap()
        
        // Start operation
        app.buttons["Sync All Data"].tap()
        
        // Verify initial loading message
        let initialMessage = app.staticTexts["Starting sync..."]
        XCTAssertTrue(initialMessage.waitForExistence(timeout: shortTimeout))
        
        // Wait for progress updates
        sleep(2)
        
        // Verify progress guidance
        let progressMessage = app.staticTexts["Syncing family data..."]
        XCTAssertTrue(progressMessage.waitForExistence(timeout: shortTimeout))
        
        // Wait for more progress
        sleep(2)
        
        // Verify final stage message
        let finalMessage = app.staticTexts["Almost done..."]
        XCTAssertTrue(finalMessage.waitForExistence(timeout: shortTimeout))
        
        // Wait for completion
        waitForLoadingToComplete(timeout: longTimeout)
        
        // Verify completion message
        let completionMessage = app.staticTexts["Sync completed successfully"]
        XCTAssertTrue(completionMessage.waitForExistence(timeout: shortTimeout))
        
        takeScreenshot(name: "Loading State User Guidance")
    }
    
    // MARK: - Loading State Performance Tests
    
    func testLoadingStatePerformance() {
        performMockSignIn()
        navigateToTab("Tasks")
        
        // Measure loading state display performance
        measure {
            // Configure quick loading scenario
            app.buttons["Demo Controls"].tap()
            app.buttons["Set Loading Duration"].tap()
            app.buttons["1 second"].tap()
            app.buttons["Done"].tap()
            
            // Trigger loading
            app.buttons["Quick Sync"].tap()
            
            // Wait for loading to appear and complete
            let loadingIndicator = app.activityIndicators.firstMatch
            XCTAssertTrue(loadingIndicator.waitForExistence(timeout: shortTimeout))
            waitForLoadingToComplete(timeout: shortTimeout)
        }
    }
    
    func testMultipleLoadingStatesHandling() {
        performMockSignIn()
        navigateToTab("Family")
        
        // Configure multiple loading operations
        app.buttons["Demo Controls"].tap()
        app.buttons["Enable Multiple Loading"].tap()
        app.buttons["Set Loading Duration"].tap()
        app.buttons["4 seconds"].tap()
        app.buttons["Done"].tap()
        
        // Start multiple operations
        app.buttons["Sync Family Data"].tap()
        
        // Wait a moment then start another operation
        sleep(1)
        app.buttons["Load Member Profiles"].tap()
        
        // Verify primary loading indicator
        let primaryLoading = app.activityIndicators["PrimaryLoading"]
        XCTAssertTrue(primaryLoading.waitForExistence(timeout: shortTimeout))
        
        // Verify secondary loading is queued or handled appropriately
        let queuedMessage = app.staticTexts["Additional operations in progress: 1"]
        XCTAssertTrue(queuedMessage.exists)
        
        // Wait for all operations to complete
        waitForLoadingToComplete(timeout: longTimeout)
        
        // Verify all loading indicators are removed
        XCTAssertTrue(primaryLoading.waitForNonExistence(timeout: defaultTimeout))
        
        takeScreenshot(name: "Multiple Loading States")
    }
}