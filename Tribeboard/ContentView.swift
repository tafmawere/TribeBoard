import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var runService = MockFirebaseRunService()
    @StateObject private var locationService = LocationService()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("TribeBoard")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Active Run Module - State Machine Demo")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                if let currentRun = runService.currentRun {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Current Run: \(currentRun.title)")
                            .font(.headline)
                        
                        HStack {
                            Text("Status:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text(currentRun.status.displayName)
                                .font(.subheadline)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(statusColor(for: currentRun.status))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        Text("Driver: \(currentRun.driverId)")
                            .font(.subheadline)
                        Text("Passengers: \(currentRun.passengers.count)")
                            .font(.subheadline)
                        
                        if currentRun.isDelayed {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Delayed: \(currentRun.delayReason ?? "Unknown reason")")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                        
                        // Available Actions
                        let availableActions = RunStateMachine.getAvailableActions(for: currentRun, userRole: .driver)
                        if !availableActions.isEmpty {
                            Text("Available Actions:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.top)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                                ForEach(Array(availableActions.enumerated()), id: \.offset) { index, action in
                                    Button(actionTitle(for: action)) {
                                        Task {
                                            await performAction(action, runId: currentRun.id)
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .font(.caption)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                } else {
                    Button("Create Demo Run") {
                        Task {
                            do {
                                let demoRun = try await runService.createDemoRun()
                                runService.listenToRun(runId: demoRun.id)
                                runService.listenToRunEvents(runId: demoRun.id)
                            } catch {
                                print("Error creating demo run: \(error)")
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                // Events Timeline
                if !runService.runEvents.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Events")
                            .font(.headline)
                        
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(runService.runEvents.suffix(5)) { event in
                                    HStack {
                                        Text(event.type.displayName)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text(event.timestamp, style: .time)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(6)
                                }
                            }
                        }
                        .frame(maxHeight: 150)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            locationService.requestLocationPermission()
        }
    }
    
    private func statusColor(for status: RunStatus) -> Color {
        switch status {
        case .scheduled: return .blue
        case .activeEnroute: return .green
        case .arrivedAtStop: return .orange
        case .paused: return .yellow
        case .completed: return .purple
        case .cancelled: return .red
        }
    }
    
    private func actionTitle(for action: DriverAction) -> String {
        switch action {
        case .startRun: return "Start Run"
        case .arriveStop: return "Arrive at Stop"
        case .confirmPickup: return "Confirm Pickup"
        case .confirmDropoff: return "Confirm Dropoff"
        case .nextStop: return "Next Stop"
        case .pauseRun: return "Pause"
        case .resumeRun: return "Resume"
        case .markDelayed: return "Mark Delayed"
        case .clearDelayed: return "Clear Delay"
        case .endRun: return "End Run"
        }
    }
    
    private func performAction(_ action: DriverAction, runId: String) async {
        do {
            try await runService.processDriverAction(action, runId: runId)
        } catch {
            print("Error performing action: \(error)")
        }
    }
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
