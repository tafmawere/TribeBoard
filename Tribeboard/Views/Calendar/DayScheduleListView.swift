//
//  DayScheduleListView.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/03.
//

import SwiftUI
import Combine

// MARK: - DayScheduleViewModel

/// View model for the day schedule list view that manages occurrences and materialization
@MainActor
class DayScheduleViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var occurrences: [ScheduledRunPreview] = []
    @Published var isLoading = false
    
    // MARK: - Dependencies
    
    private let generator: ScheduleRunGenerator
    private let materializer: RunMaterializer
    private let appCoordinator: AppCoordinator
    
    // MARK: - Initialization
    
    init(
        generator: ScheduleRunGenerator,
        materializer: RunMaterializer,
        appCoordinator: AppCoordinator
    ) {
        self.generator = generator
        self.materializer = materializer
        self.appCoordinator = appCoordinator
    }
    
    // MARK: - Public Methods
    
    /// Load occurrences for a specific date
    func loadOccurrences(for date: Date) async {
        isLoading = true
        defer { isLoading = false }
        
        // Get occurrences for the date
        let previews = generator.occurrences(on: date)
        
        // Sort chronologically by time
        occurrences = previews.sorted { $0.occurrenceDateTime < $1.occurrenceDateTime }
    }
    
    /// Materialize a preview and navigate to the run
    func materializeAndNavigate(_ preview: ScheduledRunPreview) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Materialize the preview into a Run
            let run = try await materializer.materialize(preview)
            
            // Navigate to RunFocusView for the run
            appCoordinator.navigate(to: .runDetail(runId: run.id))
        } catch {
            // Show error alert
            appCoordinator.handleError(error, context: "Failed to create run")
        }
    }
}

// MARK: - DayScheduleListView

/// View displaying all schedule occurrences for a specific date
struct DayScheduleListView: View {
    
    // MARK: - Properties
    
    let date: Date
    
    // MARK: - State
    
    @StateObject private var viewModel: DayScheduleViewModel
    
    // MARK: - Environment
    
    @EnvironmentObject private var appCoordinator: AppCoordinator
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Initialization
    
    init(date: Date, viewModel: DayScheduleViewModel) {
        self.date = date
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.spacing16) {
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.occurrences.isEmpty {
                    emptyStateView
                } else {
                    occurrencesListView
                }
            }
            .padding(DesignSystem.Spacing.spacing16)
        }
        .background(DesignSystem.Colors.screenBackground)
        .navigationTitle(formattedDate)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadOccurrences(for: date)
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: DesignSystem.Spacing.spacing16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading schedules...")
                .font(.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.spacing16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.textTertiary)
            
            Text("No Scheduled Runs")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Text("There are no scheduled runs for this date.")
                .font(.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }
    
    // MARK: - Occurrences List View
    
    private var occurrencesListView: some View {
        VStack(spacing: DesignSystem.Spacing.spacing16) {
            ForEach(viewModel.occurrences) { preview in
                SchedulePreviewDetailCard(
                    preview: preview,
                    onCreateRun: {
                        Task {
                            await viewModel.materializeAndNavigate(preview)
                        }
                    }
                )
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Schedule Preview Detail Card

/// Detailed card component for displaying a schedule preview with action button
struct SchedulePreviewDetailCard: View {
    let preview: ScheduledRunPreview
    let onCreateRun: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.spacing16) {
            // Header with title and time
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(preview.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text(timeString)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.primaryBlue)
                }
                
                Spacer()
            }
            
            Divider()
            
            // Details section
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.spacing12) {
                // Driver info
                HStack(spacing: DesignSystem.Spacing.spacing8) {
                    Image(systemName: "person.circle.fill")
                        .font(.body)
                        .foregroundColor(DesignSystem.Colors.driverBadge)
                    
                    Text("Driver: \(driverDisplayName)")
                        .font(.body)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                
                // Passenger count
                HStack(spacing: DesignSystem.Spacing.spacing8) {
                    Image(systemName: "person.2.fill")
                        .font(.body)
                        .foregroundColor(DesignSystem.Colors.passengerBadge)
                    
                    Text("\(preview.passengerUserIds.count) passenger\(preview.passengerUserIds.count == 1 ? "" : "s")")
                        .font(.body)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                
                // Stop count
                HStack(spacing: DesignSystem.Spacing.spacing8) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.body)
                        .foregroundColor(DesignSystem.Colors.infoBlue)
                    
                    Text("\(preview.stops.count) stop\(preview.stops.count == 1 ? "" : "s")")
                        .font(.body)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
            }
            
            // Create Run Now button
            Button(action: onCreateRun) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.body)
                    
                    Text("Create Run Now")
                        .font(.body)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.spacing12)
                .background(DesignSystem.Colors.primaryBlue)
                .foregroundColor(.white)
                .cornerRadius(DesignSystem.CornerRadius.radiusMedium)
            }
        }
        .padding(DesignSystem.Spacing.spacing16)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.radiusLarge)
        .shadow(
            color: DesignSystem.Shadow.card.color,
            radius: DesignSystem.Shadow.card.radius,
            x: DesignSystem.Shadow.card.x,
            y: DesignSystem.Shadow.card.y
        )
    }
    
    // MARK: - Computed Properties
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: preview.occurrenceDateTime)
    }
    
    private var driverDisplayName: String {
        // Map demo user IDs to display names
        switch preview.driverUserId {
        case "demo-tafadzwa":
            return "Tafadzwa"
        case "demo-rue":
            return "Rue"
        case "demo-tj":
            return "TJ"
        case "demo-tawana":
            return "Tawana"
        default:
            return "Driver"
        }
    }
}

// MARK: - Preview

#if DEBUG
struct DayScheduleListView_Previews: PreviewProvider {
    static var previews: some View {
        let container = DependencyContainer()
        let viewModel = DayScheduleViewModel(
            generator: container.scheduleRunGenerator,
            materializer: container.runMaterializer,
            appCoordinator: AppCoordinator(dependencyContainer: container)
        )
        
        return NavigationView {
            DayScheduleListView(date: Date(), viewModel: viewModel)
                .environmentObject(AppCoordinator(dependencyContainer: container))
        }
    }
}
#endif
