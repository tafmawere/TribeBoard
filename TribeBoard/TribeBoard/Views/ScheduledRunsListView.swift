import SwiftUI

/// NavigationView with List displaying all scheduled runs for browsing
struct ScheduledRunsListView: View {
    @StateObject private var runManager = ScheduledSchoolRunManager()
    @EnvironmentObject private var appState: AppState
    
    // Accessibility environment values
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        Group {
            if runManager.allRunsSorted.isEmpty {
                EmptyStateView.noSchoolRuns(onAddRun: {
                    HapticManager.shared.lightImpact()
                    appState.navigationPath.append(SchoolRunRoute.scheduleNew)
                })
            } else {
                List {
                    ForEach(runManager.allRunsSorted) { run in
                        Button(action: {
                            HapticManager.shared.lightImpact()
                            appState.navigationPath.append(SchoolRunRoute.runDetail(run))
                        }) {
                            RunListRowView(run: run)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .accessibilityLabel("Scheduled run: \(run.name)")
                        .accessibilityHint("Tap to view details of this run")
                        .accessibilityAddTraits(.isButton)
                    }
                }
                .listStyle(PlainListStyle())
                .background(Color(.systemGroupedBackground))
            }
        }
        .navigationTitle("Scheduled Runs")
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(false)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                TribeBoardLogo(size: .small, showBackground: false)
                    .accessibilityHidden(true)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    HapticManager.shared.lightImpact()
                    appState.navigationPath.append(SchoolRunRoute.scheduleNew)
                }) {
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundColor(.brandPrimary)
                }
                .accessibilityLabel("Schedule new run")
                .accessibilityHint("Create a new school run")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Scheduled runs list")
        .accessibilityHint("Browse all your scheduled school runs")
        .withToast()
    }
}

// MARK: - RunListRowView Component

/// Component showing run name, day/time, and stop count in a clean row format
struct RunListRowView: View {
    let run: ScheduledSchoolRun
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Status indicator
            VStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(statusColor.opacity(0.3), lineWidth: 4)
                            .scaleEffect(1.5)
                    )
                
                Spacer()
            }
            .frame(height: 60)
            
            // Main content
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                // Run name
                Text(run.name)
                    .titleMedium()
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                // Date and time
                HStack(spacing: DesignSystem.Spacing.sm) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "calendar")
                            .font(.caption)
                            .foregroundColor(.brandPrimary)
                        
                        Text(formattedDate)
                            .labelMedium()
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.brandPrimary)
                        
                        Text(formattedTime)
                            .labelMedium()
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Stops count and duration
                HStack(spacing: DesignSystem.Spacing.lg) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.caption)
                            .foregroundColor(.brandSecondary)
                        
                        Text("\(run.stops.count) stops")
                            .labelSmall()
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "timer")
                            .font(.caption)
                            .foregroundColor(.brandSecondary)
                        
                        Text(formattedDuration)
                            .labelSmall()
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // Status badge
                    if run.isCompleted {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                            
                            Text("Completed")
                                .labelSmall()
                                .foregroundColor(.green)
                        }
                    } else if isUpcoming {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "clock.badge")
                                .font(.caption)
                                .foregroundColor(.orange)
                            
                            Text("Upcoming")
                                .labelSmall()
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Chevron indicator
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
        .padding(.horizontal, DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .lightShadow()
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Tap to view run details")
        .accessibilityAddTraits(.isButton)
    }
    
    // MARK: - Computed Properties
    
    private var statusColor: Color {
        if run.isCompleted {
            return .green
        } else if isUpcoming {
            return .brandPrimary
        } else {
            return .secondary
        }
    }
    
    private var isUpcoming: Bool {
        let now = Date()
        return !run.isCompleted && 
               Calendar.current.compare(run.scheduledDate, to: now, toGranularity: .day) != .orderedAscending
    }
    
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
    
    private var accessibilityLabel: String {
        let status = run.isCompleted ? "Completed" : (isUpcoming ? "Upcoming" : "Past")
        return "\(status) run: \(run.name), \(formattedDate) at \(formattedTime), \(run.stops.count) stops, \(formattedDuration) duration"
    }
}





// MARK: - Preview

#Preview("Scheduled Runs - With Data") {
    SchoolRunPreviewProvider.previewWithSampleData {
        NavigationStack {
            ScheduledRunsListView()
        }
    }
}

#Preview("Scheduled Runs - Empty State") {
    SchoolRunPreviewProvider.previewWithSampleData {
        NavigationStack {
            ScheduledRunsListView()
                .onAppear {
                    // This would show empty state if no runs exist
                }
        }
    }
}

#Preview("Scheduled Runs - Dark Mode") {
    SchoolRunPreviewProvider.previewWithSampleData {
        NavigationStack {
            ScheduledRunsListView()
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Scheduled Runs - Large Text") {
    SchoolRunPreviewProvider.previewWithSampleData {
        NavigationStack {
            ScheduledRunsListView()
        }
    }
    .environment(\.dynamicTypeSize, .accessibility1)
}

#Preview("Scheduled Runs - High Contrast") {
    SchoolRunPreviewProvider.previewWithSampleData {
        NavigationStack {
            ScheduledRunsListView()
        }
    }

}

#Preview("Run List Row - Various States") {
    VStack(spacing: DesignSystem.Spacing.md) {
        // Upcoming run
        RunListRowView(run: SchoolRunPreviewProvider.upcomingRun)
        
        // Today's run
        RunListRowView(run: SchoolRunPreviewProvider.todayRun)
        
        // Completed run
        RunListRowView(run: SchoolRunPreviewProvider.completedRun)
        
        // Long run
        RunListRowView(run: SchoolRunPreviewProvider.longRun)
        
        // Short run
        RunListRowView(run: SchoolRunPreviewProvider.shortRun)
    }
    .screenPadding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Run List Row - Dark Mode") {
    VStack(spacing: DesignSystem.Spacing.md) {
        RunListRowView(run: SchoolRunPreviewProvider.upcomingRun)
        RunListRowView(run: SchoolRunPreviewProvider.completedRun)
    }
    .screenPadding()
    .background(Color(.systemGroupedBackground))
    .preferredColorScheme(.dark)
}

#Preview("Run List Row - Large Text") {
    VStack(spacing: DesignSystem.Spacing.md) {
        RunListRowView(run: SchoolRunPreviewProvider.accessibilityTestRun)
    }
    .screenPadding()
    .background(Color(.systemGroupedBackground))
    .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("Empty State View") {
    EmptyStateView.noSchoolRuns(onAddRun: {})
        .screenPadding()
        .background(Color(.systemGroupedBackground))
}