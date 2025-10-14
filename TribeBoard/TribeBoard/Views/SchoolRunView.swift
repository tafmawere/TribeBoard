import SwiftUI

/// Main School Run dashboard view displaying runs list and management controls
struct SchoolRunView: View {
    @StateObject private var viewModel = SchoolRunViewModel()
    @State private var showingRunPlanner = false
    @State private var showingActiveRun = false
    @State private var selectedRun: SchoolRun?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                contentBasedOnState
            }
            .navigationTitle("School Run")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Haptic feedback for navigation actions (respects accessibility settings)
                        SchoolRunHapticFeedback.navigationAction()
                        showingRunPlanner = true
                    }) {
                        Image(systemName: "plus")
                            .font(DesignSystem.Typography.titleMedium)
                            .foregroundColor(.brandPrimary)
                    }
                    .accessibilityLabel("Add new run")
                    .accessibilityHint("Create a new school run")
                    .accessibleTouchTarget()
                    .highContrastSupport(
                        normalColor: .brandPrimary,
                        highContrastColor: .blue
                    )
                }
            }
        }
        .task {
            viewModel.loadRuns()
        }
        .refreshable {
            // Haptic feedback for navigation actions (respects accessibility settings)
            SchoolRunHapticFeedback.navigationAction()
            viewModel.refresh()
        }
        .sheet(isPresented: $showingRunPlanner) {
            RunPlannerView()
        }
        .sheet(isPresented: $showingActiveRun) {
            ActiveRunView()
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("School Run Dashboard")
        .accessibilityHint("View and manage school transportation runs")
        // Add rotor support for runs
        .schoolRunRotor(runs: viewModel.runs) { run in
            selectedRun = run
        }
        // Dynamic Type support
        .dynamicTypeSupport()
        // High contrast support
        .environment(\.colorScheme, .light)
    }
    
    // MARK: - Content Views
    
    @ViewBuilder
    private var contentBasedOnState: some View {
        if viewModel.isLoading && viewModel.runs.isEmpty {
            loadingStateView
        } else if viewModel.runs.isEmpty && !viewModel.isLoading {
            emptyStateView
        } else {
            runsContentView
        }
    }
    
    @ViewBuilder
    private var loadingStateView: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            LoadingStateView(
                message: "Loading school runs...",
                style: .card
            )
            .accessibilityLabel("Loading school runs")
            
            SkeletonLoadingView(rows: 3, showAvatar: false)
                .accessibilityLabel("Loading placeholder")
        }
        .padding()
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        EmptyStateView.noSchoolRuns {
            // Haptic feedback for navigation actions (respects accessibility settings)
            SchoolRunHapticFeedback.navigationAction()
            showingRunPlanner = true
        }
    }
    
    @ViewBuilder
    private var runsContentView: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.lg, pinnedViews: [.sectionHeaders]) {
                // Today's runs section
                if !viewModel.todaysRuns.isEmpty {
                    todaysRunsSection
                }
                
                // Upcoming runs section
                if !viewModel.upcomingRuns.isEmpty {
                    upcomingRunsSection
                }
                
                // Active run section
                if let activeRun = viewModel.activeRun {
                    activeRunSection(activeRun)
                }
                
                // Quick actions section
                quickActionsSection
                
                // Recent completed runs section (limited for performance)
                if !viewModel.completedRuns.isEmpty {
                    recentCompletedRunsSection
                }
            }
            .padding()
        }
        .accessibilityLabel("School runs list")
    }
    
    // MARK: - Section Views
    
    private var todaysRunsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader(title: "Today's Runs", icon: "calendar.badge.clock")
            
            LazyVStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(viewModel.todaysRuns) { run in
                    RunCard(
                        run: run,
                        onTap: { selectedRun = run },
                        onStart: { startRun(run) },
                        onEdit: run.status.canEdit ? { editRun(run) } : nil,
                        onDelete: { deleteRun(run) }
                    )
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Today's runs section")
    }
    
    private var upcomingRunsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader(title: "Upcoming Runs", icon: "calendar")
            
            LazyVStack(spacing: DesignSystem.Spacing.sm) {
                // Limit to first 10 upcoming runs for performance
                ForEach(viewModel.upcomingRuns.prefix(10)) { run in
                    OptimizedRunCard(
                        run: run,
                        onTap: { selectedRun = run },
                        onStart: { startRun(run) },
                        onEdit: run.status.canEdit ? { editRun(run) } : nil,
                        onDelete: { deleteRun(run) }
                    )
                }
                
                // Show "Load More" if there are more than 10 upcoming runs
                if viewModel.upcomingRuns.count > 10 {
                    Button("Show More Upcoming Runs") {
                        // TODO: Implement pagination in future enhancement
                    }
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(.brandPrimary)
                    .padding(.top, DesignSystem.Spacing.sm)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Upcoming runs section")
    }
    
    private func activeRunSection(_ run: SchoolRun) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader(title: "Active Run", icon: "car.fill")
            
            ActiveRunCard(
                run: run,
                onTap: { showingActiveRun = true },
                onComplete: { completeRun(run) }
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Active run section")
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader(title: "Quick Actions", icon: "bolt.fill")
            
            QuickActionButtons.schoolRunActions(
                onNewRun: {
                    // Haptic feedback for navigation actions (respects accessibility settings)
                    SchoolRunHapticFeedback.navigationAction()
                    showingRunPlanner = true
                },
                onHistory: {
                    // Haptic feedback for navigation actions (respects accessibility settings)
                    SchoolRunHapticFeedback.navigationAction()
                    // TODO: Navigate to history view in later tasks
                },
                onSettings: {
                    // Haptic feedback for navigation actions (respects accessibility settings)
                    SchoolRunHapticFeedback.navigationAction()
                    // TODO: Navigate to settings view in later tasks
                }
            )
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Quick actions section")
    }
    
    private var recentCompletedRunsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader(title: "Recent Completed", icon: "checkmark.circle.fill")
            
            LazyVStack(spacing: DesignSystem.Spacing.sm) {
                // Limit to 5 most recent completed runs for performance
                ForEach(viewModel.completedRuns.prefix(5)) { run in
                    OptimizedRunCard(
                        run: run,
                        onTap: { selectedRun = run },
                        onStart: nil,
                        onEdit: nil,
                        onDelete: { deleteRun(run) }
                    )
                }
                
                // Show link to full history if there are more completed runs
                if viewModel.completedRuns.count > 5 {
                    Button("View All Completed Runs") {
                        // TODO: Navigate to history view in future enhancement
                    }
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(.brandPrimary)
                    .padding(.top, DesignSystem.Spacing.sm)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Recent completed runs section")
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(DesignSystem.Typography.titleSmall)
                .foregroundColor(.brandPrimary)
            
            Text(title)
                .font(DesignSystem.Typography.titleSmall)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits([.isHeader])
    }
    
    // MARK: - Actions
    
    private func startRun(_ run: SchoolRun) {
        // Haptic feedback for starting a run (respects accessibility settings)
        SchoolRunHapticFeedback.runStarted()
        Task {
            await viewModel.startRun(run)
        }
    }
    
    private func completeRun(_ run: SchoolRun) {
        // Haptic feedback for completing a run (respects accessibility settings)
        SchoolRunHapticFeedback.runCompleted()
        Task {
            await viewModel.completeRun(run)
        }
    }
    
    private func editRun(_ run: SchoolRun) {
        // Haptic feedback for navigation actions (respects accessibility settings)
        SchoolRunHapticFeedback.navigationAction()
        // TODO: Navigate to edit run view
        print("Edit run: \(run.title)")
    }
    
    private func deleteRun(_ run: SchoolRun) {
        // Haptic feedback for destructive actions (respects accessibility settings)
        SchoolRunHapticFeedback.destructiveAction()
        Task {
            await viewModel.deleteRun(run)
        }
    }
}

// MARK: - Components are now imported from Components folder

// MARK: - Active Run Card Component

/// Special card component for displaying active run with progress
struct ActiveRunCard: View {
    let run: SchoolRun
    let onTap: () -> Void
    let onComplete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: DesignSystem.Spacing.md) {
                // Header with title and progress
                HStack {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(run.title)
                            .font(DesignSystem.Typography.titleMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("In Progress")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(.orange)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
                        Text("\(run.completedStops)/\(run.totalStops)")
                            .font(DesignSystem.Typography.labelLarge)
                            .fontWeight(.semibold)
                            .foregroundColor(.brandPrimary)
                        
                        Text("stops")
                            .font(DesignSystem.Typography.captionLarge)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Progress bar
                ProgressView(value: run.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .brandPrimary))
                    .scaleEffect(y: 2)
                
                // Next stop information
                if let nextStop = run.nextStop {
                    HStack {
                        Image(systemName: "location.circle.fill")
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundColor(.orange)
                        
                        Text("Next: \(nextStop.name)")
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(nextStop.type.displayName)
                            .font(DesignSystem.Typography.captionLarge)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Complete button
                Button("Complete Run") {
                    onComplete()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .cardPadding()
            .background(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                    .fill(LinearGradient(
                        colors: [Color.brandPrimary.opacity(0.05), Color(.systemBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .mediumShadow()
            )
            .overlay(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                    .stroke(Color.brandPrimary.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Active run: \(run.title)")
        .accessibilityHint("Tap to view active run details")
        .accessibilityValue("Progress: \(run.completedStops) of \(run.totalStops) stops completed")
    }
}



// MARK: - Preview

#Preview("School Run Dashboard") {
    SchoolRunView()
}