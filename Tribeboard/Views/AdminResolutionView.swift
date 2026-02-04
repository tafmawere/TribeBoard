//
//  AdminResolutionView.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/04.
//

import SwiftUI

/// Admin interface for manual resolution of escalated issues
/// Provides manual resolution options when automatic recovery fails
/// Implements Requirement 9.4
struct AdminResolutionView: View {
    let escalation: EscalatedIssue
    let resolutionOptions: [ManualResolutionOption]
    let onResolve: (ManualResolutionOption) -> Void
    let onDismiss: () -> Void
    
    @State private var selectedOption: ManualResolutionOption?
    @State private var showingConfirmation = false
    @State private var resolutionNotes = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection
                    issuesSection
                    resolutionOptionsSection
                    notesSection
                    actionButtonsSection
                }
                .padding()
            }
            .navigationTitle("Admin Resolution")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Confirm Resolution", isPresented: $showingConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Apply", role: .destructive) {
                    if let option = selectedOption {
                        onResolve(option)
                    }
                }
            } message: {
                if let option = selectedOption {
                    Text("Are you sure you want to apply this resolution?\n\n\(option.description)")
                }
            }
        }
    }
    
    // MARK: - View Sections
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                
                VStack(alignment: .leading) {
                    Text("Manual Resolution Required")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Run ID: \(escalation.runId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Text("Automatic recovery failed for this run. Please select a manual resolution option.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var issuesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Detected Issues")
                .font(.headline)
            
            ForEach(Array(escalation.inconsistencies.enumerated()), id: \.offset) { index, inconsistency in
                HStack {
                    Circle()
                        .fill(severityColor(inconsistency.severity))
                        .frame(width: 8, height: 8)
                    
                    Text(inconsistency.description)
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text(inconsistency.severity.rawValue.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(severityColor(inconsistency.severity).opacity(0.2))
                        .cornerRadius(4)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    private var resolutionOptionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Resolution Options")
                .font(.headline)
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(resolutionOptions.enumerated()), id: \.offset) { index, option in
                        ResolutionOptionRow(
                            option: option,
                            isSelected: selectedOption?.description == option.description,
                            onSelect: { selectedOption = option }
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Resolution Notes (Optional)")
                .font(.headline)
            
            TextEditor(text: $resolutionNotes)
                .frame(height: 80)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
    
    private var actionButtonsSection: some View {
        HStack(spacing: 16) {
            Button("Cancel") {
                onDismiss()
            }
            .buttonStyle(.bordered)
            .foregroundColor(.secondary)
            
            Button("Apply Resolution") {
                showingConfirmation = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedOption == nil)
        }
        .padding()
    }
    
    private func severityColor(_ severity: InconsistencySeverity) -> Color {
        switch severity {
        case .low: return .gray
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

struct ResolutionOptionRow: View {
    let option: ManualResolutionOption
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(option.description)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .multilineTextAlignment(.leading)
                    
                    Text(optionTypeDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var optionTypeDescription: String {
        switch option {
        case .forceBackendState(_, _):
            return "Use backend state as source of truth"
        case .forceLocalState(_, _):
            return "Use local state and sync to backend"
        case .setPassengerStatus(_, _, _):
            return "Manually set passenger status"
        case .setStopCompletion(_, _, _):
            return "Manually set stop completion"
        case .refreshLocationData(_):
            return "Refresh location data from backend"
        case .synchronizeTimestamps(_):
            return "Synchronize all timestamps"
        case .cancelRun(_):
            return "Cancel the run due to unrecoverable issues"
        }
    }
}

// MARK: - Extension for ManualResolutionOption

extension ManualResolutionOption {
    var description: String {
        switch self {
        case .forceBackendState(let description, _):
            return description
        case .forceLocalState(let description, _):
            return description
        case .setPassengerStatus(_, _, let description):
            return description
        case .setStopCompletion(_, _, let description):
            return description
        case .refreshLocationData(let description):
            return description
        case .synchronizeTimestamps(let description):
            return description
        case .cancelRun(let description):
            return description
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AdminResolutionView_Previews: PreviewProvider {
    static var previews: some View {
        AdminResolutionView(
            escalation: EscalatedIssue(
                id: "test-escalation",
                runId: "test-run-123",
                inconsistencies: [
                    StateInconsistency(
                        type: .stateConflict(.activeEnroute, .arrivedAtStop),
                        description: "Run state mismatch between local and backend",
                        severity: .high
                    ),
                    StateInconsistency(
                        type: .passengerStatusMismatch("passenger-1", .waiting, .onboard),
                        description: "Passenger Emma status mismatch",
                        severity: .medium
                    )
                ],
                recoveryAttemptId: "recovery-123",
                escalationTime: Date(),
                status: .pending,
                adminNotified: true
            ),
            resolutionOptions: [
                .forceBackendState(
                    description: "Use backend state: Arrived at Stop",
                    action: .setState(.arrivedAtStop)
                ),
                .forceLocalState(
                    description: "Use local state: En Route",
                    action: .setState(.activeEnroute)
                ),
                .setPassengerStatus(
                    passengerId: "passenger-1",
                    status: .onboard,
                    description: "Set Emma to On Board status"
                ),
                .cancelRun(
                    description: "Cancel run due to unrecoverable inconsistencies"
                )
            ],
            onResolve: { option in
                print("Selected resolution: \(option.description)")
            },
            onDismiss: {
                print("Dismissed resolution view")
            }
        )
    }
}
#endif