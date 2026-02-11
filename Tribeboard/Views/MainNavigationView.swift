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
    @State private var selectedTab: MainTab = .home
    
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
            HomeDashboardView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(MainTab.home)
            
            MyRunsView(
                viewModel: dependencyContainer.homeDashboardViewModel,
                scheduleRunGenerator: dependencyContainer.scheduleRunGenerator
            )
            .tabItem {
                Label("Runs", systemImage: "car.fill")
            }
            .tag(MainTab.runs)
            
            NavigationStack {
                CalendarView(viewModel: CalendarViewModel(generator: dependencyContainer.scheduleRunGenerator))
            }
            .tabItem {
                Label("Calendar", systemImage: "calendar")
            }
            .tag(MainTab.calendar)
            
            ActivityPlaceholderView()
                .tabItem {
                    Label("Feed", systemImage: "list.bullet")
                }
                .tag(MainTab.feed)
            
            FamilyView(viewModel: createFamilyViewModel())
                .tabItem {
                    Label("Tribe", systemImage: "person.3.fill")
                }
                .tag(MainTab.tribe)
        }
        .withDependencyContainer(dependencyContainer)
        .environmentObject(appCoordinator)
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
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 20) {
                    // Modern Header
                    ModernHeaderView(
                        userDisplayName: viewModel.currentUser.displayName,
                        profileImageURL: viewModel.currentUser.avatarURL,
                        onSettingsTap: {
                            appCoordinator.presentSheet(.settings)
                        }
                    )
                    .accessibilityElement(children: .contain)
                    
                    // Loading indicator during refresh
                    if viewModel.refreshing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding(.top, 8)
                            .accessibilityLabel("Loading")
                    }
                    
                    // Date and Status
                    DateAndStatusView(
                        currentDate: Date(),
                        activeRunCount: viewModel.activeRunCount,
                        lastSyncTime: viewModel.lastSyncTime
                    )
                    .padding(.horizontal)
                    
                    // What's Next Section
                    if let _ = viewModel.featuredEventData,
                       let nextRun = viewModel.nextRun {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("What's Next")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                                .accessibilityAddTraits(.isHeader)
                            
                            FeaturedEventCard(
                                run: nextRun,
                                onViewDetails: {
                                    appCoordinator.navigate(to: .runDetail(runId: nextRun.id))
                                },
                                onShare: {
                                    // TODO: Implement share functionality
                                    appCoordinator.showAlert(message: "Share coming soon")
                                }
                            )
                            .padding(.horizontal)
                        }
                    }
                    
                    // Today's Runs Section
                    if !viewModel.todayRunCards.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Today's Runs")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.horizontal)
                                .accessibilityAddTraits(.isHeader)
                            
                            LazyVStack(spacing: 12) {
                                ForEach(viewModel.todayRunCards, id: \.id) { runCard in
                                    if let run = viewModel.getDisplayRuns().first(where: { $0.id == runCard.id }) {
                                        CompactRunCard(run: run) {
                                            appCoordinator.navigate(to: .runDetail(runId: run.id))
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Bottom padding to account for floating button and navigation
                    Spacer()
                        .frame(height: 100)
                }
                .padding(.top)
            }
            .refreshable {
                await viewModel.refreshData()
            }
            .accessibilityElement(children: .contain)
            
            // Floating Create Button
            FloatingCreateButton {
                appCoordinator.presentSheet(.runCreation)
            }
            .padding(.trailing, 16)
            .padding(.bottom, 80) // Account for bottom navigation
        }
        .navigationBarHidden(true)
        .onAppear {
            // Load initial data
            viewModel.loadData()
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
            .background(Color(.secondarySystemFill))
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