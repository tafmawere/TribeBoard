import SwiftUI

/// An animated icon button with enhanced accessibility
struct AnimatedIconButton: View {
    let icon: String
    let action: () -> Void
    let color: Color
    let backgroundColor: Color
    let size: CGFloat
    let label: String?
    let hint: String?
    
    @State private var isPressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    init(
        icon: String,
        action: @escaping () -> Void,
        color: Color = .brandPrimary,
        backgroundColor: Color = Color.brandPrimary.opacity(0.1),
        size: CGFloat = 44,
        label: String? = nil,
        hint: String? = nil
    ) {
        self.icon = icon
        self.action = action
        self.color = color
        self.backgroundColor = backgroundColor
        self.size = size
        self.label = label
        self.hint = hint
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
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: scaledIconSize, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: scaledSize, height: scaledSize)
                .background(
                    Circle()
                        .fill(backgroundColorAdjusted)
                        .shadow(
                            color: shadowColor,
                            radius: isPressed ? 2 : 4,
                            x: 0,
                            y: isPressed ? 1 : 2
                        )
                )
                .scaleEffect(isPressed && !reduceMotion ? 0.9 : 1.0)
                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits([.isButton])
    }
    
    private var scaledSize: CGFloat {
        max(size * min(scaleFactor, 1.3), 44) // Ensure minimum touch target
    }
    
    private var scaledIconSize: CGFloat {
        let baseIconSize = size * 0.5
        return min(baseIconSize * scaleFactor, size * 0.6)
    }
    
    private var iconColor: Color {
        colorSchemeContrast == .increased ? adjustColorForHighContrast(color) : color
    }
    
    private var backgroundColorAdjusted: Color {
        colorSchemeContrast == .increased ? 
            adjustBackgroundForHighContrast(backgroundColor) : backgroundColor
    }
    
    private var shadowColor: Color {
        Color.black.opacity(colorSchemeContrast == .increased ? 0.4 : 0.1)
    }
    
    private var accessibilityLabel: String {
        if let label = label {
            return label
        }
        
        // Provide default labels based on common icons
        switch icon {
        case "heart", "heart.fill":
            return "Like"
        case "star", "star.fill":
            return "Favorite"
        case "message", "message.fill":
            return "Message"
        case "plus":
            return "Add"
        case "minus":
            return "Remove"
        case "xmark":
            return "Close"
        case "checkmark":
            return "Confirm"
        default:
            return "Button"
        }
    }
    
    private var accessibilityHint: String {
        if let hint = hint {
            return hint
        }
        
        return "Tap to \(accessibilityLabel.lowercased())"
    }
    
    private func adjustColorForHighContrast(_ color: Color) -> Color {
        // Enhance color contrast for high contrast mode
        switch color {
        case .red:
            return .red
        case .blue:
            return .blue
        case .yellow:
            return .orange // Yellow can be hard to see in high contrast
        default:
            return color
        }
    }
    
    private func adjustBackgroundForHighContrast(_ backgroundColor: Color) -> Color {
        // Make backgrounds more prominent in high contrast mode
        return backgroundColor.opacity(0.3)
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 16) {
            AnimatedIconButton(
                icon: "heart.fill",
                action: { print("Heart tapped") },
                color: .red,
                backgroundColor: Color.red.opacity(0.1),
                label: "Like"
            )
            
            AnimatedIconButton(
                icon: "star.fill",
                action: { print("Star tapped") },
                color: .yellow,
                backgroundColor: Color.yellow.opacity(0.1),
                label: "Favorite"
            )
            
            AnimatedIconButton(
                icon: "message.fill",
                action: { print("Message tapped") },
                color: .blue,
                backgroundColor: Color.blue.opacity(0.1),
                label: "Message"
            )
        }
        
        HStack(spacing: 16) {
            AnimatedIconButton(
                icon: "plus",
                action: { print("Add tapped") },
                size: 52
            )
            
            AnimatedIconButton(
                icon: "minus",
                action: { print("Remove tapped") },
                size: 52
            )
        }
    }
    .padding()
}