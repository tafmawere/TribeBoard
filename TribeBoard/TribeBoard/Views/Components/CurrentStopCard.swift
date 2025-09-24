import SwiftUI

/// Prominent card component for execution mode showing current stop details and tasks
struct CurrentStopCard: View {
    let stopNumber: Int
    let totalStops: Int
    let stop: RunStop
    let isActive: Bool
    
    // Accessibility environment values
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    init(stopNumber: Int, totalStops: Int, stop: RunStop, isActive: Bool = true) {
        self.stopNumber = stopNumber
        self.totalStops = totalStops
        self.stop = stop
        self.isActive = isActive
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Header with stop progress
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Stop \(stopNumber) of \(totalStops)")
                        .labelLarge()
                        .foregroundColor(colorSchemeContrast == .increased ? .blue : .brandPrimary)
                        .fontWeight(.semibold)
                        .dynamicTypeSupport(minSize: 14, maxSize: 28)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text(progressText)
                        .captionMedium()
                        .foregroundColor(.secondary)
                        .dynamicTypeSupport(minSize: 10, maxSize: 20)
                }
                
                Spacer()
                
                // Status indicator
                statusIndicator
            }
            
            // Location information
            HStack(spacing: DesignSystem.Spacing.md) {
                // Location icon
                ZStack {
                    Circle()
                        .fill(Color.brandPrimary.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Text(stop.type.icon)
                        .font(.title2)
                        .accessibilityHidden(true)
                }
                
                // Location details
                VStack(alignment: .leading, spacing: 4) {
                    Text(stop.name)
                        .titleLarge()
                        .foregroundColor(.primary)
                        .fontWeight(.semibold)
                        .dynamicTypeSupport(minSize: 16, maxSize: 32)
                    
                    Text(stop.type.rawValue)
                        .bodyMedium()
                        .foregroundColor(.secondary)
                        .dynamicTypeSupport(minSize: 12, maxSize: 24)
                }
                
                Spacer()
                
                // Duration badge
                durationBadge
            }
            
            // Task information
            if !stop.task.isEmpty {
                taskSection
            }
            
            // Assigned child information
            if let assignedChild = stop.assignedChild {
                assignedChildSection(child: assignedChild)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(cardBackgroundColor)
                .mediumShadow()
        )
        .overlay(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .stroke(borderColor, lineWidth: isActive ? 2 : 0)
        )
        .scaleEffect(isActive ? 1.0 : 0.95)
        .animation(reduceMotion ? nil : .spring(response: 0.3), value: isActive)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(isActive ? [.isSelected] : [])
        .accessibilityIdentifier("CurrentStopCard_\(stopNumber)")
    }
    
    // MARK: - Status Indicator
    
    private var statusIndicator: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.2))
                .frame(width: 32, height: 32)
            
            Image(systemName: statusIcon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(statusColor)
        }
    }
    
    // MARK: - Duration Badge
    
    private var durationBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.caption)
            Text(stop.formattedDuration)
                .captionLarge()
        }
        .foregroundColor(.brandSecondary)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                .fill(Color.brandSecondary.opacity(0.1))
        )
    }
    
    // MARK: - Task Section
    
    private var taskSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.brandPrimary)
                    .font(.callout)
                
                Text("Task")
                    .labelMedium()
                    .foregroundColor(.secondary)
                
                Spacer()
            }
            
            Text(stop.task)
                .bodyLarge()
                .foregroundColor(.primary)
                .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Assigned Child Section
    
    private func assignedChildSection(child: ChildProfile) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Child avatar
            ZStack {
                Circle()
                    .fill(LinearGradient.brandGradientSubtle)
                    .frame(width: 40, height: 40)
                
                Image(systemName: "person.fill")
                    .font(.title3)
                    .foregroundColor(.brandPrimary)
            }
            
            // Child information
            VStack(alignment: .leading, spacing: 2) {
                Text(child.name)
                    .bodyLarge()
                    .foregroundColor(.primary)
                    .fontWeight(.medium)
                
                Text("Age \(child.age) • \(child.ageGroup)")
                    .captionLarge()
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Assignment indicator
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.title3)
                .foregroundColor(.green)
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                .fill(Color.green.opacity(0.05))
        )
    }
    
    // MARK: - Computed Properties
    
    private var progressText: String {
        let percentage = Int((Double(stopNumber) / Double(totalStops)) * 100)
        return "\(percentage)% complete"
    }
    
    private var cardBackgroundColor: Color {
        if isActive {
            return Color(.systemBackground)
        } else {
            return Color(.systemGray6)
        }
    }
    
    private var borderColor: Color {
        if isActive {
            return Color.brandPrimary
        } else {
            return Color.clear
        }
    }
    
    private var statusColor: Color {
        if stop.isCompleted {
            return .green
        } else if isActive {
            return .brandPrimary
        } else {
            return .gray
        }
    }
    
    private var statusIcon: String {
        if stop.isCompleted {
            return "checkmark"
        } else if isActive {
            return "location.fill"
        } else {
            return "clock"
        }
    }
    
    // MARK: - Accessibility Properties
    
    private var accessibilityLabel: String {
        let status = stop.isCompleted ? "Completed" : (isActive ? "Current" : "Upcoming")
        return "\(status) stop \(stopNumber) of \(totalStops): \(stop.name)"
    }
    
    private var accessibilityHint: String {
        if stop.isCompleted {
            return "This stop has been completed"
        } else if isActive {
            return "This is the current active stop"
        } else {
            return "This stop is upcoming"
        }
    }
    
    private var accessibilityValue: String {
        var components: [String] = []
        
        components.append("Location: \(stop.name), \(stop.type.rawValue)")
        components.append("Duration: \(stop.formattedDuration)")
        
        if !stop.task.isEmpty {
            components.append("Task: \(stop.task)")
        }
        
        if let assignedChild = stop.assignedChild {
            components.append("Assigned to: \(assignedChild.name)")
        }
        
        components.append(progressText)
        
        return components.joined(separator: ", ")
    }
}

// MARK: - Compact Variant

extension CurrentStopCard {
    /// Compact version for smaller spaces
    static func compact(stopNumber: Int, totalStops: Int, stop: RunStop) -> some View {
        CompactCurrentStopCard(stopNumber: stopNumber, totalStops: totalStops, stop: stop)
    }
}

private struct CompactCurrentStopCard: View {
    let stopNumber: Int
    let totalStops: Int
    let stop: RunStop
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Location icon
            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.1))
                    .frame(width: 36, height: 36)
                
                Text(stop.type.icon)
                    .font(.title3)
            }
            
            // Stop information
            VStack(alignment: .leading, spacing: 2) {
                Text("Stop \(stopNumber) of \(totalStops)")
                    .captionLarge()
                    .foregroundColor(.brandPrimary)
                    .fontWeight(.semibold)
                
                Text(stop.name)
                    .bodyMedium()
                    .foregroundColor(.primary)
                    .fontWeight(.medium)
                
                if !stop.task.isEmpty {
                    Text(stop.task)
                        .captionMedium()
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Duration
            Text(stop.formattedDuration)
                .captionLarge()
                .foregroundColor(.brandSecondary)
                .fontWeight(.medium)
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                .fill(Color(.systemBackground))
                .lightShadow()
        )
    }
}

// MARK: - Preview

#Preview("Current Stop Card - Various States") {
    VStack(spacing: DesignSystem.Spacing.xl) {
        // Active stop with child assignment
        CurrentStopCard(
            stopNumber: 3,
            totalStops: 6,
            stop: SchoolRunPreviewProvider.sampleStops[1],
            isActive: true
        )
        
        // Completed stop
        CurrentStopCard(
            stopNumber: 2,
            totalStops: 6,
            stop: RunStop(
                name: "Home",
                type: .home,
                task: "Grab snacks and water bottles",
                estimatedMinutes: 5,
                isCompleted: true
            ),
            isActive: false
        )
        
        // Stop without child assignment
        CurrentStopCard(
            stopNumber: 1,
            totalStops: 6,
            stop: SchoolRunPreviewProvider.sampleStops[0],
            isActive: true
        )
        
        // Compact variant
        CurrentStopCard.compact(
            stopNumber: 4,
            totalStops: 6,
            stop: SchoolRunPreviewProvider.sampleStops[3]
        )
    }
    .screenPadding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Current Stop Card - Dark Mode") {
    VStack(spacing: DesignSystem.Spacing.xl) {
        CurrentStopCard(
            stopNumber: 3,
            totalStops: 6,
            stop: SchoolRunPreviewProvider.sampleStops[1],
            isActive: true
        )
        
        CurrentStopCard(
            stopNumber: 2,
            totalStops: 6,
            stop: SchoolRunPreviewProvider.sampleStops[0],
            isActive: false
        )
    }
    .screenPadding()
    .background(Color(.systemGroupedBackground))
    .preferredColorScheme(.dark)
}

#Preview("Current Stop Card - Large Text") {
    VStack(spacing: DesignSystem.Spacing.xl) {
        CurrentStopCard(
            stopNumber: 1,
            totalStops: 3,
            stop: RunStop(
                name: "Riverside Elementary School",
                type: .school,
                assignedChild: ChildProfile(name: "Emma-Louise", avatar: "person.circle.fill", age: 8),
                task: "Pick up Emma-Louise from her classroom and collect her art project from the teacher. Make sure to check with the office about the field trip permission slip.",
                estimatedMinutes: 15
            ),
            isActive: true
        )
    }
    .screenPadding()
    .background(Color(.systemGroupedBackground))
    .environment(\.dynamicTypeSize, .accessibility1)
}

#Preview("Current Stop Card - High Contrast") {
    VStack(spacing: DesignSystem.Spacing.xl) {
        CurrentStopCard(
            stopNumber: 3,
            totalStops: 6,
            stop: SchoolRunPreviewProvider.sampleStops[1],
            isActive: true
        )
    }
    .screenPadding()
    .background(Color(.systemGroupedBackground))

}

#Preview("Current Stop Card - Reduced Motion") {
    VStack(spacing: DesignSystem.Spacing.xl) {
        CurrentStopCard(
            stopNumber: 3,
            totalStops: 6,
            stop: SchoolRunPreviewProvider.sampleStops[1],
            isActive: true
        )
    }
    .screenPadding()
    .background(Color(.systemGroupedBackground))

}

#Preview("Current Stop Card - Interactive") {
    VStack(spacing: DesignSystem.Spacing.xl) {
        CurrentStopCard(
            stopNumber: 3,
            totalStops: 6,
            stop: SchoolRunPreviewProvider.sampleStops[1],
            isActive: true
        )
    }
    .screenPadding()
    .background(Color(.systemGroupedBackground))
    .previewDisplayName("Interactive Stop Card")
}