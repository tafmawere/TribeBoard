import SwiftUI

/// An animated toggle button with enhanced accessibility
struct AnimatedToggleButton: View {
    @Binding var isOn: Bool
    let label: String
    let hint: String?
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    init(
        isOn: Binding<Bool>,
        label: String,
        hint: String? = nil
    ) {
        self._isOn = isOn
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
        Button(action: {
            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)) {
                isOn.toggle()
            }
        }) {
            HStack(spacing: 12) {
                // Toggle indicator
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isOn ? toggleOnColor : toggleOffColor)
                        .frame(width: 50 * scaleFactor, height: 30 * scaleFactor)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 26 * scaleFactor, height: 26 * scaleFactor)
                        .offset(x: isOn ? 10 * scaleFactor : -10 * scaleFactor)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                }
                .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: isOn)
                
                // Label
                Text(label)
                    .font(.system(size: scaledFontSize, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            .frame(minHeight: 44 * scaleFactor) // Minimum touch target
            .contentShape(Rectangle())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityHint(hint ?? "Tap to toggle \(label.lowercased())")
        .accessibilityAddTraits([.isButton])
    }
    
    private var scaledFontSize: CGFloat {
        let baseSize: CGFloat = 16
        return min(baseSize * scaleFactor, 20)
    }
    
    private var toggleOnColor: Color {
        colorSchemeContrast == .increased ? .blue : Color.brandPrimary
    }
    
    private var toggleOffColor: Color {
        colorSchemeContrast == .increased ? .gray : Color(.systemGray4)
    }
}

#Preview {
    VStack(spacing: 20) {
        AnimatedToggleButton(
            isOn: .constant(true),
            label: "Enable Notifications"
        )
        
        AnimatedToggleButton(
            isOn: .constant(false),
            label: "Dark Mode"
        )
        
        AnimatedToggleButton(
            isOn: .constant(true),
            label: "Location Services",
            hint: "Allow app to access your location"
        )
    }
    .padding()
}