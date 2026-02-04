//
//  DriverFocusModeView.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/04.
//

import SwiftUI
import CoreLocation

/// Driver Focus Mode View with Uber-like execution flow
/// Implements Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7
/// Provides step-by-step driver interface: Start → Arrive → Pickup → Dropoff → Complete
/// Prevents skipping required state transitions
struct DriverFocusModeView: View {
    @StateObject private var viewModel: DriverFocusModeViewModel
    @State private var showingDelayDialog = false
    @State private var delayReason = ""
    @State private var showingError = false
    
    init(runId: String, runEventService: RunEventService, roleContext: RoleContext) {
        self._viewModel = StateObject(wrappedValue: DriverFocusModeViewModel(
            runId: runId,
            runEventService: runEventService,
            roleContext: roleContext
        ))
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient for focus mode
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue.opacity(0.1), Color.white]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if viewModel.isLoading {
                    loadingView
                } else {
                    mainContent
                }
            }
            .navigationTitle("Focus Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if viewModel.runState.isActive {
                        delayButton
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(viewModel.error?.localizedDescription ?? "Unknown error")
            }
            .sheet(isPresented: $showingDelayDialog) {
                delayDialogView
            }
        }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Run Status Header
                runStatusHeader
                
                // Current Stop Section
                if let stopInfo = viewModel.getCurrentStopInfo() {
                    currentStopSection(stopInfo)
                }
                
                // Next Stop Preview
                if let nextStopPreview = viewModel.getNextStopPreview() {
                    nextStopSection(nextStopPreview)
                }
                
                // Primary Action Button
                primaryActionButton
                
                // Secondary Actions
                secondaryActions
                
                Spacer(minLength: 100)
            }
            .padding()
        }
    }
    
    // MARK: - Run Status Header
    
    private var runStatusHeader: some View {
        VStack(spacing: 12) {
            // Run State Indicator
            HStack {
                Circle()
                    .fill(stateColor)
                    .frame(width: 12, height: 12)
                
                Text(viewModel.runState.displayName)
                    .font(.headline)
                    .foregroundColor(stateColor)
                
                Spacer()
                
                if viewModel.isProcessingAction {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Delay Indicator
            if let run = viewModel.getFilteredRunData()?.run, run.isDelayed {
                HStack {
                    Image(systemName: "clock.badge.exclamationmark")
                        .foregroundColor(.orange)
                    
                    Text("Delayed: \(run.delayReason ?? "Unknown reason")")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - Current Stop Section
    
    private func currentStopSection(_ stopInfo: StopInfo) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: stopTypeIcon(stopInfo.stop.type))
                    .foregroundColor(.blue)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Stop")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(stopInfo.stop.label)
                        .font(.headline)
                }
                
                Spacer()
                
                // Completion Progress
                CircularProgressView(progress: stopInfo.completionProgress)
            }
            
            // Stop Address
            if let address = stopInfo.stop.location.address {
                Text(address)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Stop Completion Status
            if let progress = viewModel.getStopCompletionProgress() {
                stopCompletionStatus(progress)
            }
            
            // Required Passengers with Enhanced Actions
            if !stopInfo.requiredPassengers.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Passengers")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    ForEach(viewModel.getPassengersRequiringAction(), id: \.passenger.id) { actionItem in
                        enhancedPassengerRow(actionItem)
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
    
    // MARK: - Stop Completion Status
    
    private func stopCompletionStatus(_ progress: StopCompletionProgress) -> some View {
        HStack {
            Image(systemName: progress.isComplete ? "checkmark.circle.fill" : "clock.fill")
                .foregroundColor(progress.isComplete ? .green : .orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(progress.message)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if !progress.isComplete && !progress.remainingActions.isEmpty {
                    Text("\(progress.remainingActions.count) action(s) remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text(progress.progressText)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
        }
        .padding()
        .background(progress.isComplete ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Enhanced Passenger Row
    
    private func enhancedPassengerRow(_ actionItem: PassengerActionItem) -> some View {
        HStack {
            // Passenger Avatar/Initial
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(actionItem.passenger.displayName.prefix(1)))
                        .font(.caption)
                        .fontWeight(.medium)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(actionItem.passenger.displayName)
                    .font(.subheadline)
                
                HStack {
                    Text(actionItem.passenger.status.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !actionItem.isCompleted {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(actionItem.statusMessage)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
            
            // Enhanced Action Button
            if let action = actionItem.requiredAction, actionItem.canPerformAction {
                Button(actionItem.actionTitle ?? "Action") {
                    Task {
                        do {
                            try await viewModel.updatePassengerStatus(
                                passengerId: actionItem.passenger.id,
                                newStatus: targetStatus(for: action)
                            )
                        } catch {
                            showingError = true
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(viewModel.isProcessingAction)
            } else {
                statusIcon(for: actionItem.passenger.status, stopType: viewModel.currentStop?.type ?? .waypoint)
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Helper Methods
    
    private func targetStatus(for action: DriverAction) -> PassengerStatus {
        switch action {
        case .confirmPickup:
            return .onboard
        case .confirmDropoff:
            return .droppedOff
        default:
            return .waiting
        }
    }
    
    // MARK: - Next Stop Section
    
    private func nextStopSection(_ nextStopPreview: StopPreview) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: stopTypeIcon(nextStopPreview.stop.type))
                    .foregroundColor(.gray)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next Stop")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(nextStopPreview.stop.label)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                if let eta = nextStopPreview.estimatedArrival {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("ETA")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(eta, style: .time)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
            }
            
            // Passenger Summary
            if !nextStopPreview.requiredPassengers.isEmpty {
                Text(nextStopPreview.passengerSummary)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Primary Action Button
    
    private var primaryActionButton: some View {
        Button(action: performPrimaryAction) {
            HStack {
                if viewModel.isProcessingAction {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: primaryActionIcon)
                        .font(.title2)
                }
                
                Text(primaryActionTitle)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(primaryActionColor)
            .cornerRadius(12)
        }
        .disabled(!canPerformPrimaryAction || viewModel.isProcessingAction)
        .opacity(canPerformPrimaryAction ? 1.0 : 0.6)
    }
    
    // MARK: - Secondary Actions
    
    private var secondaryActions: some View {
        VStack(spacing: 12) {
            // Pause/Resume Button
            if viewModel.canPerformAction(.pauseRun) || viewModel.canPerformAction(.resumeRun) {
                Button(action: togglePause) {
                    HStack {
                        Image(systemName: viewModel.runState == .paused ? "play.fill" : "pause.fill")
                        Text(viewModel.runState == .paused ? "Resume Run" : "Pause Run")
                    }
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
                .disabled(viewModel.isProcessingAction)
            }
            
            // End Run Button (Emergency)
            if viewModel.canPerformAction(.endRun) && viewModel.runState != .scheduled {
                Button(action: endRun) {
                    HStack {
                        Image(systemName: "stop.fill")
                        Text("End Run")
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                .disabled(viewModel.isProcessingAction)
            }
        }
    }
    
    // MARK: - Supporting Views
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading run data...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var delayButton: some View {
        Button(action: { showingDelayDialog = true }) {
            Image(systemName: "clock.badge.exclamationmark")
                .foregroundColor(.orange)
        }
    }
    
    private var delayDialogView: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Mark Run as Delayed")
                    .font(.headline)
                
                TextField("Reason for delay", text: $delayReason)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button("Mark Delayed") {
                    Task {
                        do {
                            try await viewModel.markDelayed(reason: delayReason)
                            showingDelayDialog = false
                            delayReason = ""
                        } catch {
                            showingError = true
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(delayReason.isEmpty)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Delay Run")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingDelayDialog = false
                        delayReason = ""
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Helper Views
    
    private func passengerRow(_ passenger: MemberSummary, stopType: StopType) -> some View {
        HStack {
            // Passenger Avatar/Initial
            Circle()
                .fill(Color.blue.opacity(0.2))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(passenger.displayName.prefix(1)))
                        .font(.caption)
                        .fontWeight(.medium)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(passenger.displayName)
                    .font(.subheadline)
                
                Text(passenger.status.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Action Button for this passenger
            if viewModel.runState == .arrivedAtStop {
                passengerActionButton(passenger, stopType: stopType)
            } else {
                statusIcon(for: passenger.status, stopType: stopType)
            }
        }
    }
    
    private func passengerActionButton(_ passenger: MemberSummary, stopType: StopType) -> some View {
        Group {
            switch stopType {
            case .pickup:
                if passenger.status == .waiting && viewModel.canPerformAction(.confirmPickup(passengerId: passenger.id)) {
                    Button("Pick Up") {
                        Task {
                            do {
                                try await viewModel.confirmPickup(passengerId: passenger.id)
                            } catch {
                                showingError = true
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                } else {
                    statusIcon(for: passenger.status, stopType: stopType)
                }
                
            case .dropoff:
                if passenger.status == .onboard && viewModel.canPerformAction(.confirmDropoff(passengerId: passenger.id)) {
                    Button("Drop Off") {
                        Task {
                            do {
                                try await viewModel.confirmDropoff(passengerId: passenger.id)
                            } catch {
                                showingError = true
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                } else {
                    statusIcon(for: passenger.status, stopType: stopType)
                }
                
            case .waypoint:
                statusIcon(for: passenger.status, stopType: stopType)
            }
        }
    }
    
    private func statusIcon(for status: PassengerStatus, stopType: StopType) -> some View {
        Group {
            switch (status, stopType) {
            case (.waiting, .pickup):
                Image(systemName: "clock")
                    .foregroundColor(.orange)
            case (.onboard, .pickup), (.onboard, .dropoff):
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case (.droppedOff, .dropoff):
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            default:
                Image(systemName: "circle")
                    .foregroundColor(.gray)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var stateColor: Color {
        switch viewModel.runState {
        case .scheduled:
            return .blue
        case .activeEnroute:
            return .green
        case .arrivedAtStop:
            return .orange
        case .paused:
            return .yellow
        case .completed:
            return .green
        case .cancelled:
            return .red
        }
    }
    
    private var primaryActionTitle: String {
        switch viewModel.runState {
        case .scheduled:
            return "Start Run"
        case .activeEnroute:
            return "Arrived at Stop"
        case .arrivedAtStop:
            if let progress = viewModel.getStopCompletionProgress(), progress.isComplete {
                return "Next Stop"
            } else {
                return "Complete Stop Actions"
            }
        case .paused:
            return "Resume Run"
        case .completed, .cancelled:
            return "Run Complete"
        }
    }
    
    private var primaryActionIcon: String {
        switch viewModel.runState {
        case .scheduled:
            return "play.fill"
        case .activeEnroute:
            return "location.fill"
        case .arrivedAtStop:
            if let progress = viewModel.getStopCompletionProgress(), progress.isComplete {
                return "arrow.right.circle.fill"
            } else {
                return "checkmark.circle"
            }
        case .paused:
            return "play.fill"
        case .completed, .cancelled:
            return "checkmark.circle.fill"
        }
    }
    
    private var primaryActionColor: Color {
        switch viewModel.runState {
        case .scheduled, .paused:
            return .green
        case .activeEnroute:
            return .orange
        case .arrivedAtStop:
            if let progress = viewModel.getStopCompletionProgress(), progress.isComplete {
                return .blue
            } else {
                return .gray
            }
        case .completed, .cancelled:
            return .gray
        }
    }
    
    private var canPerformPrimaryAction: Bool {
        switch viewModel.runState {
        case .scheduled:
            return viewModel.canPerformAction(.startRun)
        case .activeEnroute:
            return viewModel.canPerformAction(.arriveStop)
        case .arrivedAtStop:
            if let progress = viewModel.getStopCompletionProgress(), progress.isComplete {
                return viewModel.canPerformAction(.nextStop)
            } else {
                return false // Must complete stop actions first
            }
        case .paused:
            return viewModel.canPerformAction(.resumeRun)
        case .completed, .cancelled:
            return false
        }
    }
    
    // MARK: - Action Methods
    
    private func performPrimaryAction() {
        Task {
            do {
                switch viewModel.runState {
                case .scheduled:
                    try await viewModel.startRun()
                case .activeEnroute:
                    try await viewModel.arrivedAtStop()
                case .arrivedAtStop:
                    if let progress = viewModel.getStopCompletionProgress(), progress.isComplete {
                        let _ = try await viewModel.advanceToNextStop()
                        // Could show a success message based on result.message
                    }
                case .paused:
                    try await viewModel.resumeRun()
                case .completed, .cancelled:
                    break
                }
            } catch {
                showingError = true
            }
        }
    }
    
    private func togglePause() {
        Task {
            do {
                if viewModel.runState == .paused {
                    try await viewModel.resumeRun()
                } else {
                    try await viewModel.pauseRun()
                }
            } catch {
                showingError = true
            }
        }
    }
    
    private func endRun() {
        Task {
            do {
                try await viewModel.endRun()
            } catch {
                showingError = true
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func stopTypeIcon(_ type: StopType) -> String {
        switch type {
        case .pickup:
            return "arrow.up.circle.fill"
        case .dropoff:
            return "arrow.down.circle.fill"
        case .waypoint:
            return "location.circle.fill"
        }
    }
}

// MARK: - Circular Progress View

struct CircularProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 3)
            
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.3), value: progress)
            
            Text("\(Int(progress * 100))%")
                .font(.caption2)
                .fontWeight(.medium)
        }
        .frame(width: 40, height: 40)
    }
}

// MARK: - Preview

#if DEBUG
struct DriverFocusModeView_Previews: PreviewProvider {
    static var previews: some View {
        let mockRunEventService = MockFirebaseRunService()
        let mockRoleContext = RoleContext(userId: "driver1", role: .driver, familyId: "family1")
        
        DriverFocusModeView(
            runId: "run1",
            runEventService: RunEventService(firebaseService: mockRunEventService),
            roleContext: mockRoleContext
        )
    }
}
#endif