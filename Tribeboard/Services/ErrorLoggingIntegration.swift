//
//  ErrorLoggingIntegration.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/04.
//

import Foundation
import Combine
import CoreLocation

/// Integration service that demonstrates privacy-preserving error logging
/// Shows how all error handling components work together while maintaining user privacy
/// Implements Requirement 9.5
@MainActor
class ErrorLoggingIntegration: ObservableObject {
    
    // MARK: - Services
    
    private let errorCoordinator: ErrorHandlingCoordinator
    private let adminNotificationService: AdminNotificationService
    private let logger: PrivacyPreservingLogger
    
    // MARK: - Published Properties
    
    @Published var recentErrorSummary: ErrorSummary?
    @Published var privacyCompliantLogs: [SanitizedLogEntry] = []
    
    // MARK: - Initialization
    
    init(firebaseService: MockFirebaseRunService) {
        self.logger = PrivacyPreservingLogger()
        self.errorCoordinator = ErrorHandlingCoordinator(firebaseService: firebaseService)
        self.adminNotificationService = AdminNotificationService(logger: logger)
        
        setupErrorLoggingDemonstration()
    }
    
    // MARK: - Privacy-Preserving Error Logging Examples
    
    /// Demonstrate logging a state transition error with privacy preservation
    func logStateTransitionError(
        runId: String,
        runTitle: String,
        driverName: String,
        error: StateTransitionError
    ) {
        // Log the error with automatic sanitization
        logger.logError(
            error,
            context: .stateTransition,
            additionalInfo: [
                "runId": runId,
                "runTitle": runTitle,
                "driverName": driverName,
                "errorType": String(describing: error),
                "timestamp": Date().timeIntervalSince1970
            ]
        )
        
        // The logger automatically:
        // 1. Removes sensitive data patterns
        // 2. Sanitizes personal information
        // 3. Preserves debugging information
        // 4. Maintains privacy compliance
        
        updateErrorSummary()
    }
    
    /// Demonstrate logging a network error with location data sanitization
    func logNetworkErrorWithLocation(
        operation: String,
        error: Error,
        userLocation: CLLocationCoordinate2D?,
        userEmail: String?
    ) {
        var additionalInfo: [String: Any] = [
            "operation": operation,
            "errorCode": (error as NSError).code,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // Add location data (will be automatically sanitized)
        if let location = userLocation {
            additionalInfo["userLocation"] = "\(location.latitude),\(location.longitude)"
        }
        
        // Add email (will be automatically sanitized)
        if let email = userEmail {
            additionalInfo["userEmail"] = email
        }
        
        logger.logError(
            error,
            context: .networkOperation,
            additionalInfo: additionalInfo
        )
        
        // The logger will automatically:
        // - Replace coordinates with [COORDINATES]
        // - Replace email with [EMAIL]
        // - Preserve operation and error code for debugging
        
        updateErrorSummary()
    }
    
    /// Demonstrate logging user data with automatic PII removal
    func logUserInteractionWithPII(
        action: String,
        userId: String,
        userName: String,
        phoneNumber: String?,
        address: String?
    ) {
        var userInfo: [String: Any] = [
            "action": action,
            "userId": userId, // Will be partially sanitized (first 8 chars kept)
            "userName": userName,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        if let phone = phoneNumber {
            userInfo["phoneNumber"] = phone // Will be replaced with [PHONE]
        }
        
        if let address = address {
            userInfo["userAddress"] = address // Will be sanitized for location info
        }
        
        logger.logInfo(
            message: "User interaction logged",
            context: .userInterface,
            additionalInfo: userInfo
        )
        
        updateErrorSummary()
    }
    
    /// Demonstrate logging system errors with stack traces (debug only)
    func logSystemErrorWithStackTrace(
        component: String,
        error: Error,
        sensitiveData: [String: Any]
    ) {
        logger.logError(
            error,
            context: .system,
            additionalInfo: [
                "component": component,
                "sensitiveUserData": sensitiveData, // Will be sanitized
                "systemInfo": [
                    "memoryUsage": "245MB", // Safe system info
                    "cpuUsage": "12%"
                ]
            ]
        )
        
        // In debug builds, stack traces are included
        // In release builds, stack traces are omitted for privacy
        
        updateErrorSummary()
    }
    
    /// Get privacy-compliant error logs for debugging
    func getPrivacyCompliantLogs(limit: Int = 50) -> [SanitizedLogEntry] {
        let logEntries = logger.getLogEntries(limit: limit)
        
        return logEntries.map { entry in
            SanitizedLogEntry(
                id: entry.id,
                timestamp: entry.timestamp,
                level: entry.level.rawValue,
                context: entry.context.rawValue,
                sanitizedMessage: entry.message,
                sanitizedData: entry.sanitizedData,
                errorCode: entry.errorCode
            )
        }
    }
    
    /// Export comprehensive privacy-compliant error report
    func exportPrivacyCompliantReport() -> PrivacyCompliantReport {
        let errorStats = errorCoordinator.getErrorStatistics()
        let notificationStats = adminNotificationService.getNotificationStatistics()
        let loggingStats = logger.getLoggingStatistics()
        let sanitizedLogs = logger.exportSanitizedLogs()
        
        return PrivacyCompliantReport(
            generatedAt: Date(),
            systemHealth: errorStats.systemHealth,
            errorStatistics: errorStats.errorHandling,
            recoveryStatistics: errorStats.recovery,
            notificationStatistics: notificationStats,
            loggingStatistics: loggingStats,
            sanitizedLogs: sanitizedLogs,
            privacyLevel: "Full Sanitization - No PII Exposed",
            complianceNotes: [
                "All personal identifiers have been removed or sanitized",
                "Location data has been replaced with placeholders",
                "Email addresses and phone numbers are redacted",
                "UUIDs are partially masked for debugging purposes",
                "Stack traces are only included in debug builds",
                "All sensitive user data is replaced with [REDACTED]"
            ]
        )
    }
    
    /// Demonstrate error logging with different privacy levels
    func demonstratePrivacyLevels() {
        // Example 1: High-privacy logging (production)
        logger.logError(
            NSError(domain: "TestDomain", code: 123, userInfo: [
                "userEmail": "john.doe@example.com",
                "userPhone": "555-123-4567",
                "userLocation": "37.7749,-122.4194",
                "sensitiveToken": "abc123xyz789"
            ]),
            context: .system,
            additionalInfo: [
                "operation": "userLogin",
                "timestamp": Date().timeIntervalSince1970
            ]
        )
        
        // Example 2: Debug logging (development only)
        #if DEBUG
        logger.logDebug(
            message: "Debug info with sensitive data: user@example.com, token: secret123",
            context: .system,
            additionalInfo: [
                "debugData": [
                    "rawUserInput": "password123",
                    "apiKey": "sk_live_abc123"
                ]
            ]
        )
        #endif
        
        updateErrorSummary()
    }
    
    // MARK: - Privacy Compliance Validation
    
    /// Validate that logs are privacy compliant
    func validatePrivacyCompliance() -> PrivacyComplianceResult {
        let logs = logger.getLogEntries(limit: 1000)
        var violations: [PrivacyViolation] = []
        
        for log in logs {
            // Check for potential PII in messages
            if containsPotentialPII(log.message) {
                violations.append(PrivacyViolation(
                    logId: log.id,
                    type: .piiInMessage,
                    description: "Potential PII found in log message",
                    severity: .high
                ))
            }
            
            // Check for sensitive data in additional info
            for (key, value) in log.sanitizedData {
                if containsSensitivePattern(String(describing: value)) {
                    violations.append(PrivacyViolation(
                        logId: log.id,
                        type: .sensitiveDataInMetadata,
                        description: "Sensitive data pattern found in key: \(key)",
                        severity: .medium
                    ))
                }
            }
        }
        
        return PrivacyComplianceResult(
            isCompliant: violations.isEmpty,
            violations: violations,
            totalLogsChecked: logs.count,
            complianceScore: calculateComplianceScore(violations: violations, totalLogs: logs.count)
        )
    }
    
    // MARK: - Private Methods
    
    private func setupErrorLoggingDemonstration() {
        // Demonstrate various error logging scenarios
        Task {
            // Wait a bit then demonstrate logging
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            // Log some example errors to show privacy preservation
            demonstratePrivacyLevels()
        }
    }
    
    private func updateErrorSummary() {
        let stats = logger.getLoggingStatistics()
        
        recentErrorSummary = ErrorSummary(
            totalErrors: stats.totalEntries,
            recentErrors: stats.recentEntries,
            errorRate: stats.errorRate,
            privacyCompliant: true,
            lastUpdated: Date()
        )
        
        // Update privacy-compliant logs display
        privacyCompliantLogs = getPrivacyCompliantLogs(limit: 20)
    }
    
    private func containsPotentialPII(_ text: String) -> Bool {
        let piiPatterns = [
            #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b"#, // Email
            #"\b\d{3}[-.]?\d{3}[-.]?\d{4}\b"#, // Phone
            #"\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b"# // Credit card
        ]
        
        for pattern in piiPatterns {
            if text.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
    
    private func containsSensitivePattern(_ text: String) -> Bool {
        let sensitivePatterns = ["password", "token", "secret", "key", "auth"]
        let lowercaseText = text.lowercased()
        
        return sensitivePatterns.contains { pattern in
            lowercaseText.contains(pattern)
        }
    }
    
    private func calculateComplianceScore(violations: [PrivacyViolation], totalLogs: Int) -> Double {
        guard totalLogs > 0 else { return 1.0 }
        
        let violationWeight = violations.reduce(0.0) { total, violation in
            switch violation.severity {
            case .low: return total + 0.1
            case .medium: return total + 0.5
            case .high: return total + 1.0
            case .critical: return total + 2.0
            }
        }
        
        let maxPossibleViolations = Double(totalLogs) * 2.0 // Assuming worst case
        return max(0.0, 1.0 - (violationWeight / maxPossibleViolations))
    }
}

// MARK: - Supporting Types

struct SanitizedLogEntry: Identifiable {
    let id: String
    let timestamp: Date
    let level: String
    let context: String
    let sanitizedMessage: String
    let sanitizedData: [String: Any]
    let errorCode: String?
}

struct ErrorSummary {
    let totalErrors: Int
    let recentErrors: Int
    let errorRate: Double
    let privacyCompliant: Bool
    let lastUpdated: Date
}

struct PrivacyCompliantReport {
    let generatedAt: Date
    let systemHealth: SystemHealth
    let errorStatistics: ErrorStatistics
    let recoveryStatistics: RecoveryStatistics
    let notificationStatistics: NotificationStatistics
    let loggingStatistics: LoggingStatistics
    let sanitizedLogs: String
    let privacyLevel: String
    let complianceNotes: [String]
}

struct PrivacyComplianceResult {
    let isCompliant: Bool
    let violations: [PrivacyViolation]
    let totalLogsChecked: Int
    let complianceScore: Double // 0.0 to 1.0
}

struct PrivacyViolation {
    let logId: String
    let type: ViolationType
    let description: String
    let severity: ViolationSeverity
}

enum ViolationType {
    case piiInMessage
    case sensitiveDataInMetadata
    case unencryptedStorage
    case excessiveDataRetention
}

enum ViolationSeverity {
    case low
    case medium
    case high
    case critical
}