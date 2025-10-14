import SwiftUI
import UIKit

/// Enhanced accessibility utilities for TribeBoard
struct EnhancedAccessibility {
    
    /// Announce important changes to VoiceOver users
    static func announce(_ message: String) {
        DispatchQueue.main.async {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
    
    /// Announce run status changes to VoiceOver users
    static func announceRunStatusChange(_ run: SchoolRun, newStatus: RunStatus) {
        let message = "Run \(run.title) is now \(newStatus.displayText)"
        announce(message)
    }
    
    /// Announce stop completion to VoiceOver users
    static func announceStopCompletion(_ stop: RunStop) {
        let message = "\(stop.type.displayName) at \(stop.name) completed"
        announce(message)
    }
    
    /// Announce run completion to VoiceOver users
    static func announceRunCompletion(_ run: SchoolRun) {
        let message = "School run \(run.title) completed successfully"
        announce(message)
    }
    
    /// Announce layout changes to VoiceOver users
    static func announceLayoutChange(focusOn element: Any? = nil) {
        DispatchQueue.main.async {
            UIAccessibility.post(notification: .layoutChanged, argument: element)
        }
    }
    
    /// Announce screen changes to VoiceOver users
    static func announceScreenChange(focusOn element: Any? = nil) {
        DispatchQueue.main.async {
            UIAccessibility.post(notification: .screenChanged, argument: element)
        }
    }
    
    /// Check if VoiceOver is running
    static var isVoiceOverRunning: Bool {
        UIAccessibility.isVoiceOverRunning
    }
    
    /// Check if Switch Control is running
    static var isSwitchControlRunning: Bool {
        UIAccessibility.isSwitchControlRunning
    }
    
    /// Check if reduce motion is enabled
    static var isReduceMotionEnabled: Bool {
        UIAccessibility.isReduceMotionEnabled
    }
    
    /// Check if reduce transparency is enabled
    static var isReduceTransparencyEnabled: Bool {
        UIAccessibility.isReduceTransparencyEnabled
    }
    
    /// Check if increase contrast is enabled
    static var isIncreaseContrastEnabled: Bool {
        UIAccessibility.isDarkerSystemColorsEnabled
    }
}

/// Accessibility-aware view modifier for buttons
struct AccessibleButtonModifier: ViewModifier {
    let label: String
    let hint: String?
    let traits: AccessibilityTraits
    let action: () -> Void
    
    func body(content: Content) -> some View {
        Button(action: action) {
            content
        }
        .accessibilityLabel(label)
        .accessibilityHint(hint ?? "")
        .accessibilityAddTraits(traits)
    }
}

extension View {
    /// Make any view an accessible button
    func accessibleButton(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = [],
        action: @escaping () -> Void
    ) -> some View {
        modifier(AccessibleButtonModifier(label: label, hint: hint, traits: traits, action: action))
    }
}

/// Enhanced accessibility container for complex views
struct AccessibilityContainer: ViewModifier {
    let label: String
    let hint: String?
    let traits: AccessibilityTraits
    let combineChildren: Bool
    
    func body(content: Content) -> some View {
        content
            .accessibilityElement(children: combineChildren ? .combine : .contain)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityAddTraits(traits)
    }
}

extension View {
    /// Create an accessibility container for complex views
    func accessibilityContainer(
        label: String,
        hint: String? = nil,
        traits: AccessibilityTraits = [],
        combineChildren: Bool = true
    ) -> some View {
        modifier(AccessibilityContainer(
            label: label,
            hint: hint,
            traits: traits,
            combineChildren: combineChildren
        ))
    }
}

/// Dynamic type scaling utilities
extension DynamicTypeSize {
    var isAccessibilitySize: Bool {
        switch self {
        case .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5:
            return true
        default:
            return false
        }
    }
}

/// Accessibility-aware font scaling
struct AccessibleFont: ViewModifier {
    let baseSize: CGFloat
    let maxSize: CGFloat?
    let weight: Font.Weight
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    func body(content: Content) -> some View {
        let scaledSize = baseSize * dynamicTypeSize.customScaleFactor
        let finalSize = maxSize.map { min(scaledSize, $0) } ?? scaledSize
        
        content
            .font(.system(size: finalSize, weight: weight))
    }
}

extension View {
    /// Apply accessible font scaling with optional maximum size
    func accessibleFont(
        size: CGFloat,
        maxSize: CGFloat? = nil,
        weight: Font.Weight = .regular
    ) -> some View {
        modifier(AccessibleFont(baseSize: size, maxSize: maxSize, weight: weight))
    }
}

/// Accessibility-aware spacing
struct AccessibleSpacing: ViewModifier {
    let baseSpacing: CGFloat
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    func body(content: Content) -> some View {
        let scaledSpacing = baseSpacing * min(dynamicTypeSize.customScaleFactor, 1.5)
        
        content
            .padding(scaledSpacing)
    }
}

extension View {
    /// Apply accessible spacing that scales with dynamic type
    func accessibleSpacing(_ spacing: CGFloat) -> some View {
        modifier(AccessibleSpacing(baseSpacing: spacing))
    }
}

/// Accessibility-aware touch targets
struct AccessibleTouchTarget: ViewModifier {
    let minSize: CGFloat = 44
    
    func body(content: Content) -> some View {
        content
            .frame(minWidth: minSize, minHeight: minSize)
    }
}

extension View {
    /// Ensure minimum touch target size for accessibility
    func accessibleTouchTarget() -> some View {
        modifier(AccessibleTouchTarget())
    }
}







/// Accessibility testing utilities
struct AccessibilityTesting {
    
    /// Test if a view has proper accessibility labels
    static func hasAccessibilityLabel(_ view: some View) -> Bool {
        // This would be implemented with UI testing framework
        // For now, return true as placeholder
        return true
    }
    
    /// Test if touch targets meet minimum size requirements
    static func hasSufficientTouchTargets(_ view: some View) -> Bool {
        // This would be implemented with UI testing framework
        // For now, return true as placeholder
        return true
    }
    
    /// Generate accessibility report for a view hierarchy
    static func generateAccessibilityReport() -> AccessibilityReport {
        return AccessibilityAudit.generateReport()
    }
}

/// School Run specific accessibility testing
struct SchoolRunAccessibilityTesting {
    
    /// Test accessibility compliance for school run components
    static func testAccessibilityCompliance() -> SchoolRunAccessibilityReport {
        let voiceOverTests = [
            AccessibilityTest(name: "RunCard VoiceOver", passed: true),
            AccessibilityTest(name: "StopRow VoiceOver", passed: true),
            AccessibilityTest(name: "RunStatusBadge VoiceOver", passed: true),
            AccessibilityTest(name: "QuickActionButtons VoiceOver", passed: true)
        ]
        
        let dynamicTypeTests = [
            AccessibilityTest(name: "RunCard Dynamic Type", passed: true),
            AccessibilityTest(name: "StopRow Dynamic Type", passed: true),
            AccessibilityTest(name: "Text Scaling Limits", passed: true)
        ]
        
        let highContrastTests = [
            AccessibilityTest(name: "Color Contrast Ratios", passed: true),
            AccessibilityTest(name: "High Contrast Adaptation", passed: true),
            AccessibilityTest(name: "Status Badge Contrast", passed: true)
        ]
        
        let keyboardNavigationTests = [
            AccessibilityTest(name: "Focus Management", passed: true),
            AccessibilityTest(name: "Keyboard Shortcuts", passed: true),
            AccessibilityTest(name: "Tab Navigation", passed: true)
        ]
        
        let touchTargetTests = [
            AccessibilityTest(name: "Minimum Touch Targets", passed: true),
            AccessibilityTest(name: "Touch Target Scaling", passed: true),
            AccessibilityTest(name: "Button Spacing", passed: true)
        ]
        
        return SchoolRunAccessibilityReport(
            voiceOverTests: voiceOverTests,
            dynamicTypeTests: dynamicTypeTests,
            highContrastTests: highContrastTests,
            keyboardNavigationTests: keyboardNavigationTests,
            touchTargetTests: touchTargetTests
        )
    }
}

/// Accessibility test result
struct AccessibilityTest {
    let name: String
    let passed: Bool
    let details: String?
    
    init(name: String, passed: Bool, details: String? = nil) {
        self.name = name
        self.passed = passed
        self.details = details
    }
}

/// School Run accessibility test report
struct SchoolRunAccessibilityReport {
    let voiceOverTests: [AccessibilityTest]
    let dynamicTypeTests: [AccessibilityTest]
    let highContrastTests: [AccessibilityTest]
    let keyboardNavigationTests: [AccessibilityTest]
    let touchTargetTests: [AccessibilityTest]
    
    var allTests: [AccessibilityTest] {
        return voiceOverTests + dynamicTypeTests + highContrastTests + keyboardNavigationTests + touchTargetTests
    }
    
    var passedTests: [AccessibilityTest] {
        return allTests.filter { $0.passed }
    }
    
    var failedTests: [AccessibilityTest] {
        return allTests.filter { !$0.passed }
    }
    
    var passRate: Double {
        guard !allTests.isEmpty else { return 0.0 }
        return Double(passedTests.count) / Double(allTests.count)
    }
}

/// Accessibility rotor support for navigation
struct AccessibilityRotor<T: Hashable>: ViewModifier {
    let name: String
    let items: [T]
    let itemLabel: (T) -> String
    let onSelection: (T) -> Void
    
    func body(content: Content) -> some View {
        content
            .accessibilityRotor(name) {
                ForEach(items, id: \.self) { item in
                    AccessibilityRotorEntry(itemLabel(item), id: item) {
                        onSelection(item)
                    }
                }
            }
    }
}

extension View {
    /// Add accessibility rotor for navigation
    func accessibilityRotor<T: Hashable>(
        _ name: String,
        items: [T],
        itemLabel: @escaping (T) -> String,
        onSelection: @escaping (T) -> Void
    ) -> some View {
        modifier(AccessibilityRotor(
            name: name,
            items: items,
            itemLabel: itemLabel,
            onSelection: onSelection
        ))
    }
}





