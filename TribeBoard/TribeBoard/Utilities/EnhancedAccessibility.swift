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
    var customScaleFactor: CGFloat {
        switch self {
        case .xSmall: return 0.82
        case .small: return 0.88
        case .medium: return 1.0
        case .large: return 1.12
        case .xLarge: return 1.24
        case .xxLarge: return 1.36
        case .xxxLarge: return 1.48
        case .accessibility1: return 1.64
        case .accessibility2: return 1.95
        case .accessibility3: return 2.35
        case .accessibility4: return 2.76
        case .accessibility5: return 3.12
        @unknown default: return 1.0
        }
    }
    
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

/// High contrast color support
struct HighContrastColor: ViewModifier {
    let normalColor: Color
    let highContrastColor: Color
    
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(colorSchemeContrast == .increased ? highContrastColor : normalColor)
    }
}

extension View {
    /// Apply high contrast color support
    func highContrastColor(normal: Color, highContrast: Color) -> some View {
        modifier(HighContrastColor(normalColor: normal, highContrastColor: highContrast))
    }
}

/// Accessibility-aware animations
struct AccessibleAnimation<V: Equatable>: ViewModifier {
    let animation: Animation
    let value: V
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    func body(content: Content) -> some View {
        content
            .animation(reduceMotion ? .none : animation, value: value)
    }
}

extension View {
    /// Apply animation that respects reduce motion preference
    func accessibleAnimation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(AccessibleAnimation(animation: animation, value: value))
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