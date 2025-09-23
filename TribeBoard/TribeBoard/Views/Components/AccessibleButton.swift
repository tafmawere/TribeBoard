import SwiftUI

/// Enhanced accessible button with animations, haptic feedback, and loading states
struct AccessibleButton<Content: View>: View {
    let action: () -> Void
    let label: String
    let hint: String?
    let hapticStyle: HapticStyle
    let isEnabled: Bool
    let isLoading: Bool
    let loadingText: String?
    let content: () -> Content
    
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    init(
        action: @escaping () -> Void,
        label: String,
        hint: String? = nil,
        hapticStyle: HapticStyle = .medium,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        loadingText: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.action = action
        self.label = label
        self.hint = hint
        self.hapticStyle = hapticStyle
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.loadingText = loadingText
        self.content = content
    }
    
    var body: some View {
        Button(action: performAction) {
            content()
        }
        .disabled(!isEnabled || isLoading)
        .frame(minWidth: 44, minHeight: 44) // Minimum touch target
        .scaleEffect(isPressed && !reduceMotion ? 0.95 : 1.0)
        .opacity((isEnabled && !isLoading) ? 1.0 : 0.6)
        .animation(reduceMotion ? nil : AnimationUtilities.buttonPress, value: isPressed)
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
            return loadingText ?? "Loading"
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
            traits.insert(.updatesFrequently)
        }
        
        return traits
    }
    
    private func performAction() {
        guard isEnabled && !isLoading else { return }
        action()
    }
}

/// Primary button with enhanced animations and accessibility
struct AnimatedPrimaryButton: View {
    let title: String
    let action: () -> Void
    let isLoading: Bool
    let isEnabled: Bool
    let icon: String?
    let hapticStyle: HapticStyle
    
    @State private var isPressed = false
    @State private var successAnimation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    init(
        title: String,
        action: @escaping () -> Void,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        icon: String? = nil,
        hapticStyle: HapticStyle = .medium
    ) {
        self.title = title
        self.action = action
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.icon = icon
        self.hapticStyle = hapticStyle
    }
    
    var body: some View {
        AccessibleButton(
            action: performAction,
            label: title,
            hint: "Tap to \(title.lowercased())",
            hapticStyle: hapticStyle,
            isEnabled: isEnabled,
            isLoading: isLoading,
            loadingText: "Processing..."
        ) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                        .accessibilityHidden(true)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: scaledIconSize))
                        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                        .accessibilityHidden(true)
                }
                
                Text(isLoading ? "Processing..." : title)
                    .font(.system(size: scaledFontSize, weight: .semibold))
                    .transition(.opacity)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity)
            .frame(height: buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                    .fill(backgroundGradient)
                    .scaleEffect(successAnimation && !reduceMotion ? 1.05 : 1.0)
                    .animation(reduceMotion ? nil : AnimationUtilities.celebration, value: successAnimation)
            )
        }
        .celebrationAnimation(trigger: successAnimation && !reduceMotion)
    }
    
    private var scaledFontSize: CGFloat {
        let baseSize: CGFloat = 18
        return min(baseSize * dynamicTypeSize.scaleFactor, 24)
    }
    
    private var scaledIconSize: CGFloat {
        let baseSize: CGFloat = 18
        return min(baseSize * dynamicTypeSize.scaleFactor, 22)
    }
    
    private var buttonHeight: CGFloat {
        let baseHeight: CGFloat = 56
        return max(baseHeight * min(dynamicTypeSize.scaleFactor, 1.3), 44)
    }
    
    private var textColor: Color {
        colorSchemeContrast == .increased ? .black : .white
    }
    
    private var backgroundGradient: LinearGradient {
        if colorSchemeContrast == .increased {
            return LinearGradient(
                colors: [.blue, .indigo],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient.brandGradient
    }
    
    private func performAction() {
        action()
        
        // Trigger success animation after a delay (simulating completion)
        if !reduceMotion {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                successAnimation = true
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    successAnimation = false
                }
            }
        }
    }
}

/// Secondary button with enhanced animations
struct AnimatedSecondaryButton: View {
    let title: String
    let action: () -> Void
    let isLoading: Bool
    let isEnabled: Bool
    let icon: String?
    let hapticStyle: HapticStyle
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    init(
        title: String,
        action: @escaping () -> Void,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        icon: String? = nil,
        hapticStyle: HapticStyle = .light
    ) {
        self.title = title
        self.action = action
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.icon = icon
        self.hapticStyle = hapticStyle
    }
    
    var body: some View {
        AccessibleButton(
            action: action,
            label: title,
            hint: "Tap to \(title.lowercased())",
            hapticStyle: hapticStyle,
            isEnabled: isEnabled,
            isLoading: isLoading,
            loadingText: "Processing..."
        ) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: foregroundColor))
                        .scaleEffect(0.8)
                        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                        .accessibilityHidden(true)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: scaledIconSize))
                        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
                        .accessibilityHidden(true)
                }
                
                Text(isLoading ? "Processing..." : title)
                    .font(.system(size: scaledFontSize, weight: .semibold))
                    .transition(.opacity)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                    .stroke(strokeColor, lineWidth: strokeWidth)
                    .background(
                        RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                            .fill(backgroundColor)
                    )
            )
        }
    }
    
    private var scaledFontSize: CGFloat {
        let baseSize: CGFloat = 18
        return min(baseSize * dynamicTypeSize.scaleFactor, 24)
    }
    
    private var scaledIconSize: CGFloat {
        let baseSize: CGFloat = 18
        return min(baseSize * dynamicTypeSize.scaleFactor, 22)
    }
    
    private var buttonHeight: CGFloat {
        let baseHeight: CGFloat = 56
        return max(baseHeight * min(dynamicTypeSize.scaleFactor, 1.3), 44)
    }
    
    private var foregroundColor: Color {
        colorSchemeContrast == .increased ? .blue : .brandPrimary
    }
    
    private var strokeColor: Color {
        colorSchemeContrast == .increased ? .blue : .brandPrimary
    }
    
    private var strokeWidth: CGFloat {
        colorSchemeContrast == .increased ? 3 : 2
    }
    
    private var backgroundColor: Color {
        Color(.systemBackground)
    }
}

/// Floating action button with enhanced animations
struct AnimatedFloatingActionButton: View {
    let icon: String
    let action: () -> Void
    let isVisible: Bool
    let hapticStyle: HapticStyle
    
    @State private var isPressed = false
    @State private var rotationAngle: Double = 0
    
    init(
        icon: String,
        action: @escaping () -> Void,
        isVisible: Bool = true,
        hapticStyle: HapticStyle = .medium
    ) {
        self.icon = icon
        self.action = action
        self.isVisible = isVisible
        self.hapticStyle = hapticStyle
    }
    
    var body: some View {
        AccessibleButton(
            action: performAction,
            label: "Floating action",
            hint: "Tap to perform action",
            hapticStyle: hapticStyle
        ) {
            Image(systemName: icon)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(LinearGradient.brandGradient)
                        .shadow(
                            color: BrandStyle.standardShadow,
                            radius: 8,
                            x: 0,
                            y: 4
                        )
                )
                .rotationEffect(.degrees(rotationAngle))
        }
        .scaleEffect(isVisible ? 1.0 : 0.0)
        .opacity(isVisible ? 1.0 : 0.0)
        .animation(AnimationUtilities.spring, value: isVisible)
        .floatingAnimation(isAnimating: isVisible)
    }
    
    private func performAction() {
        withAnimation(AnimationUtilities.spring) {
            rotationAngle += 360
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            rotationAngle = 0
        }
        
        action()
    }
}

/// Icon button with enhanced animations
struct AnimatedIconButton: View {
    let icon: String
    let action: () -> Void
    let size: CGFloat
    let color: Color
    let backgroundColor: Color?
    let hapticStyle: HapticStyle
    
    @State private var isPressed = false
    @State private var pulseAnimation = false
    
    init(
        icon: String,
        action: @escaping () -> Void,
        size: CGFloat = 44,
        color: Color = .brandPrimary,
        backgroundColor: Color? = nil,
        hapticStyle: HapticStyle = .light
    ) {
        self.icon = icon
        self.action = action
        self.size = size
        self.color = color
        self.backgroundColor = backgroundColor
        self.hapticStyle = hapticStyle
    }
    
    var body: some View {
        AccessibleButton(
            action: performAction,
            label: "Icon button",
            hint: "Tap to perform action",
            hapticStyle: hapticStyle
        ) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundColor(color)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(backgroundColor ?? Color.clear)
                        .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                        .opacity(pulseAnimation ? 0.8 : 1.0)
                )
        }
        .animation(AnimationUtilities.spring, value: pulseAnimation)
    }
    
    private func performAction() {
        pulseAnimation = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            pulseAnimation = false
        }
        
        action()
    }
}

/// Toggle button with enhanced animations
struct AnimatedToggleButton: View {
    @Binding var isOn: Bool
    let label: String
    let onIcon: String
    let offIcon: String
    let hapticStyle: HapticStyle
    
    @State private var scaleEffect: CGFloat = 1.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    init(
        isOn: Binding<Bool>,
        label: String,
        onIcon: String = "checkmark.circle.fill",
        offIcon: String = "circle",
        hapticStyle: HapticStyle = .selection
    ) {
        self._isOn = isOn
        self.label = label
        self.onIcon = onIcon
        self.offIcon = offIcon
        self.hapticStyle = hapticStyle
    }
    
    var body: some View {
        AccessibleButton(
            action: toggle,
            label: accessibilityLabel,
            hint: accessibilityHint,
            hapticStyle: hapticStyle
        ) {
            HStack(spacing: 12) {
                Image(systemName: isOn ? onIcon : offIcon)
                    .font(.system(size: scaledIconSize))
                    .foregroundColor(iconColor)
                    .scaleEffect(scaleEffect)
                    .animation(reduceMotion ? nil : AnimationUtilities.spring, value: isOn)
                    .accessibilityHidden(true)
                
                Text(label)
                    .font(.system(size: scaledFontSize, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                
                Spacer()
                
                // Status indicator for high contrast
                if colorSchemeContrast == .increased {
                    Text(isOn ? "ON" : "OFF")
                        .font(.system(size: scaledCaptionSize, weight: .bold))
                        .foregroundColor(isOn ? .green : .secondary)
                        .accessibilityHidden(true)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                            .stroke(strokeColor, lineWidth: strokeWidth)
                    )
            )
        }
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(isOn ? "On" : "Off")
        .onChange(of: isOn) { _, _ in
            if !reduceMotion {
                withAnimation(AnimationUtilities.spring) {
                    scaleEffect = 1.2
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(AnimationUtilities.spring) {
                        scaleEffect = 1.0
                    }
                }
            }
        }
    }
    
    private var scaledFontSize: CGFloat {
        let baseSize: CGFloat = 16
        return min(baseSize * dynamicTypeSize.scaleFactor, 20)
    }
    
    private var scaledIconSize: CGFloat {
        let baseSize: CGFloat = 20
        return min(baseSize * dynamicTypeSize.scaleFactor, 24)
    }
    
    private var scaledCaptionSize: CGFloat {
        let baseSize: CGFloat = 12
        return min(baseSize * dynamicTypeSize.scaleFactor, 16)
    }
    
    private var iconColor: Color {
        if colorSchemeContrast == .increased {
            return isOn ? .green : .primary
        }
        return isOn ? .green : .secondary
    }
    
    private var strokeColor: Color {
        if colorSchemeContrast == .increased {
            return isOn ? .green : .primary
        }
        return isOn ? Color.green : Color(.systemGray4)
    }
    
    private var strokeWidth: CGFloat {
        colorSchemeContrast == .increased ? 2 : 1
    }
    
    private var backgroundColor: Color {
        Color(.systemBackground)
    }
    
    private var accessibilityLabel: String {
        "\(label) toggle"
    }
    
    private var accessibilityHint: String {
        "Tap to turn \(label.lowercased()) \(isOn ? "off" : "on")"
    }
    
    private func toggle() {
        withAnimation(reduceMotion ? nil : AnimationUtilities.toggle) {
            isOn.toggle()
        }
    }
}

/// Card button with enhanced animations
struct AnimatedCardButton: View {
    let title: String
    let subtitle: String?
    let icon: String
    let action: () -> Void
    let hapticStyle: HapticStyle
    
    @State private var isPressed = false
    @State private var hoverEffect = false
    
    init(
        title: String,
        subtitle: String? = nil,
        icon: String,
        action: @escaping () -> Void,
        hapticStyle: HapticStyle = .light
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.action = action
        self.hapticStyle = hapticStyle
    }
    
    var body: some View {
        AccessibleButton(
            action: action,
            label: title,
            hint: subtitle ?? "Tap to \(title.lowercased())",
            hapticStyle: hapticStyle
        ) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.brandPrimary)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: BrandStyle.standardShadow,
                        radius: hoverEffect ? 8 : 4,
                        x: 0,
                        y: hoverEffect ? 6 : 2
                    )
                    .scaleEffect(hoverEffect ? 1.02 : 1.0)
            )
        }
        .animation(AnimationUtilities.smooth, value: hoverEffect)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            hoverEffect = pressing
        }, perform: {})
    }
}

// MARK: - Preview

#Preview("Animated Buttons") {
    ScrollView {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Primary Buttons")
                    .font(.headline)
                
                AnimatedPrimaryButton(
                    title: "Create Family",
                    action: { print("Create family tapped") },
                    icon: "plus.circle.fill"
                )
                
                AnimatedPrimaryButton(
                    title: "Processing...",
                    action: {},
                    isLoading: true
                )
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Secondary Buttons")
                    .font(.headline)
                
                AnimatedSecondaryButton(
                    title: "Join Family",
                    action: { print("Join family tapped") },
                    icon: "person.badge.plus"
                )
                
                AnimatedSecondaryButton(
                    title: "Loading...",
                    action: {},
                    isLoading: true
                )
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Icon Buttons")
                    .font(.headline)
                
                HStack(spacing: 16) {
                    AnimatedIconButton(
                        icon: "heart.fill",
                        action: { print("Heart tapped") },
                        color: .red,
                        backgroundColor: Color.red.opacity(0.1)
                    )
                    
                    AnimatedIconButton(
                        icon: "star.fill",
                        action: { print("Star tapped") },
                        color: .yellow,
                        backgroundColor: Color.yellow.opacity(0.1)
                    )
                    
                    AnimatedIconButton(
                        icon: "message.fill",
                        action: { print("Message tapped") },
                        color: .blue,
                        backgroundColor: Color.blue.opacity(0.1)
                    )
                }
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Toggle Buttons")
                    .font(.headline)
                
                AnimatedToggleButton(
                    isOn: .constant(true),
                    label: "Notifications"
                )
                
                AnimatedToggleButton(
                    isOn: .constant(false),
                    label: "Location Sharing"
                )
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Card Buttons")
                    .font(.headline)
                
                AnimatedCardButton(
                    title: "Family Calendar",
                    subtitle: "View upcoming events and birthdays",
                    icon: "calendar",
                    action: { print("Calendar tapped") }
                )
                
                AnimatedCardButton(
                    title: "Tasks & Chores",
                    subtitle: "Manage family responsibilities",
                    icon: "checkmark.circle",
                    action: { print("Tasks tapped") }
                )
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Floating Action Button")
                    .font(.headline)
                
                HStack {
                    Spacer()
                    AnimatedFloatingActionButton(
                        icon: "plus",
                        action: { print("FAB tapped") }
                    )
                }
            }
        }
        .padding()
    }
}