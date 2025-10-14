import SwiftUI

/// Performance-optimized version of HistoryRunCard with lazy loading and efficient rendering
struct OptimizedHistoryRunCard: View {
    let run: SchoolRun
    let onTap: () -> Void
    
    @State private var isVisible = false
    @State private var showFullRoute = false
    
    // Pre-computed properties for performance
    private let formattedDate: String
    private let formattedDuration: String
    private let totalStops: Int
    private let routePreview: [RunStop]
    private let hasMoreStops: Bool
    
    init(run: SchoolRun, onTap: @escaping () -> Void) {
        self.run = run
        self.onTap = onTap
        
        // Pre-compute expensive operations
        self.formattedDate = run.formattedDate
        self.formattedDuration = run.formattedDuration
        self.totalStops = run.route.count
        self.routePreview = Array(run.route.prefix(3))
        self.hasMoreStops = run.route.count > 3
    }
    
    var body: some View {
        Button(action: onTap) {
            cardContent
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .lightShadow()
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Historical run: \(run.title)")
        .accessibilityHint("Tap to view run details")
        .accessibilityValue("\(run.status.displayText), \(totalStops) stops")
        .onAppear {
            isVisible = true
        }
        .onDisappear {
            isVisible = false
        }
    }
    
    // MARK: - Card Content
    
    @ViewBuilder
    private var cardContent: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            headerSection
            routeSummarySection
            
            // Route details (lazy loaded when visible)
            if isVisible && !run.route.isEmpty {
                routeDetailsSection
            }
        }
        .cardPadding()
    }
    
    // MARK: - Sub-components
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(run.title)
                    .font(DesignSystem.Typography.titleMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2) // Limit lines for performance
                
                Text(formattedDate)
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            RunStatusBadge(status: run.status)
        }
    }
    
    private var routeSummarySection: some View {
        HStack {
            Image(systemName: "location.fill")
                .font(DesignSystem.Typography.labelMedium)
                .foregroundColor(.brandPrimary)
            
            Text("\(totalStops) stops")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Duration (pre-computed)
            if run.estimatedDuration > 0 {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "clock")
                        .font(DesignSystem.Typography.captionLarge)
                        .foregroundColor(.secondary)
                    
                    Text(formattedDuration)
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    @ViewBuilder
    private var routeDetailsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack {
                Text("Route")
                    .font(DesignSystem.Typography.labelMedium)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Toggle button for full route (if more than 3 stops)
                if hasMoreStops {
                    Button(showFullRoute ? "Show Less" : "Show All") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showFullRoute.toggle()
                        }
                    }
                    .font(DesignSystem.Typography.captionLarge)
                    .foregroundColor(.brandPrimary)
                }
            }
            
            // Route stops (optimized rendering)
            let stopsToShow = showFullRoute ? run.route : routePreview
            
            ForEach(stopsToShow) { stop in
                OptimizedStopRow(stop: stop)
            }
            
            // "More stops" indicator (if not showing full route)
            if hasMoreStops && !showFullRoute {
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

// MARK: - Optimized Stop Row Component

/// Performance-optimized stop row component
struct OptimizedStopRow: View {
    let stop: RunStop
    
    // Pre-computed properties
    private let formattedTime: String
    private let typeIcon: String
    private let typeColor: Color
    
    init(stop: RunStop) {
        self.stop = stop
        self.formattedTime = stop.formattedTime
        self.typeIcon = stop.type.icon
        self.typeColor = stop.type.color
    }
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: typeIcon)
                .font(DesignSystem.Typography.captionLarge)
                .foregroundColor(typeColor)
                .frame(width: 16)
            
            Text(stop.name)
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(.primary)
                .lineLimit(1) // Prevent overflow
            
            Spacer()
            
            Text(formattedTime)
                .font(DesignSystem.Typography.captionLarge)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

#Preview("Optimized History Run Card") {
    let mockRun = SchoolRun(
        title: "Morning School Run",
        date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
        route: [
            RunStop(name: "Home", time: Date(), type: .pickup, isCompleted: true),
            RunStop(name: "Emma's House", time: Date().addingTimeInterval(300), type: .pickup, isCompleted: true),
            RunStop(name: "Greenwood Elementary", time: Date().addingTimeInterval(900), type: .dropoff, isCompleted: true),
            RunStop(name: "Soccer Field", time: Date().addingTimeInterval(1200), type: .dropoff, isCompleted: true),
            RunStop(name: "Library", time: Date().addingTimeInterval(1500), type: .dropoff, isCompleted: true)
        ],
        status: .completed,
        estimatedDuration: 1800
    )
    
    return OptimizedHistoryRunCard(
        run: mockRun,
        onTap: { print("Tapped run: \(mockRun.title)") }
    )
    .screenPadding()
}