import SwiftUI

/// Comprehensive accessibility showcase for TribeBoard prototype
struct AccessibilityShowcase: View {
    @State private var toggleValue = false
    @State private var textInput = ""
    @State private var selectedTab = 0
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    headerSection
                    
                    // Dynamic Type Demo
                    dynamicTypeSection
                    
                    // Color Contrast Demo
                    colorContrastSection
                    
                    // Interactive Elements Demo
                    interactiveElementsSection
                    
                    // Form Elements Demo
                    formElementsSection
                    
                    // Navigation Demo
                    navigationSection
                    
                    // Accessibility Settings Info
                    accessibilitySettingsSection
                }
                .padding()
            }
            .navigationTitle("Accessibility Showcase")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "accessibility")
                .font(.system(size: 60))
                .foregroundColor(.brandPrimaryDynamic)
                .accessibilityHidden(true)
            
            AccessibleText(
                "Accessibility Features",
                style: .largeTitle,
                weight: .bold,
                alignment: .center
            )
            .accessibilityAddTraits([.isHeader])
            
            AccessibleText(
                "This showcase demonstrates comprehensive accessibility support including VoiceOver, Dynamic Type, High Contrast, and Reduced Motion.",
                style: .body,
                color: .secondary,
                alignment: .center
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemGray6))
        )
    }
    
    private var dynamicTypeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            AccessibleText(
                "Dynamic Type Support",
                style: .title2,
                weight: .bold
            )
            .accessibilityAddTraits([.isHeader])
            
            VStack(alignment: .leading, spacing: 12) {
                AccessibleText("Large Title", style: .largeTitle, weight: .bold)
                AccessibleText("Title", style: .title, weight: .semibold)
                AccessibleText("Headline", style: .headline, weight: .medium)
                AccessibleText("Body text that scales with system font size", style: .body)
                AccessibleText("Subheadline text", style: .subheadline)
                AccessibleText("Caption text", style: .caption, color: .secondary)
            }
            
            Text("Current Dynamic Type: \(dynamicTypeSize.description)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .shadow(color: BrandStyle.standardShadow, radius: 4, x: 0, y: 2)
        )
    }
    
    private var colorContrastSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            AccessibleText(
                "Color Contrast",
                style: .title2,
                weight: .bold
            )
            .accessibilityAddTraits([.isHeader])
            
            VStack(spacing: 12) {
                // Normal contrast
                HStack {
                    Rectangle()
                        .fill(Color.brandPrimary)
                        .frame(width: 60, height: 40)
                        .overlay(
                            Text("Normal")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                        .cornerRadius(8)
                    
                    AccessibleText("Brand Primary Color", style: .subheadline)
                    Spacer()
                }
                
                // High contrast
                HStack {
                    Rectangle()
                        .fill(Color.brandPrimaryDynamic)
                        .frame(width: 60, height: 40)
                        .overlay(
                            Text("High")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                        .cornerRadius(8)
                    
                    AccessibleText("Dynamic Brand Color (adapts to contrast settings)", style: .subheadline)
                    Spacer()
                }
            }
            
            Text("High Contrast: \(colorSchemeContrast == .increased ? "Enabled" : "Disabled")")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .shadow(color: BrandStyle.standardShadow, radius: 4, x: 0, y: 2)
        )
    }
    
    private var interactiveElementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            AccessibleText(
                "Interactive Elements",
                style: .title2,
                weight: .bold
            )
            .accessibilityAddTraits([.isHeader])
            
            VStack(spacing: 16) {
                // Primary button
                AnimatedPrimaryButton(
                    title: "Primary Action",
                    action: {
                        print("Primary button tapped")
                    },
                    icon: "checkmark.circle.fill"
                )
                
                // Secondary button
                AnimatedSecondaryButton(
                    title: "Secondary Action",
                    action: {
                        print("Secondary button tapped")
                    },
                    icon: "arrow.right.circle"
                )
                
                // Toggle button
                AnimatedToggleButton(
                    isOn: $toggleValue,
                    label: "Enable Notifications"
                )
                
                // Icon buttons
                HStack(spacing: 16) {
                    AnimatedIconButton(
                        icon: "heart.fill",
                        action: { print("Heart tapped") },
                        color: .red,
                        backgroundColor: Color.red.opacity(0.1)
                    )
                    .accessibilityLabel("Like")
                    .accessibilityHint("Tap to like this item")
                    
                    AnimatedIconButton(
                        icon: "star.fill",
                        action: { print("Star tapped") },
                        color: .yellow,
                        backgroundColor: Color.yellow.opacity(0.1)
                    )
                    .accessibilityLabel("Favorite")
                    .accessibilityHint("Tap to add to favorites")
                    
                    AnimatedIconButton(
                        icon: "message.fill",
                        action: { print("Message tapped") },
                        color: .blue,
                        backgroundColor: Color.blue.opacity(0.1)
                    )
                    .accessibilityLabel("Message")
                    .accessibilityHint("Tap to send a message")
                    
                    Spacer()
                }
            }
            
            Text("Reduced Motion: \(reduceMotion ? "Enabled" : "Disabled")")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .shadow(color: BrandStyle.standardShadow, radius: 4, x: 0, y: 2)
        )
    }
    
    private var formElementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            AccessibleText(
                "Form Elements",
                style: .title2,
                weight: .bold
            )
            .accessibilityAddTraits([.isHeader])
            
            VStack(spacing: 16) {
                AccessibleFormField(
                    title: "Family Name",
                    text: $textInput,
                    placeholder: "Enter your family name",
                    validation: Validation.validateFamilyName(textInput)
                )
                
                AccessibleFormField(
                    title: "Email Address",
                    text: .constant(""),
                    placeholder: "Enter your email",
                    keyboardType: .emailAddress
                )
                
                AccessibleFormField(
                    title: "Password",
                    text: .constant(""),
                    placeholder: "Enter your password",
                    isSecure: true
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .shadow(color: BrandStyle.standardShadow, radius: 4, x: 0, y: 2)
        )
    }
    
    private var navigationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            AccessibleText(
                "Navigation Elements",
                style: .title2,
                weight: .bold
            )
            .accessibilityAddTraits([.isHeader])
            
            VStack(spacing: 12) {
                // Card buttons
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
                
                AnimatedCardButton(
                    title: "Family Messages",
                    subtitle: "Stay connected with your family",
                    icon: "message.circle",
                    action: { print("Messages tapped") }
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .shadow(color: BrandStyle.standardShadow, radius: 4, x: 0, y: 2)
        )
    }
    
    private var accessibilitySettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            AccessibleText(
                "Accessibility Settings",
                style: .title2,
                weight: .bold
            )
            .accessibilityAddTraits([.isHeader])
            
            VStack(alignment: .leading, spacing: 12) {
                settingRow("Dynamic Type", dynamicTypeSize.description)
                settingRow("High Contrast", colorSchemeContrast == .increased ? "Enabled" : "Disabled")
                settingRow("Reduce Motion", reduceMotion ? "Enabled" : "Disabled")
                settingRow("VoiceOver", UIAccessibility.isVoiceOverRunning ? "Enabled" : "Disabled")
                settingRow("Switch Control", UIAccessibility.isSwitchControlRunning ? "Enabled" : "Disabled")
            }
            
            Divider()
                .padding(.vertical, 8)
            
            AccessibleText(
                "To test accessibility features, go to Settings > Accessibility on your device and enable VoiceOver, increase text size, or turn on high contrast mode.",
                style: .caption,
                color: .secondary
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemGray6))
        )
    }
    
    private func settingRow(_ title: String, _ value: String) -> some View {
        HStack {
            AccessibleText(title, style: .subheadline, weight: .medium)
            Spacer()
            AccessibleText(value, style: .subheadline, color: .secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Extensions

extension DynamicTypeSize {
    var description: String {
        switch self {
        case .xSmall: return "Extra Small"
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        case .xLarge: return "Extra Large"
        case .xxLarge: return "Extra Extra Large"
        case .xxxLarge: return "Extra Extra Extra Large"
        case .accessibility1: return "Accessibility 1"
        case .accessibility2: return "Accessibility 2"
        case .accessibility3: return "Accessibility 3"
        case .accessibility4: return "Accessibility 4"
        case .accessibility5: return "Accessibility 5"
        @unknown default: return "Unknown"
        }
    }
}

// MARK: - Preview

#Preview("Accessibility Showcase") {
    AccessibilityShowcase()
}

#Preview("Accessibility Showcase - Large Text") {
    AccessibilityShowcase()
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Accessibility Showcase - High Contrast") {
    AccessibilityShowcase()
        .preferredColorScheme(.dark)
}

#Preview("Accessibility Showcase - Reduced Motion") {
    AccessibilityShowcase()
}