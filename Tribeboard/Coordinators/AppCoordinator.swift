//
//  AppCoordinator.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/04.
//

import Foundation
import SwiftUI
import Combine

/// Main application coordinator that manages navigation flow and screen transitions
/// Implements navigation flow between all screens as per Requirements: All requirements integration
@MainActor
class AppCoordinator: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentScreen: AppScreen = .homeDashboard
    @Published var navigationPath = NavigationPath()
    @Published var presentedSheet: SheetType?
    @Published var showingAlert = false
    @Published var alertMessage = ""
    
    // MARK: - Dependencies
    
    private let dependencyContainer: DependencyContainer
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(dependencyContainer: DependencyContainer) {
        self.dependencyContainer = dependencyContainer
        setupNavigationObservers()
        setupRunCreationCallback()
    }
    
    // MARK: - Navigation Methods
    
    /// Navigate to a specific screen
    func navigate(to screen: AppScreen) {
        // Guard against navigation in Active Run Only mode (but allow demo flow mode)
        if AppConfig.isActiveRunOnlyMode {
            showAlert(message: "Navigation is not available in Active Run Only mode")
            return
        }
        
        currentScreen = screen
        
        switch screen {
        case .homeDashboard:
            navigationPath = NavigationPath()
        case .myRuns:
            navigationPath = NavigationPath()
        case .runDetail(let runId):
            navigationPath.append(RunDetailDestination(runId: runId))
        case .driverFocusMode(let runId):
            navigationPath.append(DriverFocusModeDestination(runId: runId))
        case .observerTracking(let runId):
            navigationPath.append(ObserverTrackingDestination(runId: runId))
        case .activityStream(let runId):
            navigationPath.append(ActivityStreamDestination(runId: runId))
        case .runCreation:
            presentedSheet = .runCreation
        }
    }
    
    /// Navigate back to previous screen
    func navigateBack() {
        if !navigationPath.isEmpty {
            navigationPath.removeLast()
        } else {
            currentScreen = .homeDashboard
        }
    }
    
    /// Present a sheet
    func presentSheet(_ sheet: SheetType) {
        // Guard against sheet presentation in Active Run Only mode (but allow demo flow mode)
        if AppConfig.isActiveRunOnlyMode {
            showAlert(message: "This feature is not available in Active Run Only mode")
            return
        }
        
        presentedSheet = sheet
    }
    
    /// Dismiss current sheet
    func dismissSheet() {
        presentedSheet = nil
    }
    
    /// Show alert with message
    func showAlert(message: String) {
        alertMessage = message
        showingAlert = true
    }
    
    /// Handle deep link navigation
    func handleDeepLink(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = components.host else {
            return
        }
        
        switch host {
        case "run":
            if let runId = components.queryItems?.first(where: { $0.name == "id" })?.value {
                navigate(to: .runDetail(runId: runId))
            }
        case "driver":
            if let runId = components.queryItems?.first(where: { $0.name == "runId" })?.value {
                navigate(to: .driverFocusMode(runId: runId))
            }
        case "observer":
            if let runId = components.queryItems?.first(where: { $0.name == "runId" })?.value {
                navigate(to: .observerTracking(runId: runId))
            }
        case "create":
            navigate(to: .runCreation)
        default:
            navigate(to: .homeDashboard)
        }
    }
    
    /// Handle role-based navigation
    func navigateBasedOnRole(for run: Run) {
        let role = dependencyContainer.roleManagementService.currentUserRole
        let userId = dependencyContainer.roleManagementService.currentUserId
        
        switch role {
        case .driver where run.driverId == userId:
            navigate(to: .driverFocusMode(runId: run.id))
        case .observer, .admin:
            navigate(to: .observerTracking(runId: run.id))
        default:
            navigate(to: .runDetail(runId: run.id))
        }
    }
    
    /// Handle run creation completion
    func handleRunCreationCompletion(runId: String) {
        dismissSheet()
        
        // Navigate to appropriate screen based on user role
        Task {
            do {
                let run = try await dependencyContainer.firebaseService.fetchRun(runId: runId)
                navigateBasedOnRole(for: run)
            } catch {
                showAlert(message: "Failed to load created run: \(error.localizedDescription)")
            }
        }
    }
    
    /// Show run scheduled confirmation screen
    func showRunScheduledConfirmation(run: Run) {
        dismissSheet()
        presentedSheet = .runScheduledConfirmation(run: run)
    }
    
    /// Handle run action completion
    func handleRunActionCompletion(runId: String, action: String) {
        showAlert(message: "\(action) completed successfully")
        
        // Refresh current screen if it's related to this run
        refreshCurrentScreenIfNeeded(runId: runId)
    }
    
    /// Handle error scenarios
    func handleError(_ error: Error, context: String = "") {
        let message = context.isEmpty ? error.localizedDescription : "\(context): \(error.localizedDescription)"
        showAlert(message: message)
    }
    
    // MARK: - Screen Factory Methods
    
    /// Create view for current screen
    @ViewBuilder
    func createView(for screen: AppScreen) -> some View {
        switch screen {
        case .homeDashboard:
            HomeDashboardView()
                .withDependencyContainer(dependencyContainer)
                .environmentObject(self)
        case .myRuns:
            MyRunsView(viewModel: dependencyContainer.homeDashboardViewModel)
                .withDependencyContainer(dependencyContainer)
                .environmentObject(self)
        case .runDetail(let runId):
            RunFocusView(
                runId: runId,
                firebaseService: dependencyContainer.firebaseService,
                roleManagementService: dependencyContainer.roleManagementService,
                runEventService: dependencyContainer.runEventService
            )
            .withDependencyContainer(dependencyContainer)
            .environmentObject(self)
        case .driverFocusMode(let runId):
            DriverFocusModeView(
                runId: runId,
                runEventService: dependencyContainer.runEventService,
                roleContext: RoleContext(
                    userId: dependencyContainer.roleManagementService.currentUserId,
                    role: dependencyContainer.roleManagementService.currentUserRole,
                    familyId: dependencyContainer.roleManagementService.currentFamilyId
                )
            )
            .withDependencyContainer(dependencyContainer)
            .environmentObject(self)
        case .observerTracking(let runId):
            ObserverTrackingView(
                runId: runId,
                runEventService: dependencyContainer.runEventService,
                roleContext: RoleContext(
                    userId: dependencyContainer.roleManagementService.currentUserId,
                    role: dependencyContainer.roleManagementService.currentUserRole,
                    familyId: dependencyContainer.roleManagementService.currentFamilyId
                )
            )
            .withDependencyContainer(dependencyContainer)
            .environmentObject(self)
        case .activityStream(let runId):
            ActivityStreamView(
                runId: runId,
                runEventService: dependencyContainer.runEventService
            )
            .withDependencyContainer(dependencyContainer)
            .environmentObject(self)
        case .runCreation:
            RunCreationView()
                .withDependencyContainer(dependencyContainer)
                .environmentObject(dependencyContainer.runCreationViewModel)
                .environmentObject(self)
        }
    }
    
    /// Create sheet view
    @ViewBuilder
    func createSheetView(for sheet: SheetType) -> some View {
        switch sheet {
        case .runCreation:
            NavigationView {
                RunCreationView()
                    .withDependencyContainer(dependencyContainer)
                    .environmentObject(dependencyContainer.runCreationViewModel)
                    .environmentObject(self)
            }
        case .runDetail(let runId):
            NavigationView {
                RunFocusView(
                    runId: runId,
                    firebaseService: dependencyContainer.firebaseService,
                    roleManagementService: dependencyContainer.roleManagementService,
                    runEventService: dependencyContainer.runEventService
                )
                .withDependencyContainer(dependencyContainer)
                .environmentObject(self)
            }
        case .activityStream(let runId):
            NavigationView {
                ActivityStreamView(
                    runId: runId,
                    runEventService: dependencyContainer.runEventService
                )
                .withDependencyContainer(dependencyContainer)
                .environmentObject(self)
            }
        case .runScheduledConfirmation(let run):
            RunScheduledConfirmationView(
                run: run,
                onViewRun: { [weak self] in
                    self?.dismissSheet()
                    self?.navigate(to: .runDetail(runId: run.id))
                },
                onBackToDashboard: { [weak self] in
                    self?.dismissSheet()
                    self?.navigate(to: .myRuns)
                }
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func setupRunCreationCallback() {
        dependencyContainer.runCreationViewModel.onRunCreated = { [weak self] run in
            self?.showRunScheduledConfirmation(run: run)
        }
    }
    
    private func setupNavigationObservers() {
        // Listen for role changes and update navigation accordingly
        NotificationCenter.default.publisher(for: .userRoleDidChange)
            .sink { [weak self] _ in
                self?.handleRoleChange()
            }
            .store(in: &cancellables)
        
        // Listen for run state changes that might affect navigation
        dependencyContainer.runEventService.stateChangePublisher
            .sink { [weak self] stateChange in
                self?.handleRunStateChange(stateChange)
            }
            .store(in: &cancellables)
        
        // Listen for error notifications
        NotificationCenter.default.publisher(for: .errorOccurred)
            .sink { [weak self] notification in
                if let error = notification.object as? Error {
                    self?.handleError(error)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleRoleChange() {
        // Refresh current screen to reflect new role permissions
        let currentScreenCopy = currentScreen
        currentScreen = currentScreenCopy
    }
    
    private func handleRunStateChange(_ stateChange: RunStateChange) {
        // Handle navigation changes based on run state transitions
        switch stateChange.toState {
        case .completed, .cancelled:
            // If we're viewing this run and it's completed, show completion summary
            if case .driverFocusMode(let runId) = currentScreen, runId == stateChange.runId {
                navigate(to: .activityStream(runId: runId))
            }
        case .activeEnroute:
            // If run started and user is the driver, navigate to focus mode
            let role = dependencyContainer.roleManagementService.currentUserRole
            let userId = dependencyContainer.roleManagementService.currentUserId
            
            if role == .driver {
                Task {
                    do {
                        let run = try await dependencyContainer.firebaseService.fetchRun(runId: stateChange.runId)
                        if run.driverId == userId {
                            navigate(to: .driverFocusMode(runId: stateChange.runId))
                        }
                    } catch {
                        handleError(error, context: "Failed to load run for navigation")
                    }
                }
            }
        default:
            break
        }
    }
    
    private func refreshCurrentScreenIfNeeded(runId: String) {
        switch currentScreen {
        case .runDetail(let currentRunId), 
             .driverFocusMode(let currentRunId), 
             .observerTracking(let currentRunId), 
             .activityStream(let currentRunId):
            if currentRunId == runId {
                // Trigger a refresh by reassigning the same screen
                let screenCopy = currentScreen
                currentScreen = screenCopy
            }
        default:
            break
        }
    }
}

// MARK: - Supporting Types

enum AppScreen: Hashable {
    case homeDashboard
    case myRuns
    case runDetail(runId: String)
    case driverFocusMode(runId: String)
    case observerTracking(runId: String)
    case activityStream(runId: String)
    case runCreation
}

enum SheetType: Identifiable {
    case runCreation
    case runDetail(runId: String)
    case activityStream(runId: String)
    case runScheduledConfirmation(run: Run)
    
    var id: String {
        switch self {
        case .runCreation:
            return "runCreation"
        case .runDetail(let runId):
            return "runDetail-\(runId)"
        case .activityStream(let runId):
            return "activityStream-\(runId)"
        case .runScheduledConfirmation(let run):
            return "runScheduledConfirmation-\(run.id)"
        }
    }
}

// Navigation Destinations
struct RunDetailDestination: Hashable {
    let runId: String
}

struct DriverFocusModeDestination: Hashable {
    let runId: String
}

struct ObserverTrackingDestination: Hashable {
    let runId: String
}

struct ActivityStreamDestination: Hashable {
    let runId: String
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let errorOccurred = Notification.Name("errorOccurred")
    static let navigationRequested = Notification.Name("navigationRequested")
}

// MARK: - AppCoordinator Environment Key

struct AppCoordinatorKey: EnvironmentKey {
    static let defaultValue: AppCoordinator? = nil
}

extension EnvironmentValues {
    var appCoordinator: AppCoordinator? {
        get { self[AppCoordinatorKey.self] }
        set { self[AppCoordinatorKey.self] = newValue }
    }
}