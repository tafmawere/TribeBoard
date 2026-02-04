//
//  AdminNotificationService.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/04.
//

import Foundation
import Combine
import UserNotifications

/// Service responsible for notifying admins when automatic recovery fails
/// Provides escalation mechanisms and admin resolution interfaces
/// Implements Requirements 9.3, 9.4
@MainActor
class AdminNotificationService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var pendingNotifications: [AdminNotification] = []
    @Published var notificationHistory: [AdminNotification] = []
    @Published var isNotificationEnabled: Bool = true
    
    // MARK: - Private Properties
    
    private let logger: PrivacyPreservingLogger
    private let maxPendingNotifications = 50
    private let notificationRetryInterval: TimeInterval = 300 // 5 minutes
    private var retryTimers: [String: Timer] = [:]
    
    // MARK: - Initialization
    
    init(logger: PrivacyPreservingLogger) {
        self.logger = logger
        requestNotificationPermissions()
    }
    
    // MARK: - Admin Notification
    
    /// Notify admins when automatic recovery fails
    /// Implements Requirement 9.3
    func notifyAdminsOfRecoveryFailure(
        escalation: EscalatedIssue,
        runTitle: String,
        driverName: String
    ) async {
        let notification = AdminNotification(
            id: UUID().uuidString,
            type: .recoveryFailure,
            title: "Run Recovery Failed",
            message: "Automatic recovery failed for run '\(runTitle)' driven by \(driverName)",
            severity: .high,
            runId: escalation.runId,
            escalationId: escalation.id,
            timestamp: Date(),
            status: .pending,
            retryCount: 0,
            metadata: [
                "runTitle": runTitle,
                "driverName": driverName,
                "inconsistencyCount": escalation.inconsistencies.count,
                "recoveryAttemptId": escalation.recoveryAttemptId
            ]
        )
        
        await sendNotification(notification)
    }
    
    /// Notify admins of critical system errors
    func notifyAdminsOfCriticalError(
        error: Error,
        context: String,
        runId: String? = nil
    ) async {
        let notification = AdminNotification(
            id: UUID().uuidString,
            type: .criticalError,
            title: "Critical System Error",
            message: "A critical error occurred in \(context)",
            severity: .critical,
            runId: runId,
            escalationId: nil,
            timestamp: Date(),
            status: .pending,
            retryCount: 0,
            metadata: [
                "context": context,
                "errorDescription": error.localizedDescription
            ]
        )
        
        await sendNotification(notification)
    }
    
    /// Notify admins of state inconsistencies that require manual intervention
    func notifyAdminsOfStateInconsistency(
        runId: String,
        runTitle: String,
        inconsistencies: [StateInconsistency]
    ) async {
        let highSeverityCount = inconsistencies.filter { $0.severity == .high || $0.severity == .critical }.count
        
        let notification = AdminNotification(
            id: UUID().uuidString,
            type: .stateInconsistency,
            title: "State Inconsistency Detected",
            message: "Run '\(runTitle)' has \(inconsistencies.count) state inconsistencies (\(highSeverityCount) high priority)",
            severity: highSeverityCount > 0 ? .high : .medium,
            runId: runId,
            escalationId: nil,
            timestamp: Date(),
            status: .pending,
            retryCount: 0,
            metadata: [
                "runTitle": runTitle,
                "inconsistencyCount": inconsistencies.count,
                "highSeverityCount": highSeverityCount,
                "inconsistencyTypes": inconsistencies.map { String(describing: $0.type) }
            ]
        )
        
        await sendNotification(notification)
    }
    
    /// Notify admins when a run is stuck in an invalid state
    func notifyAdminsOfStuckRun(
        runId: String,
        runTitle: String,
        currentState: RunStatus,
        stuckDuration: TimeInterval
    ) async {
        let notification = AdminNotification(
            id: UUID().uuidString,
            type: .stuckRun,
            title: "Run Stuck in State",
            message: "Run '\(runTitle)' has been stuck in \(currentState.displayName) for \(Int(stuckDuration/60)) minutes",
            severity: stuckDuration > 3600 ? .high : .medium, // High if stuck for over 1 hour
            runId: runId,
            escalationId: nil,
            timestamp: Date(),
            status: .pending,
            retryCount: 0,
            metadata: [
                "runTitle": runTitle,
                "currentState": currentState.rawValue,
                "stuckDurationMinutes": Int(stuckDuration/60)
            ]
        )
        
        await sendNotification(notification)
    }
    
    // MARK: - Notification Management
    
    /// Mark notification as acknowledged by admin
    func acknowledgeNotification(_ notificationId: String, adminId: String) {
        if let index = pendingNotifications.firstIndex(where: { $0.id == notificationId }) {
            var notification = pendingNotifications[index]
            notification.status = .acknowledged
            notification.acknowledgedBy = adminId
            notification.acknowledgedAt = Date()
            
            // Move to history
            notificationHistory.append(notification)
            pendingNotifications.remove(at: index)
            
            // Cancel retry timer if exists
            retryTimers[notificationId]?.invalidate()
            retryTimers.removeValue(forKey: notificationId)
            
            logger.logInfo(
                message: "Admin notification acknowledged",
                context: .system,
                additionalInfo: [
                    "notificationId": notificationId,
                    "adminId": adminId,
                    "notificationType": notification.type.rawValue
                ]
            )
        }
    }
    
    /// Mark notification as resolved
    func resolveNotification(_ notificationId: String, adminId: String, resolution: String) {
        if let index = pendingNotifications.firstIndex(where: { $0.id == notificationId }) {
            var notification = pendingNotifications[index]
            notification.status = .resolved
            notification.resolvedBy = adminId
            notification.resolvedAt = Date()
            notification.resolution = resolution
            
            // Move to history
            notificationHistory.append(notification)
            pendingNotifications.remove(at: index)
            
            // Cancel retry timer if exists
            retryTimers[notificationId]?.invalidate()
            retryTimers.removeValue(forKey: notificationId)
            
            logger.logInfo(
                message: "Admin notification resolved",
                context: .system,
                additionalInfo: [
                    "notificationId": notificationId,
                    "adminId": adminId,
                    "resolution": resolution
                ]
            )
        }
    }
    
    /// Get notifications for a specific admin based on their permissions
    func getNotificationsForAdmin(adminId: String, permissions: AdminPermissions) -> [AdminNotification] {
        return pendingNotifications.filter { notification in
            switch notification.type {
            case .recoveryFailure:
                return permissions.canHandleRecoveryFailures
            case .criticalError:
                return permissions.canHandleCriticalErrors
            case .stateInconsistency:
                return permissions.canHandleStateInconsistencies
            case .stuckRun:
                return permissions.canHandleStuckRuns
            case .systemHealth:
                return permissions.canViewSystemHealth
            }
        }.sorted { $0.timestamp > $1.timestamp }
    }
    
    /// Get notification statistics
    func getNotificationStatistics() -> NotificationStatistics {
        let now = Date()
        let last24Hours = now.addingTimeInterval(-86400)
        
        let recentNotifications = notificationHistory.filter { $0.timestamp >= last24Hours }
        let criticalCount = pendingNotifications.filter { $0.severity == .critical }.count
        let highCount = pendingNotifications.filter { $0.severity == .high }.count
        
        let averageResponseTime = calculateAverageResponseTime()
        
        return NotificationStatistics(
            totalPending: pendingNotifications.count,
            criticalPending: criticalCount,
            highPriorityPending: highCount,
            recentNotifications: recentNotifications.count,
            averageResponseTime: averageResponseTime,
            oldestPendingAge: pendingNotifications.min(by: { $0.timestamp < $1.timestamp })?.age
        )
    }
    
    // MARK: - Private Methods
    
    private func sendNotification(_ notification: AdminNotification) async {
        guard isNotificationEnabled else {
            logger.logInfo(
                message: "Notification skipped - notifications disabled",
                context: .system,
                additionalInfo: ["notificationId": notification.id]
            )
            return
        }
        
        // Add to pending notifications
        pendingNotifications.append(notification)
        
        // Maintain maximum pending notifications
        if pendingNotifications.count > maxPendingNotifications {
            let oldestNotification = pendingNotifications.min(by: { $0.timestamp < $1.timestamp })
            if let oldest = oldestNotification {
                pendingNotifications.removeAll { $0.id == oldest.id }
                logger.logWarning(
                    message: "Removed oldest pending notification due to limit",
                    context: .system,
                    additionalInfo: ["removedNotificationId": oldest.id]
                )
            }
        }
        
        // Send push notification
        await sendPushNotification(notification)
        
        // Setup retry timer for unacknowledged notifications
        setupRetryTimer(for: notification)
        
        logger.logInfo(
            message: "Admin notification sent",
            context: .system,
            additionalInfo: [
                "notificationId": notification.id,
                "type": notification.type.rawValue,
                "severity": notification.severity.rawValue
            ]
        )
    }
    
    private func sendPushNotification(_ notification: AdminNotification) async {
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.message
        content.sound = notification.severity == .critical ? .defaultCritical : .default
        content.categoryIdentifier = "ADMIN_NOTIFICATION"
        content.userInfo = [
            "notificationId": notification.id,
            "type": notification.type.rawValue,
            "severity": notification.severity.rawValue,
            "runId": notification.runId ?? "",
            "escalationId": notification.escalationId ?? ""
        ]
        
        // Set badge number based on pending critical notifications
        let criticalCount = pendingNotifications.filter { $0.severity == .critical }.count
        content.badge = NSNumber(value: criticalCount)
        
        let request = UNNotificationRequest(
            identifier: notification.id,
            content: content,
            trigger: nil // Immediate delivery
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            logger.logError(
                error,
                context: .system,
                additionalInfo: ["notificationId": notification.id]
            )
        }
    }
    
    private func setupRetryTimer(for notification: AdminNotification) {
        let timer = Timer.scheduledTimer(withTimeInterval: notificationRetryInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.retryNotification(notification.id)
            }
        }
        retryTimers[notification.id] = timer
    }
    
    private func retryNotification(_ notificationId: String) async {
        guard let index = pendingNotifications.firstIndex(where: { $0.id == notificationId }) else {
            return
        }
        
        var notification = pendingNotifications[index]
        
        // Only retry if still pending and under retry limit
        guard notification.status == .pending && notification.retryCount < 3 else {
            return
        }
        
        notification.retryCount += 1
        pendingNotifications[index] = notification
        
        // Send retry notification
        await sendPushNotification(notification)
        
        // Setup next retry if needed
        if notification.retryCount < 3 {
            setupRetryTimer(for: notification)
        }
        
        logger.logInfo(
            message: "Admin notification retry sent",
            context: .system,
            additionalInfo: [
                "notificationId": notificationId,
                "retryCount": notification.retryCount
            ]
        )
    }
    
    private func requestNotificationPermissions() {
        Task {
            let center = UNUserNotificationCenter.current()
            
            do {
                let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                await MainActor.run {
                    self.isNotificationEnabled = granted
                }
                
                if granted {
                    logger.logInfo(message: "Notification permissions granted", context: .system)
                } else {
                    logger.logWarning(message: "Notification permissions denied", context: .system)
                }
            } catch {
                logger.logError(error, context: .system)
            }
        }
    }
    
    private func calculateAverageResponseTime() -> TimeInterval {
        let resolvedNotifications = notificationHistory.filter { 
            $0.status == .resolved && $0.acknowledgedAt != nil 
        }
        
        guard !resolvedNotifications.isEmpty else { return 0 }
        
        let totalResponseTime = resolvedNotifications.reduce(0.0) { total, notification in
            guard let acknowledgedAt = notification.acknowledgedAt else { return total }
            return total + acknowledgedAt.timeIntervalSince(notification.timestamp)
        }
        
        return totalResponseTime / Double(resolvedNotifications.count)
    }
    
    deinit {
        retryTimers.values.forEach { $0.invalidate() }
        retryTimers.removeAll()
    }
}

// MARK: - Supporting Types

struct AdminNotification: Identifiable {
    let id: String
    let type: NotificationType
    let title: String
    let message: String
    let severity: NotificationSeverity
    let runId: String?
    let escalationId: String?
    let timestamp: Date
    var status: NotificationStatus
    var retryCount: Int
    let metadata: [String: Any]
    
    // Resolution tracking
    var acknowledgedBy: String?
    var acknowledgedAt: Date?
    var resolvedBy: String?
    var resolvedAt: Date?
    var resolution: String?
    
    var age: TimeInterval {
        Date().timeIntervalSince(timestamp)
    }
}

enum NotificationType: String, CaseIterable {
    case recoveryFailure = "recoveryFailure"
    case criticalError = "criticalError"
    case stateInconsistency = "stateInconsistency"
    case stuckRun = "stuckRun"
    case systemHealth = "systemHealth"
}

enum NotificationSeverity: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "gray"
        case .medium: return "yellow"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}

enum NotificationStatus: String, CaseIterable {
    case pending = "pending"
    case acknowledged = "acknowledged"
    case resolved = "resolved"
    case expired = "expired"
}

struct AdminPermissions {
    let canHandleRecoveryFailures: Bool
    let canHandleCriticalErrors: Bool
    let canHandleStateInconsistencies: Bool
    let canHandleStuckRuns: Bool
    let canViewSystemHealth: Bool
    
    static let fullPermissions = AdminPermissions(
        canHandleRecoveryFailures: true,
        canHandleCriticalErrors: true,
        canHandleStateInconsistencies: true,
        canHandleStuckRuns: true,
        canViewSystemHealth: true
    )
    
    static let limitedPermissions = AdminPermissions(
        canHandleRecoveryFailures: false,
        canHandleCriticalErrors: true,
        canHandleStateInconsistencies: true,
        canHandleStuckRuns: true,
        canViewSystemHealth: true
    )
}

struct NotificationStatistics {
    let totalPending: Int
    let criticalPending: Int
    let highPriorityPending: Int
    let recentNotifications: Int
    let averageResponseTime: TimeInterval
    let oldestPendingAge: TimeInterval?
    
    var hasUrgentNotifications: Bool {
        return criticalPending > 0 || (oldestPendingAge ?? 0) > 3600 // 1 hour
    }
}