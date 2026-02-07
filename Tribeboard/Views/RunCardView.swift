//
//  RunCardView.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/05.
//

import SwiftUI

/// Reusable run card component
/// Requirement 3: My Runs Screen - Run card display
@MainActor
struct RunCardView: View {
    let run: Run
    let showActions: Bool
    let onTap: () -> Void
    let onStartRun: (() -> Void)?
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header: Title and Status
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(run.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(formatTime(run.scheduledTime))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    statusBadge(status: run.status)
                }
                
                // Driver and Passengers Info
                HStack(spacing: 16) {
                    // Driver
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(getDriverName())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Passengers
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("\(run.passengers.count) passenger\(run.passengers.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Stops Info
                HStack(spacing: 6) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text("\(run.stops.count) stop\(run.stops.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Action Buttons
                if showActions && onStartRun != nil {
                    HStack(spacing: 12) {
                        Button(action: onTap) {
                            Text("Details")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color(.systemGray5))
                                .foregroundColor(.primary)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        
                        if let startAction = onStartRun {
                            Button(action: startAction) {
                                Text("Start Run")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func statusBadge(status: RunStatus) -> some View {
        let (color, text) = statusInfo(status)
        
        Text(text)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(6)
    }
    
    // MARK: - Helper Methods
    
    private func statusInfo(_ status: RunStatus) -> (Color, String) {
        switch status {
        case .scheduled:
            return (.blue, "Scheduled")
        case .activeEnroute:
            return (.orange, "En Route")
        case .arrivedAtStop:
            return (.purple, "At Stop")
        case .paused:
            return (.yellow, "Paused")
        case .completed:
            return (.green, "Completed")
        case .cancelled:
            return (.red, "Cancelled")
        }
    }
    
    private func getDriverName() -> String {
        // In a real app, we'd look up the driver name from the user service
        // For now, just return "Driver"
        return "Driver"
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Today at \(formatter.string(from: date))"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow at \(formatter.string(from: date))"
        } else {
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}
