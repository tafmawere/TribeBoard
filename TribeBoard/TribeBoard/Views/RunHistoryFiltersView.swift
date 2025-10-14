import SwiftUI

/// Sheet view for configuring run history filters and sorting options
struct RunHistoryFiltersView: View {
    @ObservedObject var viewModel: RunHistoryViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingCustomDatePicker = false
    
    var body: some View {
        NavigationStack {
            Form {
                // Date Range Section
                dateRangeSection
                
                // Status Filter Section
                statusFilterSection
                
                // Sort Options Section
                sortOptionsSection
                
                // Custom Date Range Section (if selected)
                if viewModel.selectedDateRange == .custom {
                    customDateRangeSection
                }
                
                // Actions Section
                actionsSection
            }
            .navigationTitle("Filter & Sort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        HapticManager.shared.lightImpact()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Run history filters")
    }
    
    // MARK: - Section Views
    
    private var dateRangeSection: some View {
        Section {
            ForEach(RunHistoryViewModel.DateRange.allCases) { range in
                HStack {
                    Text(range.displayName)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if viewModel.selectedDateRange == range {
                        Image(systemName: "checkmark")
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundColor(.brandPrimary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    HapticManager.shared.lightImpact()
                    viewModel.selectedDateRange = range
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Date range: \(range.displayName)")
                .accessibilityValue(viewModel.selectedDateRange == range ? "Selected" : "Not selected")
            }
        } header: {
            sectionHeader(title: "Date Range", icon: "calendar")
        }
    }
    
    private var statusFilterSection: some View {
        Section {
            ForEach(RunHistoryViewModel.StatusFilter.allCases) { filter in
                HStack {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        if let status = filter.runStatus {
                            Image(systemName: status.icon)
                                .font(DesignSystem.Typography.labelMedium)
                                .foregroundColor(status.color)
                        } else {
                            Image(systemName: "circle.grid.2x2")
                                .font(DesignSystem.Typography.labelMedium)
                                .foregroundColor(.secondary)
                        }
                        
                        Text(filter.displayName)
                            .font(DesignSystem.Typography.bodyMedium)
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    if viewModel.selectedStatusFilter == filter {
                        Image(systemName: "checkmark")
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundColor(.brandPrimary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    HapticManager.shared.lightImpact()
                    viewModel.selectedStatusFilter = filter
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Status filter: \(filter.displayName)")
                .accessibilityValue(viewModel.selectedStatusFilter == filter ? "Selected" : "Not selected")
            }
        } header: {
            sectionHeader(title: "Status", icon: "checkmark.circle")
        }
    }
    
    private var sortOptionsSection: some View {
        Section {
            ForEach(RunHistoryViewModel.SortOption.allCases) { option in
                HStack {
                    Text(option.displayName)
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if viewModel.sortOption == option {
                        Image(systemName: "checkmark")
                            .font(DesignSystem.Typography.labelMedium)
                            .foregroundColor(.brandPrimary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    HapticManager.shared.lightImpact()
                    viewModel.sortOption = option
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("Sort by: \(option.displayName)")
                .accessibilityValue(viewModel.sortOption == option ? "Selected" : "Not selected")
            }
        } header: {
            sectionHeader(title: "Sort By", icon: "arrow.up.arrow.down")
        }
    }
    
    private var customDateRangeSection: some View {
        Section {
            // Start date picker
            DatePicker(
                "Start Date",
                selection: $viewModel.customStartDate,
                displayedComponents: [.date]
            )
            .font(DesignSystem.Typography.bodyMedium)
            .accessibilityLabel("Custom start date")
            
            // End date picker
            DatePicker(
                "End Date",
                selection: $viewModel.customEndDate,
                displayedComponents: [.date]
            )
            .font(DesignSystem.Typography.bodyMedium)
            .accessibilityLabel("Custom end date")
            
        } header: {
            sectionHeader(title: "Custom Date Range", icon: "calendar.badge.clock")
        } footer: {
            Text("Select the start and end dates for your custom date range.")
                .font(DesignSystem.Typography.captionLarge)
                .foregroundColor(.secondary)
        }
    }
    
    private var actionsSection: some View {
        Section {
            // Clear all filters button
            Button(action: {
                HapticManager.shared.lightImpact()
                viewModel.clearFilters()
            }) {
                HStack {
                    Image(systemName: "trash")
                        .font(DesignSystem.Typography.labelMedium)
                        .foregroundColor(.red)
                    
                    Text("Clear All Filters")
                        .font(DesignSystem.Typography.bodyMedium)
                        .foregroundColor(.red)
                }
            }
            .disabled(!viewModel.hasActiveFilters)
            .accessibilityLabel("Clear all filters")
            .accessibilityHint("Remove all active filters and search terms")
            
            // Statistics summary
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Current Results")
                    .font(DesignSystem.Typography.labelMedium)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("\(viewModel.filteredRunsCount) of \(viewModel.totalHistoricalRuns) runs")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Filter results: \(viewModel.filteredRunsCount) of \(viewModel.totalHistoricalRuns) runs")
        }
    }
    
    // MARK: - Helper Views
    
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(DesignSystem.Typography.captionLarge)
                .foregroundColor(.brandPrimary)
            
            Text(title)
                .font(DesignSystem.Typography.captionLarge)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Preview

#Preview("Run History Filters") {
    RunHistoryFiltersView(viewModel: RunHistoryViewModel())
}