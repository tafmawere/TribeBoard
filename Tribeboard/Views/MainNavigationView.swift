//
//  MainNavigationView.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/04.
//

import SwiftUI

/// Main navigation view that coordinates all screens and handles navigation flow
/// Integrates real-time services with UI components as per Requirements: All requirements integration
struct MainNavigationView: View {
    @StateObject private var appCoordinator: AppCoordinator
    @Environment(\.dependencyContainer) private var dependencyContainer
    @State private var selectedTab: MainTab = .myRuns
    
    enum MainTab {
        case myRuns
        case family
        case activity
        case settings
    }
    
    init(dependencyContainer: DependencyContainer) {
        self._appCoordinator = StateObject(wrappedValue: AppCoordinator(dependencyContainer: dependencyContainer))
    }
    
    var body: some View {
        // Guard against access in Active Run Only mode
        if AppConfig.isActiveRunOnlyMode {
            Text("This view is not available in Active Run Only mode")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
        } else if AppConfig.isDemoFlowEnabled {
            // Demo Flow mode - use tab-based navigation
            demoFlowTabView
        } else {
            // Full app mode - use original navigation
            fullAppNavigationView
        }
    }
    
    // MARK: - Demo Flow Tab View
    
    private var demoFlowTabView: some View {
        TabView(selection: $selectedTab) {
            // Tab 1: My Runs
            MyRunsView(
                viewModel: dependencyContainer.homeDashboardViewModel,
                scheduleRunGenerator: dependencyContainer.scheduleRunGenerator
            )
                .withDependencyContainer(dependencyContainer)
                .environmentObject(appCoordinator)
                .tabItem {
                    Label("My Runs", systemImage: "car.fill")
                }
                .tag(MainTab.myRuns)
            
            // Tab 2: Family
            FamilyView(viewModel: createFamilyViewModel())
                .withDependencyContainer(dependencyContainer)
                .environmentObject(appCoordinator)
                .tabItem {
                    Label("Family", systemImage: "person.3.fill")
                }
                .tag(MainTab.family)
            
            // Tab 3: Activity
            ActivityPlaceholderView()
                .withDependencyContainer(dependencyContainer)
                .environmentObject(appCoordinator)
                .tabItem {
                    Label("Activity", systemImage: "list.bullet")
                }
                .tag(MainTab.activity)
            
            // Tab 4: Settings
            SettingsView()
                .withDependencyContainer(dependencyContainer)
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(MainTab.settings)
        }
        .sheet(item: $appCoordinator.presentedSheet) { sheet in
            appCoordinator.createSheetView(for: sheet)
        }
        .alert("TribeBoard", isPresented: $appCoordinator.showingAlert) {
            Button("OK") { }
        } message: {
            Text(appCoordinator.alertMessage)
        }
        .environment(\.appCoordinator, appCoordinator)
    }
    
    // MARK: - Full App Navigation View
    
    private var fullAppNavigationView: some View {
        NavigationStack(path: $appCoordinator.navigationPath) {
            // Root view is always Home Dashboard
            HomeDashboardView()
                .withDependencyContainer(dependencyContainer)
                .environmentObject(appCoordinator)
                .navigationDestination(for: RunDetailDestination.self) { destination in
                    RunDetailView(runId: destination.runId)
                        .withDependencyContainer(dependencyContainer)
                        .environmentObject(appCoordinator)
                }
                .navigationDestination(for: DriverFocusModeDestination.self) { destination in
                    DriverFocusModeView(
                        runId: destination.runId,
                        runEventService: dependencyContainer.runEventService,
                        roleContext: RoleContext(
                            userId: dependencyContainer.roleManagementService.currentUserId,
                            role: dependencyContainer.roleManagementService.currentUserRole,
                            familyId: dependencyContainer.roleManagementService.currentFamilyId
                        )
                    )
                    .withDependencyContainer(dependencyContainer)
                    .environmentObject(appCoordinator)
                }
                .navigationDestination(for: ObserverTrackingDestination.self) { destination in
                    ObserverTrackingView(
                        runId: destination.runId,
                        runEventService: dependencyContainer.runEventService,
                        roleContext: RoleContext(
                            userId: dependencyContainer.roleManagementService.currentUserId,
                            role: dependencyContainer.roleManagementService.currentUserRole,
                            familyId: dependencyContainer.roleManagementService.currentFamilyId
                        )
                    )
                    .withDependencyContainer(dependencyContainer)
                    .environmentObject(appCoordinator)
                }
                .navigationDestination(for: ActivityStreamDestination.self) { destination in
                    ActivityStreamView(
                        runId: destination.runId,
                        runEventService: dependencyContainer.runEventService
                    )
                    .withDependencyContainer(dependencyContainer)
                    .environmentObject(appCoordinator)
                }
        }
        .sheet(item: $appCoordinator.presentedSheet) { sheet in
            appCoordinator.createSheetView(for: sheet)
        }
        .alert("TribeBoard", isPresented: $appCoordinator.showingAlert) {
            Button("OK") { }
        } message: {
            Text(appCoordinator.alertMessage)
        }
        .environment(\.appCoordinator, appCoordinator)
        .onOpenURL { url in
            appCoordinator.handleDeepLink(url)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createFamilyViewModel() -> FamilyViewModel {
        return FamilyViewModel(
            roleManagementService: dependencyContainer.roleManagementService,
            firebaseService: dependencyContainer.firebaseService,
            homeDashboardViewModel: dependencyContainer.homeDashboardViewModel
        )
    }
}

/// Home Dashboard View with role-based content
struct HomeDashboardView: View {
    @Environment(\.dependencyContainer) private var dependencyContainer
    @EnvironmentObject private var appCoordinator: AppCoordinator
    @StateObject private var viewModel: HomeDashboardViewModel
    
    init() {
        // ViewModel will be injected via environment
        self._viewModel = StateObject(wrappedValue: HomeDashboardViewModel(
            firebaseService: MockFirebaseRunService(),
            roleManagementService: RoleManagementService(),
            roleBasedDataFilter: RoleBasedDataFilter(),
            runEventService: RunEventService(firebaseService: MockFirebaseRunService())
        ))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("TribeBoard")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Welcome, \(viewModel.currentUser.displayName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Role indicator
                RoleIndicatorView(role: dependencyContainer.roleManagementService.currentUserRole)
            }
            .padding(.horizontal)
            
            // Quick Actions
            QuickActionsView()
            
            // Active Run Section
            if let activeRun = viewModel.activeRun {
                ActiveRunCardView(run: activeRun) {
                    appCoordinator.navigateBasedOnRole(for: activeRun)
                }
            }
            
            // Next Run Section
            if let nextRun = viewModel.nextRun {
                NextRunCardView(run: nextRun) {
                    appCoordinator.navigate(to: .runDetail(runId: nextRun.id))
                }
            }
            
            // Today's Events
            if !viewModel.todayEvents.isEmpty {
                TodayEventsView(events: viewModel.todayEvents) { event in
                    if let runId = event.runId {
                        appCoordinator.navigate(to: .runDetail(runId: runId))
                    }
                }
            }
            
            Spacer()
        }
        .navigationTitle("Home")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Create Run") {
                    appCoordinator.presentSheet(.runCreation)
                }
            }
        }
        .onAppear {
            // Load initial data
            viewModel.loadData()
        }
        .refreshable {
            await viewModel.refreshData()
        }
    }
}

/// Quick actions view
struct QuickActionsView: View {
    @Environment(\.dependencyContainer) private var dependencyContainer
    @EnvironmentObject private var appCoordinator: AppCoordinator
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    QuickActionButton(
                        title: "Create Run",
                        icon: "plus.circle.fill",
                        color: .blue
                    ) {
                        appCoordinator.presentSheet(.runCreation)
                    }
                    
                    QuickActionButton(
                        title: "View Activity",
                        icon: "list.bullet.circle.fill",
                        color: .green
                    ) {
                        // Navigate to activity stream for most recent run
                        if let recentRunId = getRecentRunId() {
                            appCoordinator.navigate(to: .activityStream(runId: recentRunId))
                        }
                    }
                    
                    if dependencyContainer.roleManagementService.currentUserRole == .admin {
                        QuickActionButton(
                            title: "Admin Panel",
                            icon: "gear.circle.fill",
                            color: .orange
                        ) {
                            // TODO: Navigate to admin panel
                            appCoordinator.showAlert(message: "Admin panel coming soon")
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private func getRecentRunId() -> String? {
        // In a real implementation, this would get the most recent run ID
        return "demo_run_id"
    }
}

/// Quick action button
struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 80, height: 80)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Active run card view
struct ActiveRunCardView: View {
    let run: Run
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Active Run")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(run.status.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(run.status.color.opacity(0.2))
                    .foregroundColor(run.status.color)
                    .cornerRadius(8)
            }
            
            Text(run.title)
                .font(.title3)
                .fontWeight(.semibold)
            
            HStack {
                Label("Driver: \(run.driverId)", systemImage: "person.fill")
                Spacer()
                Label("\(run.passengers.count) passengers", systemImage: "person.2.fill")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            if run.isDelayed {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Delayed: \(run.delayReason ?? "Unknown reason")")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Button("View Details") {
                action()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

/// Next run card view
struct NextRunCardView: View {
    let run: Run
    let action: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Next Run")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text(run.scheduledTime, style: .time)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
            
            Text(run.title)
                .font(.title3)
                .fontWeight(.semibold)
            
            HStack {
                Label("Driver: \(run.driverId)", systemImage: "person.fill")
                Spacer()
                Label("\(run.passengers.count) passengers", systemImage: "person.2.fill")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            Button("View Details") {
                action()
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

/// Today's events view
struct TodayEventsView: View {
    let events: [Event]
    let onEventTap: (Event) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Events")
                .font(.headline)
                .padding(.horizontal)
            
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(events) { event in
                        EventRowView(event: event) {
                            onEventTap(event)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: 200)
        }
    }
}

/// Event row view
struct EventRowView: View {
    let event: Event
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(event.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(event.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(event.time, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Run detail view placeholder
struct RunDetailView: View {
    let runId: String
    @Environment(\.dependencyContainer) private var dependencyContainer
    @EnvironmentObject private var appCoordinator: AppCoordinator
    @State private var run: Run?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading run details...")
            } else if let run = run {
                RunDetailContentView(run: run)
            } else {
                Text("Run not found")
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Run Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadRun()
        }
    }
    
    private func loadRun() async {
        do {
            run = try await dependencyContainer.firebaseService.fetchRun(runId: runId)
        } catch {
            appCoordinator.handleError(error, context: "Loading run details")
        }
        isLoading = false
    }
}

/// Run detail content view
struct RunDetailContentView: View {
    let run: Run
    @Environment(\.dependencyContainer) private var dependencyContainer
    @EnvironmentObject private var appCoordinator: AppCoordinator
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Run header
                VStack(alignment: .leading, spacing: 8) {
                    Text(run.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    HStack {
                        Text(run.status.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(run.status.color.opacity(0.2))
                            .foregroundColor(run.status.color)
                            .cornerRadius(8)
                        
                        Spacer()
                        
                        Text(run.scheduledTime, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Driver and passengers info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Details")
                        .font(.headline)
                    
                    Label("Driver: \(run.driverId)", systemImage: "person.fill")
                    Label("\(run.passengers.count) passengers", systemImage: "person.2.fill")
                    Label("\(run.stops.count) stops", systemImage: "location.fill")
                }
                
                // Action buttons based on role
                let uiConfig = dependencyContainer.roleManagementService.getUIConfiguration(for: run)
                
                if uiConfig.showDriverInterface {
                    Button("Open Driver Mode") {
                        appCoordinator.navigate(to: .driverFocusMode(runId: run.id))
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
                
                if uiConfig.showObserverInterface {
                    Button("Track Run") {
                        appCoordinator.navigate(to: .observerTracking(runId: run.id))
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                }
                
                Button("View Activity") {
                    appCoordinator.navigate(to: .activityStream(runId: run.id))
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
    }
}

/// Run creation view placeholder
struct RunCreationView: View {
    @Environment(\.dependencyContainer) private var dependencyContainer
    @EnvironmentObject private var appCoordinator: AppCoordinator
    @EnvironmentObject private var viewModel: RunCreationViewModel
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Run Creation")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Multi-step run creation coming soon")
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Create Demo Run") {
                    Task {
                        do {
                            let demoRun = try await dependencyContainer.firebaseService.createDemoRun()
                            appCoordinator.handleRunCreationCompletion(runId: demoRun.id)
                        } catch {
                            appCoordinator.handleError(error, context: "Creating demo run")
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("Create Run")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        appCoordinator.dismissSheet()
                    }
                }
            }
        }
    }
}

// MARK: - Extensions

extension FamilyRole {
    var iconName: String {
        switch self {
        case .driver: return "car.fill"
        case .observer: return "eye.fill"
        case .admin: return "crown.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .driver: return .blue
        case .observer: return .green
        case .admin: return .orange
        }
    }
}

extension RunStatus {
    var color: Color {
        switch self {
        case .scheduled: return .blue
        case .activeEnroute: return .green
        case .arrivedAtStop: return .orange
        case .paused: return .yellow
        case .completed: return .purple
        case .cancelled: return .red
        }
    }
}

#Preview {
    let container = DependencyContainer()
    return MainNavigationView(dependencyContainer: container)
        .withDependencyContainer(container)
}