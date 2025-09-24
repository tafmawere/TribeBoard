import SwiftUI

/// Visual progress bar component for execution mode showing current step progress
struct ProgressIndicator: View {
    let current: Int
    let total: Int
    let showLabels: Bool
    
    // Accessibility environment values
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    init(current: Int, total: Int, showLabels: Bool = true) {
        self.current = current
        self.total = total
        self.showLabels = showLabels
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Progress labels
            if showLabels {
                HStack {
                    Text("Progress")
                        .labelMedium()
                        .foregroundColor(.secondary)
                        .dynamicTypeSupport(minSize: 12, maxSize: 20)
                        .accessibilityAddTraits(.isHeader)
                    
                    Spacer()
                    
                    Text("\(current) of \(total)")
                        .labelMedium()
                        .foregroundColor(colorSchemeContrast == .increased ? .blue : .brandPrimary)
                        .fontWeight(.semibold)
                        .dynamicTypeSupport(minSize: 12, maxSize: 20)
                }
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(height: 12)
                    
                    // Progress fill
                    RoundedRectangle(cornerRadius: 6)
                        .fill(progressGradient)
                        .frame(width: progressWidth(in: geometry), height: 12)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: current)
                    
                    // Step indicators
                    stepIndicators(in: geometry)
                }
            }
            .frame(height: 12)
            
            // Percentage text
            if showLabels {
                HStack {
                    Spacer()
                    Text("\(Int(progressPercentage))%")
                        .captionMedium()
                        .foregroundColor(.secondary)
                        .dynamicTypeSupport(minSize: 10, maxSize: 18)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(.updatesFrequently)
        .accessibilityIdentifier("ProgressIndicator_\(current)_of_\(total)")
    }
    
    // MARK: - Step Indicators
    
    private func stepIndicators(in geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            ForEach(1...total, id: \.self) { step in
                let isCompleted = step <= current
                let isCurrent = step == current
                
                Circle()
                    .fill(stepIndicatorColor(for: step))
                    .frame(width: isCurrent ? 16 : 12, height: isCurrent ? 16 : 12)
                    .scaleEffect(isCurrent ? 1.1 : 1.0)
                    .animation(reduceMotion ? nil : .spring(response: 0.3), value: current)
                    .position(
                        x: stepPosition(for: step, in: geometry),
                        y: 6
                    )
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var progressPercentage: Double {
        guard total > 0 else { return 0 }
        return (Double(current) / Double(total)) * 100
    }
    
    private var progressGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.brandPrimary,
                Color.brandSecondary
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private func progressWidth(in geometry: GeometryProxy) -> CGFloat {
        guard total > 0 else { return 0 }
        return geometry.size.width * CGFloat(current) / CGFloat(total)
    }
    
    private func stepPosition(for step: Int, in geometry: GeometryProxy) -> CGFloat {
        guard total > 1 else { return geometry.size.width / 2 }
        let stepWidth = geometry.size.width / CGFloat(total - 1)
        return stepWidth * CGFloat(step - 1)
    }
    
    private func stepIndicatorColor(for step: Int) -> Color {
        if step < current {
            return colorSchemeContrast == .increased ? .blue : .brandPrimary // Completed
        } else if step == current {
            return colorSchemeContrast == .increased ? .indigo : .brandSecondary // Current
        } else {
            return Color(.systemGray4) // Upcoming
        }
    }
    
    // MARK: - Accessibility Properties
    
    private var accessibilityLabel: String {
        return "Progress indicator"
    }
    
    private var accessibilityValue: String {
        return "Step \(current) of \(total), \(Int(progressPercentage)) percent complete"
    }
}

// MARK: - Circular Progress Variant

extension ProgressIndicator {
    /// Circular progress indicator variant
    static func circular(current: Int, total: Int, size: CGFloat = 80) -> some View {
        CircularProgressIndicator(current: current, total: total, size: size)
    }
}

private struct CircularProgressIndicator: View {
    let current: Int
    let total: Int
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 8)
                .frame(width: size, height: size)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: progressPercentage)
                .stroke(
                    LinearGradient.brandGradient,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: current)
            
            // Center content
            VStack(spacing: 2) {
                Text("\(current)")
                    .titleLarge()
                    .foregroundColor(.brandPrimary)
                    .fontWeight(.bold)
                
                Text("of \(total)")
                    .captionMedium()
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var progressPercentage: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(current) / CGFloat(total)
    }
}

// MARK: - Mini Progress Variant

extension ProgressIndicator {
    /// Mini progress indicator for compact spaces
    static func mini(current: Int, total: Int) -> some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            ForEach(1...total, id: \.self) { step in
                Circle()
                    .fill(step <= current ? Color.brandPrimary : Color(.systemGray4))
                    .frame(width: 6, height: 6)
                    .animation(.easeInOut(duration: 0.2), value: current)
            }
        }
    }
}

// MARK: - Preview

#Preview("Progress Indicators - All Variants") {
    VStack(spacing: DesignSystem.Spacing.xl) {
        // Standard progress indicator - various states
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Standard Progress")
                .headlineSmall()
            
            ProgressIndicator(current: 1, total: 6)
            ProgressIndicator(current: 3, total: 6)
            ProgressIndicator(current: 5, total: 6)
            ProgressIndicator(current: 6, total: 6)
        }
        
        // Circular progress indicator
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Circular Progress")
                .headlineSmall()
            
            HStack {
                ProgressIndicator.circular(current: 1, total: 4, size: 60)
                ProgressIndicator.circular(current: 2, total: 4, size: 80)
                ProgressIndicator.circular(current: 3, total: 4, size: 100)
                ProgressIndicator.circular(current: 4, total: 4, size: 120)
            }
        }
        
        // Mini progress indicator
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Mini Progress")
                .headlineSmall()
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Text("Step 1 of 4")
                        .bodySmall()
                    Spacer()
                    ProgressIndicator.mini(current: 1, total: 4)
                }
                
                HStack {
                    Text("Step 3 of 5")
                        .bodySmall()
                    Spacer()
                    ProgressIndicator.mini(current: 3, total: 5)
                }
                
                HStack {
                    Text("Complete")
                        .bodySmall()
                    Spacer()
                    ProgressIndicator.mini(current: 6, total: 6)
                }
            }
        }
        
        Spacer()
    }
    .screenPadding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Progress Indicators - Dark Mode") {
    VStack(spacing: DesignSystem.Spacing.xl) {
        ProgressIndicator(current: 3, total: 6)
        
        HStack {
            ProgressIndicator.circular(current: 2, total: 5, size: 80)
            ProgressIndicator.circular(current: 4, total: 5, size: 80)
        }
        
        ProgressIndicator.mini(current: 3, total: 5)
    }
    .screenPadding()
    .background(Color(.systemGroupedBackground))
    .preferredColorScheme(.dark)
}

#Preview("Progress Indicators - High Contrast") {
    VStack(spacing: DesignSystem.Spacing.xl) {
        ProgressIndicator(current: 3, total: 6)
        ProgressIndicator.circular(current: 3, total: 6, size: 100)
    }
    .screenPadding()
    .background(Color(.systemGroupedBackground))

}

#Preview("Progress Indicators - Large Text") {
    VStack(spacing: DesignSystem.Spacing.xl) {
        ProgressIndicator(current: 3, total: 6)
        ProgressIndicator.mini(current: 3, total: 6)
    }
    .screenPadding()
    .background(Color(.systemGroupedBackground))
    .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("Progress Indicators - Reduced Motion") {
    VStack(spacing: DesignSystem.Spacing.xl) {
        ProgressIndicator(current: 3, total: 6)
        ProgressIndicator.circular(current: 3, total: 6, size: 100)
    }
    .screenPadding()
    .background(Color(.systemGroupedBackground))

}

#Preview("Progress Indicators - Interactive") {
    VStack(spacing: DesignSystem.Spacing.xl) {
        ProgressIndicator(current: 3, total: 6)
    }
    .screenPadding()
    .background(Color(.systemGroupedBackground))
    .previewDisplayName("Interactive Progress")
}