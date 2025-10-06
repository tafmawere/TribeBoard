import SwiftUI

/// Animated floating action button with enhanced interactions
struct AnimatedFloatingActionButton: View {
    // MARK: - Properties
    
    let icon: String
    let action: () -> Void
    let size: CGFloat
    let backgroundColor: Color
    let foregroundColor: Color
    
    // MARK: - State
    
    @State private var isPressed = false
    @State private var isHovered = false
    
    // MARK: - Environment
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    // MARK: - Initializers
    
    init(
        icon: String,
        action: @escaping () -> Void,
        size: CGFloat = 56,
        backgroundColor: Color = .brandPrimary,
        foregroundColor: Color = .white
    ) {
        self.icon = icon
        self.action = action
        self.size = size
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
    }
    
    // MARK: - Body
    
    var body: some View {
        Button(action: handleTap) {
            Image(systemName: icon)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(foregroundColor)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(backgroundColor)
                        .shadow(
                            color: shadowColor,
                            radius: shadowRadius,
                            x: 0,
                            y: shadowOffset
                        )
                )
        }
        .scaleEffect(scaleEffect)
        .animation(animation, value: isPressed)
        .animation(animation, value: isHovered)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityLabel("Floating action button")
        .accessibilityHint("Double tap to perform action")
        .accessibilityAddTraits([.isButton])
    }
    
    // MARK: - Computed Properties
    
    private var iconSize: CGFloat {
        size * 0.4
    }
    
    private var scaleEffect: CGFloat {
        if isPressed {
            return 0.95
        } else if isHovered {
            return 1.05
        } else {
            return 1.0
        }
    }
    
    private var shadowColor: Color {
        backgroundColor.opacity(0.3)
    }
    
    private var shadowRadius: CGFloat {
        if isPressed {
            return 4
        } else if isHovered {
            return 12
        } else {
            return 8
        }
    }
    
    private var shadowOffset: CGFloat {
        if isPressed {
            return 2
        } else {
            return 4
        }
    }
    
    private var animation: Animation {
        if reduceMotion {
            return .easeInOut(duration: 0.2)
        } else {
            return .spring(response: 0.3, dampingFraction: 0.7)
        }
    }
    
    // MARK: - Actions
    
    private func handleTap() {
        HapticManager.shared.lightImpact()
        action()
    }
}

// MARK: - Preview

#Preview("Floating Action Button") {
    VStack(spacing: 32) {
        AnimatedFloatingActionButton(
            icon: "plus",
            action: {
                print("Add button tapped")
            }
        )
        
        AnimatedFloatingActionButton(
            icon: "message",
            action: {
                print("Message button tapped")
            },
            backgroundColor: .green
        )
        
        AnimatedFloatingActionButton(
            icon: "camera",
            action: {
                print("Camera button tapped")
            },
            size: 48,
            backgroundColor: .orange
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Floating Action Button - Dark Mode") {
    VStack(spacing: 32) {
        AnimatedFloatingActionButton(
            icon: "plus",
            action: {
                print("Add button tapped")
            }
        )
        
        AnimatedFloatingActionButton(
            icon: "heart.fill",
            action: {
                print("Heart button tapped")
            },
            backgroundColor: .red
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
    .preferredColorScheme(.dark)
}