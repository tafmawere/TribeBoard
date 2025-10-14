import SwiftUI

/// Detailed view for displaying comprehensive information about a specific school run
struct RunDetailView: View {
    let run: SchoolRun
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: DesignSystem.Spacing.xl) {
                    // Header section
                    runHeaderSection
                    
                    // Route details section
                    routeDetailsSection
                    
                    // Run statistics section
                    runStatisticsSection
                    
                    // Additional information section
                    if !run.route.allSatisfy({ $0.note.isEmpty }) {
                        notesSection
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Run Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Run details for \(run.title)")
    }
    
    // MARK: - Section Views
    
    private var runHeaderSection: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Title and status
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text(run.title)
                    .font(DesignSystem.Typography.headlineMedium)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                
                RunStatusBadge(status: run.status)
            }
            
            // Date and time information
            VStack(spacing: DesignSystem.Spacing.md) {
                InfoRow(
                    icon: "calendar",
                    title: "Date",
                    value: run.formattedDate,
                    color: .brandPrimary
                )
                
                InfoRow(
                    icon: "clock",
                    title: "Duration",
                    value: run.formattedDuration,
                    color: .blue
                )
                
                InfoRow(
                    icon: "location.fill",
                    title: "Total Stops",
                    value: "\(run.totalStops)",
                    color: .green
                )
                
                if run.status == .completed {
                    InfoRow(
                        icon: "checkmark.circle.fill",
                        title: "Completed Stops",
                        value: "\(run.completedStops)",
                        color: .green
                    )
                }
            }
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .mediumShadow()
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Run header information")
    }
    
    private var routeDetailsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader(title: "Route Details", icon: "map.fill")
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(Array(run.route.enumerated()), id: \.element.id) { index, stop in
                    RouteStopDetailCard(
                        stop: stop,
                        stopNumber: index + 1,
                        isCompleted: stop.isCompleted || run.status == .completed
                    )
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Route details section")
    }
    
    private var runStatisticsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader(title: "Statistics", icon: "chart.bar.fill")
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DesignSystem.Spacing.md) {
                StatCard(
                    title: "Pickup Stops",
                    value: "\(run.pickupStops.count)",
                    icon: "arrow.up.circle.fill",
                    color: .blue
                )
                
                StatCard(
                    title: "Drop-off Stops",
                    value: "\(run.dropoffStops.count)",
                    icon: "arrow.down.circle.fill",
                    color: .orange
                )
                
                StatCard(
                    title: "Created",
                    value: run.formattedCreatedDate,
                    icon: "plus.circle.fill",
                    color: .green
                )
                
                if run.status == .completed {
                    StatCard(
                        title: "Completion Rate",
                        value: "\(Int(run.progress * 100))%",
                        icon: "percent",
                        color: .brandPrimary
                    )
                }
            }
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .lightShadow()
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Run statistics section")
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            sectionHeader(title: "Notes", icon: "note.text")
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(run.route.filter { !$0.note.isEmpty }) { stop in
                    NoteCard(stop: stop)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Notes section")
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

// MARK: - Info Row Component

/// Component for displaying key-value information with an icon
struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: icon)
                .font(DesignSystem.Typography.labelLarge)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .font(DesignSystem.Typography.bodyMedium)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(DesignSystem.Typography.bodyMedium)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Route Stop Detail Card Component

/// Detailed card component for individual route stops
struct RouteStopDetailCard: View {
    let stop: RunStop
    let stopNumber: Int
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Stop number and completion indicator
            ZStack {
                Circle()
                    .fill(isCompleted ? Color.green : Color(.systemGray4))
                    .frame(width: 32, height: 32)
                
                if isCompleted {
                    Image(systemName: "checkmark")
                        .font(DesignSystem.Typography.labelMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                } else {
                    Text("\(stopNumber)")
                        .font(DesignSystem.Typography.labelMedium)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
            
            // Stop information
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack {
                    Text(stop.name)
                        .font(DesignSystem.Typography.bodyMedium)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text(stop.formattedTime)
                        .font(DesignSystem.Typography.bodySmall)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: stop.type.icon)
                        .font(DesignSystem.Typography.captionLarge)
                        .foregroundColor(stop.type.color)
                    
                    Text(stop.type.displayName)
                        .font(DesignSystem.Typography.captionLarge)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                
                if !stop.note.isEmpty {
                    Text(stop.note)
                        .font(DesignSystem.Typography.captionLarge)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                .fill(Color(.systemBackground))
                .lightShadow()
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Stop \(stopNumber): \(stop.name)")
        .accessibilityValue("\(stop.type.displayName) at \(stop.formattedTime)")
        .accessibilityAddTraits(isCompleted ? [.isSelected] : [])
    }
}

// MARK: - Stat Card Component

/// Small statistic card component
struct StatCard: View {
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

// MARK: - Note Card Component

/// Component for displaying stop notes
struct NoteCard: View {
    let stop: RunStop
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: stop.type.icon)
                    .font(DesignSystem.Typography.labelMedium)
                    .foregroundColor(stop.type.color)
                
                Text(stop.name)
                    .font(DesignSystem.Typography.bodyMedium)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            Text(stop.note)
                .font(DesignSystem.Typography.bodySmall)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                .fill(Color(.systemGray6))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Note for \(stop.name): \(stop.note)")
    }
}

// MARK: - Preview

#Preview("Run Detail View") {
    RunDetailView(run: MockDataGenerator.mockSchoolRuns().first!)
}