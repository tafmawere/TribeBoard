//
//  DateAndStatusView.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/07.
//

import SwiftUI

/// Date and status display component for the home dashboard
/// Displays current date and system status information
/// Requirements: 2.1, 2.2, 2.3, 2.4, 2.5
struct DateAndStatusView: View {
    let currentDate: Date
    let activeRunCount: Int
    let lastSyncTime: Date?
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.spacing8) {
            // "Today" heading with formatted date
            VStack(alignment: .leading, spacing: 4) {
                Text("Today")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text(formattedDate)
                    .font(.subheadline)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Today, \(formattedDate)")
            
            // Status badges
            HStack(spacing: DesignSystem.Spacing.spacing8) {
                // Active run count badge (only show when count > 0)
                if activeRunCount > 0 {
                    StatusBadgeView(
                        text: activeRunText,
                        style: .primary
                    )
                    .accessibilityLabel("\(activeRunCount) active \(activeRunCount == 1 ? "run" : "runs")")
                }
                
                // Sync status badge
                StatusBadgeView(
                    text: syncStatusText,
                    style: .secondary
                )
                .accessibilityLabel("Last synced \(syncStatusAccessibilityText)")
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.spacing16)
    }
    
    // MARK: - Computed Properties
    
    /// Formatted date string (e.g., "Monday, February 7")
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: currentDate)
    }
    
    /// Active run badge text (e.g., "1 Active Run" or "2 Active Runs")
    private var activeRunText: String {
        if activeRunCount == 1 {
            return "1 Active Run"
        } else {
            return "\(activeRunCount) Active Runs"
        }
    }
    
    /// Sync status text with time formatting
    /// Formats as "JUST NOW", "2M AGO", "1H AGO", etc.
    private var syncStatusText: String {
        guard let lastSync = lastSyncTime else {
            return "Sync: Never"
        }
        
        let interval = Date().timeIntervalSince(lastSync)
        
        if interval < 60 {
            // Less than 1 minute
            return "Sync: Just Now"
        } else if interval < 3600 {
            // Less than 1 hour - show minutes
            let minutes = Int(interval / 60)
            return "Sync: \(minutes)M Ago"
        } else if interval < 86400 {
            // Less than 1 day - show hours
            let hours = Int(interval / 3600)
            return "Sync: \(hours)H Ago"
        } else {
            // 1 day or more - show days
            let days = Int(interval / 86400)
            return "Sync: \(days)D Ago"
        }
    }
    
    /// Accessibility-friendly sync status text
    private var syncStatusAccessibilityText: String {
        guard let lastSync = lastSyncTime else {
            return "never"
        }
        
        let interval = Date().timeIntervalSince(lastSync)
        
        if interval < 60 {
            return "just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) \(minutes == 1 ? "minute" : "minutes") ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) \(hours == 1 ? "hour" : "hours") ago"
        } else {
            let days = Int(interval / 86400)
            return "\(days) \(days == 1 ? "day" : "days") ago"
        }
    }
}

// MARK: - Previews

#Preview("Date and Status - No Active Runs") {
    DateAndStatusView(
        currentDate: Date(),
        activeRunCount: 0,
        lastSyncTime: Date()
    )
    .padding()
    .background(DesignSystem.Colors.screenBackground)
}

#Preview("Date and Status - 1 Active Run") {
    DateAndStatusView(
        currentDate: Date(),
        activeRunCount: 1,
        lastSyncTime: Date()
    )
    .padding()
    .background(DesignSystem.Colors.screenBackground)
}

#Preview("Date and Status - Multiple Active Runs") {
    DateAndStatusView(
        currentDate: Date(),
        activeRunCount: 3,
        lastSyncTime: Date()
    )
    .padding()
    .background(DesignSystem.Colors.screenBackground)
}

#Preview("Date and Status - 2 Minutes Ago") {
    DateAndStatusView(
        currentDate: Date(),
        activeRunCount: 1,
        lastSyncTime: Date().addingTimeInterval(-120)
    )
    .padding()
    .background(DesignSystem.Colors.screenBackground)
}

#Preview("Date and Status - 1 Hour Ago") {
    DateAndStatusView(
        currentDate: Date(),
        activeRunCount: 2,
        lastSyncTime: Date().addingTimeInterval(-3600)
    )
    .padding()
    .background(DesignSystem.Colors.screenBackground)
}

#Preview("Date and Status - 2 Days Ago") {
    DateAndStatusView(
        currentDate: Date(),
        activeRunCount: 0,
        lastSyncTime: Date().addingTimeInterval(-172800)
    )
    .padding()
    .background(DesignSystem.Colors.screenBackground)
}

#Preview("Date and Status - Never Synced") {
    DateAndStatusView(
        currentDate: Date(),
        activeRunCount: 0,
        lastSyncTime: nil
    )
    .padding()
    .background(DesignSystem.Colors.screenBackground)
}
