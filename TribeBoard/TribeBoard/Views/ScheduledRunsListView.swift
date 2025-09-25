import SwiftUI

/// NavigationView with List displaying all scheduled runs for browsing
struct ScheduledRunsListView: View {
    @StateObject private var runManager = ScheduledSchoolRunManager()
    @SafeEnvironmentObject(fallback: { AppState.createFallback() }) private var appState: AppState
    
    // Accessibility environment values
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        Group {
            if runManager.allRunsSorted.isEmpty {
                EmptyStateView.noSchoolRuns(onAddRun: {
                    HapticManager.shared.lightImpact()
                    safeNavigate(to: .scheduleNew)
                })
            } else {
                List {
                    ForEach(runManager.allRunsSorted) { run in
                        Button(action: {
                            HapticManager.shared.lightImpact()
                            safeNavigate(to: .runDetail(run))
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
                    safeNavigate(to: .scheduleNew)
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
        .onAppear {
            validateEnvironmentState()
        }
    }
    
    // MARK: - Safe Navigation Methods
    
    /// Safely navigate to a school run route with fallback error handling
    /// - Parameter route: The route to navigate to
    private func safeNavigate(to route: SchoolRunRoute) {
        // Check if we're using a fallback AppState
        if $appState.isUsingFallback {
            handleFallbackNavigation(to: route)
            return
        }
        
        // Attempt normal navigation
        do {
            appState.navigationPath.append(route)
        } catch {
            handleNavigationError(error, route: route)
        }
    }
    
    /// Handle navigation when using fallback AppState
    /// - Parameter route: The route that was requested
    private func handleFallbackNavigation(to route: SchoolRunRoute) {
        // Log the fallback navigation attempt
        print("⚠️ ScheduledRunsListView: Navigation attempted with fallback AppState for route: \(route)")
        
        // For fallback scenarios, we can't navigate but we should inform the user
        // In a real app, you might show a toast or alert
        // For now, we'll just log and potentially show a message
        
        switch route {
        case .scheduleNew:
            print("📝 User attempted to schedule new run - fallback mode active")
            // Could show a toast: "Please restart the app to schedule new runs"
        case .runDetail(let run):
            print("👁️ User attempted to view run details for: \(run.name) - fallback mode active")
            // Could show a toast: "Please restart the app to view run details"
        default:
            print("🔄 Navigation attempted in fallback mode for: \(route)")
        }
    }
    
    /// Handle navigation errors with user-friendly feedback
    /// - Parameters:
    ///   - error: The navigation error that occurred
    ///   - route: The route that failed to navigate
    private func handleNavigationError(_ error: Error, route: SchoolRunRoute) {
        print("❌ ScheduledRunsListView: Navigation error for route \(route): \(error.localizedDescription)")
        
        // In a production app, you might:
        // 1. Show a toast notification
        // 2. Log to analytics
        // 3. Attempt recovery
        // 4. Provide user feedback
        
        // For now, we'll attempt a fallback navigation
        handleFallbackNavigation(to: route)
    }
    
    /// Validate the current environment state and log any issues
    private func validateEnvironmentState() {
        let environmentInfo = $appState
        
        if environmentInfo.isUsingFallback {
            print("⚠️ ScheduledRunsListView: Using fallback AppState - some functionality may be limited")
            
            // Log validation details
            let validationResult = environmentInfo.validationResult
            if !validationResult.isValid {
                print("❌ Environment validation failed:")
                if let error = validationResult.error {
                    print("   Error: \(error.localizedDescription)")
                }
                validationResult.recommendations.forEach { recommendation in
                    print("   💡 Recommendation: \(recommendation)")
                }
            }
        } else {
            print("✅ ScheduledRunsListView: Using proper environment AppState")
        }
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
    NavigationStack {
        ScheduledRunsListView()
    }
    .previewEnvironment()
}

#Preview("Scheduled Runs - Empty State") {
    NavigationStack {
        ScheduledRunsListView()
    }
    .previewEnvironment()
}

#Preview("Scheduled Runs - Parent Admin Role") {
    NavigationStack {
        ScheduledRunsListView()
    }
    .previewEnvironment(role: .parentAdmin)
}

#Preview("Scheduled Runs - Kid Role") {
    NavigationStack {
        ScheduledRunsListView()
    }
    .previewEnvironment(role: .kid)
}

#Preview("Scheduled Runs - Without Environment Object (Fallback)") {
    NavigationStack {
        ScheduledRunsListView()
    }
    // Intentionally not providing environment object to test fallback behavior
}

#Preview("Scheduled Runs - Dark Mode") {
    NavigationStack {
        ScheduledRunsListView()
    }
    .previewEnvironment()
    .preferredColorScheme(.dark)
}

#Preview("Scheduled Runs - Large Text") {
    NavigationStack {
        ScheduledRunsListView()
    }
    .previewEnvironment()
    .environment(\.dynamicTypeSize, .accessibility1)
}

#Preview("Scheduled Runs - High Contrast") {
    NavigationStack {
        ScheduledRunsListView()
    }
    .previewEnvironment()
}

#Preview("Scheduled Runs - Loading State") {
    NavigationStack {
        ScheduledRunsListView()
    }
    .previewEnvironmentLoading()
}

#Preview("Scheduled Runs - Error State") {
    NavigationStack {
        ScheduledRunsListView()
    }
    .previewEnvironmentError()
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
    .previewEnvironment()
}

#Preview("Run List Row - Dark Mode") {
    VStack(spacing: DesignSystem.Spacing.md) {
        RunListRowView(run: SchoolRunPreviewProvider.upcomingRun)
        RunListRowView(run: SchoolRunPreviewProvider.completedRun)
    }
    .screenPadding()
    .background(Color(.systemGroupedBackground))
    .previewEnvironment()
    .preferredColorScheme(.dark)
}

#Preview("Run List Row - Large Text") {
    VStack(spacing: DesignSystem.Spacing.md) {
        RunListRowView(run: SchoolRunPreviewProvider.accessibilityTestRun)
    }
    .screenPadding()
    .background(Color(.systemGroupedBackground))
    .previewEnvironment()
    .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("Empty State View") {
    EmptyStateView.noSchoolRuns(onAddRun: {})
        .screenPadding()
        .background(Color(.systemGroupedBackground))
        .previewEnvironment()
}