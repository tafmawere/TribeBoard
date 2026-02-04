//
//  RoleBasedViewModifier.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/04.
//

import SwiftUI

/// View modifier that applies role-based styling and visibility
/// Implements Requirements 5.2, 5.3, 5.4 - role-specific UI adaptation
struct RoleBasedViewModifier: ViewModifier {
    let roleContext: RoleContext
    let filteredData: FilteredRunData?
    
    func body(content: Content) -> some View {
        content
            .opacity(shouldShowContent() ? 1.0 : 0.3)
            .disabled(!shouldEnableContent())
            .overlay(
                roleIndicatorOverlay(),
                alignment: .topTrailing
            )
    }
    
    private func shouldShowContent() -> Bool {
        guard let data = filteredData else { return true }
        return data.showFullDetails
    }
    
    private func shouldEnableContent() -> Bool {
        guard let data = filteredData else { return true }
        
        switch roleContext.role {
        case .driver:
            return data.showExecutionActions
        case .observer:
            return data.showMonitoringInfo
        case .admin:
            return data.showAdminActions || data.showExecutionActions
        }
    }
    
    @ViewBuilder
    private func roleIndicatorOverlay() -> some View {
        if shouldShowRoleIndicator() {
            RoleIndicatorView(role: roleContext.role)
        }
    }
    
    private func shouldShowRoleIndicator() -> Bool {
        // Show role indicator for admin and driver roles in certain contexts
        return roleContext.role == .admin || 
               (roleContext.role == .driver && filteredData?.showExecutionActions == true)
    }
}

/// Role indicator view
struct RoleIndicatorView: View {
    let role: FamilyRole
    
    var body: some View {
        Text(role.displayName)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(roleColor.opacity(0.2))
            .foregroundColor(roleColor)
            .cornerRadius(4)
    }
    
    private var roleColor: Color {
        switch role {
        case .driver:
            return .blue
        case .observer:
            return .green
        case .admin:
            return .purple
        }
    }
}

/// Extension to apply role-based view modifier
extension View {
    func roleBasedDisplay(roleContext: RoleContext, filteredData: FilteredRunData? = nil) -> some View {
        self.modifier(RoleBasedViewModifier(roleContext: roleContext, filteredData: filteredData))
    }
}

/// View modifier for role-based action buttons
struct RoleBasedActionModifier: ViewModifier {
    let action: Any // Can be DriverAction, AdminAction, or ObserverAction
    let roleContext: RoleContext
    let isAvailable: Bool
    
    func body(content: Content) -> some View {
        content
            .disabled(!isAvailable)
            .opacity(isAvailable ? 1.0 : 0.5)
            .overlay(
                permissionIndicator(),
                alignment: .bottomTrailing
            )
    }
    
    @ViewBuilder
    private func permissionIndicator() -> some View {
        if !isAvailable {
            Image(systemName: "lock.fill")
                .font(.caption2)
                .foregroundColor(.red)
                .padding(2)
        }
    }
}

/// Extension for role-based action buttons
extension View {
    func roleBasedAction<T>(
        action: T,
        roleContext: RoleContext,
        isAvailable: Bool
    ) -> some View {
        self.modifier(RoleBasedActionModifier(
            action: action,
            roleContext: roleContext,
            isAvailable: isAvailable
        ))
    }
}

/// View that displays role-appropriate run information
struct RoleBasedRunInfoView: View {
    let run: Run
    let roleContext: RoleContext
    let filteredData: FilteredRunData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Basic run information (always shown)
            runBasicInfo
            
            // Role-specific information
            if filteredData.showDriverLocation {
                driverLocationInfo
            }
            
            if filteredData.showPassengerDetails {
                passengerDetailsInfo
            }
            
            if filteredData.showStopDetails {
                stopDetailsInfo
            }
            
            if filteredData.showMonitoringInfo {
                monitoringInfo
            }
        }
        .roleBasedDisplay(roleContext: roleContext, filteredData: filteredData)
    }
    
    @ViewBuilder
    private var runBasicInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(run.title)
                .font(.headline)
            
            Text(run.status.displayName)
                .font(.subheadline)
                .foregroundColor(statusColor)
            
            Text(formatTime(run.scheduledTime))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    @ViewBuilder
    private var driverLocationInfo: some View {
        if run.lastLocation != nil {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.blue)
                Text("Driver location updated")
                    .font(.caption)
                Spacer()
                if let updateTime = run.lastLocationUpdatedAt {
                    Text(formatTime(updateTime))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    @ViewBuilder
    private var passengerDetailsInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Passengers (\(run.passengers.count))")
                .font(.caption)
                .fontWeight(.medium)
            
            ForEach(run.passengers) { passenger in
                HStack {
                    Text(passenger.displayName)
                        .font(.caption)
                    Spacer()
                    Text(passenger.status.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(passengerStatusColor(passenger.status).opacity(0.2))
                        .foregroundColor(passengerStatusColor(passenger.status))
                        .cornerRadius(2)
                }
            }
        }
    }
    
    @ViewBuilder
    private var stopDetailsInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Stops (\(run.stops.count))")
                .font(.caption)
                .fontWeight(.medium)
            
            ForEach(Array(run.stops.enumerated()), id: \.element.id) { index, stop in
                HStack {
                    Image(systemName: index == run.currentStopIndex ? "location.circle.fill" : "location.circle")
                        .foregroundColor(index == run.currentStopIndex ? .blue : .gray)
                    
                    Text(stop.label)
                        .font(.caption)
                        .fontWeight(index == run.currentStopIndex ? .medium : .regular)
                    
                    Spacer()
                    
                    if stop.isCompleted {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var monitoringInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Monitoring")
                .font(.caption)
                .fontWeight(.medium)
            
            if run.isDelayed, let reason = run.delayReason {
                HStack {
                    Image(systemName: "clock.badge.exclamationmark")
                        .foregroundColor(.orange)
                    Text("Delayed: \(reason)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            HStack {
                Image(systemName: "eye.fill")
                    .foregroundColor(.green)
                Text("Real-time tracking active")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var statusColor: Color {
        switch run.status {
        case .scheduled:
            return .blue
        case .activeEnroute, .arrivedAtStop:
            return .green
        case .paused:
            return .orange
        case .completed:
            return .gray
        case .cancelled:
            return .red
        }
    }
    
    private func passengerStatusColor(_ status: PassengerStatus) -> Color {
        switch status {
        case .waiting:
            return .orange
        case .onboard:
            return .blue
        case .droppedOff:
            return .green
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

/// View that displays role-appropriate actions
struct RoleBasedActionsView: View {
    let actionSet: RunActionSet
    let roleContext: RoleContext
    let onDriverAction: (DriverAction) -> Void
    let onAdminAction: (AdminAction) -> Void
    let onObserverAction: (ObserverAction) -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Driver actions
            if !actionSet.driverActions.isEmpty {
                driverActionsSection
            }
            
            // Admin actions
            if !actionSet.adminActions.isEmpty {
                adminActionsSection
            }
            
            // Observer actions
            if !actionSet.observerActions.isEmpty {
                observerActionsSection
            }
        }
    }
    
    @ViewBuilder
    private var driverActionsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Driver Actions")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.blue)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(actionSet.driverActions, id: \.self) { action in
                    Button(action: {
                        onDriverAction(action)
                    }) {
                        Text(driverActionTitle(action))
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                    .roleBasedAction(action: action, roleContext: roleContext, isAvailable: true)
                }
            }
        }
    }
    
    @ViewBuilder
    private var adminActionsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Admin Actions")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.purple)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(actionSet.adminActions, id: \.self) { action in
                    Button(action: {
                        onAdminAction(action)
                    }) {
                        Text(adminActionTitle(action))
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.1))
                            .foregroundColor(.purple)
                            .cornerRadius(4)
                    }
                    .roleBasedAction(action: action, roleContext: roleContext, isAvailable: true)
                }
            }
        }
    }
    
    @ViewBuilder
    private var observerActionsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Observer Actions")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.green)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(actionSet.observerActions, id: \.self) { action in
                    Button(action: {
                        onObserverAction(action)
                    }) {
                        Text(action.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                    .roleBasedAction(action: action, roleContext: roleContext, isAvailable: true)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func driverActionTitle(_ action: DriverAction) -> String {
        switch action {
        case .startRun: return "Start"
        case .arriveStop: return "Arrive"
        case .confirmPickup: return "Pickup"
        case .confirmDropoff: return "Dropoff"
        case .nextStop: return "Next Stop"
        case .pauseRun: return "Pause"
        case .resumeRun: return "Resume"
        case .markDelayed: return "Mark Delayed"
        case .clearDelayed: return "Clear Delay"
        case .endRun: return "End Run"
        }
    }
    
    private func adminActionTitle(_ action: AdminAction) -> String {
        switch action {
        case .cancelRun: return "Cancel Run"
        case .reassignDriver: return "Reassign Driver"
        case .editRunDetails: return "Edit Details"
        }
    }
}