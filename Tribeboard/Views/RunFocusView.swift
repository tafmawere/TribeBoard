//
//  RunFocusView.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/05.
//

import SwiftUI
import MapKit

/// Run Focus View for pre-start run details
/// Implements Requirement 4
struct RunFocusView: View {
    @StateObject private var viewModel: RunFocusViewModel
    @State private var showingError = false
    @State private var showingStartConfirmation = false
    
    init(runId: String, firebaseService: MockFirebaseRunService, roleManagementService: RoleManagementService, runEventService: RunEventService) {
        self._viewModel = StateObject(wrappedValue: RunFocusViewModel(
            runId: runId,
            firebaseService: firebaseService,
            roleManagementService: roleManagementService,
            runEventService: runEventService
        ))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading {
                    loadingView
                } else if let run = viewModel.run {
                    mainContent(run: run)
                } else {
                    errorView
                }
            }
            .navigationTitle("Run Details")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Error", isPresented: $showingError) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                }
            }
            .confirmationDialog("Start Run", isPresented: $showingStartConfirmation) {
                Button("Start Run") {
                    Task {
                        await viewModel.startRun()
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you ready to start this run?")
            }
        }
    }
    
    // MARK: - Main Content
    
    private func mainContent(run: Run) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Map Preview
                mapPreviewSection(run: run)
                
                // Status Card
                statusCard(run: run)
                
                // Route Summary
                routeSummarySection(run: run)
                
                // Passenger List
                passengerSection(run: run)
                
                // Action Buttons
                actionButtons(run: run)
                
                Spacer(minLength: 40)
            }
            .padding()
        }
    }
    
    // MARK: - Map Preview Section
    
    private func mapPreviewSection(run: Run) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Route Preview")
                .font(.headline)
            
            Map {
                // Add markers for all stops
                ForEach(Array(run.stops.enumerated()), id: \.element.id) { index, stop in
                    Marker(
                        "\(index + 1). \(stop.label)",
                        systemImage: stopIcon(for: stop.type),
                        coordinate: stop.location.coordinate
                    )
                    .tint(stopColor(for: stop.type))
                }
            }
            .frame(height: 250)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Status Card
    
    private func statusCard(run: Run) -> some View {
        VStack(spacing: 16) {
            // Status Badge
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ready to go")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(run.status.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Divider()
            
            // ETA and Distance
            HStack(spacing: 32) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ETA")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(viewModel.calculateETA(), style: .time)
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Distance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(formatDistance(viewModel.calculateTotalDistance()))
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Route Summary Section
    
    private func routeSummarySection(run: Run) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Route Summary")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(Array(run.stops.enumerated()), id: \.element.id) { index, stop in
                    stopRow(stop: stop, index: index, isLast: index == run.stops.count - 1)
                }
            }
        }
    }
    
    private func stopRow(stop: RunStop, index: Int, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Stop Number and Line
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(stopColor(for: stop.type))
                        .frame(width: 32, height: 32)
                    
                    Text("\(index + 1)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                if !isLast {
                    Rectangle()
                        .fill(Color(.systemGray4))
                        .frame(width: 2, height: 40)
                }
            }
            
            // Stop Details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(stop.label)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(stop.scheduledTime, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let address = stop.location.address {
                    Text(address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Passenger count for this stop
                if !stop.requiredPassengerIds.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("\(stop.requiredPassengerIds.count) passenger\(stop.requiredPassengerIds.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Passenger Section
    
    private func passengerSection(run: Run) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Passengers")
                .font(.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(run.passengers) { passenger in
                        passengerCard(passenger: passenger)
                    }
                }
            }
        }
    }
    
    private func passengerCard(passenger: MemberSummary) -> some View {
        VStack(spacing: 8) {
            // Avatar
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(passenger.displayName.prefix(1)))
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                )
            
            // Name
            Text(passenger.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
            
            // Status
            Text(passenger.status.displayName)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(width: 80)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    // MARK: - Action Buttons
    
    private func actionButtons(run: Run) -> some View {
        VStack(spacing: 12) {
            // Start Run Button (Driver Only)
            if viewModel.canStartRun() {
                Button(action: {
                    showingStartConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                            .font(.title3)
                        
                        Text("Start Run")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.green)
                    .cornerRadius(12)
                }
            }
            
            // Open in Maps Button
            Button(action: {
                viewModel.openInMaps()
            }) {
                HStack {
                    Image(systemName: "map.fill")
                        .font(.title3)
                    
                    Text("Open in Maps")
                        .font(.headline)
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Supporting Views
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading run details...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)
            
            Text("Run not found")
                .font(.headline)
            
            Text("This run may have been deleted or you don't have permission to view it.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    // MARK: - Helper Methods
    
    private func stopIcon(for type: StopType) -> String {
        switch type {
        case .pickup:
            return "arrow.up.circle.fill"
        case .dropoff:
            return "arrow.down.circle.fill"
        case .waypoint:
            return "mappin.circle.fill"
        }
    }
    
    private func stopColor(for type: StopType) -> Color {
        switch type {
        case .pickup:
            return .green
        case .dropoff:
            return .orange
        case .waypoint:
            return .blue
        }
    }
    
    private func formatDistance(_ meters: Double) -> String {
        let kilometers = meters / 1000.0
        if kilometers < 1.0 {
            return String(format: "%.0f m", meters)
        } else {
            return String(format: "%.1f km", kilometers)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct RunFocusView_Previews: PreviewProvider {
    static var previews: some View {
        let mockFirebaseService = MockFirebaseRunService()
        let mockRoleManagementService = RoleManagementService()
        let mockRunEventService = RunEventService(firebaseService: mockFirebaseService)
        
        RunFocusView(
            runId: "run1",
            firebaseService: mockFirebaseService,
            roleManagementService: mockRoleManagementService,
            runEventService: mockRunEventService
        )
    }
}
#endif
