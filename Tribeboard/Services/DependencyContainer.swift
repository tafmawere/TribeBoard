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
        let service = RunEventService(
            firebaseService: firebaseService,
            errorHandlingService: errorHandlingService,
            logger: privacyPreservingLogger
        )
        return service
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
    
    private(set) var demoRunPlaybackController: DemoRunPlaybackController!
    
    #if DEBUG
    lazy var demoSeedDataService: DemoSeedDataService = {
        return DemoSeedDataService(firebaseService: firebaseService, scheduleStore: scheduleStore)
    }()
    #endif
    
    // MARK: - Scheduling Services
    
    lazy var scheduleStore: ScheduleStore = {
        do {
            return try ScheduleStore()
        } catch {
            fatalError("Failed to initialize ScheduleStore: \(error)")
        }
    }()
    
    lazy var scheduleRunGenerator: ScheduleRunGenerator = {
        return ScheduleRunGenerator(scheduleStore: scheduleStore)
    }()
    
    lazy var runMaterializer: RunMaterializer = {
        // Use debug user mode selection for role context in DEBUG builds
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
        
        return RunMaterializer(
            firebaseService: firebaseService,
            roleContext: RoleContext(
                userId: currentUser.id,
                role: currentUser.role,
                familyId: currentUser.familyId
            )
        )
    }()
    
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
    
    // MARK: - Calendar ViewModels
    
    func createCalendarViewModel() -> CalendarViewModel {
        return CalendarViewModel(generator: scheduleRunGenerator)
    }
    
    func createDayScheduleViewModel(appCoordinator: AppCoordinator) -> DayScheduleViewModel {
        return DayScheduleViewModel(
            generator: scheduleRunGenerator,
            materializer: runMaterializer,
            appCoordinator: appCoordinator
        )
    }
    
    func createScheduleEditorViewModel(existingSchedule: RunSchedule? = nil) -> ScheduleEditorViewModel {
        return ScheduleEditorViewModel(
            scheduleStore: scheduleStore,
            existingSchedule: existingSchedule
        )
    }
    
    // MARK: - Initialization
    
    init() {
        setupInitialConfiguration()
        
        // Initialize demo playback controller after other services (strong reference)
        self.demoRunPlaybackController = DemoRunPlaybackController(
            runEventService: runEventService,
            locationService: locationService,
            firebaseService: firebaseService,
            coreDataService: coreDataService
        )
        
        // Wire demo playback controller to RunEventService
        if AppConfig.isDemoPlaybackEnabled {
            runEventService.setDemoPlaybackController(demoRunPlaybackController)
        }
        
        // DEBUG: Log ObjectIdentifier for retention verification
        #if DEBUG
        print("DependencyContainer init: demoRunPlaybackController ObjectIdentifier=\(ObjectIdentifier(demoRunPlaybackController))")
        #endif
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
        
        // Note: Demo flow mode seed is handled in LaunchRootView.setupUserAndLoadData()
        // to ensure it completes before the UI tries to load data
        #endif
        
        // Set up demo user data for Active Run Only mode
        if AppConfig.isActiveRunOnlyMode {
            setupDemoUserData()
            
            // Start demo playback if enabled (idempotent - won't start if already running)
            if AppConfig.isDemoPlaybackEnabled {
                demoRunPlaybackController.startPlayback()
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
            demoRunPlaybackController.stopPlayback()
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