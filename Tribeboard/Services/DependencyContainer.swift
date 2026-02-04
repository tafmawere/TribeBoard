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
        return RunCreationViewModel(
            runEventService: runEventService,
            firebaseService: firebaseService,
            roleContext: RoleContext(
                userId: roleManagementService.currentUserId,
                role: roleManagementService.currentUserRole,
                familyId: roleManagementService.currentFamilyId
            )
        )
    }()
    
    func createDriverFocusModeViewModel(runId: String) -> DriverFocusModeViewModel {
        return DriverFocusModeViewModel(
            runId: runId,
            runEventService: runEventService,
            roleContext: RoleContext(
                userId: roleManagementService.currentUserId,
                role: roleManagementService.currentUserRole,
                familyId: roleManagementService.currentFamilyId
            )
        )
    }
    
    func createObserverTrackingViewModel(runId: String) -> ObserverTrackingViewModel {
        return ObserverTrackingViewModel(
            runId: runId,
            runEventService: runEventService,
            roleContext: RoleContext(
                userId: roleManagementService.currentUserId,
                role: roleManagementService.currentUserRole,
                familyId: roleManagementService.currentFamilyId
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
        // Set up demo user data for Active Run Only mode
        if AppConfig.isActiveRunOnlyMode {
            setupDemoUserData()
        }
        
        // Initialize app lifecycle management
        Task {
            await appLifecycleManager.handleAppLaunch()
        }
    }
    
    /// Set up demo user data for testing Active Run Only mode
    private func setupDemoUserData() {
        // Set up a demo user as driver
        roleManagementService.updateUserRole(
            .driver,
            userId: "demo_driver_user",
            familyId: "demo_family"
        )
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
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