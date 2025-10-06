import SwiftUI

/// Enhanced accessible button with animations and loading states
struct AccessibleButton<Content: View>: View {
    let action: () -> Void
    let label: String
    let hint: String?
    let isEnabled: Bool
    let isLoading: Bool
    let loadingText: String?
    let content: () -> Content
    
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    init(
        action: @escaping () -> Void,
        label: String,
        hint: String? = nil,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        loadingText: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.action = action
        self.label = label
        self.hint = hint
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.loadingText = loadingText
        self.content = content
    }
    
    private var scaleFactor: CGFloat {
        switch dynamicTypeSize {
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
    
    var body: some View {
        Button(action: performAction) {
            content()
        }
        .disabled(!isEnabled || isLoading)
        .frame(minWidth: 44 * scaleFactor, minHeight: 44 * scaleFactor) // Minimum touch target
        .scaleEffect(isPressed && !reduceMotion ? 0.95 : 1.0)
        .opacity((isEnabled && !isLoading) ? 1.0 : 0.6)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.1), value: isPressed)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(accessibilityTraits)
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
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    init(
        title: String,
        action: @escaping () -> Void,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        icon: String? = nil
    ) {
        self.title = title
        self.action = action
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.icon = icon
    }
    
    private var scaleFactor: CGFloat {
        switch dynamicTypeSize {
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
    
    var body: some View {
        AccessibleButton(
            action: action,
            label: title,
            hint: "Tap to \(title.lowercased())",
            isEnabled: isEnabled,
            isLoading: isLoading,
            loadingText: "Processing..."
        ) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                        .accessibilityHidden(true)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: scaledIconSize))
                        .accessibilityHidden(true)
                }
                
                Text(isLoading ? "Processing..." : title)
                    .font(.system(size: scaledFontSize, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity)
            .frame(height: buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                    .fill(backgroundGradient)
            )
        }
    }
    
    private var scaledFontSize: CGFloat {
        let baseSize: CGFloat = 18
        return min(baseSize * scaleFactor, 24)
    }
    
    private var scaledIconSize: CGFloat {
        let baseSize: CGFloat = 18
        return min(baseSize * scaleFactor, 22)
    }
    
    private var buttonHeight: CGFloat {
        let baseHeight: CGFloat = 56
        return max(baseHeight * min(scaleFactor, 1.3), 44)
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
}

/// Secondary button with enhanced animations
struct AnimatedSecondaryButton: View {
    let title: String
    let action: () -> Void
    let isLoading: Bool
    let isEnabled: Bool
    let icon: String?
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    init(
        title: String,
        action: @escaping () -> Void,
        isLoading: Bool = false,
        isEnabled: Bool = true,
        icon: String? = nil
    ) {
        self.title = title
        self.action = action
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.icon = icon
    }
    
    private var scaleFactor: CGFloat {
        switch dynamicTypeSize {
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
    
    var body: some View {
        AccessibleButton(
            action: action,
            label: title,
            hint: "Tap to \(title.lowercased())",
            isEnabled: isEnabled,
            isLoading: isLoading,
            loadingText: "Processing..."
        ) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: foregroundColor))
                        .scaleEffect(0.8)
                        .accessibilityHidden(true)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: scaledIconSize))
                        .accessibilityHidden(true)
                }
                
                Text(isLoading ? "Processing..." : title)
                    .font(.system(size: scaledFontSize, weight: .semibold))
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
        return min(baseSize * scaleFactor, 24)
    }
    
    private var scaledIconSize: CGFloat {
        let baseSize: CGFloat = 18
        return min(baseSize * scaleFactor, 22)
    }
    
    private var buttonHeight: CGFloat {
        let baseHeight: CGFloat = 56
        return max(baseHeight * min(scaleFactor, 1.3), 44)
    }
    
    private var foregroundColor: Color {
        colorSchemeContrast == .increased ? .blue : Color.brandPrimary
    }
    
    private var strokeColor: Color {
        colorSchemeContrast == .increased ? .blue : Color.brandPrimary
    }
    
    private var strokeWidth: CGFloat {
        colorSchemeContrast == .increased ? 3 : 2
    }
    
    private var backgroundColor: Color {
        Color(.systemBackground)
    }
}

#if DEBUG
struct AccessibleButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            AnimatedPrimaryButton(title: "Primary Button") {
                print("Primary button tapped")
            }
            
            AnimatedSecondaryButton(title: "Secondary Button") {
                print("Secondary button tapped")
            }
            
            AnimatedPrimaryButton(title: "Loading Button", action: {
                print("Loading button tapped")
            }, isLoading: true)
        }
        .padding()
    }
}
#endif