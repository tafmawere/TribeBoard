//
//  LaunchRootView.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/04.
//

import SwiftUI

/// Root view that decides what to show based on launch mode and active run status
struct LaunchRootView: View {
    @Environment(\.dependencyContainer) private var dependencyContainer
    @State private var activeRun: Run?
    @State private var isLoading = true
    @State private var error: Error?
    @State private var selectedUserId: String = DemoSeedDataService.rueId
    
    var body: some View {
        Group {
            if AppConfig.isActiveRunOnlyMode {
                activeRunOnlyContent
            } else if AppConfig.isDemoFlowEnabled {
                // Demo flow mode - land on MyRunsView (to be created in Task 5)
                demoFlowContent
            } else {
                // Full app mode - use existing MainNavigationView
                fullAppContent
            }
        }
        .task {
            await setupUserAndLoadData()
        }
    }
    
    // MARK: - Full App Content
    
    @ViewBuilder
    private var fullAppContent: some View {
        #if DEBUG
        // Set up demo user based on AppConfig.demoUser
        let _ = setupDemoUser()
        #endif
        
        MainNavigationView(dependencyContainer: dependencyContainer)
    }
    
    // MARK: - Demo Flow Content
    
    @ViewBuilder
    private var demoFlowContent: some View {
        // Main tab navigation (user switching now in Settings)
        MainNavigationView(dependencyContainer: dependencyContainer)
    }
    
    #if DEBUG
    /// Set up demo user for full app mode
    private func setupDemoUser() {
        let demoUser: User
        
        switch AppConfig.demoUser {
        case .rue:
            demoUser = User(
                id: DemoSeedDataService.rueId,
                displayName: "Rue",
                role: .admin,
                familyId: DemoSeedDataService.demoFamilyId
            )
        case .tafadzwa:
            demoUser = User(
                id: DemoSeedDataService.tafadzwaId,
                displayName: "Tafadzwa",
                role: .admin,
                familyId: DemoSeedDataService.demoFamilyId
            )
        }
        
        // Update role management service with demo user
        dependencyContainer.roleManagementService.updateUserRole(
            demoUser.role,
            userId: demoUser.id,
            familyId: demoUser.familyId
        )
    }
    #endif
    
    // MARK: - Active Run Only Content
    
    @ViewBuilder
    private var activeRunOnlyContent: some View {
        Group {
            if isLoading {
                loadingView
            } else if let activeRun = activeRun {
                activeRunView(activeRun)
            } else {
                EmptyStateView(onRefresh: loadActiveRun)
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Active Run View
    
    @ViewBuilder
    private func activeRunView(_ run: Run) -> some View {
        let currentUserId = dependencyContainer.roleManagementService.currentUserId
        
        if run.driverId == currentUserId {
            // User is the driver - show Driver Focus Mode
            DriverFocusModeView(
                runId: run.id,
                runEventService: dependencyContainer.runEventService,
                roleContext: RoleContext(
                    userId: currentUserId,
                    role: .driver,
                    familyId: dependencyContainer.roleManagementService.currentFamilyId
                )
            )
        } else {
            // User is observer/admin - show Observer Tracking
            ObserverTrackingView(
                runId: run.id,
                runEventService: dependencyContainer.runEventService,
                roleContext: RoleContext(
                    userId: currentUserId,
                    role: dependencyContainer.roleManagementService.currentUserRole,
                    familyId: dependencyContainer.roleManagementService.currentFamilyId
                )
            )
        }
    }
    
    // MARK: - Helper Methods
    
    @MainActor
    private func setupUserAndLoadData() async {
        #if DEBUG
        if AppConfig.isFullAppMode {
            // In full app mode, just set up the demo user
            setupDemoUser()
            return
        }
        
        if AppConfig.isDemoFlowEnabled {
            // In demo flow mode, wait for seed to complete first
            await dependencyContainer.demoSeedDataService.seedDemoFamily()
            
            // Set up initial user (Rue by default)
            let (displayName, role) = getUserInfo(for: selectedUserId)
            dependencyContainer.roleManagementService.setCurrentUser(
                userId: selectedUserId,
                displayName: displayName,
                role: role,
                familyId: DemoSeedDataService.demoFamilyId
            )
            
            dependencyContainer.homeDashboardViewModel.updateRoleContext(
                userId: selectedUserId,
                displayName: displayName,
                role: role,
                familyId: DemoSeedDataService.demoFamilyId
            )
            
            DebugStateManager.shared.updateCurrentUser(id: selectedUserId, mode: role.displayName)
            return
        }
        #endif
        
        // In active run only mode, load the active run
        await loadActiveRun()
    }
    
    /// Get user info for a given user ID
    private func getUserInfo(for userId: String) -> (displayName: String, role: FamilyRole) {
        switch userId {
        case DemoSeedDataService.rueId:
            return ("Rue Mawere", .observer) // Parent/Admin/Observer
        case DemoSeedDataService.tafadzwaId:
            return ("Tafadzwa Mawere", .driver) // Parent/Admin/Driver
        case DemoSeedDataService.tjId:
            return ("TJ", .observer) // Child/Passenger
        case DemoSeedDataService.tawanaId:
            return ("Tawana", .observer) // Child/Passenger
        default:
            return ("Unknown", .observer)
        }
    }
    
    @MainActor
    private func loadActiveRun() async {
        isLoading = true
        error = nil
        
        do {
            activeRun = try await getCurrentActiveRun()
        } catch {
            self.error = error
            print("Error loading active run: \(error)")
        }
        
        isLoading = false
    }
    
    /// Get the current active run for the user's family
    private func getCurrentActiveRun() async throws -> Run? {
        let familyId = dependencyContainer.roleManagementService.currentFamilyId
        
        // Try to get existing active run
        if let activeRun = try await dependencyContainer.firebaseService.getCurrentActiveRun(for: familyId) {
            // Debug assertion: Log that we found an active run
            debugLog("App launch: getCurrentActiveRun() returned active run with id=\(activeRun.id), state=\(activeRun.status)")
            return activeRun
        }
        
        // Debug assertion: Log that no active run was found
        debugLog("App launch: getCurrentActiveRun() returned nil - no active run found for family \(familyId)")
        
        // For demo purposes in Active Run Only mode, create a demo active run if none exists
        #if DEBUG
        if AppConfig.isActiveRunOnlyMode {
            let demoRun = try await createDemoActiveRun(for: familyId)
            debugLog("App launch: Created demo active run with id=\(demoRun.id)")
            return demoRun
        }
        #endif
        
        return nil
    }
    
    #if DEBUG
    /// Create a demo active run for testing
    private func createDemoActiveRun(for familyId: String) async throws -> Run {
        let demoRun = try await dependencyContainer.firebaseService.createDemoRun()
        
        // Make sure the run belongs to the correct family
        var updatedRun = demoRun
        updatedRun = Run(
            id: demoRun.id,
            title: demoRun.title,
            scheduledTime: demoRun.scheduledTime,
            driverId: dependencyContainer.roleManagementService.currentUserId,
            status: demoRun.status,
            stops: demoRun.stops,
            passengers: demoRun.passengers,
            createdBy: demoRun.createdBy,
            familyId: familyId
        )
        
        // Start the demo run to make it active
        try await dependencyContainer.firebaseService.updateRunStatus(
            runId: updatedRun.id,
            newStatus: .activeEnroute
        )
        
        return try await dependencyContainer.firebaseService.fetchRun(runId: updatedRun.id)
    }
    #endif
}

#Preview {
    let container = DependencyContainer()
    return LaunchRootView()
        .withDependencyContainer(container)
}