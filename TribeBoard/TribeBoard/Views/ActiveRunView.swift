import SwiftUI

/// View for live school run execution with map display and stop navigation
/// 
/// This view provides the interface for executing an active school run, including:
/// - Map placeholder view showing current location and route
/// - Current stop information with name, type, and ETA
/// - Action buttons for "Next Stop" and "End Run"
/// - Run progress indicator and remaining stops count
/// - Pause/resume controls for run management
/// - Haptic feedback integration for all interactions
///
/// Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 7.2, 7.3
struct ActiveRunView: View {
    @StateObject private var viewModel = ActiveRunViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if let currentRun = viewModel.currentRun {
                    // Main content
                    ScrollView {
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            // Map placeholder section
                            mapSection
                            
                            // Current stop information
                            currentStopSection
                            
                            // Progress indicator
                            progressSection
                            
                            // Action buttons
                            actionButtonsSection
                            
                            // Run controls (pause/resume)
                            runControlsSection
                            
                            // Remaining stops preview
                            remainingStopsSection
                        }
                        .screenPadding()
                    }
                } else {
                    // No active run state
                    noActiveRunView
                }
                
                // Loading overlay
                if viewModel.isLoading {
                    loadingOverlay
                }
            }
        }
        .navigationTitle("Active Run")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Close") {
                    // Haptic feedback for navigation actions (respects accessibility settings)
                    SchoolRunHapticFeedback.navigationAction()
                    dismiss()
                }
                .buttonStyle(TertiaryButtonStyle(hapticStyle: .light))
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.canCancel {
                    Button("Cancel Run") {
                        // Haptic feedback for destructive actions (respects accessibility settings)
                        SchoolRunHapticFeedback.destructiveAction()
                        Task {
                            await viewModel.cancelRun()
                        }
                    }
                    .buttonStyle(TertiaryButtonStyle(hapticStyle: .warning))
                    .foregroundColor(.red)
                }
            }
        }
        .alert("Complete Run", isPresented: $viewModel.showingCompletionConfirmation) {
            Button("Complete", role: .destructive) {
                // Haptic feedback for run completion (respects accessibility settings)
                SchoolRunHapticFeedback.runCompleted()
                Task {
                    await viewModel.confirmCompleteRun()
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) { 
                // Haptic feedback for navigation actions (respects accessibility settings)
                SchoolRunHapticFeedback.navigationAction()
            }
        } message: {
            Text("Are you sure you want to complete this run? This action cannot be undone.")
        }
        .alert("Cancel Run", isPresented: $viewModel.showingCancellationConfirmation) {
            Button("Cancel Run", role: .destructive) {
                // Haptic feedback for destructive actions (respects accessibility settings)
                SchoolRunHapticFeedback.destructiveAction()
                Task {
                    await viewModel.confirmCancelRun()
                    dismiss()
                }
            }
            Button("Keep Running", role: .cancel) { 
                // Haptic feedback for navigation actions (respects accessibility settings)
                SchoolRunHapticFeedback.navigationAction()
            }
        } message: {
            Text("Are you sure you want to cancel this run? All progress will be lost.")
        }
        .onAppear {
            Task {
                await viewModel.loadActiveRun()
            }
        }
        .accessibilityIdentifier("ActiveRunView")
        // Enhanced accessibility support
        .dynamicTypeSupport()
        .preferredColorScheme(.light)
        // Add rotor support for stops
        .stopsRotor(stops: viewModel.remainingStops) { stop in
            // Focus on the selected stop
            EnhancedAccessibility.announce("Selected stop: \(stop.name)")
        }
        // Announce status changes
        .onChange(of: viewModel.currentRun?.status) { _, newStatus in
            if let status = newStatus, let run = viewModel.currentRun {
                EnhancedAccessibility.announceRunStatusChange(run, newStatus: status)
            }
        }
    }
    
    // MARK: - Map Section
    
    private var mapSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Route Map")
                    .titleMedium()
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let currentStop = viewModel.currentStop {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(.brandPrimary)
                        
                        Text("At \(currentStop.name)")
                            .captionLarge()
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Map placeholder using existing pattern
            SchoolRunMapPlaceholder(
                currentStop: viewModel.currentStop,
                showCurrentLocation: true,
                mapStyle: .execution
            )
            .frame(height: 250)
            .accessibilityLabel("Route map showing current location and stops")
            .accessibilityHint("Visual representation of the school run route")
            .accessibilityAddTraits([.isImage])
            .dynamicTypeSupport()
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .mediumShadow()
        )
    }
    
    // MARK: - Current Stop Section
    
    private var currentStopSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Current Stop")
                    .titleMedium()
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(viewModel.completedStopsCount + 1) of \(viewModel.totalStopsCount)")
                    .captionLarge()
                    .foregroundColor(.secondary)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                            .fill(Color(.systemGray6))
                    )
            }
            
            if let currentStop = viewModel.currentStop {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    // Stop name and type
                    HStack(spacing: DesignSystem.Spacing.md) {
                        // Stop type icon
                        Image(systemName: currentStop.type.icon)
                            .font(.title2)
                            .foregroundColor(currentStop.type.color)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(currentStop.type.color.opacity(0.1))
                            )
                        
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text(currentStop.name)
                                .titleLarge()
                                .foregroundColor(.primary)
                            
                            Text(currentStop.type.displayName)
                                .bodyMedium()
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // ETA display
                        VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
                            Text("ETA")
                                .captionLarge()
                                .foregroundColor(.secondary)
                            
                            Text(currentStop.formattedTime)
                                .titleMedium()
                                .foregroundColor(.brandPrimary)
                        }
                    }
                    
                    // Stop note (if available)
                    if !currentStop.note.isEmpty {
                        Text(currentStop.note)
                            .bodySmall()
                            .foregroundColor(.secondary)
                            .padding(.top, DesignSystem.Spacing.xs)
                    }
                    
                    // Next stop preview (if available)
                    if let nextStop = viewModel.nextStop {
                        Divider()
                            .padding(.vertical, DesignSystem.Spacing.xs)
                        
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Text("Next:")
                                .captionLarge()
                                .foregroundColor(.secondary)
                            
                            Image(systemName: nextStop.type.icon)
                                .font(.caption)
                                .foregroundColor(nextStop.type.color)
                            
                            Text(nextStop.name)
                                .captionLarge()
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(nextStop.formattedTime)
                                .captionLarge()
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                // No current stop (run completed or error state)
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                    
                    Text("All stops completed!")
                        .titleMedium()
                        .foregroundColor(.primary)
                }
            }
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .mediumShadow()
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(currentStopAccessibilityLabel)
        .accessibilityHint("Current stop information and next stop preview")
    }
    
    // MARK: - Progress Section
    
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Progress")
                    .titleMedium()
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(viewModel.progressPercentage)% Complete")
                    .bodyMedium()
                    .foregroundColor(.brandPrimary)
                    .fontWeight(.semibold)
            }
            
            // Progress bar
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                ProgressView(value: viewModel.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .brandPrimary))
                    .scaleEffect(y: 2.0) // Make progress bar thicker
                
                HStack {
                    Text("\(viewModel.completedStopsCount) completed")
                        .captionLarge()
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(viewModel.remainingStopsCount) remaining")
                        .captionLarge()
                        .foregroundColor(.secondary)
                }
            }
            
            // Time remaining estimate
            HStack {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Estimated time remaining: \(viewModel.formattedTimeRemaining)")
                    .captionLarge()
                    .foregroundColor(.secondary)
            }
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .mediumShadow()
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Run progress: \(viewModel.progressPercentage) percent complete")
        .accessibilityValue("\(viewModel.completedStopsCount) stops completed, \(viewModel.remainingStopsCount) remaining")
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        QuickActionButtons.activeRunActions(
            onNextStop: {
                Task {
                    await viewModel.moveToNextStop()
                }
            },
            onPause: {
                Task {
                    await viewModel.pauseRun()
                }
            },
            onEndRun: {
                Task {
                    await viewModel.completeRun()
                }
            },
            canPause: viewModel.isRunning && !viewModel.isLoading,
            canEnd: viewModel.canComplete && !viewModel.isLoading
        )
    }
    
    // MARK: - Run Controls Section
    
    private var runControlsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Run Controls")
                .titleMedium()
                .foregroundColor(.primary)
            
            HStack(spacing: DesignSystem.Spacing.md) {
                if viewModel.canPause {
                    // Pause button
                    Button(action: {
                        Task {
                            await viewModel.pauseRun()
                        }
                    }) {
                        HStack {
                            Image(systemName: "pause.circle.fill")
                                .font(.title3)
                            
                            Text("Pause")
                                .fontWeight(.medium)
                        }
                    }
                    .buttonStyle(TertiaryButtonStyle(hapticStyle: .light))
                    .disabled(viewModel.isLoading)
                }
                
                if viewModel.canResume {
                    // Resume button
                    Button(action: {
                        Task {
                            await viewModel.resumeRun()
                        }
                    }) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .font(.title3)
                            
                            Text("Resume")
                                .fontWeight(.medium)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle(hapticStyle: .medium))
                    .disabled(viewModel.isLoading)
                }
                
                Spacer()
                
                // Run status indicator
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Circle()
                        .fill(runStatusColor)
                        .frame(width: 8, height: 8)
                    
                    Text(runStatusText)
                        .captionLarge()
                        .foregroundColor(.secondary)
                }
            }
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .mediumShadow()
        )
    }
    
    // MARK: - Remaining Stops Section
    
    private var remainingStopsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Remaining Stops")
                    .titleMedium()
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(viewModel.remainingStopsCount)")
                    .captionLarge()
                    .foregroundColor(.secondary)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                            .fill(Color(.systemGray6))
                    )
            }
            
            if !viewModel.remainingStops.isEmpty {
                LazyVStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(Array(viewModel.remainingStops.enumerated()), id: \.element.id) { index, stop in
                        remainingStopRow(stop: stop, index: index)
                    }
                }
            } else {
                // No remaining stops
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.green)
                    
                    Text("No more stops remaining")
                        .bodyMedium()
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, DesignSystem.Spacing.md)
            }
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .mediumShadow()
        )
    }
    
    private func remainingStopRow(stop: RunStop, index: Int) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Stop number
            Text("\(viewModel.currentStopIndex + index + 2)")
                .captionLarge()
                .foregroundColor(.secondary)
                .frame(width: 20, alignment: .leading)
            
            // Use the new CompactStopRow component
            CompactStopRow(stop: stop)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Stop \(viewModel.currentStopIndex + index + 2): \(stop.name), \(stop.type.displayName) at \(stop.formattedTime)")
    }
    
    // MARK: - No Active Run View
    
    private var noActiveRunView: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Image(systemName: "car.circle")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: DesignSystem.Spacing.md) {
                Text("No Active Run")
                    .titleLarge()
                    .foregroundColor(.primary)
                
                Text("There is no school run currently in progress. Start a run from the main School Run view to begin tracking.")
                    .bodyMedium()
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Go to School Runs") {
                // Haptic feedback for navigation actions (respects accessibility settings)
                SchoolRunHapticFeedback.navigationAction()
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle(hapticStyle: .light))
        }
        .screenPadding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No active run. Go to School Runs to start a new run.")
    }
    
    // MARK: - Loading Overlay
    
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: DesignSystem.Spacing.md) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .brandPrimary))
                    .scaleEffect(1.2)
                
                Text("Updating run...")
                    .bodyMedium()
                    .foregroundColor(.primary)
            }
            .padding(DesignSystem.Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                    .fill(Color(.systemBackground))
                    .mediumShadow()
            )
        }
    }
    
    // MARK: - Computed Properties
    
    private var currentStopAccessibilityLabel: String {
        if let currentStop = viewModel.currentStop {
            var label = "Current stop: \(currentStop.name), \(currentStop.type.displayName) at \(currentStop.formattedTime)"
            
            if let nextStop = viewModel.nextStop {
                label += ". Next stop: \(nextStop.name) at \(nextStop.formattedTime)"
            }
            
            return label
        } else {
            return "All stops completed"
        }
    }
    
    private var runStatusColor: Color {
        if viewModel.isPaused {
            return .orange
        } else if viewModel.isRunning {
            return .green
        } else {
            return .secondary
        }
    }
    
    private var runStatusText: String {
        if viewModel.isPaused {
            return "Paused"
        } else if viewModel.isRunning {
            return "Running"
        } else {
            return "Stopped"
        }
    }
}

// MARK: - Preview

#Preview("Active Run View - In Progress") {
    NavigationView {
        ActiveRunView()
    }
    .environmentObject(ActiveRunViewModel.preview(with: SchoolRunPreviewProvider.sampleRuns[0]))
}

#Preview("Active Run View - Last Stop") {
    let run = SchoolRunPreviewProvider.sampleRuns[0]
    let viewModel = ActiveRunViewModel.preview(with: run)
    viewModel.currentStopIndex = run.route.count - 1
    
    return NavigationView {
        ActiveRunView()
    }
    .environmentObject(viewModel)
}

#Preview("Active Run View - No Active Run") {
    NavigationView {
        ActiveRunView()
    }
    .environmentObject(ActiveRunViewModel.preview(with: nil))
}

#Preview("Active Run View - Paused") {
    let run = SchoolRunPreviewProvider.sampleRuns[1]
    let viewModel = ActiveRunViewModel.preview(with: run)
    viewModel.isPaused = true
    viewModel.isRunning = false
    
    return NavigationView {
        ActiveRunView()
    }
    .environmentObject(viewModel)
}

#Preview("Active Run View - Dark Mode") {
    NavigationView {
        ActiveRunView()
    }
    .environmentObject(ActiveRunViewModel.preview(with: SchoolRunPreviewProvider.sampleRuns[0]))
    .preferredColorScheme(.dark)
}

#Preview("Active Run View - Accessibility") {
    NavigationView {
        ActiveRunView()
    }
    .environmentObject(ActiveRunViewModel.preview(with: SchoolRunPreviewProvider.sampleRuns[0]))
    .environment(\.dynamicTypeSize, .accessibility3)
}