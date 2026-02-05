//
//  DependencyContainer.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/04.
//

import Foundation
import CoreData
import SwiftUI
import Combine

/// Dependency injection container for managing service instances and their dependencies
/// Implements proper dependency injection for all components as per Requirements: All requirements integration
@MainActor
class DependencyContainer: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isInitialized = false
    
    // MARK: - Core Services
    
    lazy var persistenceController: PersistenceController = {
        return PersistenceController.shared
    }()
    
    lazy var coreDataService: CoreDataService = {
        return CoreDataService.shared
    }()
    
    lazy var locationService: LocationService = {
        return LocationService()
    }()
    
    lazy var privacyPreservingLogger: PrivacyPreservingLogger = {
        return PrivacyPreservingLogger()
    }()
    
    // MARK: - Error Handling Services
    
    lazy var errorHandlingService: ErrorHandlingService = {
        return ErrorHandlingService()
    }()
    
    lazy var errorRecoveryService: ErrorRecoveryService = {
        return ErrorRecoveryService(
            firebaseService: firebaseService,
            errorHandlingService: errorHandlingService
        )
    }()
    
    lazy var errorHandlingCoordinator: ErrorHandlingCoordinator = {
        return ErrorHandlingCoordinator(firebaseService: firebaseService)
    }()
    
    lazy var adminNotificationService: AdminNotificationService = {
        return AdminNotificationService(logger: privacyPreservingLogger)
    }()
    
    // MARK: - App Lifecycle
    
    lazy var appLifecycleManager: AppLifecycleManager = {
        return AppLifecycleManager(dependencyContainer: self)
    }()
    
    // MARK: - Cache Management
    
    lazy var cacheManagementService: CacheManagementService = {
        return CacheManagementService(
            coreDataService: coreDataService,
            persistenceController: persistenceController,
            logger: privacyPreservingLogger
        )
    }()
    
    // MARK: - Firebase and Network Services
    
    lazy var firebaseService: MockFirebaseRunService = {
        return MockFirebaseRunService()
    }()
    
    lazy var offlineSyncService: OfflineSyncService = {
        return OfflineSyncService(firebaseService: firebaseService)
    }()
    
    lazy var runEventService: RunEventService = {
        return RunEventService(
            firebaseService: firebaseService,
            errorHandlingService: errorHandlingService,
            logger: privacyPreservingLogger
        )
    }()
    
    lazy var synchronizationCoordinator: SynchronizationCoordinator = {
        return SynchronizationCoordinator(
            runEventService: runEventService,
            offlineSyncService: offlineSyncService,
            coreDataService: coreDataService
        )
    }()
    
    // MARK: - Role and Permission Services
    
    lazy var roleManagementService: RoleManagementService = {
        return RoleManagementService()
    }()
    
    lazy var roleBasedDataFilter: RoleBasedDataFilter = {
        return RoleBasedDataFilter()
    }()
    
    lazy var dynamicRoleUpdateService: DynamicRoleUpdateService = {
        return DynamicRoleUpdateService(
            roleManagementService: roleManagementService,
            runEventService: runEventService
        )
    }()
    
    // MARK: - Notification Services
    
    lazy var delayNotificationService: DelayNotificationService = {
        return DelayNotificationService(runEventService: runEventService)
    }()
    
    // MARK: - Demo Services
    
    lazy var demoRunPlaybackController: DemoRunPlaybackController = {
        return DemoRunPlaybackController(
            runEventService: runEventService,
            locationService: locationService,
            firebaseService: firebaseService,
            coreDataService: coreDataService
        )
    }()
    
    #if DEBUG
    lazy var demoSeedDataService: DemoSeedDataService = {
        return DemoSeedDataService(firebaseService: firebaseService)
    }()
    #endif
    
    // MARK: - ViewModels
    
    lazy var homeDashboardViewModel: HomeDashboardViewModel = {
        return HomeDashboardViewModel(
            firebaseService: firebaseService,
            roleManagementService: roleManagementService,
            roleBasedDataFilter: roleBasedDataFilter,
            runEventService: runEventService
        )
    }()
    
    lazy var runCreationViewModel: RunCreationViewModel = {
        // Use debug user mode selection for role context in DEBUG builds
        // Requirements: 5.2, 5.4
        #if DEBUG
        let currentUser = AppConfig.isActiveRunOnlyMode ? AppConfig.currentDemoUser : User(
            id: roleManagementService.currentUserId,
            displayName: "Demo User",
            role: roleManagementService.currentUserRole,
            familyId: roleManagementService.currentFamilyId
        )
        #else
        let currentUser = User(
            id: roleManagementService.currentUserId,
            displayName: "Demo User",
            role: roleManagementService.currentUserRole,
            familyId: roleManagementService.currentFamilyId
        )
        #endif
        
        return RunCreationViewModel(
            runEventService: runEventService,
            firebaseService: firebaseService,
            roleContext: RoleContext(
                userId: currentUser.id,
                role: currentUser.role,
                familyId: currentUser.familyId
            )
        )
    }()
    
    func createDriverFocusModeViewModel(runId: String) -> DriverFocusModeViewModel {
        // Use debug user mode selection for role context in DEBUG builds
        // Requirements: 5.2, 5.4
        #if DEBUG
        let currentUser = AppConfig.isActiveRunOnlyMode ? AppConfig.currentDemoUser : User(
            id: roleManagementService.currentUserId,
            displayName: "Demo User",
            role: roleManagementService.currentUserRole,
            familyId: roleManagementService.currentFamilyId
        )
        #else
        let currentUser = User(
            id: roleManagementService.currentUserId,
            displayName: "Demo User",
            role: roleManagementService.currentUserRole,
            familyId: roleManagementService.currentFamilyId
        )
        #endif
        
        return DriverFocusModeViewModel(
            runId: runId,
            runEventService: runEventService,
            roleContext: RoleContext(
                userId: currentUser.id,
                role: currentUser.role,
                familyId: currentUser.familyId
            )
        )
    }
    
    func createObserverTrackingViewModel(runId: String) -> ObserverTrackingViewModel {
        // Use debug user mode selection for role context in DEBUG builds
        // Requirements: 5.2, 5.4
        #if DEBUG
        let currentUser = AppConfig.isActiveRunOnlyMode ? AppConfig.currentDemoUser : User(
            id: roleManagementService.currentUserId,
            displayName: "Demo User",
            role: roleManagementService.currentUserRole,
            familyId: roleManagementService.currentFamilyId
        )
        #else
        let currentUser = User(
            id: roleManagementService.currentUserId,
            displayName: "Demo User",
            role: roleManagementService.currentUserRole,
            familyId: roleManagementService.currentFamilyId
        )
        #endif
        
        return ObserverTrackingViewModel(
            runId: runId,
            runEventService: runEventService,
            roleContext: RoleContext(
                userId: currentUser.id,
                role: currentUser.role,
                familyId: currentUser.familyId
            )
        )
    }
    
    func createActivityStreamViewModel(runId: String) -> ActivityStreamViewModel {
        return ActivityStreamViewModel(
            runId: runId,
            runEventService: runEventService
        )
    }
    
    // MARK: - Step ViewModels for Run Creation
    
    func createStep1MetadataViewModel() -> Step1MetadataViewModel {
        return Step1MetadataViewModel()
    }
    
    func createStep2DriverViewModel() -> Step2DriverViewModel {
        return Step2DriverViewModel()
    }
    
    func createStep3PassengerViewModel() -> Step3PassengerViewModel {
        return Step3PassengerViewModel()
    }
    
    func createStep4StopsViewModel() -> Step4StopsViewModel {
        return Step4StopsViewModel()
    }
    
    // MARK: - Initialization
    
    init() {
        setupInitialConfiguration()
    }
    
    // MARK: - Configuration
    
    private func setupInitialConfiguration() {
        // Seed demo data in full app mode (DEBUG only)
        #if DEBUG
        if AppConfig.isFullAppMode {
            Task {
                await demoSeedDataService.seedIfNeeded()
            }
        }
        
        // Seed demo family in demo flow mode (DEBUG only)
        // Requirements: 2.1, 2.2, 2.3, 2.7, 2.9
        if AppConfig.isDemoFlowEnabled {
            Task {
                await demoSeedDataService.seedDemoFamily()
            }
        }
        #endif
        
        // Set up demo user data for Active Run Only mode
        if AppConfig.isActiveRunOnlyMode {
            setupDemoUserData()
            
            // Start demo playback if enabled (idempotent - won't start if already running)
            if AppConfig.isDemoPlaybackEnabled {
                demoRunPlaybackController.startIfNeeded()
            }
        }
        
        // Initialize app lifecycle management
        Task {
            await appLifecycleManager.handleAppLaunch()
        }
    }
    
    /// Set up demo user data for testing Active Run Only mode
    /// Uses AppConfig.currentDemoUser to respect debug user mode selection
    /// Requirements: 5.2, 5.4
    private func setupDemoUserData() {
        // Get current demo user based on debug mode selection
        let currentUser = AppConfig.currentDemoUser
        
        // Set up user role based on debug mode selection
        roleManagementService.updateUserRole(
            currentUser.role,
            userId: currentUser.id,
            familyId: currentUser.familyId
        )
        
        // Create demo observer user for testing (Requirement 4.6)
        // This ensures we have both driver and observer users available for debug mode switching
        let _ = firebaseService.createDemoObserverUser()
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        // Stop demo playback
        if AppConfig.isActiveRunOnlyMode && AppConfig.isDemoPlaybackEnabled {
            demoRunPlaybackController.stop()
        }
        
        // Notify app lifecycle manager of termination
        appLifecycleManager.handleAppWillTerminate()
    }
}

// MARK: - Environment Key

struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue = DependencyContainer()
}

extension EnvironmentValues {
    var dependencyContainer: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    func withDependencyContainer(_ container: DependencyContainer) -> some View {
        self.environment(\.dependencyContainer, container)
    }
}