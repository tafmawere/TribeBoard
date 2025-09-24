import SwiftUI

/// Component showing detailed stop information with stop number, location, assigned child, and tasks
struct StopDetailRow: View {
    let stopNumber: Int
    let totalStops: Int
    let stop: RunStop
    
    // Accessibility environment values
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.lg) {
            // Stop number indicator
            VStack(spacing: DesignSystem.Spacing.xs) {
                ZStack {
                    Circle()
                        .fill(stop.isCompleted ? Color.green : (colorSchemeContrast == .increased ? .blue : .brandPrimary))
                        .frame(width: 32, height: 32)
                    
                    Text("\(stopNumber)")
                        .labelMedium()
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                        .dynamicTypeSupport(minSize: 12, maxSize: 18)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Stop \(stopNumber) of \(totalStops)")
                .accessibilityValue(stop.isCompleted ? "Completed" : "Pending")
                
                if stopNumber < totalStops {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.3))
                        .frame(width: 2, height: 20)
                        .accessibilityHidden(true)
                }
            }
            
            // Stop details
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Location name with icon
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Text(stop.type.icon)
                        .font(.title3)
                        .accessibilityHidden(true)
                    
                    Text(stop.name)
                        .titleMedium()
                        .foregroundColor(.primary)
                        .dynamicTypeSupport(minSize: 14, maxSize: 24)
                    
                    Spacer()
                    
                    // Estimated time
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .accessibilityHidden(true)
                        
                        Text(stop.formattedDuration)
                            .captionLarge()
                            .foregroundColor(.secondary)
                            .dynamicTypeSupport(minSize: 10, maxSize: 16)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Duration: \(stop.formattedDuration)")
                }
                
                // Assigned child (if any)
                if let child = stop.assignedChild {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "person.circle.fill")
                            .font(.caption)
                            .foregroundColor(colorSchemeContrast == .increased ? .blue : .brandPrimary)
                            .accessibilityHidden(true)
                        
                        Text("Assigned to \(child.name)")
                            .bodySmall()
                            .foregroundColor(.secondary)
                            .dynamicTypeSupport(minSize: 10, maxSize: 18)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Assigned to \(child.name)")
                }
                
                // Task description
                if !stop.task.isEmpty {
                    HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "checkmark.circle")
                            .font(.caption)
                            .foregroundColor(colorSchemeContrast == .increased ? .blue : .brandPrimary)
                            .padding(.top, 2)
                            .accessibilityHidden(true)
                        
                        Text(stop.task)
                            .bodySmall()
                            .foregroundColor(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                            .dynamicTypeSupport(minSize: 10, maxSize: 18)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Task: \(stop.task)")
                }
                
                // Completion status
                if stop.isCompleted {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                            .accessibilityHidden(true)
                        
                        Text("Completed")
                            .captionLarge()
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                            .dynamicTypeSupport(minSize: 10, maxSize: 16)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Stop completed")
                }
            }
            
            Spacer()
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(stop.isCompleted ? [.isStaticText] : [])
        .accessibilityIdentifier("StopDetailRow_\(stopNumber)")
    }
    
    // MARK: - Accessibility Properties
    
    private var accessibilityLabel: String {
        let status = stop.isCompleted ? "Completed" : "Upcoming"
        return "\(status) stop \(stopNumber) of \(totalStops): \(stop.name)"
    }
    
    private var accessibilityValue: String {
        var components: [String] = []
        
        components.append("Location: \(stop.name), \(stop.type.rawValue)")
        components.append("Duration: \(stop.formattedDuration)")
        
        if let child = stop.assignedChild {
            components.append("Assigned to: \(child.name)")
        }
        
        if !stop.task.isEmpty {
            components.append("Task: \(stop.task)")
        }
        
        return components.joined(separator: ", ")
    }
}

#Preview("Stop Detail Row - Various States") {
    VStack(spacing: DesignSystem.Spacing.lg) {
        // First stop
        StopDetailRow(
            stopNumber: 1,
            totalStops: 6,
            stop: SchoolRunPreviewProvider.sampleStops[0]
        )
        
        // School stop with child
        StopDetailRow(
            stopNumber: 2,
            totalStops: 6,
            stop: SchoolRunPreviewProvider.sampleStops[1]
        )
        
        // Completed stop
        StopDetailRow(
            stopNumber: 3,
            totalStops: 6,
            stop: RunStop(
                name: "OT Clinic",
                type: .ot,
                assignedChild: SchoolRunPreviewProvider.sampleChildren[0],
                task: "Drop Emma for therapy session",
                estimatedMinutes: 15,
                isCompleted: true
            )
        )
        
        // Music stop
        StopDetailRow(
            stopNumber: 4,
            totalStops: 6,
            stop: SchoolRunPreviewProvider.sampleStops[3]
        )
        
        // Custom stop
        StopDetailRow(
            stopNumber: 5,
            totalStops: 6,
            stop: RunStop(
                name: "Grocery Store",
                type: .custom,
                task: "Quick grocery run",
                estimatedMinutes: 20
            )
        )
        
        // Final stop
        StopDetailRow(
            stopNumber: 6,
            totalStops: 6,
            stop: SchoolRunPreviewProvider.sampleStops[5]
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Stop Detail Row - Dark Mode") {
    VStack(spacing: DesignSystem.Spacing.lg) {
        StopDetailRow(
            stopNumber: 1,
            totalStops: 3,
            stop: SchoolRunPreviewProvider.sampleStops[0]
        )
        
        StopDetailRow(
            stopNumber: 2,
            totalStops: 3,
            stop: SchoolRunPreviewProvider.sampleStops[1]
        )
        
        StopDetailRow(
            stopNumber: 3,
            totalStops: 3,
            stop: RunStop(
                name: "Home",
                type: .home,
                task: "Return home safely",
                estimatedMinutes: 10,
                isCompleted: true
            )
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
    .preferredColorScheme(.dark)
}

#Preview("Stop Detail Row - Large Text") {
    VStack(spacing: DesignSystem.Spacing.lg) {
        StopDetailRow(
            stopNumber: 1,
            totalStops: 2,
            stop: RunStop(
                name: "Riverside Elementary School",
                type: .school,
                assignedChild: ChildProfile(name: "Emma-Louise", avatar: "person.circle.fill", age: 8),
                task: "Pick up Emma-Louise from her classroom and collect her art project from the teacher. Make sure to check with the office about the field trip permission slip.",
                estimatedMinutes: 15
            )
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
    .environment(\.dynamicTypeSize, .accessibility2)
}

#Preview("Stop Detail Row - High Contrast") {
    VStack(spacing: DesignSystem.Spacing.lg) {
        StopDetailRow(
            stopNumber: 1,
            totalStops: 3,
            stop: SchoolRunPreviewProvider.sampleStops[1]
        )
        
        StopDetailRow(
            stopNumber: 2,
            totalStops: 3,
            stop: RunStop(
                name: "Music Academy",
                type: .music,
                assignedChild: SchoolRunPreviewProvider.sampleChildren[1],
                task: "Drop off for piano lesson",
                estimatedMinutes: 15,
                isCompleted: true
            )
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))

}

#Preview("Stop Detail Row - Interactive") {
    VStack(spacing: DesignSystem.Spacing.lg) {
        StopDetailRow(
            stopNumber: 2,
            totalStops: 4,
            stop: SchoolRunPreviewProvider.sampleStops[1]
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
    .previewDisplayName("Interactive Stop Detail")
}