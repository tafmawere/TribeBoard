import SwiftUI

/// Reusable card component for displaying school run information
struct RunCard: View {
    let run: SchoolRun
    let onTap: () -> Void
    let onStart: (() -> Void)?
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    
    @State private var showingActionSheet = false
    
    init(
        run: SchoolRun,
        onTap: @escaping () -> Void,
        onStart: (() -> Void)? = nil,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.run = run
        self.onTap = onTap
        self.onStart = onStart
        self.onEdit = onEdit
        self.onDelete = onDelete
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Main card content
                HStack(spacing: DesignSystem.Spacing.md) {
                    // Status indicator
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        // Status icon
                        Image(systemName: run.status.icon)
                            .font(DesignSystem.Typography.titleMedium)
                            .foregroundColor(run.status.color)
                        
                        // Status line indicator
                        Rectangle()
                            .fill(run.status.color)
                            .frame(width: 4, height: 40)
                            .cornerRadius(2)
                    }
                    
                    // Run details
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        // Title and date
                        HStack {
                            Text(run.title)
                                .titleMedium()
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                            
                            Spacer()
                            
                            Text(run.formattedDate)
                                .captionLarge()
                                .foregroundColor(.secondary)
                        }
                        
                        // Progress indicator (if in progress)
                        if run.status == .inProgress {
                            ProgressView(value: run.progress)
                                .progressViewStyle(LinearProgressViewStyle(tint: run.status.color))
                                .scaleEffect(y: 0.8)
                            
                            Text("\(run.completedStops) of \(run.totalStops) stops completed")
                                .captionMedium()
                                .foregroundColor(.secondary)
                        }
                        
                        // Route summary
                        HStack(spacing: DesignSystem.Spacing.md) {
                            // Pickup count
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: RunStop.StopType.pickup.icon)
                                    .font(DesignSystem.Typography.captionLarge)
                                    .foregroundColor(RunStop.StopType.pickup.color)
                                
                                Text("\(run.pickupStops.count)")
                                    .captionLarge()
                                    .foregroundColor(.secondary)
                            }
                            
                            // Drop-off count
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: RunStop.StopType.dropoff.icon)
                                    .font(DesignSystem.Typography.captionLarge)
                                    .foregroundColor(RunStop.StopType.dropoff.color)
                                
                                Text("\(run.dropoffStops.count)")
                                    .captionLarge()
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            // Duration
                            if run.estimatedDuration > 0 {
                                HStack(spacing: DesignSystem.Spacing.xs) {
                                    Image(systemName: "clock")
                                        .font(DesignSystem.Typography.captionLarge)
                                        .foregroundColor(.secondary)
                                    
                                    Text(run.formattedDuration)
                                        .captionLarge()
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        // Status badge
                        HStack {
                            RunStatusBadge(status: run.status)
                            
                            Spacer()
                            
                            // Next stop info (if in progress)
                            if run.status == .inProgress, let nextStop = run.nextStop {
                                HStack(spacing: DesignSystem.Spacing.xs) {
                                    Text("Next:")
                                        .captionMedium()
                                        .foregroundColor(.secondary)
                                    
                                    Text(nextStop.name)
                                        .captionMedium()
                                        .foregroundColor(.primary)
                                        .fontWeight(.medium)
                                }
                            }
                        }
                    }
                    
                    // Action buttons
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        // Primary action button
                        if let onStart = onStart, run.status.canStart {
                            Button(action: {
                                // Haptic feedback for starting a run (respects accessibility settings)
                                SchoolRunHapticFeedback.runStarted()
                                onStart()
                            }) {
                                Image(systemName: "play.circle.fill")
                                    .font(DesignSystem.Typography.titleMedium)
                                    .foregroundColor(.green)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .actionButtonAccessibility(action: "Start run", isEnabled: true)
                            .accessibleTouchTarget()
                        }
                        
                        // More actions button
                        if onEdit != nil || onDelete != nil {
                            Button(action: {
                                // Haptic feedback for navigation actions (respects accessibility settings)
                                SchoolRunHapticFeedback.navigationAction()
                                showingActionSheet = true
                            }) {
                                Image(systemName: "ellipsis.circle")
                                    .font(DesignSystem.Typography.titleMedium)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .actionButtonAccessibility(action: "More actions", isEnabled: true)
                            .accessibleTouchTarget()
                        }
                    }
                }
                .cardPadding()
            }
        }
        .buttonStyle(PlainButtonStyle())
        .background(backgroundColorForRun)
        .cornerRadius(BrandStyle.cornerRadius)
        .mediumShadow()
        .confirmationDialog(
            "Run Actions",
            isPresented: $showingActionSheet,
            titleVisibility: .visible
        ) {
            if let onEdit = onEdit, run.status.canEdit {
                Button("Edit Run") {
                    // Haptic feedback for navigation actions (respects accessibility settings)
                    SchoolRunHapticFeedback.navigationAction()
                    onEdit()
                }
            }
            
            if let onDelete = onDelete, run.status.canDelete {
                Button("Delete Run", role: .destructive) {
                    // Haptic feedback for destructive actions (respects accessibility settings)
                    SchoolRunHapticFeedback.destructiveAction()
                    onDelete()
                }
            }
            
            Button("Cancel", role: .cancel) { 
                // Haptic feedback for navigation actions (respects accessibility settings)
                SchoolRunHapticFeedback.navigationAction()
            }
        } message: {
            Text("Choose an action for '\(run.title)'")
        }
        // Enhanced accessibility support
        .runCardAccessibility(run: run)
        .accessibleTouchTarget()
        .highContrastSupport(
            normalColor: .primary,
            highContrastColor: .primary
        )
        .animation(.easeInOut(duration: 0.2), value: run.status)
        .onAppear {
            // Announce when new runs appear
            if run.status == .scheduled {
                EnhancedAccessibility.announce("New school run scheduled: \(run.title)")
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var backgroundColorForRun: Color {
        switch run.status {
        case .completed:
            return Color.green.opacity(0.05)
        case .cancelled:
            return Color.red.opacity(0.05)
        case .inProgress:
            return Color.orange.opacity(0.05)
        default:
            return Color(.systemBackground)
        }
    }
}

// MARK: - Preview

#Preview("Run Card States") {
    let mockRuns = [
        SchoolRun(
            title: "Morning School Run",
            date: Date(),
            route: [
                RunStop(name: "Home", time: Date(), type: .pickup),
                RunStop(name: "Emma's House", time: Date().addingTimeInterval(300), type: .pickup),
                RunStop(name: "Greenwood Elementary", time: Date().addingTimeInterval(900), type: .dropoff)
            ],
            status: .scheduled,
            estimatedDuration: 1800
        ),
        SchoolRun(
            title: "Afternoon Pickup",
            date: Date(),
            route: [
                RunStop(name: "Greenwood Elementary", time: Date(), type: .pickup, isCompleted: true),
                RunStop(name: "Emma's House", time: Date().addingTimeInterval(600), type: .dropoff),
                RunStop(name: "Home", time: Date().addingTimeInterval(1200), type: .dropoff)
            ],
            status: .inProgress,
            estimatedDuration: 1500
        ),
        SchoolRun(
            title: "Soccer Practice Run",
            date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
            route: [
                RunStop(name: "Home", time: Date(), type: .pickup, isCompleted: true),
                RunStop(name: "Soccer Field", time: Date().addingTimeInterval(900), type: .dropoff, isCompleted: true)
            ],
            status: .completed,
            estimatedDuration: 1200
        )
    ]
    
    return ScrollView {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ForEach(mockRuns) { run in
                RunCard(
                    run: run,
                    onTap: { print("Tapped run: \(run.title)") },
                    onStart: run.status.canStart ? { print("Start run: \(run.title)") } : nil,
                    onEdit: run.status.canEdit ? { print("Edit run: \(run.title)") } : nil,
                    onDelete: run.status.canDelete ? { print("Delete run: \(run.title)") } : nil
                )
            }
        }
        .screenPadding()
    }
}