import Foundation
import OSLog

/// Centralized service for logging all calendar errors and analytics
/// This service eliminates error logging duplication across all calendar services
@MainActor
class CalendarErrorLogger: ObservableObject {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.tribeboard.calendar", category: "ErrorLogger")
    private let maxLogEntries = 1000
    private let logRetentionDays = 30
    
    @Published private(set) var errorHistory: [CalendarErrorLogEntry] = []
    @Published private(set) var errorStats: CalendarErrorStats = CalendarErrorStats()
    
    // MARK: - Singleton
    
    static let shared = CalendarErrorLogger()
    
    private init() {
        loadErrorHistory()
        cleanupOldEntries()
    }
    
    // MARK: - Error Logging
    
    /**
     * Logs a calendar error with context and debugging information
     * 
     * METHOD SIGNATURE DOCUMENTATION:
     * This method signature was corrected during compilation error fixes.
     * All calls to this method now use proper parameter labels:
     * 
     * Correct usage:
     *   CalendarErrorLogger.shared.logError(error, context: context)
     * 
     * The method requires:
     * - error: CalendarError (unlabeled first parameter)
     * - context: CalendarErrorContext (labeled parameter)
     * - file, function, line: Automatically captured for debugging
     */
    func logError(
        _ error: CalendarError,
        context: CalendarErrorContext,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let entry = CalendarErrorLogEntry(
            error: error,
            context: context,
            sourceFile: extractFileName(from: file),
            sourceFunction: function,
            sourceLine: line
        )
        
        // Add to history
        errorHistory.insert(entry, at: 0)
        
        // Maintain size limit
        if errorHistory.count > maxLogEntries {
            errorHistory = Array(errorHistory.prefix(maxLogEntries))
        }
        
        // Update statistics
        updateErrorStats(with: entry)
        
        // Log to system logger
        logToSystem(entry)
        
        // Save to persistent storage
        saveErrorHistory()
        
        // Send analytics if enabled
        sendErrorAnalytics(entry)
        
        print("🚨 CalendarErrorLogger: Logged \(error.category.displayName) error - \(error.localizedDescription)")
    }
    
    /// Logs a generic error with automatic categorization
    func logGenericError(
        _ error: Error,
        operation: String,
        userId: String? = nil,
        familyId: String? = nil,
        eventId: String? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let calendarError: CalendarError
        
        // Try to convert to CalendarError or create a generic one
        if let calError = error as? CalendarError {
            calendarError = calError
        } else {
            calendarError = .databaseOperationFailed(operation: operation, error: error.localizedDescription)
        }
        
        let context = CalendarErrorContext(
            userId: userId,
            familyId: familyId,
            eventId: eventId,
            operation: operation,
            additionalInfo: ["originalError": error.localizedDescription]
        )
        
        logError(calendarError, context: context, file: file, function: function, line: line)
    }
    
    // MARK: - Error Retrieval
    
    /// Gets error history filtered by criteria
    func getErrorHistory(
        category: CalendarErrorCategory? = nil,
        severity: CalendarErrorSeverity? = nil,
        userId: String? = nil,
        familyId: String? = nil,
        since: Date? = nil,
        limit: Int = 100
    ) -> [CalendarErrorLogEntry] {
        var filtered = errorHistory
        
        if let category = category {
            filtered = filtered.filter { $0.error.category == category }
        }
        
        if let severity = severity {
            filtered = filtered.filter { $0.error.severity == severity }
        }
        
        if let userId = userId {
            filtered = filtered.filter { $0.context.userId == userId }
        }
        
        if let familyId = familyId {
            filtered = filtered.filter { $0.context.familyId == familyId }
        }
        
        if let since = since {
            filtered = filtered.filter { $0.timestamp >= since }
        }
        
        return Array(filtered.prefix(limit))
    }
    
    /// Gets error statistics for a specific time period
    func getErrorStats(since: Date? = nil) -> CalendarErrorStats {
        let relevantEntries: [CalendarErrorLogEntry]
        
        if let since = since {
            relevantEntries = errorHistory.filter { $0.timestamp >= since }
        } else {
            relevantEntries = errorHistory
        }
        
        return calculateStats(from: relevantEntries)
    }
    
    /// Gets the most common errors
    func getMostCommonErrors(limit: Int = 10) -> [(CalendarError, Int)] {
        let errorCounts = Dictionary(grouping: errorHistory) { entry in
            entry.error.localizedDescription
        }.mapValues { $0.count }
        
        let sortedErrors = errorCounts.sorted { $0.value > $1.value }
        
        return Array(sortedErrors.prefix(limit)).compactMap { (description: String, count: Int) -> (CalendarError, Int)? in
            if let entry = errorHistory.first(where: { $0.error.localizedDescription == description }) {
                return (entry.error, count)
            }
            return nil
        }
    }
    
    /// Gets errors by user
    func getErrorsByUser() -> [String: Int] {
        return Dictionary(grouping: errorHistory.compactMap { (entry: CalendarErrorLogEntry) -> String? in entry.context.userId }) { $0 }
            .mapValues { $0.count }
    }
    
    /// Gets errors by family
    func getErrorsByFamily() -> [String: Int] {
        return Dictionary(grouping: errorHistory.compactMap { (entry: CalendarErrorLogEntry) -> String? in entry.context.familyId }) { $0 }
            .mapValues { $0.count }
    }
    
    // MARK: - Error Analysis
    
    /// Analyzes error patterns and provides insights
    func analyzeErrorPatterns() -> CalendarErrorAnalysis {
        let recentErrors = getErrorHistory(since: Calendar.current.date(byAdding: .day, value: -7, to: Date()))
        let stats = calculateStats(from: recentErrors)
        
        var insights: [String] = []
        var recommendations: [String] = []
        
        // Analyze error frequency
        if stats.totalErrors > 50 {
            insights.append("High error frequency detected (\(stats.totalErrors) errors in the last 7 days)")
            recommendations.append("Consider investigating system stability and user experience issues")
        }
        
        // Analyze error categories
        let categoryStats = stats.errorsByCategory
        if let topCategory = categoryStats.max(by: { $0.value < $1.value }) {
            insights.append("Most common error category: \(topCategory.key.displayName) (\(topCategory.value) errors)")
            
            switch topCategory.key {
            case .validation:
                recommendations.append("Review input validation and provide better user guidance")
            case .permission:
                recommendations.append("Review permission system and user onboarding")
            case .sync:
                recommendations.append("Investigate synchronization reliability and error handling")
            case .network:
                recommendations.append("Improve offline functionality and network error handling")
            case .data:
                recommendations.append("Review data integrity and backup procedures")
            default:
                recommendations.append("Focus on improving \(topCategory.key.displayName.lowercased()) error handling")
            }
        }
        
        // Analyze severity distribution
        let criticalErrors = recentErrors.filter { $0.error.severity == .critical }.count
        if criticalErrors > 0 {
            insights.append("Critical errors detected: \(criticalErrors)")
            recommendations.append("Prioritize fixing critical errors immediately")
        }
        
        // Analyze user impact
        let affectedUsers = Set(recentErrors.compactMap { $0.context.userId }).count
        if affectedUsers > 0 {
            insights.append("Errors affected \(affectedUsers) unique users")
            if affectedUsers > 10 {
                recommendations.append("Consider implementing proactive user communication about known issues")
            }
        }
        
        return CalendarErrorAnalysis(
            analysisDate: Date(),
            timeRange: Calendar.current.date(byAdding: .day, value: -7, to: Date())!...Date(),
            totalErrorsAnalyzed: recentErrors.count,
            insights: insights,
            recommendations: recommendations,
            stats: stats
        )
    }
    
    // MARK: - Error Recovery
    
    /// Provides recovery suggestions for a specific error
    func getRecoverySuggestions(for error: CalendarError) -> [CalendarErrorRecovery] {
        var suggestions: [CalendarErrorRecovery] = []
        
        switch error.category {
        case .validation:
            suggestions.append(CalendarErrorRecovery(
                title: "Fix Input Validation",
                description: error.recoverySuggestion ?? "Please correct the input and try again",
                action: .userAction,
                priority: .medium
            ))
            
        case .permission:
            suggestions.append(CalendarErrorRecovery(
                title: "Request Permissions",
                description: "Contact your family administrator to grant necessary permissions",
                action: .contactAdmin,
                priority: .high
            ))
            
        case .sync:
            suggestions.append(CalendarErrorRecovery(
                title: "Retry Synchronization",
                description: "Try syncing again or check your Apple Calendar settings",
                action: .retryOperation,
                priority: .medium
            ))
            
        case .network:
            suggestions.append(CalendarErrorRecovery(
                title: "Check Connection",
                description: "Verify your internet connection and try again",
                action: .checkNetwork,
                priority: .high
            ))
            
        case .data:
            suggestions.append(CalendarErrorRecovery(
                title: "Refresh Data",
                description: "Try refreshing the app or restarting to reload data",
                action: .refreshApp,
                priority: .high
            ))
            
        case .businessLogic:
            suggestions.append(CalendarErrorRecovery(
                title: "Adjust Request",
                description: error.recoverySuggestion ?? "Please modify your request and try again",
                action: .userAction,
                priority: .medium
            ))
            
        case .configuration:
            suggestions.append(CalendarErrorRecovery(
                title: "Check Settings",
                description: "Review app settings and configuration",
                action: .checkSettings,
                priority: .high
            ))
        }
        
        return suggestions
    }
    
    // MARK: - Cleanup and Maintenance
    
    /// Clears error history
    func clearErrorHistory() {
        errorHistory.removeAll()
        errorStats = CalendarErrorStats()
        saveErrorHistory()
        print("🧹 CalendarErrorLogger: Error history cleared")
    }
    
    /// Cleans up old error entries
    func cleanupOldEntries() {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -logRetentionDays, to: Date()) ?? Date()
        let originalCount = errorHistory.count
        
        errorHistory = errorHistory.filter { $0.timestamp >= cutoffDate }
        
        if errorHistory.count != originalCount {
            saveErrorHistory()
            print("🧹 CalendarErrorLogger: Cleaned up \(originalCount - errorHistory.count) old error entries")
        }
    }
    
    // MARK: - Private Methods
    
    private func updateErrorStats(with entry: CalendarErrorLogEntry) {
        errorStats.totalErrors += 1
        errorStats.errorsByCategory[entry.error.category, default: 0] += 1
        errorStats.errorsBySeverity[entry.error.severity, default: 0] += 1
        
        if let userId = entry.context.userId {
            errorStats.errorsByUser[userId, default: 0] += 1
        }
        
        if let familyId = entry.context.familyId {
            errorStats.errorsByFamily[familyId, default: 0] += 1
        }
        
        errorStats.lastUpdated = Date()
    }
    
    private func calculateStats(from entries: [CalendarErrorLogEntry]) -> CalendarErrorStats {
        var stats = CalendarErrorStats()
        
        stats.totalErrors = entries.count
        
        for entry in entries {
            stats.errorsByCategory[entry.error.category, default: 0] += 1
            stats.errorsBySeverity[entry.error.severity, default: 0] += 1
            
            if let userId = entry.context.userId {
                stats.errorsByUser[userId, default: 0] += 1
            }
            
            if let familyId = entry.context.familyId {
                stats.errorsByFamily[familyId, default: 0] += 1
            }
        }
        
        stats.lastUpdated = Date()
        return stats
    }
    
    private func logToSystem(_ entry: CalendarErrorLogEntry) {
        let message = """
        Calendar Error: \(entry.error.localizedDescription)
        Category: \(entry.error.category.displayName)
        Severity: \(entry.error.severity.displayName)
        Operation: \(entry.context.operation)
        Source: \(entry.sourceFile):\(entry.sourceLine) in \(entry.sourceFunction)
        """
        
        switch entry.error.severity {
        case .low:
            logger.info("\(message)")
        case .medium:
            logger.notice("\(message)")
        case .high:
            logger.error("\(message)")
        case .critical:
            logger.critical("\(message)")
        }
    }
    
    private func extractFileName(from path: String) -> String {
        return URL(fileURLWithPath: path).lastPathComponent
    }
    
    private func saveErrorHistory() {
        // In a real implementation, this would save to persistent storage
        // For now, we'll just log the action
        print("💾 CalendarErrorLogger: Saving error history (\(errorHistory.count) entries)")
    }
    
    private func loadErrorHistory() {
        // In a real implementation, this would load from persistent storage
        // For now, we'll start with empty history
        print("📂 CalendarErrorLogger: Loading error history")
    }
    
    private func sendErrorAnalytics(_ entry: CalendarErrorLogEntry) {
        // In a real implementation, this would send anonymized error data to analytics
        // For now, we'll just log the action
        print("📊 CalendarErrorLogger: Sending error analytics for \(entry.error.category.displayName) error")
    }
}

// MARK: - Supporting Types

struct CalendarErrorLogEntry: Identifiable, Codable {
    let id = UUID()
    let timestamp: Date
    let error: CalendarError
    let context: CalendarErrorContext
    let sourceFile: String
    let sourceFunction: String
    let sourceLine: Int
    
    init(
        error: CalendarError,
        context: CalendarErrorContext,
        sourceFile: String,
        sourceFunction: String,
        sourceLine: Int
    ) {
        self.timestamp = Date()
        self.error = error
        self.context = context
        self.sourceFile = sourceFile
        self.sourceFunction = sourceFunction
        self.sourceLine = sourceLine
    }
}

struct CalendarErrorStats: Codable {
    var totalErrors: Int = 0
    var errorsByCategory: [CalendarErrorCategory: Int] = [:]
    var errorsBySeverity: [CalendarErrorSeverity: Int] = [:]
    var errorsByUser: [String: Int] = [:]
    var errorsByFamily: [String: Int] = [:]
    var lastUpdated: Date = Date()
}

struct CalendarErrorAnalysis {
    let analysisDate: Date
    let timeRange: ClosedRange<Date>
    let totalErrorsAnalyzed: Int
    let insights: [String]
    let recommendations: [String]
    let stats: CalendarErrorStats
}

struct CalendarErrorRecovery {
    let title: String
    let description: String
    let action: CalendarErrorRecoveryAction
    let priority: CalendarErrorRecoveryPriority
}

enum CalendarErrorRecoveryAction {
    case userAction
    case retryOperation
    case contactAdmin
    case checkNetwork
    case refreshApp
    case checkSettings
    case restartApp
}

// Note: CalendarErrorRecoveryPriority is now defined in CalendarService.swift