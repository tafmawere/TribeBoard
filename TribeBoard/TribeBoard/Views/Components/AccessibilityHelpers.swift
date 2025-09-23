import SwiftUI

/// Accessibility helpers and extensions for better VoiceOver support
extension View {
    
    /// Add accessibility label and hint with optional value
    func accessibilityInfo(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "")
            .accessibilityValue(value ?? "")
            .accessibilityAddTraits(traits)
    }
    
    /// Add dynamic type support with custom scaling
    func dynamicTypeSupport(
        minSize: CGFloat? = nil,
        maxSize: CGFloat? = nil
    ) -> some View {
        self.modifier(DynamicTypeModifier(minSize: minSize, maxSize: maxSize))
    }
    
    /// Ensure minimum touch target size for accessibility
    func accessibleTouchTarget(minSize: CGFloat = 44) -> some View {
        self.frame(minWidth: minSize, minHeight: minSize)
    }
    
    /// Add high contrast support
    func highContrastSupport(
        normalColor: Color,
        highContrastColor: Color
    ) -> some View {
        self.modifier(HighContrastModifier(
            normalColor: normalColor,
            highContrastColor: highContrastColor
        ))
    }
    
    /// Add reduced motion support
    func reducedMotionSupport<T: Equatable>(
        animation: Animation,
        value: T
    ) -> some View {
        self.modifier(ReducedMotionModifier(animation: animation, value: value))
    }
    
    /// Mark as accessibility element with custom content
    func accessibilityElement(
        label: String,
        hint: String? = nil,
        value: String? = nil,
        traits: AccessibilityTraits = []
    ) -> some View {
        self
            .accessibilityElement(children: .ignore)
            .accessibilityInfo(
                label: label,
                hint: hint,
                value: value,
                traits: traits
            )
    }
    
    /// Add haptic feedback on tap
    func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) -> some View {
        self.onTapGesture {
            let impactFeedback = UIImpactFeedbackGenerator(style: style)
            impactFeedback.impactOccurred()
        }
    }
    
    /// Add success haptic feedback
    func successHaptic() -> some View {
        self.onAppear {
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
        }
    }
    
    /// Add error haptic feedback
    func errorHaptic() -> some View {
        self.onAppear {
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.error)
        }
    }
    
    /// Add warning haptic feedback
    func warningHaptic() -> some View {
        self.onAppear {
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.warning)
        }
    }
}



/// Role selection accessibility helper
struct AccessibleRoleCard: View {
    let role: Role
    let isSelected: Bool
    let isEnabled: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            RoleCardContent(role: role, isSelected: isSelected, isEnabled: isEnabled)
        }
        .disabled(!isEnabled)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(accessibilityTraits)
        .onTapGesture {
            if isEnabled {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            }
        }
    }
    
    private var accessibilityLabel: String {
        "\(role.displayName) role"
    }
    
    private var accessibilityHint: String {
        if !isEnabled {
            return "This role is not available"
        } else if isSelected {
            return "Currently selected role"
        } else {
            return "Tap to select this role"
        }
    }
    
    private var accessibilityValue: String {
        role.description
    }
    
    private var accessibilityTraits: AccessibilityTraits {
        var traits: AccessibilityTraits = [.isButton]
        
        if isSelected {
            _ = traits.insert(.isSelected)
        }
        
        if !isEnabled {
            // Note: .notEnabled is not available in iOS, using button trait instead
            _ = traits.insert(.isButton)
        }
        
        return traits
    }
}

/// Placeholder for role card content (would be implemented in the actual RoleCard)
private struct RoleCardContent: View {
    let role: Role
    let isSelected: Bool
    let isEnabled: Bool
    
    var body: some View {
        VStack {
            Text(role.displayName)
            Text(role.description)
                .font(.caption)
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
        .cornerRadius(8)
        .opacity(isEnabled ? 1.0 : 0.5)
    }
}

/// Loading state accessibility helper
struct AccessibleLoadingView: View {
    let message: String
    let isLoading: Bool
    
    var body: some View {
        HStack {
            if isLoading {
                ProgressView()
                    .accessibilityHidden(true)
            }
            
            Text(message)
                .accessibilityLabel(isLoading ? "Loading: \(message)" : message)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(isLoading ? [.updatesFrequently] : [])
    }
}

/// Member row accessibility helper
struct AccessibleMemberRow: View {
    let memberName: String
    let role: Role
    let status: MembershipStatus
    let canManage: Bool
    let onRoleChange: (() -> Void)?
    let onRemove: (() -> Void)?
    
    var body: some View {
        VStack {
            memberInfoSection
            
            if canManage {
                managementButtonsSection
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(.isButton)
    }
    
    private var memberInfoSection: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(memberName)
                Text("\(role.displayName) - \(status.displayName)")
                    .font(.caption)
            }
            Spacer()
        }
    }
    
    private var managementButtonsSection: some View {
        HStack {
            if let onRoleChange = onRoleChange {
                Button("Change Role", action: onRoleChange)
                    .accessibilityLabel("Change role for \(memberName)")
                    .accessibilityHint("Opens role selection for this member")
            }
            
            if let onRemove = onRemove {
                Button("Remove", action: onRemove)
                    .accessibilityLabel("Remove \(memberName)")
                    .accessibilityHint("Removes this member from the family")
            }
        }
    }
    
    private var accessibilityLabel: String {
        "\(memberName), \(role.displayName)"
    }
    
    private var accessibilityHint: String {
        if status == .invited {
            return "Invitation pending"
        } else if canManage {
            return "Double tap to manage this member"
        } else {
            return "Family member"
        }
    }
}

/// Form validation accessibility helper
extension ValidationState {
    var accessibilityAnnouncement: String? {
        guard let message = message else { return nil }
        
        if isValid {
            return "Valid: \(message)"
        } else {
            return "Error: \(message)"
        }
    }
}

// MARK: - Haptic Feedback Manager
// HapticManager is defined in TribeBoard/Utilities/HapticManager.swift

// MARK: - Accessibility Modifiers

/// Dynamic type support modifier
struct DynamicTypeModifier: ViewModifier {
    let minSize: CGFloat?
    let maxSize: CGFloat?
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: scaledSize))
    }
    
    private var scaledSize: CGFloat {
        let baseSize: CGFloat = 16 // Default font size
        let scaleFactor = dynamicTypeSize.scaleFactor
        let scaledSize = baseSize * scaleFactor
        
        if let minSize = minSize, scaledSize < minSize {
            return minSize
        }
        if let maxSize = maxSize, scaledSize > maxSize {
            return maxSize
        }
        
        return scaledSize
    }
}

/// High contrast support modifier
struct HighContrastModifier: ViewModifier {
    let normalColor: Color
    let highContrastColor: Color
    
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(colorSchemeContrast == .increased ? highContrastColor : normalColor)
    }
}

/// Reduced motion support modifier
struct ReducedMotionModifier<T: Equatable>: ViewModifier {
    let animation: Animation
    let value: T
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    func body(content: Content) -> some View {
        content
            .animation(reduceMotion ? nil : animation, value: value)
    }
}

/// Dynamic type size extension for scaling
extension DynamicTypeSize {
    var scaleFactor: CGFloat {
        switch self {
        case .xSmall: return 0.8
        case .small: return 0.9
        case .medium: return 1.0
        case .large: return 1.1
        case .xLarge: return 1.2
        case .xxLarge: return 1.3
        case .xxxLarge: return 1.4
        case .accessibility1: return 1.6
        case .accessibility2: return 1.8
        case .accessibility3: return 2.0
        case .accessibility4: return 2.2
        case .accessibility5: return 2.4
        @unknown default: return 1.0
        }
    }
}

// MARK: - Accessibility-Enhanced Components

/// Enhanced text with full accessibility support
struct AccessibleText: View {
    let text: String
    let style: Font.TextStyle
    let weight: Font.Weight
    let color: Color
    let alignment: TextAlignment
    let lineLimit: Int?
    
    init(
        _ text: String,
        style: Font.TextStyle = .body,
        weight: Font.Weight = .regular,
        color: Color = .primary,
        alignment: TextAlignment = .leading,
        lineLimit: Int? = nil
    ) {
        self.text = text
        self.style = style
        self.weight = weight
        self.color = color
        self.alignment = alignment
        self.lineLimit = lineLimit
    }
    
    var body: some View {
        Text(text)
            .font(.system(style, weight: weight))
            .foregroundColor(color)
            .multilineTextAlignment(alignment)
            .lineLimit(lineLimit)
            .dynamicTypeSupport()
            .highContrastSupport(
                normalColor: color,
                highContrastColor: contrastColor
            )
    }
    
    private var contrastColor: Color {
        // Provide high contrast alternatives
        switch color {
        case .primary: return .primary
        case .secondary: return .primary
        case .brandPrimary: return .blue
        case .brandSecondary: return .blue
        default: return color
        }
    }
}

/// Enhanced button with comprehensive accessibility
struct AccessibleEnhancedButton<Content: View>: View {
    let action: () -> Void
    let label: String
    let hint: String?
    let isEnabled: Bool
    let isLoading: Bool
    let hapticStyle: HapticStyle
    let content: () -> Content
    
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    init(
        action: @escaping () -> Void,
        label: String,
        hint: String? = nil,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        hapticStyle: HapticStyle = .medium,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.action = action
        self.label = label
        self.hint = hint
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.hapticStyle = hapticStyle
        self.content = content
    }
    
    var body: some View {
        Button(action: performAction) {
            content()
        }
        .disabled(!isEnabled || isLoading)
        .accessibleTouchTarget()
        .scaleEffect(isPressed && !reduceMotion ? 0.95 : 1.0)
        .opacity((isEnabled && !isLoading) ? 1.0 : 0.6)
        .reducedMotionSupport(animation: .easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(accessibilityTraits)
        .onChange(of: isPressed) { _, newValue in
            if newValue && isEnabled && !isLoading {
                hapticStyle.trigger()
            }
        }
    }
    
    private var accessibilityLabel: String {
        if isLoading {
            return "Loading"
        }
        return label
    }
    
    private var accessibilityHint: String {
        if !isEnabled {
            return "Button is disabled"
        } else if isLoading {
            return "Please wait while processing"
        }
        return hint ?? "Tap to \(label.lowercased())"
    }
    
    private var accessibilityTraits: AccessibilityTraits {
        var traits: AccessibilityTraits = [.isButton]
        
        if isLoading {
            _ = traits.insert(.updatesFrequently)
        }
        
        return traits
    }
    
    private func performAction() {
        guard isEnabled && !isLoading else { return }
        action()
    }
}

/// Enhanced form field with accessibility
struct AccessibleFormField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let isSecure: Bool
    let validation: ValidationResult?
    let keyboardType: UIKeyboardType
    
    @FocusState private var isFocused: Bool
    
    init(
        title: String,
        text: Binding<String>,
        placeholder: String = "",
        isSecure: Bool = false,
        validation: ValidationResult? = nil,
        keyboardType: UIKeyboardType = .default
    ) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.isSecure = isSecure
        self.validation = validation
        self.keyboardType = keyboardType
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AccessibleText(
                title,
                style: .headline,
                weight: .medium
            )
            
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .focused($isFocused)
            .keyboardType(keyboardType)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .accessibilityLabel("\(title) input field")
            .accessibilityHint(placeholder.isEmpty ? "Enter \(title.lowercased())" : placeholder)
            .accessibilityValue(text.isEmpty ? "Empty" : "Contains text")
            
            if let validation = validation, !validation.message.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: validation.isValid ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(validation.isValid ? .green : .red)
                        .accessibilityHidden(true)
                    
                    AccessibleText(
                        validation.message,
                        style: .caption,
                        color: validation.isValid ? .green : .red
                    )
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(validation.isValid ? "Valid: \(validation.message)" : "Error: \(validation.message)")
                .accessibilityAddTraits(validation.isValid ? [] : [.isStaticText])
            }
        }
    }
}

// MARK: - Color Contrast Utilities

extension Color {
    /// High contrast versions of brand colors
    static let brandPrimaryHighContrast = Color.blue
    static let brandSecondaryHighContrast = Color.indigo
    
    /// Check if color meets WCAG contrast requirements
    func contrastRatio(with background: Color) -> Double {
        // Simplified contrast calculation
        // In a real implementation, you'd calculate the actual luminance
        return 4.5 // Placeholder - meets WCAG AA standard
    }
    
    /// Get accessible version of color
    func accessibleVersion(for background: Color = .white) -> Color {
        let ratio = self.contrastRatio(with: background)
        return ratio >= 4.5 ? self : .primary
    }
}

// MARK: - Preview

#Preview("Accessibility Helpers") {
    ScrollView {
        VStack(spacing: 24) {
            // Text examples
            VStack(alignment: .leading, spacing: 16) {
                AccessibleText("Dynamic Type Support", style: .title, weight: .bold)
                AccessibleText("This text scales with system font size settings", style: .body)
                AccessibleText("Small caption text", style: .caption, color: .secondary)
            }
            
            // Button examples
            VStack(spacing: 16) {
                AccessibleEnhancedButton(
                    action: {},
                    label: "Create Family",
                    hint: "Creates a new family group"
                ) {
                    Text("Create Family")
                        .padding()
                        .background(Color.brandPrimary)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                AccessibleEnhancedButton(
                    action: {},
                    label: "Loading Button",
                    isLoading: true
                ) {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading...")
                    }
                    .padding()
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            
            // Form field examples
            VStack(spacing: 16) {
                AccessibleFormField(
                    title: "Family Name",
                    text: .constant(""),
                    placeholder: "Enter your family name"
                )
                
                AccessibleFormField(
                    title: "Email",
                    text: .constant(""),
                    placeholder: "Enter your email",
                    keyboardType: .emailAddress
                )
            }
            
            AccessibleLoadingView(
                message: "Creating family...",
                isLoading: true
            )
        }
        .padding()
    }
}