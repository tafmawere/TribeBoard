import SwiftUI

/// View for displaying historical school run data with filtering and search capabilities
struct RunHistoryView: View {
    @StateObject private var viewModel = RunHistoryViewModel()
    @State private var showingFilters = false
    @State private var showingRunDetail = false
    @State private var selectedRun: SchoolRun?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                contentBasedOnState
            }
            .navigationTitle("Run History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    // Filter button
                    Button(action: {
                        HapticManager.shared.lightImpact()
                        showingFilters = true
                    }) {
                        Image(systemName: viewModel.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .font(DesignSystem.Typography.titleMedium)
                            .foregroundColor(viewModel.hasActiveFilters ? .brandPrimary : .secondary)
                    }
                    .accessibilityLabel("Filter runs")
                    .accessibilityHint("Open filter options")
                    .accessibleTouchTarget()
                    .highContrastSupport(
                        normalColor: viewModel.hasActiveFilters ? .brandPrimary : .secondary,
                        highContrastColor: viewModel.hasActiveFilters ? .blue : .primary
                    )
                }
            }
            .searchable(
                text: $viewModel.searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search runs or stops..."
            )
        }
        .task {
            viewModel.loadHistoricalRuns()
        }
        .refreshable {
            HapticManager.shared.lightImpact()
            viewModel.refresh()
        }
        .sheet(isPresented: $showingFilters) {
            RunHistoryFiltersView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingRunDetail) {
            if let selectedRun = selectedRun {
                RunDetailView(run: selectedRun)
            }
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
        .accessibilityLabel("Run History")
        .accessibilityHint("View and filter historical school runs")
        // Add rotor support for historical runs
        .schoolRunRotor(runs: viewModel.filteredRuns) { run in
            selectedRun = run
            showingRunDetail = true
        }
        // Dynamic Type support
        .dynamicTypeSupport()
        // High contrast support
        .environment(\.colorScheme, .light)
    }
    
    // MARK: - Content Views
    
    @ViewBuilder
    private var contentBasedOnState: some View {
        if viewModel.isLoading && !viewModel.hasHistoricalRuns {
            loadingStateView
        } else if !viewModel.hasHistoricalRuns && !viewModel.isLoading {
            emptyHistoryView
        } else if !viewModel.hasFilteredResults && viewModel.hasActiveFilters {
            noFilterResultsView
        } else {
            historyContentView
        }
    }
    
    @ViewBuilder
    private var loadingStateView: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            LoadingStateView(
                message: "Loading run history...",
                style: .card
            )
            .accessibilityLabel("Loading run history")
            
            SkeletonLoadingView(rows: 4, showAvatar: false)
                .accessibilityLabel("Loading placeholder")
        }
        .padding()
    }
    
    @ViewBuilder
    private var emptyHistoryView: some View {
        EmptyStateView(
            icon: "clock.arrow.circlepath",
            title: "No Run History",
            message: "You haven't completed any school runs yet. Once you finish your first run, it will appear here for future reference.",
            style: .branded
        )
    }
    
    @ViewBuilder
    private var noFilterResultsView: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            EmptyStateView(
                icon: "magnifyingglass.circle",
                title: "No Matching Runs",
                message: "No runs match your current search and filter criteria. Try adjusting your filters or search terms.",
                actionTitle: "Clear Filters",
                action: {
                    HapticManager.shared.lightImpact()
                    viewModel.clearFilters()
                },
                style: .minimal
            )
        }
    }
    
    @ViewBuilder
    private var historyContentView: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.lg, pinnedViews: [.sectionHeaders]) {
                // Statistics section (lazy loaded)
                if viewModel.hasFilteredResults {
                    statisticsSection
                }
                
                // Active filters section
                if viewModel.hasActiveFilters {
                    activeFiltersSection
                }
                
                // Runs list section with pagination
                paginatedRunsListSection
            }
            .padding()
        }
        .accessibilityLabel("Run history list")
    }
    
    // MARK: - Section Views
    
    private var statisticsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader(title: "Statistics", icon: "chart.bar.fill")
            
            RunStatisticsCard(statistics: viewModel.runStatistics)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Run statistics section")
    }
    
    private var activeFiltersSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                sectionHeader(title: "Active Filters", icon: "line.3.horizontal.decrease")
                
                Spacer()
                
                Button("Clear All") {
                    HapticManager.shared.lightImpact()
                    viewModel.clearFilters()
                }
                .font(DesignSystem.Typography.labelMedium)
                .foregroundColor(.brandPrimary)
            }
            
            ActiveFiltersView(viewModel: viewModel)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Active filters section")
    }
    
    private var paginatedRunsListSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader(
                title: "Runs (\(viewModel.filteredRunsCount))",
                icon: "list.bullet"
            )
            
            LazyVStack(spacing: DesignSystem.Spacing.sm) {
                // Display runs with pagination (20 at a time for performance)
                ForEach(viewModel.paginatedFilteredRuns) { run in
                    OptimizedHistoryRunCard(
                        run: run,
                        onTap: {
                            selectedRun = run
                            showingRunDetail = true
                        }
                    )
                    .onAppear {
                        // Load more when approaching the end
                        if run.id == viewModel.paginatedFilteredRuns.last?.id {
                            viewModel.loadMoreRuns()
                        }
                    }
                }
                
                // Loading indicator for pagination
                if viewModel.isLoadingMore {
                    HStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading more runs...")
                            .font(DesignSystem.Typography.captionLarge)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, DesignSystem.Spacing.md)
                }
                
                // Load more button if there are more runs
                if viewModel.hasMoreRuns && !viewModel.isLoadingMore {
                    Button("Load More Runs") {
                        HapticManager.shared.lightImpact()
                        viewModel.loadMoreRuns()
                    }
                    .font(DesignSystem.Typography.bodyMedium)
                    .foregroundColor(.brandPrimary)
                    .padding(.vertical, DesignSystem.Spacing.md)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Historical runs list")
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
}

// MARK: - Run Statistics Card Component

/// Card component for displaying run statistics
struct RunStatisticsCard: View {
    let statistics: RunStatistics
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Header
            HStack {
                Text("Summary")
                    .font(DesignSystem.Typography.titleSmall)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            // Statistics grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DesignSystem.Spacing.md) {
                StatisticItem(
                    title: "Total Runs",
                    value: "\(statistics.totalRuns)",
                    icon: "car.fill",
                    color: .brandPrimary
                )
                
                StatisticItem(
                    title: "Completed",
                    value: "\(statistics.completedRuns)",
                    icon: "checkmark.circle.fill",
                    color: .green
                )
                
                StatisticItem(
                    title: "Total Time",
                    value: statistics.formattedTotalDuration,
                    icon: "clock.fill",
                    color: .blue
                )
                
                StatisticItem(
                    title: "Avg Duration",
                    value: statistics.formattedAverageDuration,
                    icon: "timer",
                    color: .orange
                )
            }
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .lightShadow()
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Run statistics")
        .accessibilityValue("Total runs: \(statistics.totalRuns), Completed: \(statistics.completedRuns)")
    }
}

// MARK: - Statistic Item Component

/// Individual statistic item component
struct StatisticItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(DesignSystem.Typography.labelMedium)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(value)
                    .font(DesignSystem.Typography.titleMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(DesignSystem.Typography.captionLarge)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                .fill(color.opacity(0.05))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Active Filters View Component

/// Component for displaying active filters
struct ActiveFiltersView: View {
    @ObservedObject var viewModel: RunHistoryViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Search filter
                if !viewModel.searchText.isEmpty {
                    FilterChip(
                        title: "Search: \(viewModel.searchText)",
                        icon: "magnifyingglass",
                        onRemove: {
                            viewModel.searchText = ""
                        }
                    )
                }
                
                // Date range filter
                if viewModel.selectedDateRange != .all {
                    FilterChip(
                        title: viewModel.selectedDateRange.displayName,
                        icon: "calendar",
                        onRemove: {
                            viewModel.selectedDateRange = .all
                        }
                    )
                }
                
                // Status filter
                if viewModel.selectedStatusFilter != .all {
                    FilterChip(
                        title: viewModel.selectedStatusFilter.displayName,
                        icon: "checkmark.circle",
                        onRemove: {
                            viewModel.selectedStatusFilter = .all
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
        .accessibilityLabel("Active filters")
    }
}

// MARK: - Filter Chip Component

/// Individual filter chip component
struct FilterChip: View {
    let title: String
    let icon: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(DesignSystem.Typography.captionLarge)
                .foregroundColor(.brandPrimary)
            
            Text(title)
                .font(DesignSystem.Typography.captionLarge)
                .foregroundColor(.primary)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(DesignSystem.Typography.captionLarge)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(
            Capsule()
                .fill(Color(.systemGray6))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Filter: \(title)")
        .accessibilityHint("Tap X to remove filter")
    }
}

// MARK: - History Run Card Component

/// Card component for displaying historical run information
struct HistoryRunCard: View {
    let run: SchoolRun
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: DesignSystem.Spacing.md) {
                // Header with title, date, and status
                HStack {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(run.title)
                            .font(DesignSystem.Typography.titleMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading)
                        
                        Text(run.formattedDate)
                            .font(DesignSystem.Typography.bodySmall)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    RunStatusBadge(status: run.status)
                }
                
                // Route summary
                HStack {
                    Image(systemName: "location.fill")
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(.brandPrimary)
                    
                    Text("\(run.totalStops) stops")
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if run.estimatedDuration > 0 {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "clock")
                                .font(DesignSystem.Typography.captionLarge)
                                .foregroundColor(.secondary)
                            
                            Text(run.formattedDuration)
                                .font(DesignSystem.Typography.bodySmall)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Stop preview (first few stops)
                if !run.route.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        HStack {
                            Text("Route")
                                .font(DesignSystem.Typography.labelMedium)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        
                        ForEach(run.route.prefix(3)) { stop in
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                Image(systemName: stop.type.icon)
                                    .font(DesignSystem.Typography.captionLarge)
                                    .foregroundColor(stop.type.color)
                                    .frame(width: 16)
                                
                                Text(stop.name)
                                    .font(DesignSystem.Typography.bodySmall)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text(stop.formattedTime)
                                    .font(DesignSystem.Typography.captionLarge)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if run.route.count > 3 {
                            HStack {
                                Text("+ \(run.route.count - 3) more stops")
                                    .font(DesignSystem.Typography.captionLarge)
                                    .foregroundColor(.brandPrimary)
                                
                                Spacer()
                            }
                            .padding(.leading, 24)
                        }
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
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Historical run: \(run.title)")
        .accessibilityHint("Tap to view run details")
        .accessibilityValue("\(run.status.displayText), \(run.totalStops) stops")
    }
}

// MARK: - Preview

#Preview("Run History - With Data") {
    RunHistoryView()
}

#Preview("Run History - Empty") {
    RunHistoryView()
}