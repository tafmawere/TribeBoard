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
    
    var body: some View {
        Group {
            if AppConfig.isActiveRunOnlyMode {
                activeRunOnlyContent
            } else {
                // Full app mode - use existing MainNavigationView
                MainNavigationView(dependencyContainer: dependencyContainer)
            }
        }
        .task {
            await loadActiveRun()
        }
    }
    
    // MARK: - Active Run Only Content
    
    @ViewBuilder
    private var activeRunOnlyContent: some View {
        if isLoading {
            loadingView
        } else if let activeRun = activeRun {
            activeRunView(activeRun)
        } else {
            EmptyStateView(onRefresh: loadActiveRun)
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
            return activeRun
        }
        
        // For demo purposes in Active Run Only mode, create a demo active run if none exists
        #if DEBUG
        if AppConfig.isActiveRunOnlyMode {
            return try await createDemoActiveRun(for: familyId)
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