import SwiftUI

/// Card component displaying run overview with day, time, duration, and participant summary
struct RunOverviewCard: View {
    let run: SchoolRun
    
    // Accessibility environment values
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            headerSection
            dateTimeSection
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .mediumShadow()
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Run overview")
        .accessibilityHint("Summary information about \(run.title)")
        .accessibilityIdentifier("RunOverviewCard_\(run.id)")
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        HStack {
            Text(run.title)
                .titleLarge()
                .foregroundColor(.primary)
                .dynamicTypeSupport(minSize: 18, maxSize: 32)
                .accessibilityAddTraits(.isHeader)
            
            Spacer()
            
            // Status indicator
            HStack(spacing: DesignSystem.Spacing.xs) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                
                Text(run.status == .completed ? "Completed" : "Scheduled")
                    .captionLarge()
                    .foregroundColor(.secondary)
                    .dynamicTypeSupport(minSize: 10, maxSize: 18)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Status: \(run.status == .completed ? "Completed" : "Scheduled")")
        }
    }
    
    private var dateTimeSection: some View {
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
                    
                    Text(formatDate(run.date))
                        .bodyMedium()
                        .foregroundColor(.primary)
                        .dynamicTypeSupport(minSize: 12, maxSize: 20)
                }
                
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(colorSchemeContrast == .increased ? .blue : .brandPrimary)
                        .accessibilityHidden(true)
                    
                    Text(formatTime(run.date))
                        .bodyMedium()
                        .foregroundColor(.primary)
                        .dynamicTypeSupport(minSize: 12, maxSize: 20)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Date and time")
            .accessibilityValue("\(formatDate(run.date)) at \(formatTime(run.date))")
        }
    }
    
    // MARK: - Helper Methods
    
    private var statusColor: Color {
        if run.status == .completed {
            return .green
        } else if colorSchemeContrast == .increased {
            return .blue
        } else {
            return .brandPrimary
        }
    }
    
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

#Preview("Interactive Overview Card") {
    VStack(spacing: DesignSystem.Spacing.lg) {
        RunOverviewCard(run: SchoolRunPreviewProvider.upcomingRun)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}