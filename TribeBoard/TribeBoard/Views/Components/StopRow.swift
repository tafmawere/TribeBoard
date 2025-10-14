import SwiftUI

/// Reusable component for displaying individual stop information
struct StopRow: View {
    let stop: RunStop
    let showTime: Bool
    let showStatus: Bool
    let onTap: (() -> Void)?
    let onToggleComplete: (() -> Void)?
    
    init(
        stop: RunStop,
        showTime: Bool = true,
        showStatus: Bool = true,
        onTap: (() -> Void)? = nil,
        onToggleComplete: (() -> Void)? = nil
    ) {
        self.stop = stop
        self.showTime = showTime
        self.showStatus = showStatus
        self.onTap = onTap
        self.onToggleComplete = onToggleComplete
    }
    
    var body: some View {
        Button(action: onTap ?? {}) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Stop type indicator
                VStack {
                    Image(systemName: stop.type.icon)
                        .font(DesignSystem.Typography.titleSmall)
                        .foregroundColor(stop.type.color)
                        .frame(width: 24, height: 24)
                    
                    // Connection line (if not the last stop)
                    Rectangle()
                        .fill(stop.type.color.opacity(0.3))
                        .frame(width: 2, height: 20)
                }
                
                // Stop details
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    // Stop name and type
                    HStack {
                        Text(stop.name)
                            .bodyMedium()
                            .foregroundColor(.primary)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        // Stop type badge
                        Text(stop.type.displayName)
                            .captionMedium()
                            .foregroundColor(stop.type.color)
                            .padding(.horizontal, DesignSystem.Spacing.sm)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .background(stop.type.color.opacity(0.1))
                            .cornerRadius(BrandStyle.cornerRadiusSmall)
                    }
                    
                    // Time information
                    if showTime {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "clock")
                                .font(DesignSystem.Typography.captionLarge)
                                .foregroundColor(.secondary)
                            
                            Text(stop.formattedTime)
                                .captionLarge()
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Note (if available)
                    if !stop.note.isEmpty {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "note.text")
                                .font(DesignSystem.Typography.captionLarge)
                                .foregroundColor(.secondary)
                            
                            Text(stop.note)
                                .captionLarge()
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    
                    // Status information
                    if showStatus {
                        HStack {
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: stop.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .font(DesignSystem.Typography.captionLarge)
                                    .foregroundColor(stop.isCompleted ? .green : .secondary)
                                
                                Text(stop.statusText)
                                    .captionLarge()
                                    .foregroundColor(stop.isCompleted ? .green : .secondary)
                            }
                            
                            Spacer()
                        }
                    }
                }
                
                // Action buttons
                VStack(spacing: DesignSystem.Spacing.sm) {
                    // Complete toggle button
                    if let onToggleComplete = onToggleComplete {
                        Button(action: {
                            // Haptic feedback for stop completion (respects accessibility settings)
                            if stop.isCompleted {
                                SchoolRunHapticFeedback.navigationAction()
                            } else {
                                SchoolRunHapticFeedback.stopCompleted()
                            }
                            onToggleComplete()
                        }) {
                            Image(systemName: stop.isCompleted ? "checkmark.circle.fill" : "circle")
                                .font(DesignSystem.Typography.titleSmall)
                                .foregroundColor(stop.isCompleted ? .green : .secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .actionButtonAccessibility(
                            action: stop.isCompleted ? "Mark incomplete" : "Mark complete",
                            isEnabled: true
                        )
                        .accessibleTouchTarget()
                    }
                }
            }
            .contentPadding()
        }
        .buttonStyle(PlainButtonStyle())
        .background(backgroundColorForStop)
        .cornerRadius(BrandStyle.cornerRadiusSmall)
        .overlay(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusSmall)
                .stroke(borderColorForStop, lineWidth: stop.isCompleted ? 2 : 1)
        )
        .opacity(stop.isCompleted ? 0.7 : 1.0)
        .animation(DesignSystem.Animation.standard, value: stop.isCompleted)
        // Enhanced accessibility support
        .stopRowAccessibility(stop: stop)
        .accessibleTouchTarget()
        .highContrastSupport(
            normalColor: Color.primary,
            highContrastColor: Color.primary
        )
        .onAppear {
            // Announce stop completion changes
            if stop.isCompleted {
                EnhancedAccessibility.announceStopCompletion(stop)
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var backgroundColorForStop: Color {
        if stop.isCompleted {
            return Color.green.opacity(0.05)
        } else {
            return Color(.systemBackground)
        }
    }
    
    private var borderColorForStop: Color {
        if stop.isCompleted {
            return Color.green.opacity(0.3)
        } else {
            return Color(.systemGray5)
        }
    }
}

// MARK: - Compact Stop Row Variant

struct CompactStopRow: View {
    let stop: RunStop
    let onTap: (() -> Void)?
    
    init(stop: RunStop, onTap: (() -> Void)? = nil) {
        self.stop = stop
        self.onTap = onTap
    }
    
    var body: some View {
        Button(action: onTap ?? {}) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                // Stop type icon
                Image(systemName: stop.type.icon)
                    .font(DesignSystem.Typography.labelMedium)
                    .foregroundColor(stop.type.color)
                    .frame(width: 20, height: 20)
                
                // Stop name
                Text(stop.name)
                    .bodySmall()
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Time
                Text(stop.formattedTime)
                    .captionMedium()
                    .foregroundColor(.secondary)
                
                // Completion indicator
                Image(systemName: stop.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(DesignSystem.Typography.labelMedium)
                    .foregroundColor(stop.isCompleted ? .green : .secondary)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
        }
        .buttonStyle(PlainButtonStyle())
        .background(Color(.systemGray6))
        .cornerRadius(BrandStyle.cornerRadiusSmall)
    }
}

// MARK: - Preview

#Preview("Stop Row Variants") {
    let mockStops = [
        RunStop(
            name: "Home",
            time: Date(),
            note: "Pick up Emma and backpack",
            type: .pickup,
            isCompleted: false
        ),
        RunStop(
            name: "Emma's House",
            time: Date().addingTimeInterval(300),
            note: "Pick up Emma's friend Sarah",
            type: .pickup,
            isCompleted: true
        ),
        RunStop(
            name: "Greenwood Elementary School",
            time: Date().addingTimeInterval(900),
            note: "",
            type: .dropoff,
            isCompleted: false
        )
    ]
    
    return ScrollView {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Full stop rows
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Full Stop Rows")
                    .headlineSmall()
                
                VStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(mockStops) { stop in
                        StopRow(
                            stop: stop,
                            onTap: { print("Tapped stop: \(stop.name)") },
                            onToggleComplete: { print("Toggle complete: \(stop.name)") }
                        )
                    }
                }
            }
            
            Divider()
            
            // Compact stop rows
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Compact Stop Rows")
                    .headlineSmall()
                
                VStack(spacing: DesignSystem.Spacing.xs) {
                    ForEach(mockStops) { stop in
                        CompactStopRow(
                            stop: stop,
                            onTap: { print("Tapped compact stop: \(stop.name)") }
                        )
                    }
                }
            }
            
            Divider()
            
            // Stop row without status
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Stop Row (No Status)")
                    .headlineSmall()
                
                StopRow(
                    stop: mockStops[0],
                    showStatus: false,
                    onTap: { print("Tapped stop without status") }
                )
            }
        }
        .screenPadding()
    }
}