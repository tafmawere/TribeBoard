import SwiftUI

/// Reusable card component for displaying run overview with day, time, and stops count
struct RunSummaryCard: View {
    let run: ScheduledSchoolRun
    
    // Accessibility environment values
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header with run name and status
            HStack {
                Text(run.name)
                    .titleMedium()
                    .foregroundColor(.primary)
                    .dynamicTypeSupport(minSize: 14, maxSize: 28)
                
                Spacer()
                
                if run.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                        .accessibilityLabel("Completed")
                }
            }
            
            // Date and time information
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "calendar")
                    .foregroundColor(colorSchemeContrast == .increased ? .blue : .brandPrimary)
                    .font(.callout)
                    .accessibilityHidden(true)
                
                Text(formattedDate)
                    .bodyMedium()
                    .foregroundColor(.secondary)
                    .dynamicTypeSupport(minSize: 12, maxSize: 24)
                
                Spacer()
                
                Image(systemName: "clock")
                    .foregroundColor(colorSchemeContrast == .increased ? .blue : .brandPrimary)
                    .font(.callout)
                    .accessibilityHidden(true)
                
                Text(formattedTime)
                    .bodyMedium()
                    .foregroundColor(.secondary)
                    .dynamicTypeSupport(minSize: 12, maxSize: 24)
            }
            
            // Stops and duration summary
            HStack(spacing: DesignSystem.Spacing.lg) {
                // Stops count
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundColor(colorSchemeContrast == .increased ? .indigo : .brandSecondary)
                        .font(.callout)
                        .accessibilityHidden(true)
                    
                    Text("\(run.stops.count) stops")
                        .labelMedium()
                        .foregroundColor(.secondary)
                        .dynamicTypeSupport(minSize: 10, maxSize: 20)
                }
                
                // Duration
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "timer")
                        .foregroundColor(colorSchemeContrast == .increased ? .indigo : .brandSecondary)
                        .font(.callout)
                        .accessibilityHidden(true)
                    
                    Text(formattedDuration)
                        .labelMedium()
                        .foregroundColor(.secondary)
                        .dynamicTypeSupport(minSize: 10, maxSize: 20)
                }
                
                Spacer()
                
                // Participating children count
                if !run.participatingChildren.isEmpty {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(colorSchemeContrast == .increased ? .indigo : .brandSecondary)
                            .font(.callout)
                            .accessibilityHidden(true)
                        
                        Text("\(run.participatingChildren.count)")
                            .labelMedium()
                            .foregroundColor(.secondary)
                            .dynamicTypeSupport(minSize: 10, maxSize: 20)
                    }
                }
            }
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .mediumShadow()
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("RunSummaryCard_\(run.id)")
    }
    
    // MARK: - Computed Properties
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: run.scheduledDate)
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: run.scheduledTime)
    }
    
    private var formattedDuration: String {
        let totalMinutes = Int(run.estimatedDuration / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    // MARK: - Accessibility Properties
    
    private var accessibilityLabel: String {
        let status = run.isCompleted ? "Completed run" : "Scheduled run"
        return "\(status): \(run.name)"
    }
    
    private var accessibilityHint: String {
        return "Tap to view details and manage this school run"
    }
    
    private var accessibilityValue: String {
        let childrenText = run.participatingChildren.isEmpty ? "No children assigned" : "\(run.participatingChildren.count) children participating"
        return "Scheduled for \(formattedDate) at \(formattedTime), \(run.stops.count) stops, \(formattedDuration) duration, \(childrenText)"
    }
}

// MARK: - Preview

#Preview("Run Summary Card - Various States") {
    VStack(spacing: DesignSystem.Spacing.lg) {
        // Upcoming run
        RunSummaryCard(run: SchoolRunPreviewProvider.upcomingRun)
        
        // Today's run
        RunSummaryCard(run: SchoolRunPreviewProvider.todayRun)
        
        // Completed run
        RunSummaryCard(run: SchoolRunPreviewProvider.completedRun)
        
        // Long run
        RunSummaryCard(run: SchoolRunPreviewProvider.longRun)
        
        // Short run
        RunSummaryCard(run: SchoolRunPreviewProvider.shortRun)
    }
    .screenPadding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Run Summary Card - Dark Mode") {
    VStack(spacing: DesignSystem.Spacing.lg) {
        RunSummaryCard(run: SchoolRunPreviewProvider.upcomingRun)
        RunSummaryCard(run: SchoolRunPreviewProvider.completedRun)
    }
    .screenPadding()
    .background(Color(.systemGroupedBackground))
    .preferredColorScheme(.dark)
}

#Preview("Run Summary Card - Large Text") {
    VStack(spacing: DesignSystem.Spacing.lg) {
        RunSummaryCard(run: SchoolRunPreviewProvider.accessibilityTestRun)
    }
    .screenPadding()
    .background(Color(.systemGroupedBackground))
    .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("Run Summary Card - High Contrast") {
    VStack(spacing: DesignSystem.Spacing.lg) {
        RunSummaryCard(run: SchoolRunPreviewProvider.upcomingRun)
        RunSummaryCard(run: SchoolRunPreviewProvider.completedRun)
    }
    .screenPadding()
    .background(Color(.systemGroupedBackground))

}

#Preview("Run Summary Card - Interactive") {
    VStack(spacing: DesignSystem.Spacing.lg) {
        RunSummaryCard(run: SchoolRunPreviewProvider.upcomingRun)
    }
    .screenPadding()
    .background(Color(.systemGroupedBackground))
    .previewDisplayName("Interactive Card")
}