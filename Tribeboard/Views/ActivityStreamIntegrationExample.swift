//
//  ActivityStreamIntegrationExample.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/04.
//

import SwiftUI

/// Example showing how to integrate ActivityStreamView and RunCompletionSummaryView
/// This demonstrates the complete activity stream and audit trail functionality
/// Implements Requirements 8.1, 8.2, 8.3, 8.4, 8.5
struct ActivityStreamIntegrationExample: View {
    
    @StateObject private var runEventService = RunEventService(firebaseService: MockFirebaseRunService())
    @State private var selectedRun: Run?
    @State private var showingCompletionSummary = false
    
    let sampleRun = Run(
        title: "School Pickup Run",
        scheduledTime: Date().addingTimeInterval(-7200), // 2 hours ago
        driverId: "driver1",
        status: .completed,
        stops: [
            RunStop(
                type: .pickup,
                label: "Elementary School",
                scheduledTime: Date().addingTimeInterval(-7200),
                requiredPassengerIds: ["child1", "child2"],
                location: LocationData(latitude: 37.7749, longitude: -122.4194, address: "123 School St")
            ),
            RunStop(
                type: .dropoff,
                label: "Home",
                scheduledTime: Date().addingTimeInterval(-3600),
                requiredPassengerIds: ["child1", "child2"],
                location: LocationData(latitude: 37.7849, longitude: -122.4094, address: "456 Home Ave")
            )
        ],
        passengers: [
            MemberSummary(
                id: "child1",
                displayName: "Emma",
                role: .passenger,
                status: .droppedOff
            ),
            MemberSummary(
                id: "child2",
                displayName: "Liam",
                role: .passenger,
                status: .droppedOff
            )
        ],
        createdBy: "parent1",
        familyId: "family1",
        startTime: Date().addingTimeInterval(-7200)
    )
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Run information
                runInfoCard
                
                // Activity Stream button
                NavigationLink(destination: ActivityStreamView(runId: sampleRun.id, runEventService: runEventService)) {
                    actionButton(
                        title: "View Activity Stream",
                        subtitle: "See all run events and timeline",
                        icon: "clock.arrow.circlepath",
                        color: .blue
                    )
                }
                
                // Completion Summary button (only for completed runs)
                if sampleRun.status.isTerminal {
                    Button(action: {
                        selectedRun = sampleRun
                        showingCompletionSummary = true
                    }) {
                        actionButton(
                            title: "View Completion Summary",
                            subtitle: "See detailed run summary and audit trail",
                            icon: "doc.text.magnifyingglass",
                            color: .green
                        )
                    }
                }
                
                Spacer()
                
                // Demo section
                demoSection
            }
            .padding()
            .navigationTitle("Activity & Audit Trail")
            .onAppear {
                setupDemoEvents()
            }
            .sheet(isPresented: $showingCompletionSummary) {
                if let run = selectedRun {
                    RunCompletionSummaryView(run: run, events: createDemoEvents(for: run.id))
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var runInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "car.fill")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text(sampleRun.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(sampleRun.status.displayName)
                        .font(.subheadline)
                        .foregroundColor(sampleRun.status == .completed ? .green : .orange)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("\(sampleRun.passengers.count) passengers")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(sampleRun.stops.count) stops")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func actionButton(title: String, subtitle: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    private var demoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Demo Features")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 4) {
                featureItem("✓ Real-time event logging", "All state transitions are logged with timestamps")
                featureItem("✓ Event acknowledgment", "Users can acknowledge events they've seen")
                featureItem("✓ Comment system", "Add contextual comments to any event")
                featureItem("✓ Chronological display", "Events shown in timeline order")
                featureItem("✓ Completion summary", "Detailed audit trail for completed runs")
                featureItem("✓ Passenger tracking", "Track pickup/dropoff status and times")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func featureItem(_ title: String, _ description: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.body)
                .fontWeight(.medium)
            
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Demo Data Setup
    
    private func setupDemoEvents() {
        // Simulate some events for the demo
        let events = createDemoEvents(for: sampleRun.id)
        
        // Broadcast events to the service
        for event in events {
            runEventService.broadcastEvent(event)
        }
    }
    
    private func createDemoEvents(for runId: String) -> [RunEvent] {
        let baseTime = Date().addingTimeInterval(-7200) // 2 hours ago
        
        return [
            RunEvent(
                runId: runId,
                type: .runCreated,
                timestamp: baseTime.addingTimeInterval(-300), // 5 minutes before start
                actorId: "parent1",
                stateBefore: nil,
                stateAfter: .scheduled,
                currentStopIndex: 0,
                note: "Run created by parent"
            ),
            RunEvent(
                runId: runId,
                type: .runStarted,
                timestamp: baseTime,
                actorId: "driver1",
                stateBefore: .scheduled,
                stateAfter: .activeEnroute,
                currentStopIndex: 0,
                note: "Driver started the run"
            ),
            RunEvent(
                runId: runId,
                type: .runArrivedStop,
                timestamp: baseTime.addingTimeInterval(900), // 15 minutes later
                actorId: "driver1",
                stateBefore: .activeEnroute,
                stateAfter: .arrivedAtStop,
                currentStopIndex: 0,
                note: "Arrived at Elementary School"
            ),
            RunEvent(
                runId: runId,
                type: .passengerPickedUp,
                timestamp: baseTime.addingTimeInterval(1200), // 20 minutes later
                actorId: "driver1",
                stateBefore: .arrivedAtStop,
                stateAfter: .arrivedAtStop,
                currentStopIndex: 0,
                note: "Picked up Emma"
            ),
            RunEvent(
                runId: runId,
                type: .passengerPickedUp,
                timestamp: baseTime.addingTimeInterval(1320), // 22 minutes later
                actorId: "driver1",
                stateBefore: .arrivedAtStop,
                stateAfter: .arrivedAtStop,
                currentStopIndex: 0,
                note: "Picked up Liam"
            ),
            RunEvent(
                runId: runId,
                type: .runArrivedStop,
                timestamp: baseTime.addingTimeInterval(3300), // 55 minutes later
                actorId: "driver1",
                stateBefore: .activeEnroute,
                stateAfter: .arrivedAtStop,
                currentStopIndex: 1,
                note: "Arrived at Home"
            ),
            RunEvent(
                runId: runId,
                type: .passengerDroppedOff,
                timestamp: baseTime.addingTimeInterval(3480), // 58 minutes later
                actorId: "driver1",
                stateBefore: .arrivedAtStop,
                stateAfter: .arrivedAtStop,
                currentStopIndex: 1,
                note: "Dropped off Emma"
            ),
            RunEvent(
                runId: runId,
                type: .passengerDroppedOff,
                timestamp: baseTime.addingTimeInterval(3540), // 59 minutes later
                actorId: "driver1",
                stateBefore: .arrivedAtStop,
                stateAfter: .arrivedAtStop,
                currentStopIndex: 1,
                note: "Dropped off Liam"
            ),
            RunEvent(
                runId: runId,
                type: .runCompleted,
                timestamp: baseTime.addingTimeInterval(3600), // 1 hour later
                actorId: "driver1",
                stateBefore: .arrivedAtStop,
                stateAfter: .completed,
                currentStopIndex: 1,
                note: "Run completed successfully"
            )
        ]
    }
}

// MARK: - Preview

#Preview {
    ActivityStreamIntegrationExample()
}