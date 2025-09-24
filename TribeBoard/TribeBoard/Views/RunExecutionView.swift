import SwiftUI

/// Step-by-step execution interface for school runs with progress tracking and controls
struct RunExecutionView: View {
    let run: ScheduledSchoolRun
    
    @State private var currentStopIndex = 0
    @State private var executionState: RunExecutionState = .active
    @State private var showingCancelAlert = false
    @State private var showingPauseAlert = false
    @State private var showingCompleteStopAlert = false
    @State private var showingCompleteRunAlert = false
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        mainContent
            .navigationBarHidden(true)
            .toolbar(.hidden, for: .navigationBar)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Run execution view")
            .accessibilityHint("Step-by-step execution of \(run.name)")
            .accessibilityIdentifier("RunExecutionView_\(run.id)")
            .onAppear {
                setupExecution()
            }
            .alert("Cancel Run", isPresented: $showingCancelAlert) {
                cancelRunAlertButtons
            } message: {
                cancelRunAlertMessage
            }
            .alert("Pause Run", isPresented: $showingPauseAlert) {
                pauseRunAlertButtons
            } message: {
                pauseRunAlertMessage
            }
            .alert("Complete Stop", isPresented: $showingCompleteStopAlert) {
                completeStopAlertButtons
            } message: {
                completeStopAlertMessage
            }
            .alert("Run Complete!", isPresented: $showingCompleteRunAlert) {
                completeRunAlertButtons
            } message: {
                completeRunAlertMessage
            }
            .withToast()
    }
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            mapSection
            controlsSection
        }
    }
    
    @ViewBuilder
    private var cancelRunAlertButtons: some View {
        Button("Continue Run", role: .cancel) { }
        Button("Cancel Run", role: .destructive) {
            cancelRun()
        }
    }
    
    private var cancelRunAlertMessage: some View {
        Text("Are you sure you want to cancel this run?\n\nYou've completed \(currentStopIndex) of \(run.stops.count) stops. All progress will be lost and you'll need to start over.")
    }
    
    @ViewBuilder
    private var pauseRunAlertButtons: some View {
        Button("Continue", role: .cancel) { }
        Button("Pause Run") {
            pauseRunConfirmed()
        }
    }
    
    private var pauseRunAlertMessage: some View {
        Text("Do you want to pause this run?\n\nYou can resume from stop \(currentStopIndex + 1) later. Your progress will be saved.")
    }
    
    @ViewBuilder
    private var completeStopAlertButtons: some View {
        Button("Not Yet", role: .cancel) { }
        Button("Mark Complete") {
            completeCurrentStopConfirmed()
        }
    }
    
    private var completeStopAlertMessage: some View {
        Text("Have you completed all tasks at \(currentStop.name)?\n\nTask: \(currentStop.task)")
    }
    
    @ViewBuilder
    private var completeRunAlertButtons: some View {
        Button("Finish") {
            completeRunConfirmed()
        }
    }
    
    private var completeRunAlertMessage: some View {
        Text("Congratulations! You've completed all \(run.stops.count) stops in your \(run.name).")
    }
    
    private var mapSection: some View {
        SchoolRunMapPlaceholder(
            currentStop: currentStop,
            showCurrentLocation: true,
            mapStyle: .execution
        )
        .frame(height: UIScreen.main.bounds.height * 0.4)
        .accessibilityLabel("Navigation map")
        .accessibilityHint("Shows current location and route for run execution")
        .accessibilityIdentifier("ExecutionMap")
    }
    
    private var controlsSection: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            headerSection
            currentStopCard
            actionButtons
        }
        .padding(DesignSystem.Spacing.lg)
        .background(Color(.systemBackground))
    }
    
    private var headerSection: some View {
        HStack {
            TribeBoardLogo(size: .small, showBackground: false)
                .accessibilityHidden(true)
            
            Text(run.name)
                .titleMedium()
                .foregroundColor(.primary)
                .dynamicTypeSupport(minSize: 16, maxSize: 28)
                .accessibilityAddTraits(.isHeader)
            
            Spacer()
            
            statusIndicator
        }
    }
    
    private var statusIndicator: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Circle()
                .fill(executionState == .active ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            
            Text(executionState == .active ? "Active" : "Paused")
                .captionLarge()
                .foregroundColor(.secondary)
                .dynamicTypeSupport(minSize: 10, maxSize: 18)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Run status: \(executionState == .active ? "Active" : "Paused")")
    }
    
    private var currentStopCard: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            CurrentStopCard(
                stopNumber: currentStopIndex + 1,
                totalStops: run.stops.count,
                stop: currentStop,
                isActive: executionState == .active
            )
            
            ProgressIndicator(
                current: currentStopIndex + 1,
                total: run.stops.count
            )
        }
    }
    
    private var actionButtons: some View {
        ExecutionControls(
            executionState: executionState,
            onComplete: completeCurrentStop,
            onPause: pauseRun,
            onCancel: showCancelAlert
        )
    }
    
    // MARK: - Computed Properties
    
    private var currentStop: RunStop {
        guard currentStopIndex < run.stops.count else {
            return run.stops.last ?? RunStop(name: "Unknown", type: .custom, task: "", estimatedMinutes: 0)
        }
        return run.stops[currentStopIndex]
    }
    
    // MARK: - Actions
    
    private func setupExecution() {
        // Initialize execution state if needed
        if executionState == .notStarted {
            executionState = .active
        }
        
        // Show initial toast
        ToastManager.shared.info("Run started! Navigate to your first stop.")
    }
    
    private func completeCurrentStop() {
        showingCompleteStopAlert = true
    }
    
    private func completeCurrentStopConfirmed() {
        guard currentStopIndex < run.stops.count else { return }
        
        // Show completion toast
        ToastManager.shared.success("Stop \(currentStopIndex + 1) completed!")
        
        // Check if this was the last stop
        if currentStopIndex >= run.stops.count - 1 {
            // Show run completion alert after a brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showingCompleteRunAlert = true
            }
        } else {
            // Advance to next stop
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                currentStopIndex += 1
            }
        }
    }
    
    private func pauseRun() {
        showingPauseAlert = true
    }
    
    private func pauseRunConfirmed() {
        executionState = .paused
        ToastManager.shared.info("Run paused at stop \(currentStopIndex + 1)")
        
        // Delay navigation to show toast
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            appState.navigationPath.removeLast()
        }
    }
    
    private func showCancelAlert() {
        showingCancelAlert = true
    }
    
    private func cancelRun() {
        executionState = .cancelled
        ToastManager.shared.warning("Run cancelled")
        
        // Delay navigation to show toast
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            appState.navigationPath.removeLast()
        }
    }
    
    private func completeRunConfirmed() {
        executionState = .completed
        ToastManager.shared.success("🎉 Run completed successfully!")
        
        // Delay navigation back to show completion state
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            appState.navigationPath.removeLast()
        }
    }
}

// MARK: - Execution Controls Component

private struct ExecutionControls: View {
    let executionState: RunExecutionState
    let onComplete: () -> Void
    let onPause: () -> Void
    let onCancel: () -> Void
    
    // Accessibility environment values
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Primary action button
            Button(action: onComplete) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .accessibilityHidden(true)
                    Text("Done → Next Stop")
                        .fontWeight(.semibold)
                        .dynamicTypeSupport(minSize: 14, maxSize: 24)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(executionState != .active)
            .accessibilityLabel("Complete current stop")
            .accessibilityHint("Mark the current stop as completed and move to the next stop")
            .accessibilityIdentifier("CompleteStopButton")
            
            // Secondary action buttons
            HStack(spacing: DesignSystem.Spacing.md) {
                // Pause button
                Button(action: onPause) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "pause.circle")
                            .font(.callout)
                            .accessibilityHidden(true)
                        Text("Pause Run")
                            .font(DesignSystem.Typography.buttonSmall)
                            .dynamicTypeSupport(minSize: 12, maxSize: 20)
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                .disabled(executionState != .active)
                .accessibilityLabel("Pause run")
                .accessibilityHint("Temporarily pause the run execution")
                .accessibilityIdentifier("PauseRunButton")
                
                // Cancel button
                Button(action: onCancel) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "xmark.circle")
                            .font(.callout)
                            .accessibilityHidden(true)
                        Text("Cancel Run")
                            .font(DesignSystem.Typography.buttonSmall)
                            .dynamicTypeSupport(minSize: 12, maxSize: 20)
                    }
                }
                .buttonStyle(DestructiveButtonStyle())
                .accessibilityLabel("Cancel run")
                .accessibilityHint("Cancel the run execution and return to dashboard")
                .accessibilityIdentifier("CancelRunButton")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Execution controls")
        .accessibilityHint("Controls for managing run execution")
    }
}

// MARK: - Preview

#Preview("Run Execution - Start") {
    SchoolRunPreviewProvider.previewWithSampleData {
        RunExecutionView(run: SchoolRunPreviewProvider.executionRunStart)
    }
}

#Preview("Run Execution - Mid Progress") {
    SchoolRunPreviewProvider.previewWithSampleData {
        RunExecutionView(run: SchoolRunPreviewProvider.executionRunMidway)
            .onAppear {
                // Simulate mid-progress state - would set currentStopIndex = 2
            }
    }
}

#Preview("Run Execution - Near End") {
    SchoolRunPreviewProvider.previewWithSampleData {
        RunExecutionView(run: SchoolRunPreviewProvider.executionRunNearEnd)
            .onAppear {
                // Simulate near-end state - would set currentStopIndex = 3
            }
    }
}

#Preview("Run Execution - Dark Mode") {
    SchoolRunPreviewProvider.previewWithSampleData {
        RunExecutionView(run: SchoolRunPreviewProvider.executionRunStart)
    }
    .preferredColorScheme(.dark)
}

#Preview("Run Execution - Large Text") {
    SchoolRunPreviewProvider.previewWithSampleData {
        RunExecutionView(run: SchoolRunPreviewProvider.executionRunStart)
    }
    .environment(\.dynamicTypeSize, .accessibility1)
}

#Preview("Run Execution - High Contrast") {
    SchoolRunPreviewProvider.previewWithSampleData {
        RunExecutionView(run: SchoolRunPreviewProvider.executionRunStart)
    }

}

#Preview("Run Execution - Reduced Motion") {
    SchoolRunPreviewProvider.previewWithSampleData {
        RunExecutionView(run: SchoolRunPreviewProvider.executionRunStart)
    }

}

#Preview("Run Execution - Interactive") {
    SchoolRunPreviewProvider.previewWithSampleData {
        RunExecutionView(run: SchoolRunPreviewProvider.executionRunStart)
    }
    .previewDisplayName("Interactive Execution")
}