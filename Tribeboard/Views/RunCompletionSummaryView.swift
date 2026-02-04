//
//  RunCompletionSummaryView.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/04.
//

import SwiftUI

/// View that displays completion summary with all timestamps and passenger status
/// Shows audit trail of all state transitions
/// Implements Requirement 8.2
struct RunCompletionSummaryView: View {
    
    let run: Run
    let events: [RunEvent]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header section
                    headerSection
                    
                    // Run overview
                    runOverviewSection
                    
                    // Passenger status summary
                    passengerStatusSection
                    
                    // Timeline summary
                    timelineSummarySection
                    
                    // Audit trail
                    auditTrailSection
                }
                .padding()
            }
            .navigationTitle("Run Summary")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - View Sections
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: run.status == .completed ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.title)
                    .foregroundColor(run.status == .completed ? .green : .red)
                
                VStack(alignment: .leading) {
                    Text(run.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(run.status.displayName)
                        .font(.subheadline)
                        .foregroundColor(run.status == .completed ? .green : .red)
                }
                
                Spacer()
            }
            
            if let completionTime = completionTimestamp {
                Text("Completed at \(formatDateTime(completionTime))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var runOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Run Overview")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                InfoRow(label: "Scheduled Time", value: formatDateTime(run.scheduledTime))
                
                if let startTime = run.startTime {
                    InfoRow(label: "Started At", value: formatDateTime(startTime))
                }
                
                if let completionTime = completionTimestamp {
                    InfoRow(label: "Completed At", value: formatDateTime(completionTime))
                }
                
                if let duration = runDuration {
                    InfoRow(label: "Total Duration", value: formatDuration(duration))
                }
                
                InfoRow(label: "Total Stops", value: "\(run.stops.count)")
                InfoRow(label: "Total Passengers", value: "\(run.passengers.count)")
            }
        }
    }
    
    private var passengerStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Passenger Status")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ForEach(run.passengers, id: \.id) { passenger in
                    PassengerStatusRow(
                        passenger: passenger,
                        pickupTime: getPassengerPickupTime(passenger.id),
                        dropoffTime: getPassengerDropoffTime(passenger.id)
                    )
                }
            }
        }
    }
    
    private var timelineSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Timeline Summary")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                ForEach(run.stops.indices, id: \.self) { index in
                    let stop = run.stops[index]
                    StopSummaryRow(
                        stop: stop,
                        index: index + 1,
                        arrivalTime: getStopArrivalTime(stop.id),
                        completionTime: stop.completedAt
                    )
                }
            }
        }
    }
    
    private var auditTrailSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Audit Trail")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("All state transitions and user actions")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(spacing: 4) {
                ForEach(sortedEvents, id: \.id) { event in
                    AuditTrailRow(event: event)
                }
            }
        }
    }
    
    // MARK: - Helper Properties and Methods
    
    private var completionTimestamp: Date? {
        return events.first { $0.type == .runCompleted || $0.type == .runCancelled }?.timestamp
    }
    
    private var runDuration: TimeInterval? {
        guard let startTime = run.startTime,
              let completionTime = completionTimestamp else { return nil }
        return completionTime.timeIntervalSince(startTime)
    }
    
    private var sortedEvents: [RunEvent] {
        return events.sorted { $0.timestamp < $1.timestamp }
    }
    
    private func getPassengerPickupTime(_ passengerId: String) -> Date? {
        return events.first { event in
            event.type == .passengerPickedUp && 
            event.note?.contains(passengerId) == true
        }?.timestamp
    }
    
    private func getPassengerDropoffTime(_ passengerId: String) -> Date? {
        return events.first { event in
            event.type == .passengerDroppedOff && 
            event.note?.contains(passengerId) == true
        }?.timestamp
    }
    
    private func getStopArrivalTime(_ stopId: String) -> Date? {
        return events.first { event in
            event.type == .runArrivedStop && 
            event.note?.contains(stopId) == true
        }?.timestamp
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
        .padding(.vertical, 2)
    }
}

struct PassengerStatusRow: View {
    let passenger: MemberSummary
    let pickupTime: Date?
    let dropoffTime: Date?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(passenger.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                
                Spacer()
                
                StatusBadge(status: passenger.status)
            }
            
            if let pickupTime = pickupTime {
                HStack {
                    Text("Picked up:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatTime(pickupTime))
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                }
            }
            
            if let dropoffTime = dropoffTime {
                HStack {
                    Text("Dropped off:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatTime(dropoffTime))
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct StatusBadge: View {
    let status: PassengerStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(backgroundColor)
            .foregroundColor(.white)
            .cornerRadius(4)
    }
    
    private var backgroundColor: Color {
        switch status {
        case .waiting: return .orange
        case .onboard: return .blue
        case .droppedOff: return .green
        }
    }
}

struct StopSummaryRow: View {
    let stop: RunStop
    let index: Int
    let arrivalTime: Date?
    let completionTime: Date?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Stop \(index): \(stop.label)")
                    .font(.body)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(stop.type.displayName)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .cornerRadius(4)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Scheduled:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatTime(stop.scheduledTime))
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                }
                
                if let arrivalTime = arrivalTime {
                    HStack {
                        Text("Arrived:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formatTime(arrivalTime))
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Spacer()
                    }
                }
                
                if let completionTime = completionTime {
                    HStack {
                        Text("Completed:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(formatTime(completionTime))
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct AuditTrailRow: View {
    let event: RunEvent
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(formatTime(event.timestamp))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.type.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                
                if let stateBefore = event.stateBefore {
                    HStack(spacing: 4) {
                        Text(stateBefore.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color(.systemGray5))
                            .cornerRadius(2)
                        
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(event.stateAfter.displayName)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(2)
                    }
                }
                
                if let note = event.note, !note.isEmpty {
                    Text(note)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    let sampleRun = Run(
        title: "School Pickup",
        scheduledTime: Date().addingTimeInterval(-3600),
        driverId: "driver1",
        status: .completed,
        stops: [
            RunStop(
                type: .pickup,
                label: "Elementary School",
                scheduledTime: Date().addingTimeInterval(-3600),
                requiredPassengerIds: ["child1"],
                location: LocationData(latitude: 37.7749, longitude: -122.4194)
            ),
            RunStop(
                type: .dropoff,
                label: "Home",
                scheduledTime: Date().addingTimeInterval(-1800),
                requiredPassengerIds: ["child1"],
                location: LocationData(latitude: 37.7849, longitude: -122.4094)
            )
        ],
        passengers: [
            MemberSummary(
                id: "child1",
                displayName: "Emma",
                role: .passenger,
                status: .droppedOff
            )
        ],
        createdBy: "parent1",
        familyId: "family1",
        startTime: Date().addingTimeInterval(-3600)
    )
    
    let sampleEvents = [
        RunEvent(
            runId: sampleRun.id,
            type: .runStarted,
            timestamp: Date().addingTimeInterval(-3600),
            actorId: "driver1",
            stateBefore: .scheduled,
            stateAfter: .activeEnroute,
            currentStopIndex: 0
        ),
        RunEvent(
            runId: sampleRun.id,
            type: .runCompleted,
            timestamp: Date().addingTimeInterval(-1800),
            actorId: "driver1",
            stateBefore: .activeEnroute,
            stateAfter: .completed,
            currentStopIndex: 1
        )
    ]
    
    return RunCompletionSummaryView(run: sampleRun, events: sampleEvents)
}