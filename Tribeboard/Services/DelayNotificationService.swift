//
//  DelayNotificationService.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/04.
//

import Foundation
import Combine
import UserNotifications

/// Service for handling delay notifications and status updates
/// Implements Requirement 3.5 - delay notification and status updates
@MainActor
class DelayNotificationService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var activeDelays: [DelayNotification] = []
    @Published var delayHistory: [DelayNotification] = []
    @Published var isNotificationEnabled: Bool = false
    
    // MARK: - Private Properties
    
    private let runEventService: RunEventService
    private let notificationCenter = UNUserNotificationCenter.current()
    private var cancellables = Set<AnyCancellable>()
    
    // Delay tracking
    private var delayTimers: [String: Timer] = [:]
    private var etaCalculator: ETACalculator
    
    // MARK: - Initialization
    
    init(runEventService: RunEventService) {
        self.runEventService = runEventService
        self.etaCalculator = ETACalculator()
        
        setupNotificationPermissions()
        setupEventListeners()
    }
    
    // MARK: - Public Interface
    
    /// Handle delay event and notify observers
    /// Requirement 3.5
    func handleDelayEvent(_ event: RunEvent) {
        guard event.type == .runDelayed else { return }
        
        let delayNotification = DelayNotification(
            id: UUID().uuidString,
            runId: event.runId,
            reason: event.note ?? "Unspecified delay",
            timestamp: event.timestamp,
            estimatedDelay: calculateEstimatedDelay(for: event),
            severity: calculateDelaySeverity(for: event)
        )
        
        // Add to active delays
        activeDelays.append(delayNotification)
        
        // Send push notification
        sendDelayNotification(delayNotification)
        
        // Update ETA calculations
        updateETAForDelay(runId: event.runId, delay: delayNotification)
        
        // Start monitoring delay duration
        startDelayMonitoring(for: delayNotification)
    }
    
    /// Handle delay cleared event
    /// Requirement 3.5
    func handleDelayClearedEvent(_ event: RunEvent) {
        guard event.type == .runDelayCleared else { return }
        
        // Move delay from active to history
        if let index = activeDelays.firstIndex(where: { $0.runId == event.runId }) {
            var delayNotification = activeDelays.remove(at: index)
            delayNotification.clearedAt = event.timestamp
            delayNotification.actualDuration = event.timestamp.timeIntervalSince(delayNotification.timestamp)
            delayHistory.append(delayNotification)
            
            // Send delay cleared notification
            sendDelayClearedNotification(delayNotification)
            
            // Stop monitoring
            stopDelayMonitoring(for: event.runId)
            
            // Update ETA calculations
            updateETAForDelayClear(runId: event.runId)
        }
    }
    
    /// Get current delay for a run
    func getCurrentDelay(for runId: String) -> DelayNotification? {
        return activeDelays.first { $0.runId == runId }
    }
    
    /// Get delay history for a run
    func getDelayHistory(for runId: String) -> [DelayNotification] {
        return delayHistory.filter { $0.runId == runId }
    }
    
    /// Calculate updated ETA with delay
    func calculateUpdatedETA(for runId: String, originalETA: Date) -> Date {
        guard let delay = getCurrentDelay(for: runId) else {
            return originalETA
        }
        
        return etaCalculator.calculateUpdatedETA(
            originalETA: originalETA,
            delay: delay,
            currentTime: Date()
        )
    }
    
    /// Get delay status summary for observers
    func getDelayStatusSummary(for runId: String) -> DelayStatusSummary? {
        guard let delay = getCurrentDelay(for: runId) else { return nil }
        
        let duration = Date().timeIntervalSince(delay.timestamp)
        let impact = calculateDelayImpact(delay: delay, duration: duration)
        
        return DelayStatusSummary(
            delay: delay,
            currentDuration: duration,
            impact: impact,
            updatedETA: calculateUpdatedETA(for: runId, originalETA: Date().addingTimeInterval(600)) // Placeholder
        )
    }
    
    /// Request notification permissions
    func requestNotificationPermissions() async -> Bool {
        do {
            let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
            isNotificationEnabled = granted
            return granted
        } catch {
            print("Failed to request notification permissions: \(error)")
            return false
        }
    }
    
    /// Enable/disable delay notifications
    func setNotificationsEnabled(_ enabled: Bool) {
        isNotificationEnabled = enabled
        
        if !enabled {
            // Remove all pending delay notifications
            notificationCenter.removeAllPendingNotificationRequests()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupNotificationPermissions() {
        Task {
            let settings = await notificationCenter.notificationSettings()
            isNotificationEnabled = settings.authorizationStatus == .authorized
        }
    }
    
    private func setupEventListeners() {
        // Listen to delay events
        runEventService.eventPublisher
            .filter { $0.type == .runDelayed || $0.type == .runDelayCleared }
            .sink { [weak self] event in
                Task { @MainActor in
                    if event.type == .runDelayed {
                        self?.handleDelayEvent(event)
                    } else if event.type == .runDelayCleared {
                        self?.handleDelayClearedEvent(event)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func calculateEstimatedDelay(for event: RunEvent) -> TimeInterval {
        // Simple heuristic - could be enhanced with ML or historical data
        let baseDelay: TimeInterval = 300 // 5 minutes default
        
        // Adjust based on time of day, traffic patterns, etc.
        let hour = Calendar.current.component(.hour, from: event.timestamp)
        let trafficMultiplier: Double = (hour >= 7 && hour <= 9) || (hour >= 17 && hour <= 19) ? 1.5 : 1.0
        
        return baseDelay * trafficMultiplier
    }
    
    private func calculateDelaySeverity(for event: RunEvent) -> DelayNotification.Severity {
        let estimatedDelay = calculateEstimatedDelay(for: event)
        
        switch estimatedDelay {
        case 0..<300: // < 5 minutes
            return .minor
        case 300..<900: // 5-15 minutes
            return .moderate
        default: // > 15 minutes
            return .severe
        }
    }
    
    private func sendDelayNotification(_ delay: DelayNotification) {
        guard isNotificationEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Run Delayed"
        content.body = "Run is delayed: \(delay.reason)"
        content.sound = .default
        content.userInfo = [
            "runId": delay.runId,
            "delayId": delay.id,
            "type": "delay"
        ]
        
        // Set badge based on severity
        content.badge = NSNumber(value: delay.severity.badgeValue)
        
        let request = UNNotificationRequest(
            identifier: "delay-\(delay.id)",
            content: content,
            trigger: nil // Send immediately
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to send delay notification: \(error)")
            }
        }
    }
    
    private func sendDelayClearedNotification(_ delay: DelayNotification) {
        guard isNotificationEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Delay Cleared"
        content.body = "Run delay has been cleared"
        content.sound = .default
        content.userInfo = [
            "runId": delay.runId,
            "delayId": delay.id,
            "type": "delay_cleared"
        ]
        
        let request = UNNotificationRequest(
            identifier: "delay-cleared-\(delay.id)",
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to send delay cleared notification: \(error)")
            }
        }
    }
    
    private func updateETAForDelay(runId: String, delay: DelayNotification) {
        // Update ETA calculations for the run
        etaCalculator.addDelay(runId: runId, delay: delay)
    }
    
    private func updateETAForDelayClear(runId: String) {
        // Clear delay from ETA calculations
        etaCalculator.clearDelay(runId: runId)
    }
    
    private func startDelayMonitoring(for delay: DelayNotification) {
        // Start a timer to monitor delay duration and send periodic updates
        let timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.sendDelayUpdateNotification(delay)
            }
        }
        
        delayTimers[delay.runId] = timer
    }
    
    private func stopDelayMonitoring(for runId: String) {
        delayTimers[runId]?.invalidate()
        delayTimers.removeValue(forKey: runId)
    }
    
    private func sendDelayUpdateNotification(_ delay: DelayNotification) {
        guard isNotificationEnabled else { return }
        
        let duration = Date().timeIntervalSince(delay.timestamp)
        let minutes = Int(duration / 60)
        
        let content = UNMutableNotificationContent()
        content.title = "Delay Update"
        content.body = "Run has been delayed for \(minutes) minutes"
        content.sound = nil // Silent update
        content.userInfo = [
            "runId": delay.runId,
            "delayId": delay.id,
            "type": "delay_update",
            "duration": duration
        ]
        
        let request = UNNotificationRequest(
            identifier: "delay-update-\(delay.id)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        notificationCenter.add(request) { error in
            if let error = error {
                print("Failed to send delay update notification: \(error)")
            }
        }
    }
    
    private func calculateDelayImpact(delay: DelayNotification, duration: TimeInterval) -> DelayImpact {
        let _ = Int(duration / 60)
        
        switch delay.severity {
        case .minor:
            return DelayImpact(
                passengerImpact: .low,
                scheduleImpact: .minimal,
                estimatedRecoveryTime: 300 // 5 minutes
            )
        case .moderate:
            return DelayImpact(
                passengerImpact: .medium,
                scheduleImpact: .moderate,
                estimatedRecoveryTime: 600 // 10 minutes
            )
        case .severe:
            return DelayImpact(
                passengerImpact: .high,
                scheduleImpact: .significant,
                estimatedRecoveryTime: 1200 // 20 minutes
            )
        }
    }
}

// MARK: - Supporting Types

/// Delay notification information
struct DelayNotification: Identifiable, Codable {
    let id: String
    let runId: String
    let reason: String
    let timestamp: Date
    let estimatedDelay: TimeInterval
    let severity: Severity
    var clearedAt: Date?
    var actualDuration: TimeInterval?
    
    enum Severity: String, Codable, CaseIterable {
        case minor = "minor"
        case moderate = "moderate"
        case severe = "severe"
        
        var displayName: String {
            switch self {
            case .minor: return "Minor"
            case .moderate: return "Moderate"
            case .severe: return "Severe"
            }
        }
        
        var color: String {
            switch self {
            case .minor: return "yellow"
            case .moderate: return "orange"
            case .severe: return "red"
            }
        }
        
        var badgeValue: Int {
            switch self {
            case .minor: return 1
            case .moderate: return 2
            case .severe: return 3
            }
        }
    }
    
    var isActive: Bool {
        return clearedAt == nil
    }
    
    var durationText: String {
        let duration = actualDuration ?? Date().timeIntervalSince(timestamp)
        let minutes = Int(duration / 60)
        return "\(minutes) min"
    }
}

/// Delay status summary for observers
struct DelayStatusSummary {
    let delay: DelayNotification
    let currentDuration: TimeInterval
    let impact: DelayImpact
    let updatedETA: Date
    
    var statusText: String {
        let minutes = Int(currentDuration / 60)
        return "Delayed \(minutes) min - \(delay.reason)"
    }
}

/// Impact assessment of a delay
struct DelayImpact {
    let passengerImpact: ImpactLevel
    let scheduleImpact: ImpactLevel
    let estimatedRecoveryTime: TimeInterval
    
    enum ImpactLevel: String, CaseIterable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case minimal = "minimal"
        case moderate = "moderate"
        case significant = "significant"
        
        var displayName: String {
            return rawValue.capitalized
        }
    }
}

/// ETA Calculator for handling delay impacts
class ETACalculator {
    private var runDelays: [String: DelayNotification] = [:]
    
    func addDelay(runId: String, delay: DelayNotification) {
        runDelays[runId] = delay
    }
    
    func clearDelay(runId: String) {
        runDelays.removeValue(forKey: runId)
    }
    
    func calculateUpdatedETA(originalETA: Date, delay: DelayNotification, currentTime: Date) -> Date {
        // Simple calculation - add estimated delay to original ETA
        let additionalDelay = delay.estimatedDelay
        
        // Adjust based on how long the delay has been active
        let delayDuration = currentTime.timeIntervalSince(delay.timestamp)
        let adjustmentFactor = min(1.5, 1.0 + (delayDuration / 1800)) // Max 1.5x after 30 minutes
        
        return originalETA.addingTimeInterval(additionalDelay * adjustmentFactor)
    }
    
    func getDelayAdjustment(for runId: String) -> TimeInterval {
        guard let delay = runDelays[runId] else { return 0 }
        
        let delayDuration = Date().timeIntervalSince(delay.timestamp)
        let adjustmentFactor = min(1.5, 1.0 + (delayDuration / 1800))
        
        return delay.estimatedDelay * adjustmentFactor
    }
}