import XCTest

/// Collection of helper functions and utilities for UI testing
struct UITestHelpers {
    
    // MARK: - Element Queries
    
    /// Finds a button by its accessibility identifier or label
    static func findButton(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        let button = app.buttons[identifier]
        if button.exists {
            return button
        }
        return app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", identifier)).firstMatch
    }
    
    /// Finds a text field by its accessibility identifier or placeholder
    static func findTextField(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        let textField = app.textFields[identifier]
        if textField.exists {
            return textField
        }
        return app.textFields.matching(NSPredicate(format: "placeholderValue CONTAINS[c] %@", identifier)).firstMatch
    }
    
    /// Finds a navigation bar by title
    static func findNavigationBar(_ title: String, in app: XCUIApplication) -> XCUIElement {
        return app.navigationBars[title]
    }
    
    /// Finds a tab bar button by label
    static func findTabBarButton(_ label: String, in app: XCUIApplication) -> XCUIElement {
        return app.tabBars.buttons[label]
    }
    
    // MARK: - Wait Utilities
    
    /// Waits for multiple elements to exist
    static func waitForElements(_ elements: [XCUIElement], timeout: TimeInterval = 10.0) -> Bool {
        for element in elements {
            if !element.waitForExistence(timeout: timeout) {
                return false
            }
        }
        return true
    }
    
    /// Waits for any one of multiple elements to exist
    static func waitForAnyElement(_ elements: [XCUIElement], timeout: TimeInterval = 10.0) -> XCUIElement? {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            for element in elements {
                if element.exists {
                    return element
                }
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        return nil
    }
    
    /// Waits for an element to become hittable
    static func waitForElementToBeHittable(_ element: XCUIElement, timeout: TimeInterval = 10.0) -> Bool {
        let startTime = Date()
        
        while Date().timeIntervalSince(startTime) < timeout {
            if element.exists && element.isHittable {
                return true
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        
        return false
    }
    
    // MARK: - Interaction Utilities
    
    /// Performs a safe tap with retry logic
    static func safeTapWithRetry(_ element: XCUIElement, maxRetries: Int = 3, timeout: TimeInterval = 10.0) -> Bool {
        for attempt in 1...maxRetries {
            if element.waitForExistence(timeout: timeout) && element.isHittable {
                element.tap()
                return true
            }
            
            if attempt < maxRetries {
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
        
        return false
    }
    
    /// Types text with automatic keyboard handling
    static func typeTextWithKeyboardHandling(_ text: String, into element: XCUIElement, app: XCUIApplication) {
        element.tap()
        
        // Wait for keyboard to appear
        let keyboard = app.keyboards.firstMatch
        _ = keyboard.waitForExistence(timeout: 5.0)
        
        element.typeText(text)
        
        // Dismiss keyboard if needed
        if keyboard.exists {
            app.toolbars.buttons["Done"].tap()
        }
    }
    
    /// Scrolls to make an element visible and tappable
    static func scrollToElement(_ element: XCUIElement, in scrollView: XCUIElement, direction: ScrollDirection = .up) {
        var attempts = 0
        let maxAttempts = 10
        
        while !element.isHittable && attempts < maxAttempts {
            switch direction {
            case .up:
                scrollView.swipeUp()
            case .down:
                scrollView.swipeDown()
            case .left:
                scrollView.swipeLeft()
            case .right:
                scrollView.swipeRight()
            }
            attempts += 1
        }
    }
    
    // MARK: - Form Utilities
    
    /// Fills out a form with validation
    static func fillFormFields(_ formData: [String: String], in app: XCUIApplication) -> Bool {
        for (fieldIdentifier, value) in formData {
            let textField = findTextField(fieldIdentifier, in: app)
            
            if !textField.waitForExistence(timeout: 5.0) {
                return false
            }
            
            textField.tap()
            textField.clearText()
            textField.typeText(value)
        }
        
        return true
    }
    
    /// Validates form field values
    static func validateFormFields(_ expectedValues: [String: String], in app: XCUIApplication) -> Bool {
        for (fieldIdentifier, expectedValue) in expectedValues {
            let textField = findTextField(fieldIdentifier, in: app)
            
            guard textField.exists,
                  let actualValue = textField.value as? String,
                  actualValue == expectedValue else {
                return false
            }
        }
        
        return true
    }
    
    // MARK: - Alert Utilities
    
    /// Handles system alerts (like permissions)
    static func handleSystemAlert(accept: Bool = true, in app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        
        if alert.waitForExistence(timeout: 5.0) {
            let button = accept ? alert.buttons.element(boundBy: 1) : alert.buttons.element(boundBy: 0)
            if button.exists {
                button.tap()
            }
        }
    }
    
    /// Dismisses app alerts with specific button text
    static func dismissAlert(withButton buttonText: String, in app: XCUIApplication) -> Bool {
        let alert = app.alerts.firstMatch
        
        if alert.waitForExistence(timeout: 5.0) {
            let button = alert.buttons[buttonText]
            if button.exists {
                button.tap()
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Screenshot Utilities
    
    /// Takes a screenshot with timestamp
    static func takeTimestampedScreenshot(name: String, testCase: XCTestCase) {
        let app = XCUIApplication()
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        let timestamp = DateFormatter.screenshotFormatter.string(from: Date())
        attachment.name = "\(name)_\(timestamp)"
        attachment.lifetime = .keepAlways
        testCase.add(attachment)
    }
    
    /// Takes a screenshot of a specific element
    static func takeElementScreenshot(_ element: XCUIElement, name: String, testCase: XCTestCase) {
        if element.exists {
            let screenshot = element.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = name
            attachment.lifetime = .keepAlways
            testCase.add(attachment)
        }
    }
    
    // MARK: - Performance Utilities
    
    /// Measures the time for an element to appear
    static func measureElementAppearanceTime(_ element: XCUIElement) -> TimeInterval {
        let startTime = Date()
        _ = element.waitForExistence(timeout: 30.0)
        return Date().timeIntervalSince(startTime)
    }
    
    /// Measures the time for a screen transition
    static func measureScreenTransition(from sourceElement: XCUIElement, 
                                      to destinationElement: XCUIElement,
                                      action: () -> Void) -> TimeInterval {
        let startTime = Date()
        action()
        _ = destinationElement.waitForExistence(timeout: 30.0)
        return Date().timeIntervalSince(startTime)
    }
    
    // MARK: - Accessibility Utilities
    
    /// Validates accessibility properties of an element
    static func validateAccessibility(of element: XCUIElement) -> AccessibilityValidationResult {
        var issues: [String] = []
        
        // Check if element exists
        guard element.exists else {
            return AccessibilityValidationResult(isValid: false, issues: ["Element does not exist"])
        }
        
        // Check accessibility label
        if element.label.isEmpty {
            issues.append("Missing accessibility label")
        }
        
        // Check if element is hittable (for interactive elements)
        if element.elementType == .button || element.elementType == .textField {
            if !element.isHittable {
                issues.append("Interactive element is not hittable")
            }
        }
        
        // Check minimum touch target size (44x44 points)
        let frame = element.frame
        if frame.width < 44 || frame.height < 44 {
            issues.append("Touch target too small (minimum 44x44 points)")
        }
        
        return AccessibilityValidationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    /// Simulates VoiceOver navigation
    static func simulateVoiceOverNavigation(in app: XCUIApplication, steps: Int = 5) {
        // This is a simplified simulation - real VoiceOver testing requires device/simulator
        for _ in 0..<steps {
            app.swipeRight() // VoiceOver next element gesture
            Thread.sleep(forTimeInterval: 0.5)
        }
    }
}

// MARK: - Supporting Types

enum ScrollDirection {
    case up, down, left, right
}

struct AccessibilityValidationResult {
    let isValid: Bool
    let issues: [String]
}

// MARK: - Extensions

extension XCUIElement {
    /// Clears text from a text field
    func clearText() {
        guard let stringValue = self.value as? String else {
            return
        }
        
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        self.typeText(deleteString)
    }
    
    /// Checks if element is fully visible on screen
    var isFullyVisible: Bool {
        guard exists else { return false }
        let app = XCUIApplication()
        let appFrame = app.frame
        let elementFrame = frame
        
        return appFrame.contains(elementFrame)
    }
}

extension DateFormatter {
    static let screenshotFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()
}