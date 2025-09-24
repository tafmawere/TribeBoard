import SwiftUI

/// Card component displaying run overview with day, time, duration, and participant summary
struct RunOverviewCard: View {
    let run: ScheduledSchoolRun
    
    // Accessibility environment values
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Header with run name
            HStack {
                Text(run.name)
                    .titleLarge()
                    .foregroundColor(.primary)
                    .dynamicTypeSupport(minSize: 18, maxSize: 32)
                    .accessibilityAddTraits(.isHeader)
                
                Spacer()
                
                // Status indicator
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Circle()
                        .fill(run.isCompleted ? Color.green : (colorSchemeContrast == .increased ? .blue : .brandPrimary))
                        .frame(width: 8, height: 8)
                        .accessibilityHidden(true)
                    
                    Text(run.isCompleted ? "Completed" : "Scheduled")
                        .captionLarge()
                        .foregroundColor(.secondary)
                        .dynamicTypeSupport(minSize: 10, maxSize: 18)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Status: \(run.isCompleted ? "Completed" : "Scheduled")")
            }
            
            // Date and time information
            HStack(spacing: DesignSystem.Spacing.lg) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Date & Time")
                        .labelSmall()
                        .foregroundColor(.secondary)
                        .dynamicTypeSupport(minSize: 10, maxSize: 16)
                        .accessibilityAddTraits(.isHeader)
                    
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(colorSchemeContrast == .increased ? .blue : .brandPrimary)
                            .accessibilityHidden(true)
                        
                        Text(formatDate(run.scheduledDate))
                            .bodyMedium()
                            .foregroundColor(.primary)
                            .dynamicTypeSupport(minSize: 12, maxSize: 20)
                    }
                    
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(colorSchemeContrast == .increased ? .blue : .brandPrimary)
                            .accessibilityHidden(true)
                        
                        Text(formatTime(run.scheduledTime))
                            .bodyMedium()
                            .foregroundColor(.primary)
                            .dynamicTypeSupport(minSize: 12, maxSize: 20)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Date and time")
                .accessibilityValue("\(formatDate(run.scheduledDate)) at \(formatTime(run.scheduledTime))")
                
                Spacer()
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Duration")
                        .labelSmall()
                        .foregroundColor(.secondary)
                        .dynamicTypeSupport(minSize: 10, maxSize: 16)
                        .accessibilityAddTraits(.isHeader)
                    
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "timer")
                            .font(.caption)
                            .foregroundColor(colorSchemeContrast == .increased ? .blue : .brandPrimary)
                            .accessibilityHidden(true)
                        
                        Text(formatDuration(run.estimatedDuration))
                            .bodyMedium()
                            .foregroundColor(.primary)
                            .dynamicTypeSupport(minSize: 12, maxSize: 20)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Duration")
                .accessibilityValue(formatDuration(run.estimatedDuration))
            }
            
            // Participants and stops summary
            HStack(spacing: DesignSystem.Spacing.lg) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Participants")
                        .labelSmall()
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "person.2")
                            .font(.caption)
                            .foregroundColor(.brandPrimary)
                        
                        Text("\(run.participatingChildren.count) children")
                            .bodyMedium()
                            .foregroundColor(.primary)
                    }
                    
                    if !run.participatingChildren.isEmpty {
                        Text(run.participatingChildren.map(\.name).joined(separator: ", "))
                            .captionLarge()
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Stops")
                        .labelSmall()
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.caption)
                            .foregroundColor(.brandPrimary)
                        
                        Text("\(run.stops.count) stops")
                            .bodyMedium()
                            .foregroundColor(.primary)
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
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Run overview")
        .accessibilityHint("Summary information about \(run.name)")
        .accessibilityIdentifier("RunOverviewCard_\(run.id)")
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func formatTime(_ time: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

#Preview("Run Overview Card - Various States") {
    VStack(spacing: DesignSystem.Spacing.lg) {
        // Upcoming run
        RunOverviewCard(run: SchoolRunPreviewProvider.upcomingRun)
        
        // Today's run
        RunOverviewCard(run: SchoolRunPreviewProvider.todayRun)
        
        // Completed run
        RunOverviewCard(run: SchoolRunPreviewProvider.completedRun)
        
        // Long run
        RunOverviewCard(run: SchoolRunPreviewProvider.longRun)
        
        // Short run
        RunOverviewCard(run: SchoolRunPreviewProvider.shortRun)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Run Overview Card - Dark Mode") {
    VStack(spacing: DesignSystem.Spacing.lg) {
        RunOverviewCard(run: SchoolRunPreviewProvider.upcomingRun)
        RunOverviewCard(run: SchoolRunPreviewProvider.completedRun)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
    .preferredColorScheme(.dark)
}

#Preview("Run Overview Card - Large Text") {
    VStack(spacing: DesignSystem.Spacing.lg) {
        RunOverviewCard(run: SchoolRunPreviewProvider.accessibilityTestRun)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
    .environment(\.dynamicTypeSize, .accessibility1)
}

#Preview("Run Overview Card - High Contrast") {
    VStack(spacing: DesignSystem.Spacing.lg) {
        RunOverviewCard(run: SchoolRunPreviewProvider.upcomingRun)
        RunOverviewCard(run: SchoolRunPreviewProvider.completedRun)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Run Overview Card - Interactive") {
    VStack(spacing: DesignSystem.Spacing.lg) {
        RunOverviewCard(run: SchoolRunPreviewProvider.upcomingRun)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
    .previewDisplayName("Interactive Overview Card")
}