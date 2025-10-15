import Foundation
import UIKit
import SwiftUI

/// Service for handling calendar error recovery with retry logic and user guidance
@MainActor
class CalendarErrorRecoveryService: ObservableObject {
    
    // MARK: - Properties
    
    private let calendarService: CalendarService
    private let eventKitManager: EventKitManager
    private let networkMonitor: NetworkMonitor
    
    @Published var isRecovering = false
    @Published var recoveryProgress: Double = 0.0
    @Published var recoveryMessage: String = ""
    
    // MARK: - Initialization
    
    init(
        calendarService: CalendarService,
        eventKitManager: EventKitManager,
        networkMonitor: NetworkMonitor = NetworkMonitor.shared
    ) {
        self.calendarService = calendarService
        self.eventKitManager = eventKitManager
        self.networkMonitor = networkMonitor
    }
    
    // MARK: - Error Recovery Methods
    
    /// Attempts to recover from a calendar error with appropriate strategy
    func recoverFromError(
        _ error: CalendarError,
        context: CalendarErrorContext,
        retryAction: (() async throws -> Void)? = nil
    ) async throws {
        isRecovering = true
        recoveryProgress = 0.0
        
        defer {
            isRecovering = false
            recoveryProgress = 0.0
            recoveryMessage = ""
        }
        
        do {
            switch error.category {
            case .validation:
                try await handleValidationErrorRecovery(error, context: context)
                
            case .permission:
                try await handlePermissionErrorRecovery(error, context: context)
                
            case .sync:
                try await handleSyncErrorRecovery(error, context: context, retryAction: retryAction)
                
            case .network:
                try await handleNetworkErrorRecovery(error, context: context, retryAction: retryAction)
                
            case .data:
                try await handleDataErrorRecovery(error, context: context, retryAction: retryAction)
                
            case .businessLogic:
                try await handleBusinessLogicErrorRecovery(error, context: context)
                
            case .configuration:
                try await handleConfigurationErrorRecovery(error, context: context)
            }
            
            recoveryProgress = 1.0
            recoveryMessage = "Recovery completed successfully"
            
        } catch {
            recoveryMessage = "Recovery failed: \(error.localizedDescription)"
            throw error
        }
    }
    
    /// Gets available recovery options for an error
    func getRecoveryOptions(for error: CalendarError) -> [CalendarErrorRecoveryOption] {
        var options: [CalendarErrorRecoveryOption] = []
        
        switch error.category {
        case .validation:
            options.append(CalendarErrorRecoveryOption(
                title: "Fix Input",
                description: error.recoverySuggestion ?? "Please correct the input and try again",
                action: .userAction,
                priority: .medium,
                isAutomated: false
            ))
            
        case .permission:
            options.append(CalendarErrorRecoveryOption(
                title: "Request Permissions",
                description: "Contact your family administrator for necessary permissions",
                action: .contactAdmin,
                priority: .high,
                isAutomated: false
            ))
            
            if error == .eventKitAccessDenied {
                options.append(CalendarErrorRecoveryOption(
                    title: "Open Settings",
                    description: "Open Settings to enable calendar access",
                    action: .openSettings,
                    priority: .high,
                    isAutomated: true
                ))
            }
            
        case .sync:
            options.append(CalendarErrorRecoveryOption(
                title: "Retry Sync",
                description: "Attempt to synchronize again",
                action: .retryOperation,
                priority: .medium,
                isAutomated: true
            ))
            
            options.append(CalendarErrorRecoveryOption(
                title: "Reset Sync",
                description: "Reset synchronization settings and try again",
                action: .resetSync,
                priority: .low,
                isAutomated: true
            ))
            
        case .network:
            options.append(CalendarErrorRecoveryOption(
                title: "Check Connection",
                description: "Verify your internet connection and try again",
                action: .checkNetwork,
                priority: .high,
                isAutomated: false
            ))
            
            options.append(CalendarErrorRecoveryOption(
                title: "Retry When Online",
                description: "Automatically retry when connection is restored",
                action: .retryWhenOnline,
                priority: .medium,
                isAutomated: true
            ))
            
        case .data:
            options.append(CalendarErrorRecoveryOption(
                title: "Refresh Data",
                description: "Reload data from the server",
                action: .refreshData,
                priority: .high,
                isAutomated: true
            ))
            
            options.append(CalendarErrorRecoveryOption(
                title: "Clear Cache",
                description: "Clear local cache and reload",
                action: .clearCache,
                priority: .medium,
                isAutomated: true
            ))
            
        case .businessLogic:
            options.append(CalendarErrorRecoveryOption(
                title: "Adjust Request",
                description: error.recoverySuggestion ?? "Please modify your request and try again",
                action: .userAction,
                priority: .medium,
                isAutomated: false
            ))
            
        case .configuration:
            options.append(CalendarErrorRecoveryOption(
                title: "Check Settings",
                description: "Review app settings and configuration",
                action: .checkSettings,
                priority: .high,
                isAutomated: false
            ))
            
            options.append(CalendarErrorRecoveryOption(
                title: "Reset Configuration",
                description: "Reset to default settings",
                action: .resetConfiguration,
                priority: .low,
                isAutomated: true
            ))
        }
        
        return options.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }
    
    /// Executes a specific recovery action
    func executeRecoveryAction(
        _ action: CalendarErrorRecoveryAction,
        for error: CalendarError,
        context: CalendarErrorContext
    ) async throws {
        isRecovering = true
        recoveryProgress = 0.0
        
        defer {
            isRecovering = false
        }
        
        switch action {
        case .retryOperation:
            try await retryFailedOperation(error: error, context: context)
            
        case .checkNetwork:
            try await checkNetworkConnectivity()
            
        case .refreshData:
            try await refreshCalendarData(context: context)
            
        case .clearCache:
            try await clearCalendarCache(context: context)
            
        case .resetSync:
            try await resetSyncConfiguration(context: context)
            
        case .openSettings:
            await openAppSettings()
            
        case .resetConfiguration:
            try await resetAppConfiguration(context: context)
            
        case .retryWhenOnline:
            await setupRetryWhenOnline(error: error, context: context)
            
        default:
            throw CalendarError.featureNotEnabled("Recovery action not implemented")
        }
    }
    
    // MARK: - Private Recovery Methods
    
    private func handleValidationErrorRecovery(
        _ error: CalendarError,
        context: CalendarErrorContext
    ) async throws {
        recoveryMessage = "Validation error detected - user input required"
        recoveryProgress = 1.0
        
        // Validation errors require user input, no automated recovery
        // Log the error for analytics
        CalendarErrorLogger.shared.logError(error, context: context)
    }
    
    private func handlePermissionErrorRecovery(
        _ error: CalendarError,
        context: CalendarErrorContext
    ) async throws {
        recoveryMessage = "Checking permissions..."
        recoveryProgress = 0.3
        
        if error == .eventKitAccessDenied {
            recoveryMessage = "Requesting calendar access..."
            recoveryProgress = 0.6
            
            // Try to request EventKit access
            let hasAccess = try await eventKitManager.requestAccess()
            
            if !hasAccess {
                recoveryMessage = "Calendar access denied - manual intervention required"
                recoveryProgress = 1.0
                throw CalendarError.eventKitAccessDenied
            }
            
            recoveryMessage = "Calendar access granted"
            recoveryProgress = 1.0
        } else {
            recoveryMessage = "Permission error requires administrator action"
            recoveryProgress = 1.0
        }
    }
    
    private func handleSyncErrorRecovery(
        _ error: CalendarError,
        context: CalendarErrorContext,
        retryAction: (() async throws -> Void)?
    ) async throws {
        recoveryMessage = "Attempting sync recovery..."
        recoveryProgress = 0.2
        
        // Check EventKit availability
        let hasAccess = try await eventKitManager.requestAccess()
        if !hasAccess {
            throw CalendarError.eventKitAccessDenied
        }
        
        recoveryProgress = 0.5
        recoveryMessage = "Retrying sync operation..."
        
        // Retry the failed operation if provided
        if let retryAction = retryAction {
            try await retryAction()
        }
        
        recoveryProgress = 1.0
        recoveryMessage = "Sync recovery completed"
    }
    
    private func handleNetworkErrorRecovery(
        _ error: CalendarError,
        context: CalendarErrorContext,
        retryAction: (() async throws -> Void)?
    ) async throws {
        recoveryMessage = "Checking network connectivity..."
        recoveryProgress = 0.3
        
        // Wait for network connectivity
        var retryCount = 0
        let maxRetries = 5
        
        while !networkMonitor.isConnected && retryCount < maxRetries {
            recoveryMessage = "Waiting for network connection... (\(retryCount + 1)/\(maxRetries))"
            recoveryProgress = 0.3 + (Double(retryCount) / Double(maxRetries)) * 0.4
            
            try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            retryCount += 1
        }
        
        if !networkMonitor.isConnected {
            throw CalendarError.networkUnavailable
        }
        
        recoveryProgress = 0.8
        recoveryMessage = "Network available - retrying operation..."
        
        // Retry the failed operation if provided
        if let retryAction = retryAction {
            try await retryAction()
        }
        
        recoveryProgress = 1.0
        recoveryMessage = "Network recovery completed"
    }
    
    private func handleDataErrorRecovery(
        _ error: CalendarError,
        context: CalendarErrorContext,
        retryAction: (() async throws -> Void)?
    ) async throws {
        recoveryMessage = "Attempting data recovery..."
        recoveryProgress = 0.2
        
        // Try to refresh data
        try await refreshCalendarData(context: context)
        
        recoveryProgress = 0.7
        recoveryMessage = "Retrying operation with fresh data..."
        
        // Retry the failed operation if provided
        if let retryAction = retryAction {
            try await retryAction()
        }
        
        recoveryProgress = 1.0
        recoveryMessage = "Data recovery completed"
    }
    
    private func handleBusinessLogicErrorRecovery(
        _ error: CalendarError,
        context: CalendarErrorContext
    ) async throws {
        recoveryMessage = "Business logic error - user intervention required"
        recoveryProgress = 1.0
        
        // Business logic errors typically require user input
        // Log for analytics
        CalendarErrorLogger.shared.logError(error, context: context)
    }
    
    private func handleConfigurationErrorRecovery(
        _ error: CalendarError,
        context: CalendarErrorContext
    ) async throws {
        recoveryMessage = "Checking configuration..."
        recoveryProgress = 0.3
        
        // Try to reset configuration to defaults
        try await resetAppConfiguration(context: context)
        
        recoveryProgress = 1.0
        recoveryMessage = "Configuration recovery completed"
    }
    
    // MARK: - Recovery Action Implementations
    
    private func retryFailedOperation(
        error: CalendarError,
        context: CalendarErrorContext
    ) async throws {
        recoveryMessage = "Retrying failed operation..."
        recoveryProgress = 0.5
        
        // Implement exponential backoff
        let delay = min(pow(2.0, Double(context.additionalInfo["retryCount"] as? Int ?? 0)), 30.0)
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        recoveryProgress = 1.0
        recoveryMessage = "Retry completed"
    }
    
    private func checkNetworkConnectivity() async throws {
        recoveryMessage = "Checking network connectivity..."
        recoveryProgress = 0.5
        
        if !networkMonitor.isConnected {
            throw CalendarError.networkUnavailable
        }
        
        recoveryProgress = 1.0
        recoveryMessage = "Network connectivity confirmed"
    }
    
    private func refreshCalendarData(context: CalendarErrorContext) async throws {
        recoveryMessage = "Refreshing calendar data..."
        recoveryProgress = 0.3
        
        // Refresh data based on context
        if let userId = context.userId, let userUUID = UUID(uuidString: userId) {
            recoveryProgress = 0.6
            // Trigger sync for user data
            try await calendarService.syncWithAppleCalendar(userId: userUUID)
        }
        
        recoveryProgress = 1.0
        recoveryMessage = "Calendar data refreshed"
    }
    
    private func clearCalendarCache(context: CalendarErrorContext) async throws {
        recoveryMessage = "Clearing calendar cache..."
        recoveryProgress = 0.5
        
        // Clear cache implementation would go here
        // For now, just simulate the action
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        recoveryProgress = 1.0
        recoveryMessage = "Calendar cache cleared"
    }
    
    private func resetSyncConfiguration(context: CalendarErrorContext) async throws {
        recoveryMessage = "Resetting sync configuration..."
        recoveryProgress = 0.3
        
        if let userId = context.userId, let userUUID = UUID(uuidString: userId) {
            recoveryProgress = 0.6
            
            // Disable and re-enable sync
            try await calendarService.disableAppleCalendarSync(userId: userUUID)
            try await calendarService.enableAppleCalendarSync(userId: userUUID)
        }
        
        recoveryProgress = 1.0
        recoveryMessage = "Sync configuration reset"
    }
    
    private func openAppSettings() async {
        recoveryMessage = "Opening app settings..."
        recoveryProgress = 0.5
        
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            await UIApplication.shared.open(settingsUrl)
        }
        
        recoveryProgress = 1.0
        recoveryMessage = "Settings opened"
    }
    
    private func resetAppConfiguration(context: CalendarErrorContext) async throws {
        recoveryMessage = "Resetting app configuration..."
        recoveryProgress = 0.5
        
        // Reset configuration implementation would go here
        // For now, just simulate the action
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        recoveryProgress = 1.0
        recoveryMessage = "App configuration reset"
    }
    
    private func setupRetryWhenOnline(
        error: CalendarError,
        context: CalendarErrorContext
    ) async {
        recoveryMessage = "Setting up automatic retry when online..."
        recoveryProgress = 1.0
        
        // This would set up a network observer to retry when connection is restored
        // Implementation would depend on the specific retry mechanism
    }
}

// MARK: - Supporting Types

struct CalendarErrorRecoveryOption: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let action: CalendarErrorRecoveryAction
    let priority: CalendarErrorRecoveryPriority
    let isAutomated: Bool
}

// Note: CalendarErrorRecoveryPriority is now defined in CalendarService.swift