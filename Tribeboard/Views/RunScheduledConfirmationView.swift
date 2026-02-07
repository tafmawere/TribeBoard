//
//  RunScheduledConfirmationView.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/06.
//

import SwiftUI

/// Confirmation screen shown after successful run creation
/// Implements Requirement 10
struct RunScheduledConfirmationView: View {
    
    let run: Run
    let onViewRun: () -> Void
    let onBackToDashboard: () -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Success icon and title
                    successHeader
                    
                    // Run details card
                    runDetailsCard
                    
                    // Action buttons
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("Success")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - View Components
    
    private var successHeader: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            Text("Run Scheduled!")
                .font(.title)
                .fontWeight(.bold)
        }
        .padding(.top, 32)
    }
    
    private var runDetailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Run Details")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                DetailRow(label: "Title", value: run.title)
                DetailRow(label: "Scheduled Time", value: formatDateTime(run.scheduledTime))
                DetailRow(label: "Driver", value: getDriverName())
                DetailRow(label: "Passengers", value: getPassengerNames())
                DetailRow(label: "Stops", value: "\(run.stops.count)")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: onViewRun) {
                Text("View Run")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            
            Button(action: onBackToDashboard) {
                Text("Back to Dashboard")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func getDriverName() -> String {
        // In a real implementation, this would fetch the driver's name from the service
        // For now, we'll use the driverId
        return "Driver"
    }
    
    private func getPassengerNames() -> String {
        let names = run.passengers.map { $0.displayName }
        if names.count <= 3 {
            return names.joined(separator: ", ")
        } else {
            let firstThree = Array(names.prefix(3)).joined(separator: ", ")
            return "\(firstThree) and \(names.count - 3) more"
        }
    }
}

// MARK: - Supporting Views

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.body)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleRun = Run(
        title: "School Pickup",
        scheduledTime: Date().addingTimeInterval(3600),
        driverId: "driver1",
        stops: [
            RunStop(
                type: .pickup,
                label: "Elementary School",
                scheduledTime: Date().addingTimeInterval(3600),
                requiredPassengerIds: ["child1", "child2"],
                location: LocationData(latitude: 37.7749, longitude: -122.4194)
            ),
            RunStop(
                type: .dropoff,
                label: "Home",
                scheduledTime: Date().addingTimeInterval(5400),
                requiredPassengerIds: ["child1", "child2"],
                location: LocationData(latitude: 37.7849, longitude: -122.4094)
            )
        ],
        passengers: [
            MemberSummary(id: "child1", displayName: "Emma", role: .passenger),
            MemberSummary(id: "child2", displayName: "Liam", role: .passenger)
        ],
        createdBy: "parent1",
        familyId: "family1"
    )
    
    return RunScheduledConfirmationView(
        run: sampleRun,
        onViewRun: { print("View Run tapped") },
        onBackToDashboard: { print("Back to Dashboard tapped") }
    )
}
