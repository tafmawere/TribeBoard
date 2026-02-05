//
//  ObserverTrackingView.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/04.
//

import SwiftUI
import MapKit
import CoreLocation

/// Observer Tracking View for real-time monitoring
/// Implements Requirements 3.1, 3.2, 3.3, 3.4, 3.5 - real-time tracking interface with delay notifications
struct ObserverTrackingView: View {
    @StateObject private var viewModel: ObserverTrackingViewModel
    @StateObject private var delayNotificationService: DelayNotificationService
    @State private var showingContactDriver = false
    @State private var selectedEvent: RunEvent?
    @State private var showingDelayDetails = false
    @State private var selectedDelay: DelayNotification?
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    
    init(runId: String, runEventService: RunEventService, roleContext: RoleContext) {
        self._viewModel = StateObject(wrappedValue: ObserverTrackingViewModel(
            runId: runId,
            runEventService: runEventService,
            roleContext: roleContext
        ))
        self._delayNotificationService = StateObject(wrappedValue: DelayNotificationService(
            runEventService: runEventService
        ))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Connection Status Banner
                    if !viewModel.isConnected {
                        connectionStatusBanner
                    }
                    
                    // Active Delay Banner
                    if let currentDelay = delayNotificationService.getCurrentDelay(for: viewModel.runId) {
                        delayBanner(delay: currentDelay)
                    }
                    
                    // Run Status Header
                    runStatusHeader
                    
                    // Driver Location Map
                    driverLocationMap
                    
                    // Passenger Status Summary
                    passengerStatusSection
                    
                    // Delay Status Section (if delayed)
                    if delayNotificationService.getCurrentDelay(for: viewModel.runId) != nil {
                        delayStatusSection
                    }
                    
                    // Timeline Events
                    timelineEventsSection
                    
                    // Observer Actions
                    observerActionsSection
                }
                .padding()
            }
            .navigationTitle("Run Tracking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    refreshButton
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .alert("Error", isPresented: .constant(viewModel.error != nil)) {
                Button("OK") {
                    viewModel.error = nil
                }
            } message: {
                if let error = viewModel.error {
                    Text(error.localizedDescription)
                }
            }
            .sheet(isPresented: $showingContactDriver) {
                contactDriverSheet
            }
            .sheet(item: $selectedEvent) { event in
                eventDetailSheet(event: event)
            }
            .sheet(item: $selectedDelay) { delay in
                delayDetailSheet(delay: delay)
            }
        }
        .debugOverlay()
        .onAppear {
            updateMapRegion()
        }
        .task(id: viewModel.driverLocation) {
            updateMapRegion()
        }
    }
    
    // MARK: - Delay Banner
    
    private func delayBanner(delay: DelayNotification) -> some View {
        Button(action: {
            selectedDelay = delay
        }) {
            HStack {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Run Delayed")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(delay.reason)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(1)
                }
                
                Spacer()
                
                Text(delay.durationText)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(delay.severity.color))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Connection Status Banner
    
    private var connectionStatusBanner: some View {
        HStack {
            Image(systemName: "wifi.slash")
                .foregroundColor(.white)
            Text("Offline - Updates will sync when connected")
                .font(.caption)
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.orange)
        .cornerRadius(8)
    }
    
    // MARK: - Run Status Header
    
    private var runStatusHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let runInfo = viewModel.getCurrentRunInfo() {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(runInfo.run.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(runInfo.statusDescription)
                            .font(.subheadline)
                            .foregroundColor(statusColor(for: runInfo.run.status))
                        
                        if let eta = viewModel.eta {
                            let updatedETA = delayNotificationService.calculateUpdatedETA(for: viewModel.runId, originalETA: eta)
                            Text("ETA: \(formatTime(updatedETA))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(Int(runInfo.progress * 100))%")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Complete")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Progress Bar
                ProgressView(value: runInfo.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: statusColor(for: runInfo.run.status)))
                
                // Delay Information
                if runInfo.isDelayed, let reason = runInfo.delayReason {
                    HStack {
                        Image(systemName: "clock.badge.exclamationmark")
                            .foregroundColor(.orange)
                        Text("Delayed: \(reason)")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 4)
                }
            } else {
                Text("Loading run information...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Driver Location Map
    
    private var driverLocationMap: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Driver Location")
                    .font(.headline)
                
                Spacer()
                
                if let lastUpdate = viewModel.lastUpdateTime {
                    Text("Updated \(formatRelativeTime(lastUpdate))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Map(position: .constant(.region(mapRegion))) {
                // Driver location marker
                if let driverLocation = viewModel.driverLocation {
                    Marker("Driver", systemImage: "car.fill", coordinate: driverLocation)
                        .tint(.blue)
                }
                
                // Current run stops
                if let runInfo = viewModel.getCurrentRunInfo() {
                    ForEach(Array(runInfo.run.stops.enumerated()), id: \.element.id) { index, stop in
                        if index == runInfo.run.currentStopIndex {
                            Marker(stop.label, systemImage: "mappin.circle.fill", coordinate: stop.location.coordinate)
                                .tint(.green)
                        } else {
                            Marker(stop.label, systemImage: "mappin.circle", coordinate: stop.location.coordinate)
                                .tint(.orange)
                        }
                    }
                }
            }
            .frame(height: 200)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Delay Status Section
    
    private var delayStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Delay Information")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    if let delay = delayNotificationService.getCurrentDelay(for: viewModel.runId) {
                        selectedDelay = delay
                    }
                }) {
                    Text("Details")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            if let delaySummary = delayNotificationService.getDelayStatusSummary(for: viewModel.runId) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "clock.badge.exclamationmark")
                            .foregroundColor(Color(delaySummary.delay.severity.color))
                        
                        Text(delaySummary.statusText)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(delaySummary.delay.severity.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(delaySummary.delay.severity.color).opacity(0.2))
                            .foregroundColor(Color(delaySummary.delay.severity.color))
                            .cornerRadius(4)
                    }
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Updated ETA")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(formatTime(delaySummary.updatedETA))
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Impact")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text(delaySummary.impact.passengerImpact.displayName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Passenger Status Section
    
    private var passengerStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Passenger Status")
                .font(.headline)
            
            if let summary = viewModel.getPassengerStatusSummary() {
                VStack(spacing: 8) {
                    HStack {
                        Text(summary.statusText)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text("\(summary.droppedOff)/\(summary.total)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: summary.completionPercentage)
                        .progressViewStyle(LinearProgressViewStyle(tint: .green))
                    
                    HStack(spacing: 16) {
                        statusBadge(count: summary.waiting, label: "Waiting", color: .orange)
                        statusBadge(count: summary.onboard, label: "Onboard", color: .blue)
                        statusBadge(count: summary.droppedOff, label: "Delivered", color: .green)
                    }
                }
            } else {
                Text("No passenger information available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Timeline Events Section
    
    private var timelineEventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Timeline")
                    .font(.headline)
                
                Spacer()
                
                if viewModel.getUnacknowledgedEventsCount() > 0 {
                    Badge(count: viewModel.getUnacknowledgedEventsCount(), color: .red)
                }
            }
            
            LazyVStack(spacing: 8) {
                ForEach(viewModel.getGroupedTimelineEvents(), id: \.date) { group in
                    timelineGroupView(group: group)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Observer Actions Section
    
    private var observerActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Actions")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(viewModel.getAvailableObserverActions(), id: \.self) { action in
                    observerActionButton(action: action)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Views
    
    private var refreshButton: some View {
        Button(action: {
            Task {
                await viewModel.refresh()
            }
        }) {
            Image(systemName: "arrow.clockwise")
        }
        .disabled(viewModel.isLoading)
    }
    
    private func statusBadge(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func timelineGroupView(group: EventGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.dateString)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
            
            ForEach(group.events, id: \.id) { event in
                timelineEventRow(event: event)
            }
        }
    }
    
    private func timelineEventRow(event: RunEvent) -> some View {
        Button(action: {
            selectedEvent = event
        }) {
            HStack(spacing: 12) {
                eventIcon(for: event.type)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.type.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(formatTime(event.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let note = event.note {
                        Text(note)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                if !viewModel.acknowledgedEvents.contains(event.id) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func observerActionButton(action: ObserverAction) -> some View {
        Button(action: {
            handleObserverAction(action)
        }) {
            VStack(spacing: 8) {
                Image(systemName: iconName(for: action))
                    .font(.title2)
                    .foregroundColor(.blue)
                
                Text(action.displayName)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var contactDriverSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Contact Driver")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Choose how you'd like to contact the driver:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 12) {
                    Button(action: {
                        // Handle phone call
                        showingContactDriver = false
                    }) {
                        HStack {
                            Image(systemName: "phone.fill")
                            Text("Call Driver")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    
                    Button(action: {
                        // Handle message
                        showingContactDriver = false
                    }) {
                        HStack {
                            Image(systemName: "message.fill")
                            Text("Send Message")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showingContactDriver = false
                    }
                }
            }
        }
    }
    
    private func eventDetailSheet(event: RunEvent) -> some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    eventIcon(for: event.type)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.type.displayName)
                            .font(.headline)
                        
                        Text(formatFullDateTime(event.timestamp))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                if let note = event.note {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Details")
                            .font(.headline)
                        
                        Text(note)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let location = event.location {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location")
                            .font(.headline)
                        
                        Text("Lat: \(location.latitude, specifier: "%.6f"), Lng: \(location.longitude, specifier: "%.6f")")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    viewModel.acknowledgeUpdate()
                    selectedEvent = nil
                }) {
                    Text("Acknowledge")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding()
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        selectedEvent = nil
                    }
                }
            }
        }
    }
    
    private func delayDetailSheet(delay: DelayNotification) -> some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Delay Header
                HStack {
                    Image(systemName: "clock.badge.exclamationmark")
                        .font(.title2)
                        .foregroundColor(Color(delay.severity.color))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Run Delayed")
                            .font(.headline)
                        
                        Text("Started \(formatFullDateTime(delay.timestamp))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text(delay.severity.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(delay.severity.color).opacity(0.2))
                        .foregroundColor(Color(delay.severity.color))
                        .cornerRadius(6)
                }
                
                // Delay Information
                VStack(alignment: .leading, spacing: 12) {
                    Text("Delay Details")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Reason:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text(delay.reason)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Duration:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text(delay.durationText)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Estimated Impact:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            Text("\(Int(delay.estimatedDelay / 60)) min")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Impact Assessment
                if let summary = delayNotificationService.getDelayStatusSummary(for: delay.runId) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Impact Assessment")
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            HStack {
                                Text("Passenger Impact:")
                                    .font(.subheadline)
                                Spacer()
                                Text(summary.impact.passengerImpact.displayName)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Schedule Impact:")
                                    .font(.subheadline)
                                Spacer()
                                Text(summary.impact.scheduleImpact.displayName)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                Text("Recovery Time:")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(Int(summary.impact.estimatedRecoveryTime / 60)) min")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Actions
                VStack(spacing: 12) {
                    Button(action: {
                        viewModel.acknowledgeUpdate()
                        selectedDelay = nil
                    }) {
                        Text("Acknowledge Delay")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    if viewModel.canContactDriver() {
                        Button(action: {
                            selectedDelay = nil
                            showingContactDriver = true
                        }) {
                            Text("Contact Driver")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .padding()
            .navigationTitle("Delay Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        selectedDelay = nil
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateMapRegion() {
        if let driverLocation = viewModel.driverLocation {
            mapRegion = MKCoordinateRegion(
                center: driverLocation,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }
    
    private func handleObserverAction(_ action: ObserverAction) {
        switch action {
        case .viewDetails:
            // Handle view details
            break
        case .viewTimeline:
            // Handle view timeline
            break
        case .contactDriver:
            if viewModel.canContactDriver() {
                showingContactDriver = true
                viewModel.contactDriver()
            }
        case .acknowledgeUpdate:
            viewModel.acknowledgeUpdate()
        }
    }
    
    private func statusColor(for status: RunStatus) -> Color {
        switch status {
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
    
    private func eventIcon(for eventType: RunEventType) -> some View {
        let iconName: String
        let color: Color
        
        switch eventType {
        case .runCreated:
            iconName = "plus.circle.fill"
            color = .blue
        case .runStarted:
            iconName = "play.circle.fill"
            color = .green
        case .runArrivedStop:
            iconName = "mappin.circle.fill"
            color = .orange
        case .passengerPickedUp:
            iconName = "person.badge.plus"
            color = .blue
        case .passengerDroppedOff:
            iconName = "person.badge.minus"
            color = .green
        case .runDelayed:
            iconName = "clock.badge.exclamationmark"
            color = .orange
        case .runCompleted:
            iconName = "checkmark.circle.fill"
            color = .green
        case .runCancelled:
            iconName = "xmark.circle.fill"
            color = .red
        default:
            iconName = "circle.fill"
            color = .gray
        }
        
        return Image(systemName: iconName)
            .foregroundColor(color)
            .font(.title3)
    }
    
    private func iconName(for action: ObserverAction) -> String {
        switch action {
        case .viewDetails:
            return "info.circle"
        case .viewTimeline:
            return "clock"
        case .contactDriver:
            return "phone"
        case .acknowledgeUpdate:
            return "checkmark.circle"
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatFullDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatRelativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Supporting Types

extension Color {
    init(_ colorName: String) {
        switch colorName {
        case "yellow":
            self = .yellow
        case "orange":
            self = .orange
        case "red":
            self = .red
        default:
            self = .gray
        }
    }
}

struct Badge: View {
    let count: Int
    let color: Color
    
    var body: some View {
        Text("\(count)")
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color)
            .clipShape(Capsule())
    }
}

// MARK: - Preview

struct ObserverTrackingView_Previews: PreviewProvider {
    static var previews: some View {
        let mockFirebaseService = MockFirebaseRunService()
        let runEventService = RunEventService(firebaseService: mockFirebaseService)
        let roleContext = RoleContext(userId: "observer1", role: .observer, familyId: "family1")
        
        ObserverTrackingView(
            runId: "test-run",
            runEventService: runEventService,
            roleContext: roleContext
        )
    }
}