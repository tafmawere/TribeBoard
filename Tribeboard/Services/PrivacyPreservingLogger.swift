//
//  PrivacyPreservingLogger.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/04.
//

import Foundation
import os.log
import Combine

/// Privacy-preserving error logging service for TribeBoard
/// Logs all errors for debugging while maintaining user privacy
/// Implements error reporting without exposing sensitive data
/// Implements Requirement 9.5
@MainActor
class PrivacyPreservingLogger: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var logStatistics: LoggingStatistics = LoggingStatistics(
        totalEntries: 0,
        recentEntries: 0,
        errorCount: 0,
        warningCount: 0,
        oldestEntry: nil,
        newestEntry: nil
    )
    
    // MARK: - Private Properties
    
    private let logger = Logger(subsystem: "com.tribeboard.app", category: "ErrorLogging")
    private let maxLogEntries = 1000
    private var logEntries: [LogEntry] = []
    private let sensitiveDataPatterns = [
        "password", "token", "secret", "key", "auth",
        "email", "phone", "address", "location", "coordinate"
    ]
    
    // MARK: - Public Interface
    
    /// Log an error with privacy preservation
    /// Automatically sanitizes sensitive data before logging
    func logError(
        _ error: Error,
        context: LogContext,
        additionalInfo: [String: Any] = [:]
    ) {
        let sanitizedInfo = sanitizeData(additionalInfo)
        let sanitizedError = sanitizeError(error)
        
        let logEntry = LogEntry(
            id: UUID().uuidString,
            timestamp: Date(),
            level: .error,
            context: context,
            message: sanitizedError.localizedDescription,
            sanitizedData: sanitizedInfo,
            errorCode: getErrorCode(from: error),
            stackTrace: getStackTrace()
        )
        
        addLogEntry(logEntry)
        
        // Log to system logger
        logger.error("[\(context.rawValue)] \(sanitizedError.localizedDescription)")
    }
    
    /// Log a warning with privacy preservation
    func logWarning(
        message: String,
        context: LogContext,
        additionalInfo: [String: Any] = [:]
    ) {
        let sanitizedInfo = sanitizeData(additionalInfo)
        let sanitizedMessage = sanitizeString(message)
        
        let logEntry = LogEntry(
            id: UUID().uuidString,
            timestamp: Date(),
            level: .warning,
            context: context,
            message: sanitizedMessage,
            sanitizedData: sanitizedInfo,
            errorCode: nil,
            stackTrace: nil
        )
        
        addLogEntry(logEntry)
        
        // Log to system logger
        logger.warning("[\(context.rawValue)] \(sanitizedMessage)")
    }
    
    /// Log informational message with privacy preservation
    func logInfo(
        message: String,
        context: LogContext,
        additionalInfo: [String: Any] = [:]
    ) {
        let sanitizedInfo = sanitizeData(additionalInfo)
        let sanitizedMessage = sanitizeString(message)
        
        let logEntry = LogEntry(
            id: UUID().uuidString,
            timestamp: Date(),
            level: .info,
            context: context,
            message: sanitizedMessage,
            sanitizedData: sanitizedInfo,
            errorCode: nil,
            stackTrace: nil
        )
        
        addLogEntry(logEntry)
        
        // Log to system logger
        logger.info("[\(context.rawValue)] \(sanitizedMessage)")
    }
    
    /// Log debug information (only in debug builds)
    func logDebug(
        message: String,
        context: LogContext,
        additionalInfo: [String: Any] = [:]
    ) {
        #if DEBUG
        let sanitizedInfo = sanitizeData(additionalInfo)
        let sanitizedMessage = sanitizeString(message)
        
        let logEntry = LogEntry(
            id: UUID().uuidString,
            timestamp: Date(),
            level: .debug,
            context: context,
            message: sanitizedMessage,
            sanitizedData: sanitizedInfo,
            errorCode: nil,
            stackTrace: nil
        )
        
        addLogEntry(logEntry)
        
        // Log to system logger
        logger.debug("[\(context.rawValue)] \(sanitizedMessage)")
        #endif
    }
    
    /// Get sanitized log entries for debugging
    func getLogEntries(
        level: LogLevel? = nil,
        context: LogContext? = nil,
        limit: Int = 100
    ) -> [LogEntry] {
        var filteredEntries = logEntries
        
        if let level = level {
            filteredEntries = filteredEntries.filter { $0.level == level }
        }
        
        if let context = context {
            filteredEntries = filteredEntries.filter { $0.context == context }
        }
        
        return Array(filteredEntries.suffix(limit))
    }
    
    /// Export sanitized logs for debugging (removes all sensitive data)
    func exportSanitizedLogs() -> String {
        let entries = logEntries.suffix(500) // Last 500 entries
        
        var logOutput = "TribeBoard Error Log Export\n"
        logOutput += "Generated: \(Date())\n"
        logOutput += "Total Entries: \(entries.count)\n"
        logOutput += "Privacy Level: Full Sanitization\n\n"
        
        for entry in entries {
            logOutput += "[\(entry.timestamp)] [\(entry.level.rawValue.uppercased())] [\(entry.context.rawValue)]\n"
            logOutput += "Message: \(entry.message)\n"
            
            if !entry.sanitizedData.isEmpty {
                logOutput += "Data: \(entry.sanitizedData)\n"
            }
            
            if let errorCode = entry.errorCode {
                logOutput += "Error Code: \(errorCode)\n"
            }
            
            logOutput += "\n"
        }
        
        return logOutput
    }
    
    /// Clear old log entries to manage memory
    func clearOldLogs(olderThan timeInterval: TimeInterval = 604800) { // 7 days default
        let cutoffDate = Date().addingTimeInterval(-timeInterval)
        let initialCount = logEntries.count
        
        logEntries.removeAll { $0.timestamp < cutoffDate }
        
        let removedCount = initialCount - logEntries.count
        if removedCount > 0 {
            logInfo(
                message: "Cleared \(removedCount) old log entries",
                context: .system
            )
        }
    }
    
    /// Get logging statistics
    func getLoggingStatistics() -> LoggingStatistics {
        let now = Date()
        let last24Hours = now.addingTimeInterval(-86400)
        
        let recentEntries = logEntries.filter { $0.timestamp >= last24Hours }
        let errorCount = recentEntries.filter { $0.level == .error }.count
        let warningCount = recentEntries.filter { $0.level == .warning }.count
        
        return LoggingStatistics(
            totalEntries: logEntries.count,
            recentEntries: recentEntries.count,
            errorCount: errorCount,
            warningCount: warningCount,
            oldestEntry: logEntries.first?.timestamp,
            newestEntry: logEntries.last?.timestamp
        )
    }
    
    // MARK: - Private Methods
    
    private func addLogEntry(_ entry: LogEntry) {
        logEntries.append(entry)
        
        // Maintain maximum log entries
        if logEntries.count > maxLogEntries {
            logEntries.removeFirst(logEntries.count - maxLogEntries)
        }
    }
    
    private func sanitizeData(_ data: [String: Any]) -> [String: Any] {
        var sanitized: [String: Any] = [:]
        
        for (key, value) in data {
            let sanitizedKey = sanitizeString(key)
            
            if isSensitiveKey(key) {
                sanitized[sanitizedKey] = "[REDACTED]"
            } else {
                sanitized[sanitizedKey] = sanitizeValue(value)
            }
        }
        
        return sanitized
    }
    
    private func sanitizeValue(_ value: Any) -> Any {
        switch value {
        case let string as String:
            return sanitizeString(string)
        case let array as [Any]:
            return array.map { sanitizeValue($0) }
        case let dict as [String: Any]:
            return sanitizeData(dict)
        case let number as NSNumber:
            return number
        case let date as Date:
            return date.timeIntervalSince1970 // Convert to timestamp
        default:
            return String(describing: value)
        }
    }
    
    private func sanitizeString(_ string: String) -> String {
        var sanitized = string
        
        // Remove potential email addresses
        let emailRegex = try! NSRegularExpression(pattern: #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b"#)
        sanitized = emailRegex.stringByReplacingMatches(
            in: sanitized,
            range: NSRange(location: 0, length: sanitized.count),
            withTemplate: "[EMAIL]"
        )
        
        // Remove potential phone numbers
        let phoneRegex = try! NSRegularExpression(pattern: #"\b\d{3}[-.]?\d{3}[-.]?\d{4}\b"#)
        sanitized = phoneRegex.stringByReplacingMatches(
            in: sanitized,
            range: NSRange(location: 0, length: sanitized.count),
            withTemplate: "[PHONE]"
        )
        
        // Remove potential coordinates (latitude/longitude pairs)
        let coordRegex = try! NSRegularExpression(pattern: #"-?\d+\.\d+,\s*-?\d+\.\d+"#)
        sanitized = coordRegex.stringByReplacingMatches(
            in: sanitized,
            range: NSRange(location: 0, length: sanitized.count),
            withTemplate: "[COORDINATES]"
        )
        
        // Remove potential UUIDs (but keep first 8 characters for debugging)
        let uuidRegex = try! NSRegularExpression(pattern: #"\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b"#)
        sanitized = uuidRegex.stringByReplacingMatches(
            in: sanitized,
            range: NSRange(location: 0, length: sanitized.count),
            withTemplate: "[ID-$1****]"
        )
        
        return sanitized
    }
    
    private func sanitizeError(_ error: Error) -> Error {
        // Create a sanitized version of the error
        let sanitizedDescription = sanitizeString(error.localizedDescription)
        return SanitizedError(originalDescription: sanitizedDescription, code: getErrorCode(from: error))
    }
    
    private func isSensitiveKey(_ key: String) -> Bool {
        let lowercaseKey = key.lowercased()
        return sensitiveDataPatterns.contains { pattern in
            lowercaseKey.contains(pattern)
        }
    }
    
    private func getErrorCode(from error: Error) -> String? {
        if let nsError = error as NSError? {
            return "\(nsError.domain).\(nsError.code)"
        }
        
        if let firebaseError = error as? FirebaseError {
            return "Firebase.\(firebaseError)"
        }
        
        if let stateError = error as? StateTransitionError {
            return "StateTransition.\(stateError)"
        }
        
        return nil
    }
    
    private func getStackTrace() -> String? {
        #if DEBUG
        return Thread.callStackSymbols.prefix(10).joined(separator: "\n")
        #else
        return nil
        #endif
    }
}

// MARK: - Supporting Types

struct LogEntry: Identifiable {
    let id: String
    let timestamp: Date
    let level: LogLevel
    let context: LogContext
    let message: String
    let sanitizedData: [String: Any]
    let errorCode: String?
    let stackTrace: String?
}

enum LogLevel: String, CaseIterable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
}

enum LogContext: String, CaseIterable {
    case stateTransition = "StateTransition"
    case networkOperation = "NetworkOperation"
    case dataSync = "DataSync"
    case userInterface = "UserInterface"
    case errorRecovery = "ErrorRecovery"
    case authentication = "Authentication"
    case locationServices = "LocationServices"
    case appLifecycle = "AppLifecycle"
    case cacheManagement = "CacheManagement"
    case system = "System"
}

struct SanitizedError: LocalizedError {
    let originalDescription: String
    let code: String?
    
    var errorDescription: String? {
        return originalDescription
    }
}

struct LoggingStatistics {
    let totalEntries: Int
    let recentEntries: Int
    let errorCount: Int
    let warningCount: Int
    let oldestEntry: Date?
    let newestEntry: Date?
    
    var errorRate: Double {
        guard recentEntries > 0 else { return 0 }
        return Double(errorCount) / Double(recentEntries)
    }
}