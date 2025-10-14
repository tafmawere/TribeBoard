import SwiftUI

/// Reusable card component for displaying run overview with day, time, and stops count
struct RunSummaryCard: View {
    let run: SchoolRun
    
    // Accessibility environment values
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            headerSection
            dateTimeSection
            summarySection
        }
        .cardPadding()
        .background(cardBackground)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("RunSummaryCard_\(run.id)")
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var headerSection: some View {
        HStack {
            Text(run.title)
                .titleMedium()
                .foregroundColor(.primary)
                .dynamicTypeSupport(minSize: 14, maxSize: 28)
            
            Spacer()
            
            if isCompleted {
                completionIcon
            }
        }
    }
    
    @ViewBuilder
    private var completionIcon: some View {
        Image(systemName: "checkmark.circle.fill")
            .foregroundColor(.green)
            .font(.title3)
            .accessibilityLabel("Completed")
    }
    
    @ViewBuilder
    private var dateTimeSection: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            dateInfo
            Spacer()
            timeInfo
        }
    }
    
    @ViewBuilder
    private var dateInfo: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "calendar")
                .foregroundColor(primaryIconColor)
                .font(.callout)
                .accessibilityHidden(true)
            
            Text(formattedDate)
                .bodyMedium()
                .foregroundColor(.secondary)
                .dynamicTypeSupport(minSize: 12, maxSize: 24)
        }
    }
    
    @ViewBuilder
    private var timeInfo: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "clock")
                .foregroundColor(primaryIconColor)
                .font(.callout)
                .accessibilityHidden(true)
            
            Text(formattedTime)
                .bodyMedium()
                .foregroundColor(.secondary)
                .dynamicTypeSupport(minSize: 12, maxSize: 24)
        }
    }
    
    @ViewBuilder
    private var summarySection: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            stopsInfo
            durationInfo
            Spacer()
            if hasParticipatingChildren {
                childrenInfo
            }
        }
    }
    
    @ViewBuilder
    private var stopsInfo: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "mappin.circle.fill")
                .foregroundColor(secondaryIconColor)
                .font(.callout)
                .accessibilityHidden(true)
            
            Text("\(stopsCount) stops")
                .labelMedium()
                .foregroundColor(.secondary)
                .dynamicTypeSupport(minSize: 10, maxSize: 20)
        }
    }
    
    @ViewBuilder
    private var durationInfo: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "timer")
                .foregroundColor(secondaryIconColor)
                .font(.callout)
                .accessibilityHidden(true)
            
            Text(formattedDuration)
                .labelMedium()
                .foregroundColor(.secondary)
                .dynamicTypeSupport(minSize: 10, maxSize: 20)
        }
    }
    
    @ViewBuilder
    private var childrenInfo: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "person.2.fill")
                .foregroundColor(secondaryIconColor)
                .font(.callout)
                .accessibilityHidden(true)
            
            Text("\(childrenCount)")
                .labelMedium()
                .foregroundColor(.secondary)
                .dynamicTypeSupport(minSize: 10, maxSize: 20)
        }
    }
    
    @ViewBuilder
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
            .fill(Color(.systemBackground))
            .mediumShadow()
    }
    
    // MARK: - Computed Properties
    
    private var isCompleted: Bool {
        run.status == .completed
    }
    
    private var stopsCount: Int {
        run.route.count
    }
    
    private var childrenCount: Int {
        run.participatingChildren.count
    }
    
    private var hasParticipatingChildren: Bool {
        !run.participatingChildren.isEmpty
    }
    
    private var primaryIconColor: Color {
        colorScheme == .dark ? .blue : .brandPrimary
    }
    
    private var secondaryIconColor: Color {
        colorScheme == .dark ? .indigo : .brandSecondary
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: run.date)
    }
    
    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: run.date)
    }
    
    private var formattedDuration: String {
        run.formattedDuration
    }
    
    // MARK: - Accessibility Properties
    
    private var accessibilityLabel: String {
        let status = run.status == .completed ? "Completed run" : "Scheduled run"
        return "\(status): \(run.title)"
    }
    
    private var accessibilityHint: String {
        return "Tap to view details and manage this school run"
    }
    
    private var accessibilityValue: String {
        let childrenText = run.participatingChildren.isEmpty ? "No children assigned" : "\(run.participatingChildren.count) children participating"
        return "Scheduled for \(formattedDate) at \(formattedTime), \(run.route.count) stops, \(formattedDuration) duration, \(childrenText)"
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

#Preview("Interactive Card") {
    VStack(spacing: DesignSystem.Spacing.lg) {
        RunSummaryCard(run: SchoolRunPreviewProvider.upcomingRun)
    }
    .screenPadding()
    .background(Color(.systemGroupedBackground))
}