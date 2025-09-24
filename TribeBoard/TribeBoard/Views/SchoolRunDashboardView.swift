import SwiftUI

/// Main entry point for School Run feature providing overview and navigation to all run-related screens
struct SchoolRunDashboardView: View {
    @StateObject private var runManager = ScheduledSchoolRunManager()
    @EnvironmentObject private var appState: AppState
    
    // Accessibility environment values
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.componentSpacing) {
                // Header section with title
                HeaderSection()
                
                // Primary action buttons
                ActionButtonsSection()
                
                // Upcoming runs section
                UpcomingRunsSection(runs: runManager.upcomingRuns)
                
                // Past runs section
                PastRunsSection(runs: runManager.pastRuns)
            }
            .screenPadding()
        }
        .navigationTitle("School Runs")
        .navigationBarTitleDisplayMode(.large)
        .background(Color(.systemGroupedBackground))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("School Run Dashboard")
        .accessibilityHint("Main screen for managing school transportation runs")
        .withToast()
    }
}

// MARK: - Header Section

/// Header section with "School Runs" title using TribeBoard typography and branding
struct HeaderSection: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            HStack {
                // TribeBoard logo integration
                TribeBoardLogo(size: .small, showBackground: true)
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("School Runs")
                        .headlineLarge()
                        .foregroundColor(.primary)
                        .dynamicTypeSupport()
                    
                    Text("Manage your family's school transportation")
                        .bodyMedium()
                        .foregroundColor(.secondary)
                        .dynamicTypeSupport()
                }
                
                Spacer()
                
                // School run icon
                Image(systemName: "car.fill")
                    .font(scaledIconFont)
                    .foregroundColor(.brandPrimary)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("TribeBoard School Runs dashboard")
        .accessibilityHint(LocalizedStringKey("Manage your family's school transportation"))
        .accessibilityAddTraits(.isHeader)
    }
    
    /// Scaled icon font
    private var scaledIconFont: Font {
        return Font.system(size: 28, weight: .regular, design: .default)
    }
}

// MARK: - Action Buttons Section

/// Action buttons section with "Schedule New Run" and "View Scheduled Runs" buttons
struct ActionButtonsSection: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Schedule New Run button
            Button(action: {
                HapticManager.shared.lightImpact()
                withAnimation(reduceMotion ? nil : DesignSystem.Animation.standard) {
                    appState.navigationPath.append(SchoolRunRoute.scheduleNew)
                }
            }) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: "plus.circle.fill")
                        .font(DesignSystem.Typography.titleMedium)
                    
                    Text("Schedule New Run")
                    
                    Spacer()
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityLabel("Schedule new school run")
            .accessibilityHint("Create a new school transportation run with multiple stops")
            .accessibilityAddTraits(.isButton)
            
            // View Scheduled Runs button
            Button(action: {
                HapticManager.shared.lightImpact()
                withAnimation(reduceMotion ? nil : DesignSystem.Animation.standard) {
                    appState.navigationPath.append(SchoolRunRoute.scheduledList)
                }
            }) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: "calendar")
                        .font(DesignSystem.Typography.titleMedium)
                    
                    Text("View Scheduled Runs")
                    
                    Spacer()
                }
            }
            .buttonStyle(SecondaryButtonStyle())
            .accessibilityLabel("View scheduled runs")
            .accessibilityHint("Browse all your scheduled school runs")
            .accessibilityAddTraits(.isButton)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Action buttons")
        .accessibilityHint("Primary actions for managing school runs")
    }
}

// MARK: - Upcoming Runs Section

/// Upcoming runs section displaying list of scheduled runs using RunSummaryCard
struct UpcomingRunsSection: View {
    let runs: [ScheduledSchoolRun]
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Section header
            HStack {
                Text("Upcoming Runs")
                    .titleLarge()
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !runs.isEmpty {
                    Text("\(runs.count)")
                        .labelMedium()
                        .foregroundColor(.secondary)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(
                            Capsule()
                                .fill(Color.brandPrimary.opacity(0.1))
                        )
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Upcoming runs section")
            .accessibilityValue(runs.isEmpty ? "No upcoming runs" : "\(runs.count) upcoming runs")
            .accessibilityAddTraits(.isHeader)
            
            // Runs list or empty state
            if runs.isEmpty {
                UpcomingRunsEmptyState()
            } else {
                LazyVStack(spacing: DesignSystem.Spacing.md) {
                    ForEach(runs) { run in
                        Button(action: {
                            HapticManager.shared.lightImpact()
                            appState.navigationPath.append(SchoolRunRoute.runDetail(run))
                        }) {
                            RunSummaryCard(run: run)
                        }
                        .buttonStyle(CardButtonStyle())
                        .accessibilityLabel("Upcoming run: \(run.name)")
                        .accessibilityHint("Tap to view details and start this run")
                        .accessibilityAddTraits(.isButton)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Upcoming runs")
        .accessibilityHint("List of scheduled school runs")
    }
}

// MARK: - Past Runs Section

/// Past runs section showing completed runs for reference
struct PastRunsSection: View {
    let runs: [ScheduledSchoolRun]
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Section header
            HStack {
                Text("Past Runs")
                    .titleLarge()
                    .foregroundColor(.primary)
                
                Spacer()
                
                if !runs.isEmpty {
                    Text("\(runs.count)")
                        .labelMedium()
                        .foregroundColor(.secondary)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(
                            Capsule()
                                .fill(Color.secondary.opacity(0.1))
                        )
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Past runs section")
            .accessibilityValue(runs.isEmpty ? "No past runs" : "\(runs.count) past runs")
            .accessibilityAddTraits(.isHeader)
            
            // Runs list or empty state
            if runs.isEmpty {
                PastRunsEmptyState()
            } else {
                LazyVStack(spacing: DesignSystem.Spacing.md) {
                    ForEach(runs.prefix(5)) { run in // Show only first 5 past runs
                        Button(action: {
                            HapticManager.shared.lightImpact()
                            appState.navigationPath.append(SchoolRunRoute.runDetail(run))
                        }) {
                            RunSummaryCard(run: run)
                        }
                        .buttonStyle(CardButtonStyle())
                        .accessibilityLabel("Past run: \(run.name)")
                        .accessibilityHint("Tap to view details of this completed run")
                        .accessibilityAddTraits(.isButton)
                    }
                    
                    if runs.count > 5 {
                        Button("View All Past Runs") {
                            HapticManager.shared.lightImpact()
                            appState.navigationPath.append(SchoolRunRoute.scheduledList)
                        }
                        .buttonStyle(TertiaryButtonStyle())
                        .accessibilityLabel("View all past runs")
                        .accessibilityHint("See complete history of school runs")
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Past runs")
        .accessibilityHint("History of completed school runs")
    }
}

// MARK: - Empty State Views

/// Empty state for upcoming runs section
struct UpcomingRunsEmptyState: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // TribeBoard branded icon
            ZStack {
                Circle()
                    .fill(LinearGradient.brandGradientSubtle)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "calendar.badge.plus")
                    .font(.system(size: 32))
                    .foregroundColor(.brandPrimary)
            }
            .accessibilityHidden(true)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("No Upcoming Runs")
                    .titleMedium()
                    .foregroundColor(.primary)
                
                Text("Schedule your first school run to get started with TribeBoard")
                    .bodyMedium()
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Schedule New Run") {
                HapticManager.shared.lightImpact()
                appState.navigationPath.append(SchoolRunRoute.scheduleNew)
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .mediumShadow()
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("No upcoming runs")
        .accessibilityHint("Schedule your first school run to get started")
        .accessibilityAddTraits(.isStaticText)
    }
}

/// Empty state for past runs section
struct PastRunsEmptyState: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // TribeBoard branded icon
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 64, height: 64)
                
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 24))
                    .foregroundColor(.secondary)
            }
            .accessibilityHidden(true)
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("No Past Runs")
                    .titleMedium()
                    .foregroundColor(.primary)
                
                Text("Completed runs will appear here")
                    .bodyMedium()
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .lightShadow()
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("No past runs")
        .accessibilityHint("Completed runs will appear here")
        .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Placeholder Views (TODO: Replace with actual implementations in later tasks)

/// Placeholder for Schedule New Run view
struct ScheduleNewRunPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.brandPrimary)
                
                Text("Schedule New Run")
                    .headlineMedium()
                    .foregroundColor(.primary)
                
                Text("This will be the run creation form")
                    .bodyMedium()
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Schedule New Run")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}



/// Placeholder for Run Detail view
struct RunDetailPlaceholderView: View {
    let run: ScheduledSchoolRun
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.brandPrimary)
                
                Text("Run Details")
                    .headlineMedium()
                    .foregroundColor(.primary)
                
                Text("Details for: \(run.name)")
                    .bodyMedium()
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("This will be the run detail view")
                    .bodySmall()
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Spacer()
            }
            .padding()
            .navigationTitle(run.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Dynamic Type Support Extension



// MARK: - Preview

#Preview("Dashboard - Default State") {
    SchoolRunPreviewProvider.previewWithSampleData {
        NavigationStack {
            SchoolRunDashboardView()
        }
    }
}

#Preview("Dashboard - Empty State") {
    SchoolRunPreviewProvider.previewWithSampleData {
        NavigationStack {
            SchoolRunDashboardView()
                .onAppear {
                    // This would show empty state if no runs exist
                }
        }
    }
}

#Preview("Dashboard - Dark Mode") {
    SchoolRunPreviewProvider.previewWithSampleData {
        NavigationStack {
            SchoolRunDashboardView()
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Dashboard - High Contrast") {
    SchoolRunPreviewProvider.previewWithSampleData {
        NavigationStack {
            SchoolRunDashboardView()
        }
    }

}

#Preview("Dashboard - Large Text") {
    SchoolRunPreviewProvider.previewWithSampleData {
        NavigationStack {
            SchoolRunDashboardView()
        }
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("Dashboard - Reduced Motion") {
    SchoolRunPreviewProvider.previewWithSampleData {
        NavigationStack {
            SchoolRunDashboardView()
        }
    }

}

#Preview("Dashboard - Interactive Demo") {
    SchoolRunPreviewProvider.previewWithSampleData {
        NavigationStack {
            SchoolRunDashboardView()
        }
    }
    .previewDisplayName("Interactive Dashboard")
}