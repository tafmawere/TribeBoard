import SwiftUI

/// Performance-optimized version of RunCard with lazy loading and efficient rendering
struct OptimizedRunCard: View {
    let run: SchoolRun
    let onTap: () -> Void
    let onStart: (() -> Void)?
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?
    
    @State private var showingActionSheet = false
    @State private var isVisible = false
    
    // Memoized computed properties for performance
    private let pickupCount: Int
    private let dropoffCount: Int
    private let formattedDate: String
    private let formattedDuration: String
    private let statusColor: Color
    private let statusIcon: String
    
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
        
        // Pre-compute expensive operations
        self.pickupCount = run.route.filter { $0.type == .pickup }.count
        self.dropoffCount = run.route.filter { $0.type == .dropoff }.count
        self.formattedDate = run.formattedDate
        self.formattedDuration = run.formattedDuration
        self.statusColor = run.status.color
        self.statusIcon = run.status.icon
    }
    
    var body: some View {
        Button(action: onTap) {
            cardContent
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
            actionSheetContent
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
        .onAppear {
            isVisible = true
            // Announce when new runs appear (throttled for performance)
            if run.status == .scheduled && !isVisible {
                EnhancedAccessibility.announce("New school run scheduled: \(run.title)")
            }
        }
        .onDisappear {
            isVisible = false
        }
    }
    
    // MARK: - Card Content
    
    @ViewBuilder
    private var cardContent: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Status indicator (simplified for performance)
            statusIndicator
            
            // Run details
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                titleAndDateRow
                
                // Progress indicator (only if in progress)
                if run.status == .inProgress {
                    progressSection
                }
                
                routeSummaryRow
                statusRow
            }
            
            // Action buttons (lazy loaded)
            if isVisible {
                actionButtons
            }
        }
        .cardPadding()
    }
    
    // MARK: - Sub-components
    
    private var statusIndicator: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: statusIcon)
                .font(DesignSystem.Typography.titleMedium)
                .foregroundColor(statusColor)
            
            Rectangle()
                .fill(statusColor)
                .frame(width: 4, height: 40)
                .cornerRadius(2)
        }
    }
    
    private var titleAndDateRow: some View {
        HStack {
            Text(run.title)
                .titleMedium()
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(2) // Limit lines for performance
            
            Spacer()
            
            Text(formattedDate)
                .captionLarge()
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private var progressSection: some View {
        ProgressView(value: run.progress)
            .progressViewStyle(LinearProgressViewStyle(tint: statusColor))
            .scaleEffect(y: 0.8)
        
        Text("\(run.completedStops) of \(run.totalStops) stops completed")
            .captionMedium()
            .foregroundColor(.secondary)
    }
    
    private var routeSummaryRow: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Pickup count (pre-computed)
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: RunStop.StopType.pickup.icon)
                    .font(DesignSystem.Typography.captionLarge)
                    .foregroundColor(RunStop.StopType.pickup.color)
                
                Text("\(pickupCount)")
                    .captionLarge()
                    .foregroundColor(.secondary)
            }
            
            // Drop-off count (pre-computed)
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: RunStop.StopType.dropoff.icon)
                    .font(DesignSystem.Typography.captionLarge)
                    .foregroundColor(RunStop.StopType.dropoff.color)
                
                Text("\(dropoffCount)")
                    .captionLarge()
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Duration (pre-computed)
            if run.estimatedDuration > 0 {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "clock")
                        .font(DesignSystem.Typography.captionLarge)
                        .foregroundColor(.secondary)
                    
                    Text(formattedDuration)
                        .captionLarge()
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var statusRow: some View {
        HStack {
            RunStatusBadge(status: run.status)
            
            Spacer()
            
            // Next stop info (only if in progress and visible)
            if run.status == .inProgress, let nextStop = run.nextStop, isVisible {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text("Next:")
                        .captionMedium()
                        .foregroundColor(.secondary)
                    
                    Text(nextStop.name)
                        .captionMedium()
                        .foregroundColor(.primary)
                        .fontWeight(.medium)
                        .lineLimit(1) // Prevent overflow
                }
            }
        }
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Primary action button
            if let onStart = onStart, run.status.canStart {
                Button(action: {
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
    
    @ViewBuilder
    private var actionSheetContent: some View {
        if let onEdit = onEdit, run.status.canEdit {
            Button("Edit Run") {
                SchoolRunHapticFeedback.navigationAction()
                onEdit()
            }
        }
        
        if let onDelete = onDelete, run.status.canDelete {
            Button("Delete Run", role: .destructive) {
                SchoolRunHapticFeedback.destructiveAction()
                onDelete()
            }
        }
        
        Button("Cancel", role: .cancel) { 
            SchoolRunHapticFeedback.navigationAction()
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

#Preview("Optimized Run Card") {
    let mockRun = SchoolRun(
        title: "Morning School Run",
        date: Date(),
        route: [
            RunStop(name: "Home", time: Date(), type: .pickup, task: "Start run", estimatedMinutes: 5),
            RunStop(name: "Emma's House", time: Date().addingTimeInterval(300), type: .pickup, task: "Pick up Emma", estimatedMinutes: 5),
            RunStop(name: "Greenwood Elementary", time: Date().addingTimeInterval(900), type: .dropoff, task: "Drop off at school", estimatedMinutes: 10)
        ],
        status: .scheduled,
        estimatedDuration: 1800
    )
    
    return OptimizedRunCard(
        run: mockRun,
        onTap: { print("Tapped run: \(mockRun.title)") },
        onStart: { print("Start run: \(mockRun.title)") },
        onEdit: { print("Edit run: \(mockRun.title)") },
        onDelete: { print("Delete run: \(mockRun.title)") }
    )
    .screenPadding()
}