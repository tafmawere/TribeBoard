import SwiftUI

/// Showcase view demonstrating all accessibility features implemented for School Run components
struct SchoolRunAccessibilityShowcase: View {
    @State private var selectedRun: SchoolRun?
    @State private var testResults: SchoolRunAccessibilityReport?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    private let sampleRuns = SchoolRunPreviewProvider.sampleRuns
    private let sampleStops = SchoolRunPreviewProvider.sampleRuns.first?.route ?? []
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: DesignSystem.Spacing.xl) {
                    // Header
                    headerSection
                    
                    // Accessibility Status
                    accessibilityStatusSection
                    
                    // VoiceOver Support Demo
                    voiceOverDemoSection
                    
                    // Dynamic Type Demo
                    dynamicTypeDemoSection
                    
                    // High Contrast Demo
                    highContrastDemoSection
                    
                    // Reduced Motion Demo
                    reducedMotionDemoSection
                    
                    // Keyboard Navigation Demo
                    keyboardNavigationDemoSection
                    
                    // Touch Target Demo
                    touchTargetDemoSection
                    
                    // Accessibility Testing
                    accessibilityTestingSection
                }
                .screenPadding()
            }
        }
        .navigationTitle("Accessibility Showcase")
        .navigationBarTitleDisplayMode(.large)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("School Run Accessibility Showcase")
        .accessibilityHint("Demonstrates accessibility features for school run components")
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "accessibility")
                .font(.system(size: 48))
                .foregroundColor(.brandPrimary)
                .accessibilityHidden(true)
            
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text("School Run Accessibility")
                    .titleLarge()
                    .foregroundColor(.primary)
                    .accessibilityAddTraits([.isHeader])
                    .dynamicTypeSupport()
                
                Text("Comprehensive accessibility features for inclusive design")
                    .bodyMedium()
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .dynamicTypeSupport()
                    .highContrastSupport(
                        normalColor: .secondary,
                        highContrastColor: .primary
                    )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("School Run Accessibility showcase")
    }
    
    // MARK: - Accessibility Status Section
    
    private var accessibilityStatusSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader(title: "Current Accessibility Settings", icon: "gear")
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                AccessibilityStatusRow(
                    title: "VoiceOver",
                    isEnabled: EnhancedAccessibility.isVoiceOverRunning,
                    icon: "speaker.wave.3"
                )
                
                AccessibilityStatusRow(
                    title: "Switch Control",
                    isEnabled: EnhancedAccessibility.isSwitchControlRunning,
                    icon: "switch.2"
                )
                
                AccessibilityStatusRow(
                    title: "Reduce Motion",
                    isEnabled: reduceMotion,
                    icon: "motion.sensor"
                )
                
                AccessibilityStatusRow(
                    title: "Increase Contrast",
                    isEnabled: colorSchemeContrast == .increased,
                    icon: "circle.lefthalf.filled"
                )
                
                AccessibilityStatusRow(
                    title: "Dynamic Type",
                    isEnabled: dynamicTypeSize != .medium,
                    icon: "textformat.size",
                    value: dynamicTypeSize.description
                )
            }
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .lightShadow()
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Current accessibility settings")
    }
    
    // MARK: - VoiceOver Demo Section
    
    private var voiceOverDemoSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader(title: "VoiceOver Support", icon: "speaker.wave.3")
            
            Text("All components include proper accessibility labels, hints, and values for VoiceOver users.")
                .bodySmall()
                .foregroundColor(.secondary)
                .dynamicTypeSupport()
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                // Sample RunCard with accessibility
                if let sampleRun = sampleRuns.first {
                    RunCard(
                        run: sampleRun,
                        onTap: { selectedRun = sampleRun },
                        onStart: { print("Start run") },
                        onEdit: { print("Edit run") },
                        onDelete: { print("Delete run") }
                    )
                }
                
                // Sample StopRow with accessibility
                if let sampleStop = sampleStops.first {
                    StopRow(
                        stop: sampleStop,
                        onTap: { print("Tap stop") },
                        onToggleComplete: { print("Toggle complete") }
                    )
                }
            }
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .lightShadow()
        )
    }
    
    // MARK: - Dynamic Type Demo Section
    
    private var dynamicTypeDemoSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader(title: "Dynamic Type Support", icon: "textformat.size")
            
            Text("Text and UI elements scale appropriately with system font size settings.")
                .bodySmall()
                .foregroundColor(.secondary)
                .dynamicTypeSupport()
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Current Size: \(dynamicTypeSize.description)")
                    .labelMedium()
                    .foregroundColor(.brandPrimary)
                    .dynamicTypeSupport()
                
                Text("This text scales with Dynamic Type")
                    .titleMedium()
                    .dynamicTypeSupport()
                
                Text("Smaller text also scales appropriately")
                    .captionLarge()
                    .dynamicTypeSupport()
                
                // Sample status badge
                RunStatusBadge(status: .scheduled)
                
                // Sample quick action button
                Button("Sample Action") {
                    print("Sample action")
                }
                .buttonStyle(.bordered)
                .accessibleTouchTarget()
            }
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .lightShadow()
        )
    }
    
    // MARK: - High Contrast Demo Section
    
    private var highContrastDemoSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader(title: "High Contrast Support", icon: "circle.lefthalf.filled")
            
            Text("Colors adapt to provide better contrast when high contrast mode is enabled.")
                .bodySmall()
                .foregroundColor(.secondary)
                .dynamicTypeSupport()
                .highContrastSupport(
                    normalColor: .secondary,
                    highContrastColor: .primary
                )
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Contrast Mode: \(colorSchemeContrast == .increased ? "High" : "Standard")")
                    .labelMedium()
                    .foregroundColor(.brandPrimary)
                    .highContrastSupport(
                        normalColor: .brandPrimary,
                        highContrastColor: .blue
                    )
                
                HStack(spacing: DesignSystem.Spacing.md) {
                    ForEach(RunStatus.allCases, id: \.self) { status in
                        RunStatusBadge(status: status, style: .compact)
                    }
                }
                
                Text("Brand colors automatically adjust for better visibility")
                    .bodySmall()
                    .foregroundColor(.brandPrimary)
                    .highContrastSupport(
                        normalColor: .brandPrimary,
                        highContrastColor: .blue
                    )
            }
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .lightShadow()
        )
    }
    
    // MARK: - Reduced Motion Demo Section
    
    private var reducedMotionDemoSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader(title: "Reduced Motion Support", icon: "motion.sensor")
            
            Text("Animations are disabled or reduced when reduce motion is enabled.")
                .bodySmall()
                .foregroundColor(.secondary)
                .dynamicTypeSupport()
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Reduce Motion: \(reduceMotion ? "Enabled" : "Disabled")")
                    .labelMedium()
                    .foregroundColor(.brandPrimary)
                
                // Animated status badge
                RunStatusBadge(status: .inProgress)
                
                Text("Status badges respect motion preferences")
                    .bodySmall()
                    .foregroundColor(.secondary)
            }
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .lightShadow()
        )
    }
    
    // MARK: - Keyboard Navigation Demo Section
    
    private var keyboardNavigationDemoSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader(title: "Keyboard Navigation", icon: "keyboard")
            
            Text("All interactive elements support keyboard navigation and focus management.")
                .bodySmall()
                .foregroundColor(.secondary)
                .dynamicTypeSupport()
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                // Sample focusable buttons
                HStack(spacing: DesignSystem.Spacing.md) {
                    Button("Button 1") { print("Button 1") }
                        .buttonStyle(.bordered)
                        .accessibleTouchTarget()
                    
                    Button("Button 2") { print("Button 2") }
                        .buttonStyle(.bordered)
                        .accessibleTouchTarget()
                    
                    Button("Button 3") { print("Button 3") }
                        .buttonStyle(.bordered)
                        .accessibleTouchTarget()
                }
                
                Text("Use Tab key to navigate between buttons")
                    .captionLarge()
                    .foregroundColor(.secondary)
            }
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .lightShadow()
        )
    }
    
    // MARK: - Touch Target Demo Section
    
    private var touchTargetDemoSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader(title: "Touch Target Sizes", icon: "hand.tap")
            
            Text("All interactive elements meet the minimum 44pt touch target size requirement.")
                .bodySmall()
                .foregroundColor(.secondary)
                .dynamicTypeSupport()
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    // Small button with proper touch target
                    Button(action: { print("Small button") }) {
                        Image(systemName: "star")
                            .font(.caption)
                    }
                    .accessibleTouchTarget()
                    .background(Color.blue.opacity(0.1))
                    
                    Text("Small icon with 44pt touch area")
                        .bodySmall()
                        .foregroundColor(.secondary)
                }
                
                Text("Touch targets are highlighted in blue for demonstration")
                    .captionLarge()
                    .foregroundColor(.secondary)
            }
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .lightShadow()
        )
    }
    
    // MARK: - Accessibility Testing Section
    
    private var accessibilityTestingSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader(title: "Accessibility Testing", icon: "checkmark.shield")
            
            Text("Run comprehensive accessibility tests to verify compliance.")
                .bodySmall()
                .foregroundColor(.secondary)
                .dynamicTypeSupport()
            
            VStack(spacing: DesignSystem.Spacing.md) {
                Button("Run Accessibility Tests") {
                    testResults = SchoolRunAccessibilityTesting.testAccessibilityCompliance()
                }
                .buttonStyle(.borderedProminent)
                .accessibleTouchTarget()
                
                if let results = testResults {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Test Results")
                            .labelLarge()
                            .foregroundColor(.primary)
                        
                        Text("Pass Rate: \(String(format: "%.1f", results.passRate * 100))%")
                            .bodyMedium()
                            .foregroundColor(results.passRate > 0.8 ? .green : .orange)
                        
                        Text("Passed: \(results.passedTests.count)/\(results.allTests.count)")
                            .bodySmall()
                            .foregroundColor(.secondary)
                    }
                    .cardPadding()
                    .background(
                        RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                            .fill(Color(.secondarySystemBackground))
                    )
                }
            }
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .lightShadow()
        )
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(.brandPrimary)
                .highContrastSupport(
                    normalColor: .brandPrimary,
                    highContrastColor: .blue
                )
            
            Text(title)
                .font(DesignSystem.Typography.titleSmall)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .dynamicTypeSupport()
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits([.isHeader])
    }
}

// MARK: - Accessibility Status Row Component

struct AccessibilityStatusRow: View {
    let title: String
    let isEnabled: Bool
    let icon: String
    let value: String?
    
    init(title: String, isEnabled: Bool, icon: String, value: String? = nil) {
        self.title = title
        self.isEnabled = isEnabled
        self.icon = icon
        self.value = value
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(DesignSystem.Typography.labelMedium)
                .foregroundColor(isEnabled ? .green : .secondary)
                .frame(width: 20)
            
            Text(title)
                .bodyMedium()
                .foregroundColor(.primary)
                .dynamicTypeSupport()
            
            Spacer()
            
            if let value = value {
                Text(value)
                    .captionLarge()
                    .foregroundColor(.secondary)
                    .dynamicTypeSupport()
            }
            
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "xmark.circle")
                .font(DesignSystem.Typography.labelMedium)
                .foregroundColor(isEnabled ? .green : .secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(isEnabled ? "enabled" : "disabled")\(value.map { ", \($0)" } ?? "")")
    }
}



// MARK: - Helper Extension

extension View {
    func `let`<T>(_ transform: (Self) -> T) -> T {
        transform(self)
    }
}

// MARK: - Preview

#Preview("Accessibility Showcase") {
    SchoolRunAccessibilityShowcase()
}

#Preview("Accessibility Showcase - High Contrast") {
    SchoolRunAccessibilityShowcase()
        .preferredColorScheme(.dark)
}

#Preview("Accessibility Showcase - Large Text") {
    SchoolRunAccessibilityShowcase()
        .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Accessibility Showcase - Reduced Motion") {
    SchoolRunAccessibilityShowcase()
        .environment(\.dynamicTypeSize, .accessibility3)
}