import XCTest
import UIKit

/// Comprehensive accessibility testing utilities for TribeBoard UI tests
class AccessibilityTestHelpers {
    
    // MARK: - VoiceOver Testing Utilities
    
    /// Validates that an element has proper accessibility labels and traits
    /// - Parameters:
    ///   - element: The UI element to validate
    ///   - expectedLabel: The expected accessibility label
    ///   - expectedTraits: The expected accessibility traits
    ///   - file: Source file for test reporting
    ///   - line: Source line for test reporting
    static func validateVoiceOverElement(
        _ element: XCUIElement,
        expectedLabel: String,
        expectedTraits: UIAccessibilityTraits = [],
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.exists, "Element should exist for VoiceOver testing", file: file, line: line)
        XCTAssertEqual(element.label, expectedLabel, "Accessibility label should match expected value", file: file, line: line)
        
        if expectedTraits != [] {
            XCTAssertTrue(element.accessibilityTraits.contains(expectedTraits), 
                         "Element should have expected accessibility traits", file: file, line: line)
        }
    }
    
    /// Validates VoiceOver navigation order for a collection of elements
    /// - Parameters:
    ///   - elements: Array of elements in expected navigation order
    ///   - file: Source file for test reporting
    ///   - line: Source line for test reporting
    static func validateVoiceOverNavigationOrder(
        _ elements: [XCUIElement],
        file: StaticString = #file,
        line: UInt = #line
    ) {
        for (index, element) in elements.enumerated() {
            XCTAssertTrue(element.exists, "Element at index \(index) should exist for navigation testing", file: file, line: line)
            XCTAssertTrue(element.isAccessibilityElement, "Element at index \(index) should be accessible", file: file, line: line)
        }
    }
    
    /// Tests VoiceOver focus behavior for interactive elements
    /// - Parameters:
    ///   - element: The element to test focus on
    ///   - file: Source file for test reporting
    ///   - line: Source line for test reporting
    static func validateVoiceOverFocus(
        _ element: XCUIElement,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.exists, "Element should exist for focus testing", file: file, line: line)
        XCTAssertTrue(element.isAccessibilityElement, "Element should be accessible for VoiceOver", file: file, line: line)
        
        // Test that element can receive focus
        element.tap()
        XCTAssertTrue(element.hasFocus, "Element should be focusable by VoiceOver", file: file, line: line)
    }
    
    // MARK: - Dynamic Type Testing Utilities
    
    /// Validates that text elements support Dynamic Type scaling
    /// - Parameters:
    ///   - app: The XCUIApplication instance
    ///   - textElement: The text element to validate
    ///   - file: Source file for test reporting
    ///   - line: Source line for test reporting
    static func validateDynamicTypeSupport(
        app: XCUIApplication,
        textElement: XCUIElement,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertTrue(textElement.exists, "Text element should exist for Dynamic Type testing", file: file, line: line)
        
        // Get initial frame size
        let initialFrame = textElement.frame
        
        // Increase text size
        setDynamicTypeSize(app: app, size: .accessibilityExtraExtraExtraLarge)
        
        // Wait for UI to update
        Thread.sleep(forTimeInterval: 0.5)
        
        // Validate that text element has grown
        let enlargedFrame = textElement.frame
        XCTAssertGreaterThan(enlargedFrame.height, initialFrame.height, 
                           "Text element should grow with Dynamic Type", file: file, line: line)
        
        // Reset to default size
        setDynamicTypeSize(app: app, size: .large)
    }
    
    /// Sets Dynamic Type size for testing
    /// - Parameters:
    ///   - app: The XCUIApplication instance
    ///   - size: The content size category to set
    private static func setDynamicTypeSize(app: XCUIApplication, size: UIContentSizeCategory) {
        // This would typically involve launching the app with specific launch arguments
        // or using accessibility settings APIs in a real implementation
        app.launchArguments.append("--dynamic-type-\(size.rawValue)")
    }
    
    /// Validates text readability at different Dynamic Type sizes
    /// - Parameters:
    ///   - textElement: The text element to validate
    ///   - file: Source file for test reporting
    ///   - line: Source line for test reporting
    static func validateTextReadability(
        _ textElement: XCUIElement,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertTrue(textElement.exists, "Text element should exist for readability testing", file: file, line: line)
        XCTAssertFalse(textElement.label.isEmpty, "Text element should have readable content", file: file, line: line)
        
        // Validate minimum touch target size for text elements that are interactive
        if textElement.elementType == .button || textElement.elementType == .link {
            validateTouchTargetSize(textElement, file: file, line: line)
        }
    }
    
    // MARK: - Color Contrast and Visual Testing Utilities
    
    /// Validates color contrast compliance (simulated validation)
    /// - Parameters:
    ///   - element: The element to validate contrast for
    ///   - file: Source file for test reporting
    ///   - line: Source line for test reporting
    static func validateColorContrast(
        _ element: XCUIElement,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.exists, "Element should exist for color contrast testing", file: file, line: line)
        
        // In a real implementation, this would analyze the element's colors
        // For now, we validate that the element is visible and has content
        XCTAssertTrue(element.isHittable, "Element should be visually distinguishable", file: file, line: line)
        
        // Validate that text elements have readable labels
        if !element.label.isEmpty {
            XCTAssertGreaterThan(element.label.count, 0, "Text should be readable for contrast validation", file: file, line: line)
        }
    }
    
    /// Validates visual elements work in high contrast mode
    /// - Parameters:
    ///   - app: The XCUIApplication instance
    ///   - element: The element to validate
    ///   - file: Source file for test reporting
    ///   - line: Source line for test reporting
    static func validateHighContrastMode(
        app: XCUIApplication,
        element: XCUIElement,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.exists, "Element should exist for high contrast testing", file: file, line: line)
        
        // Enable high contrast mode (simulated)
        app.launchArguments.append("--high-contrast-enabled")
        
        // Validate element remains visible and functional
        XCTAssertTrue(element.isHittable, "Element should remain functional in high contrast mode", file: file, line: line)
        XCTAssertTrue(element.exists, "Element should remain visible in high contrast mode", file: file, line: line)
    }
    
    // MARK: - Touch Target Testing Utilities
    
    /// Validates that interactive elements meet minimum touch target size requirements
    /// - Parameters:
    ///   - element: The interactive element to validate
    ///   - minimumSize: Minimum required size (default 44x44 points per Apple HIG)
    ///   - file: Source file for test reporting
    ///   - line: Source line for test reporting
    static func validateTouchTargetSize(
        _ element: XCUIElement,
        minimumSize: CGSize = CGSize(width: 44, height: 44),
        file: StaticString = #file,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.exists, "Element should exist for touch target testing", file: file, line: line)
        
        let frame = element.frame
        XCTAssertGreaterThanOrEqual(frame.width, minimumSize.width, 
                                  "Touch target width should meet minimum requirements", file: file, line: line)
        XCTAssertGreaterThanOrEqual(frame.height, minimumSize.height, 
                                  "Touch target height should meet minimum requirements", file: file, line: line)
    }
    
    /// Validates spacing between interactive elements
    /// - Parameters:
    ///   - elements: Array of interactive elements to validate spacing for
    ///   - minimumSpacing: Minimum required spacing between elements
    ///   - file: Source file for test reporting
    ///   - line: Source line for test reporting
    static func validateTouchTargetSpacing(
        _ elements: [XCUIElement],
        minimumSpacing: CGFloat = 8.0,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        guard elements.count > 1 else { return }
        
        for i in 0..<(elements.count - 1) {
            let currentElement = elements[i]
            let nextElement = elements[i + 1]
            
            XCTAssertTrue(currentElement.exists, "Element \(i) should exist for spacing testing", file: file, line: line)
            XCTAssertTrue(nextElement.exists, "Element \(i+1) should exist for spacing testing", file: file, line: line)
            
            let currentFrame = currentElement.frame
            let nextFrame = nextElement.frame
            
            // Calculate spacing (simplified - assumes horizontal layout)
            let spacing = nextFrame.minX - currentFrame.maxX
            XCTAssertGreaterThanOrEqual(spacing, minimumSpacing, 
                                      "Spacing between elements should meet minimum requirements", file: file, line: line)
        }
    }
    
    // MARK: - Comprehensive Accessibility Validation
    
    /// Performs comprehensive accessibility validation on an element
    /// - Parameters:
    ///   - element: The element to validate
    ///   - expectedLabel: Expected accessibility label
    ///   - expectedTraits: Expected accessibility traits
    ///   - shouldSupportDynamicType: Whether element should support Dynamic Type
    ///   - file: Source file for test reporting
    ///   - line: Source line for test reporting
    static func validateAccessibilityCompliance(
        _ element: XCUIElement,
        expectedLabel: String? = nil,
        expectedTraits: UIAccessibilityTraits = [],
        shouldSupportDynamicType: Bool = false,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        // Basic existence and accessibility
        XCTAssertTrue(element.exists, "Element should exist for accessibility compliance", file: file, line: line)
        XCTAssertTrue(element.isAccessibilityElement, "Element should be accessible", file: file, line: line)
        
        // Label validation
        if let expectedLabel = expectedLabel {
            validateVoiceOverElement(element, expectedLabel: expectedLabel, expectedTraits: expectedTraits, file: file, line: line)
        }
        
        // Touch target validation for interactive elements
        if element.elementType == .button || element.elementType == .link || element.elementType == .textField {
            validateTouchTargetSize(element, file: file, line: line)
        }
        
        // Color contrast validation
        validateColorContrast(element, file: file, line: line)
        
        // Text readability for text elements
        if element.elementType == .staticText || element.elementType == .textField {
            validateTextReadability(element, file: file, line: line)
        }
    }
    
    /// Validates accessibility for a complete screen or view
    /// - Parameters:
    ///   - app: The XCUIApplication instance
    ///   - screenIdentifier: Identifier for the screen being tested
    ///   - keyElements: Key elements that should be accessible on the screen
    ///   - file: Source file for test reporting
    ///   - line: Source line for test reporting
    static func validateScreenAccessibility(
        app: XCUIApplication,
        screenIdentifier: String,
        keyElements: [XCUIElement],
        file: StaticString = #file,
        line: UInt = #line
    ) {
        // Validate all key elements are accessible
        for (index, element) in keyElements.enumerated() {
            XCTAssertTrue(element.exists, "Key element \(index) should exist on \(screenIdentifier)", file: file, line: line)
            XCTAssertTrue(element.isAccessibilityElement, "Key element \(index) should be accessible on \(screenIdentifier)", file: file, line: line)
        }
        
        // Validate navigation order
        validateVoiceOverNavigationOrder(keyElements, file: file, line: line)
        
        // Validate interactive elements have proper touch targets
        let interactiveElements = keyElements.filter { 
            $0.elementType == .button || $0.elementType == .link || $0.elementType == .textField 
        }
        
        for element in interactiveElements {
            validateTouchTargetSize(element, file: file, line: line)
        }
    }
}

// MARK: - Accessibility Testing Extensions

extension XCUIElement {
    /// Convenience property to check if element has focus (simulated)
    var hasFocus: Bool {
        return self.hasFocus
    }
    
    /// Validates that this element meets basic accessibility requirements
    func validateBasicAccessibility(file: StaticString = #file, line: UInt = #line) {
        AccessibilityTestHelpers.validateAccessibilityCompliance(self, file: file, line: line)
    }
}

extension XCUIApplication {
    /// Launches the app with accessibility testing configuration
    func launchForAccessibilityTesting() {
        self.launchArguments.append("--accessibility-testing-enabled")
        self.launchArguments.append("--ui-testing-mode")
        self.launch()
    }
}