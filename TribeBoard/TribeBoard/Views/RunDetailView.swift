import SwiftUI

/// Detailed view of a specific run before execution, showing overview and route details
struct RunDetailView: View {
    let run: ScheduledSchoolRun
    @EnvironmentObject private var appState: AppState
    @State private var showingStartRunAlert = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.xxl) {
                RunOverviewCard(run: run)
                routeDetailsSection
            }
            .screenPadding()
        }
        .navigationTitle("Run Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                startRunButton
            }
        }
        .alert("Start Run", isPresented: $showingStartRunAlert) {
            alertButtons
        } message: {
            alertMessage
        }
    }
    
    private var routeDetailsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            routeDetailsHeader
            stopsList
        }
    }
    
    private var routeDetailsHeader: some View {
        HStack {
            Text("Route Details")
                .headlineSmall()
                .foregroundColor(.primary)
                .dynamicTypeSupport(minSize: 16, maxSize: 28)
                .accessibilityAddTraits(.isHeader)
            
            Spacer()
            
            routeSummary
        }
    }
    
    private var routeSummary: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "map")
                .font(.caption)
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            
            Text("\(run.stops.count) stops")
                .captionLarge()
                .foregroundColor(.secondary)
                .dynamicTypeSupport(minSize: 10, maxSize: 18)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(run.stops.count) stops in route")
    }
    
    private var stopsList: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            ForEach(Array(run.stops.enumerated()), id: \.offset) { index, stop in
                StopDetailRow(
                    stopNumber: index + 1,
                    totalStops: run.stops.count,
                    stop: stop
                )
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .lightShadow()
        )
    }
    
    private var startRunButton: some View {
        Group {
            if !run.isCompleted {
                Button("Start") {
                    showingStartRunAlert = true
                }
                .accessibilityLabel("Start run execution")
                .accessibilityIdentifier("StartRunButton")
            }
        }
    }
    
    @ViewBuilder
    private var alertButtons: some View {
        Button("Cancel", role: .cancel) { }
        Button("Start Run") {
            startRun()
        }
    }
    
    private var alertMessage: some View {
        Text("Are you ready to start '\(run.name)'?\n\nYou'll be guided through \(run.stops.count) stops with an estimated duration of \(formattedDuration).")
    }
    
    // MARK: - Actions
    
    private func startRun() {
        // Validate run before starting
        let validationErrors = RunValidation.validateRun(run)
        
        if !validationErrors.isEmpty {
            // Show validation errors
            let errorMessages = validationErrors.compactMap(\.errorDescription).joined(separator: "\n")
            ToastManager.shared.error("Cannot start run: \(errorMessages)")
            return
        }
        
        // Add haptic feedback
        HapticManager.shared.buttonPress()
        
        // Show success toast
        ToastManager.shared.info("Starting run...")
        
        // Navigate to execution view after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            appState.navigationPath.append(SchoolRunRoute.runExecution(run))
        }
    }
    
    /// Formatted duration for the run
    private var formattedDuration: String {
        let totalMinutes = run.stops.reduce(0) { $0 + $1.estimatedMinutes }
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

#Preview("Run Detail - Upcoming Run") {
    SchoolRunPreviewProvider.previewWithSampleData {
        NavigationStack {
            RunDetailView(run: SchoolRunPreviewProvider.upcomingRun)
        }
    }
}

#Preview("Run Detail - Completed Run") {
    SchoolRunPreviewProvider.previewWithSampleData {
        NavigationStack {
            RunDetailView(run: SchoolRunPreviewProvider.completedRun)
        }
    }
}

#Preview("Run Detail - Long Run") {
    SchoolRunPreviewProvider.previewWithSampleData {
        NavigationStack {
            RunDetailView(run: SchoolRunPreviewProvider.longRun)
        }
    }
}

#Preview("Run Detail - Short Run") {
    SchoolRunPreviewProvider.previewWithSampleData {
        NavigationStack {
            RunDetailView(run: SchoolRunPreviewProvider.shortRun)
        }
    }
}

#Preview("Run Detail - Dark Mode") {
    SchoolRunPreviewProvider.previewWithSampleData {
        NavigationStack {
            RunDetailView(run: SchoolRunPreviewProvider.upcomingRun)
        }
    }
    .preferredColorScheme(.dark)
}

#Preview("Run Detail - Large Text") {
    SchoolRunPreviewProvider.previewWithSampleData {
        NavigationStack {
            RunDetailView(run: SchoolRunPreviewProvider.accessibilityTestRun)
        }
    }
    .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("Run Detail - High Contrast") {
    SchoolRunPreviewProvider.previewWithSampleData {
        NavigationStack {
            RunDetailView(run: SchoolRunPreviewProvider.upcomingRun)
        }
    }

}

#Preview("Run Detail - Interactive") {
    SchoolRunPreviewProvider.previewWithSampleData {
        NavigationStack {
            RunDetailView(run: SchoolRunPreviewProvider.upcomingRun)
        }
    }
    .previewDisplayName("Interactive Detail View")
}