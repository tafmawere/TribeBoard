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

/// Accessibility-enhanced button wrapper
struct AccessibleButton<Content: View>: View {
    let action: () -> Void
    let label: String
    let hint: String?
    let hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle
    let content: () -> Content
    
    init(
        action: @escaping () -> Void,
        label: String,
        hint: String? = nil,
        hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle = .medium,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.action = action
        self.label = label
        self.hint = hint
        self.hapticStyle = hapticStyle
        self.content = content
    }
    
    var body: some View {
        Button(action: {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: hapticStyle)
            impactFeedback.impactOccurred()
            
            // Execute action
            action()
        }) {
            content()
        }
        .accessibilityLabel(label)
        .accessibilityHint(hint ?? "")
        .accessibilityAddTraits(.isButton)
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
            traits.insert(.isButton)
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

class HapticManager {
    static let shared = HapticManager()
    
    private init() {}
    
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type)
    }
    
    func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
    
    // Convenience methods
    func success() {
        notification(.success)
    }
    
    func error() {
        notification(.error)
    }
    
    func warning() {
        notification(.warning)
    }
    
    func lightImpact() {
        impact(.light)
    }
    
    func mediumImpact() {
        impact(.medium)
    }
    
    func heavyImpact() {
        impact(.heavy)
    }
}

// MARK: - Preview

#Preview("Accessibility Helpers") {
    VStack(spacing: 20) {
        AccessibleButton(
            action: {},
            label: "Create Family",
            hint: "Creates a new family group"
        ) {
            Text("Create Family")
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
        
        AccessibleLoadingView(
            message: "Creating family...",
            isLoading: true
        )
        
        AccessibleMemberRow(
            memberName: "John Doe",
            role: .parentAdmin,
            status: .active,
            canManage: false,
            onRoleChange: nil,
            onRemove: nil
        )
    }
    .padding()
}