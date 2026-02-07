//
//  AppLifecycleManager.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/04.
//

import Foundation
import SwiftUI
import Combine

/// Manages application lifecycle events and state restoration
/// Implements Requirements 10.5 - handle app restart state restoration
@MainActor
class AppLifecycleManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var appState: AppState = .launching
    @Published var isRestoringState = false
    
    // MARK: - Dependencies
    
    private let dependencyContainer: DependencyContainer
    private let logger: PrivacyPreservingLogger
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private let appStateKey = "TribeBoard_AppState"
    private let lastActiveRunKey = "TribeBoard_LastActiveRun"
    private let lastScreenKey = "TribeBoard_LastScreen"
    
    // MARK: - Initialization
    
    init(dependencyContainer: DependencyContainer) {
        self.dependencyContainer = dependencyContainer
        self.logger = dependencyContainer.privacyPreservingLogger
        
        setupLifecycleObservers()
    }
    
    // MARK: - Public Interface
    
    /// Handle app launch and state restoration
    func handleAppLaunch() async {
        appState = .launching
        isRestoringState = true
        
        logger.logInfo(
            message: "App launching - starting state restoration",
            context: .appLifecycle,
            additionalInfo: [:]
        )
        
        // Step 1: Restore cache and data
        dependencyContainer.cacheManagementService.restoreAppState()
        
        // Step 2: Restore user session
        await restoreUserSession()
        
        // Step 3: Restore navigation state
        await restoreNavigationState()
        
        // Step 4: Restore active runs
        await restoreActiveRuns()
        
        // Step 5: Initialize real-time services
        await initializeRealTimeServices()
        
        appState = .active
        
        logger.logInfo(
            message: "App launch and state restoration completed successfully",
            context: .appLifecycle,
            additionalInfo: ["finalState": appState.rawValue]
        )
        
        isRestoringState = false
    }
    
    /// Handle app entering background
    func handleAppDidEnterBackground() {
        appState = .background
        
        logger.logInfo(
            message: "App entering background - saving state",
            context: .appLifecycle,
            additionalInfo: [:]
        )
        
        Task { @MainActor in
            await saveAppState()
            await pauseNonEssentialServices()
        }
    }
    
    /// Handle app becoming active
    func handleAppDidBecomeActive() {
        let previousState = appState
        appState = .active
        
        logger.logInfo(
            message: "App becoming active - resuming services",
            context: .appLifecycle,
            additionalInfo: ["previousState": previousState.rawValue]
        )
        
        Task { @MainActor in
            await resumeServices()
            await syncPendingChanges()
        }
    }
    
    /// Handle app termination
    func handleAppWillTerminate() {
        logger.logInfo(
            message: "App terminating - performing final cleanup",
            context: .appLifecycle,
            additionalInfo: [:]
        )
        
        // Synchronous cleanup for app termination
        saveAppStateSync()
        dependencyContainer.cleanup()
    }
    
    /// Get last active run for restoration
    func getLastActiveRun() -> String? {
        return UserDefaults.standard.string(forKey: lastActiveRunKey)
    }
    
    /// Save last active run
    func saveLastActiveRun(_ runId: String?) {
        if let runId = runId {
            UserDefaults.standard.set(runId, forKey: lastActiveRunKey)
        } else {
            UserDefaults.standard.removeObject(forKey: lastActiveRunKey)
        }
    }
    
    /// Get last screen for restoration
    func getLastScreen() -> String? {
        return UserDefaults.standard.string(forKey: lastScreenKey)
    }
    
    /// Save last screen
    func saveLastScreen(_ screen: String) {
        UserDefaults.standard.set(screen, forKey: lastScreenKey)
    }
    
    // MARK: - Private Methods
    
    private func setupLifecycleObservers() {
        // Listen for app lifecycle notifications
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleAppDidEnterBackground()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.handleAppDidBecomeActive()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in
                self?.handleAppWillTerminate()
            }
            .store(in: &cancellables)
    }
    
    /// Restore user session
    /// Implements Requirements 10.5 - handle app restart state restoration
    private func restoreUserSession() async {
        // Restore user authentication and role information
        let savedUserId = UserDefaults.standard.string(forKey: "currentUserId") ?? "demo_user"
        let savedFamilyId = UserDefaults.standard.string(forKey: "currentFamilyId") ?? "demo_family"
        let savedRoleRaw = UserDefaults.standard.string(forKey: "currentUserRole") ?? FamilyRole.driver.rawValue
        let savedRole = FamilyRole(rawValue: savedRoleRaw) ?? .driver
        
        dependencyContainer.roleManagementService.updateUserRole(
            savedRole,
            userId: savedUserId,
            familyId: savedFamilyId
        )
        
        logger.logInfo(
            message: "User session restored",
            context: .appLifecycle,
            additionalInfo: [
                "userId": savedUserId,
                "role": savedRole.rawValue,
                "familyId": savedFamilyId
            ]
        )
    }
    
    /// Restore navigation state
    /// Implements Requirements 10.5 - handle app restart state restoration
    private func restoreNavigationState() async {
        if let lastScreen = getLastScreen() {
            logger.logInfo(
                message: "Navigation state restored",
                context: .appLifecycle,
                additionalInfo: ["lastScreen": lastScreen]
            )
            
            // Post notification for navigation restoration
            NotificationCenter.default.post(
                name: .restoreNavigationState,
                object: nil,
                userInfo: ["lastScreen": lastScreen]
            )
        }
    }
    
    /// Restore active runs
    /// Implements Requirements 10.5 - handle app restart state restoration
    private func restoreActiveRuns() async {
        if let lastActiveRunId = getLastActiveRun() {
            // Start listening to the last active run
            dependencyContainer.runEventService.startListening(to: lastActiveRunId)
            
            logger.logInfo(
                message: "Active run restored",
                context: .appLifecycle,
                additionalInfo: ["runId": lastActiveRunId]
            )
        }
    }
    
    /// Initialize real-time services
    private func initializeRealTimeServices() async {
        // Force synchronization to get latest data
        await dependencyContainer.runEventService.forceSynchronization()
        
        logger.logInfo(
            message: "Real-time services initialized",
            context: .appLifecycle,
            additionalInfo: [:]
        )
    }
    
    /// Save current app state
    private func saveAppState() async {
        let currentState = AppStateSnapshot(
            timestamp: Date(),
            userId: dependencyContainer.roleManagementService.currentUserId,
            userRole: dependencyContainer.roleManagementService.currentUserRole,
            familyId: dependencyContainer.roleManagementService.currentFamilyId,
            lastActiveRun: getLastActiveRun(),
            lastScreen: getLastScreen()
        )
        
        // Save to UserDefaults
        if let data = try? JSONEncoder().encode(currentState) {
            UserDefaults.standard.set(data, forKey: appStateKey)
        }
        
        // Save individual components
        UserDefaults.standard.set(currentState.userId, forKey: "currentUserId")
        UserDefaults.standard.set(currentState.userRole.rawValue, forKey: "currentUserRole")
        UserDefaults.standard.set(currentState.familyId, forKey: "currentFamilyId")
        
        logger.logInfo(
            message: "App state saved",
            context: .appLifecycle,
            additionalInfo: ["timestamp": currentState.timestamp.description]
        )
    }
    
    /// Save app state synchronously (for app termination)
    private func saveAppStateSync() {
        let currentState = AppStateSnapshot(
            timestamp: Date(),
            userId: dependencyContainer.roleManagementService.currentUserId,
            userRole: dependencyContainer.roleManagementService.currentUserRole,
            familyId: dependencyContainer.roleManagementService.currentFamilyId,
            lastActiveRun: getLastActiveRun(),
            lastScreen: getLastScreen()
        )
        
        // Save to UserDefaults synchronously
        if let data = try? JSONEncoder().encode(currentState) {
            UserDefaults.standard.set(data, forKey: appStateKey)
        }
        
        UserDefaults.standard.set(currentState.userId, forKey: "currentUserId")
        UserDefaults.standard.set(currentState.userRole.rawValue, forKey: "currentUserRole")
        UserDefaults.standard.set(currentState.familyId, forKey: "currentFamilyId")
        UserDefaults.standard.synchronize()
    }
    
    /// Pause non-essential services when app goes to background
    private func pauseNonEssentialServices() async {
        // Pause location updates if not in active run
        if getLastActiveRun() == nil {
            dependencyContainer.locationService.stopLocationUpdates()
        }
        
        // Reduce sync frequency
        // In a real implementation, this would reduce Firebase listener frequency
        
        logger.logInfo(
            message: "Non-essential services paused",
            context: .appLifecycle,
            additionalInfo: [:]
        )
    }
    
    /// Resume services when app becomes active
    private func resumeServices() async {
        // Resume location services if needed
        if getLastActiveRun() != nil {
            dependencyContainer.locationService.requestLocationPermission()
        }
        
        // Resume full sync frequency
        await dependencyContainer.runEventService.forceSynchronization()
        
        logger.logInfo(
            message: "Services resumed",
            context: .appLifecycle,
            additionalInfo: [:]
        )
    }
    
    /// Sync pending changes after app becomes active
    private func syncPendingChanges() async {
        // Check if there are pending offline actions
        let pendingActionsCount = dependencyContainer.runEventService.getQueuedActionsCount(for: getLastActiveRun() ?? "")
        
        if pendingActionsCount > 0 {
            await dependencyContainer.runEventService.forceSynchronization()
            
            logger.logInfo(
                message: "Pending changes synchronized",
                context: .appLifecycle,
                additionalInfo: ["pendingActionsCount": String(pendingActionsCount)]
            )
        }
    }
}

// MARK: - Supporting Types

enum AppState: Equatable {
    case launching
    case active
    case background
    case error(String)
    
    var rawValue: String {
        switch self {
        case .launching: return "launching"
        case .active: return "active"
        case .background: return "background"
        case .error(let message): return "error: \(message)"
        }
    }
}

struct AppStateSnapshot: Codable {
    let timestamp: Date
    let userId: String
    let userRole: FamilyRole
    let familyId: String
    let lastActiveRun: String?
    let lastScreen: String?
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let restoreNavigationState = Notification.Name("restoreNavigationState")
    static let appStateChanged = Notification.Name("appStateChanged")
}

// MARK: - Environment Key

struct AppLifecycleManagerKey: EnvironmentKey {
    static let defaultValue: AppLifecycleManager? = nil
}

extension EnvironmentValues {
    var appLifecycleManager: AppLifecycleManager? {
        get { self[AppLifecycleManagerKey.self] }
        set { self[AppLifecycleManagerKey.self] = newValue }
    }
}
