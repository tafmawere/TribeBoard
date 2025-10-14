import SwiftUI

/// Main navigation view that handles app-wide navigation and state management for UI/UX prototype
struct MainNavigationView: View {
    @StateObject private var appState = AppState()
    @EnvironmentObject private var authService: AuthService
    
    // Mock Services for prototype - no real database or CloudKit dependencies
    @State private var mockServiceCoordinator: MockServiceCoordinator?
    @State private var servicesInitialized = false
    @State private var showSplashScreen = true
    
    var body: some View {
        ZStack {
            mainContentBasedOnState
        }
        .onAppear {
            initializePrototypeApp()
        }
        .onChange(of: authService.isAuthenticated) { _, isAuthenticated in
            handleAuthenticationStateChange(isAuthenticated)
        }
        .overlay {
            globalLoadingOverlay
        }
        .alert("Error", isPresented: .constant(appState.errorMessage != nil)) {
            errorAlertButton
        } message: {
            errorAlertMessage
        }
        .overlay(alignment: .bottomTrailing) {
            demoControlOverlay
        }
        .sheet(isPresented: .constant(false)) {
            demoLauncherSheet
        }
    }
    
    // MARK: - Main Content Views
    
    @ViewBuilder
    private var mainContentBasedOnState: some View {
        if showSplashScreen {
            splashScreenView
        } else if !authService.isAuthenticated {
            signInView
        } else {
            authenticatedContentView
        }
    }
    
    @ViewBuilder
    private var splashScreenView: some View {
        SplashScreenView()
            .transition(AnimationUtilities.fadeTransition)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("TribeBoard app loading")
            .accessibilityHint("Please wait while the app loads")
    }
    
    @ViewBuilder
    private var signInView: some View {
        SignInView()
            .transition(.opacity.combined(with: .scale))
    }
    
    @ViewBuilder
    private var authenticatedContentView: some View {
        NavigationStack(path: $appState.navigationPath) {
            mainNavigationContent
                .environmentObject(appState)
                .environmentObject(mockServiceCoordinator ?? MockServiceCoordinator())
                .animation(AnimationUtilities.smooth, value: appState.currentFlow)
                .navigationDestination(for: NavigationTab.self) { tab in
                    destinationView(for: tab)
                }
                .navigationDestination(for: SchoolRunRoute.self) { route in
                    schoolRunDestinationView(for: route)
                }
        }
        .transition(AnimationUtilities.slideTransition)
        .overlay(alignment: .bottom) {
            bottomNavigationOverlay
        }
    }
    
    @ViewBuilder
    private var mainNavigationContent: some View {
        Group {
            if servicesInitialized {
                currentFlowView
            } else {
                serviceInitializationView
            }
        }
    }
    
    @ViewBuilder
    private var currentFlowView: some View {
        switch appState.currentFlow {
        case .onboarding:
            onboardingFlowView
        case .familySelection:
            FamilySelectionView()
        case .createFamily:
            createFamilyFlowView
        case .joinFamily:
            JoinFamilyView()
        case .roleSelection:
            roleSelectionFlowView
        case .familyDashboard:
            dashboardContent
        }
    }
    
    @ViewBuilder
    private var onboardingFlowView: some View {
        if let mockServices = mockServiceCoordinator {
            MockOnboardingView(mockAuthService: mockServices.mockAuthService)
        } else {
            OnboardingPlaceholderView()
                .environmentObject(mockServiceCoordinator ?? MockServiceCoordinator())
        }
    }
    
    @ViewBuilder
    private var createFamilyFlowView: some View {
        CreateFamilyPlaceholderView()
            .environmentObject(mockServiceCoordinator ?? MockServiceCoordinator())
    }
    
    @ViewBuilder
    private var roleSelectionFlowView: some View {
        if let user = appState.currentUser,
           let family = appState.currentFamily {
            MockRoleSelectionView(family: family, user: user)
        } else {
            RoleSelectionPlaceholderView()
        }
    }
    
    @ViewBuilder
    private var serviceInitializationView: some View {
        LoadingStateView(
            style: .overlay,
            mockScenario: .authentication
        )
        .fadeTransition()
    }
    
    @ViewBuilder
    private var bottomNavigationOverlay: some View {
        if appState.shouldShowBottomNavigation {
            FloatingBottomNavigation(
                selectedTab: $appState.selectedNavigationTab,
                onTabSelected: { tab in
                    handleTabSelection(tab)
                }
            )
            .transition(
                .asymmetric(
                    insertion: .move(edge: .bottom)
                        .combined(with: .opacity)
                        .combined(with: .scale(scale: 0.9)),
                    removal: .move(edge: .bottom)
                        .combined(with: .opacity)
                )
            )
            .animation(DesignSystem.Animation.spring, value: appState.shouldShowBottomNavigation)
        }
    }
    
    @ViewBuilder
    private var globalLoadingOverlay: some View {
        if appState.isLoading {
            LoadingOverlay(
                message: "Processing your request...",
                showProgress: false
            )
            .transition(AnimationUtilities.fadeTransition)
        }
    }
    
    @ViewBuilder
    private var errorAlertButton: some View {
        Button("OK") {
            appState.clearError()
        }
    }
    
    @ViewBuilder
    private var errorAlertMessage: some View {
        if let errorMessage = appState.errorMessage {
            Text(errorMessage)
        }
    }
    
    @ViewBuilder
    private var demoControlOverlay: some View {
        if let demoManager = appState.getDemoManager() {
            DemoControlOverlay(demoManager: demoManager)
                .transition(.scale.combined(with: .opacity))
        }
    }
    
    @ViewBuilder
    private var demoLauncherSheet: some View {
        DemoLauncherView()
            .environmentObject(appState)
    }
    
    // MARK: - Navigation Support
    
    /// Dashboard content that responds to bottom navigation with smooth transitions
    @ViewBuilder
    private var dashboardContent: some View {
        Group {
            // Ensure user is authenticated before showing protected content
            if authService.isAuthenticated {
                switch appState.selectedNavigationTab {
                case .dashboard:
                    // Main family dashboard with School Run access
                    if let user = appState.currentUser,
                       let family = appState.currentFamily,
                       let membership = appState.currentMembership {
                        MockFamilyDashboardView(
                            family: family,
                            currentUserId: user.id,
                            currentUserRole: membership.role
                        )
                    } else {
                        FamilyDashboardPlaceholderView()
                    }
                
            case .calendar:
                // Calendar view
                CalendarView()
                
            case .schoolRun:
                // School Run main view
                SchoolRunView()
                
            case .homeLife:
                // HomeLife navigation hub
                HomeLifeNavigationView()
                
                case .tasks:
                    // Tasks view
                    if let user = appState.currentUser,
                       let membership = appState.currentMembership {
                        TasksView(
                            currentUserId: user.id,
                            currentUserRole: membership.role
                        )
                    } else {
                        TasksPlaceholderView()
                    }
                }
            } else {
                // User not authenticated - show placeholder
                Text("Please sign in to access this feature")
                    .bodyMedium()
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
            }
        }
        .transition(
            .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        )
        .animation(DesignSystem.Animation.smooth, value: appState.selectedNavigationTab)
    }
    
    /// Handle tab selection with enhanced navigation coordination
    private func handleTabSelection(_ tab: NavigationTab) {
        // Skip if already selected
        guard appState.selectedNavigationTab != tab else {
            // Light haptic for already selected tab
            HapticManager.shared.lightImpact()
            return
        }
        
        // Enhanced haptic feedback sequence
        HapticManager.shared.selection()
        
        // Coordinated animation sequence
        withAnimation(DesignSystem.Animation.smooth) {
            appState.handleTabSelection(tab)
        }
        
        // Additional success feedback after transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            HapticManager.shared.lightImpact()
        }
    }
    
    /// Get destination view for navigation
    @ViewBuilder
    private func destinationView(for tab: NavigationTab) -> some View {
        // Ensure user is authenticated before showing protected content
        if authService.isAuthenticated {
            switch tab {
        case .dashboard:
            if let user = appState.currentUser,
               let family = appState.currentFamily,
               let membership = appState.currentMembership {
                MockFamilyDashboardView(
                    family: family,
                    currentUserId: user.id,
                    currentUserRole: membership.role
                )
                .environmentObject(appState)
            } else {
                FamilyDashboardPlaceholderView()
                    .environmentObject(appState)
            }
            
        case .calendar:
            CalendarView()
                .environmentObject(appState)
            
        case .schoolRun:
            SchoolRunView()
                .environmentObject(appState)
            
        case .homeLife:
            HomeLifeNavigationView()
                .environmentObject(appState)
            
            case .tasks:
                if let user = appState.currentUser,
                   let membership = appState.currentMembership {
                    TasksView(
                        currentUserId: user.id,
                        currentUserRole: membership.role
                    )
                    .environmentObject(appState)
                } else {
                    TasksPlaceholderView()
                        .environmentObject(appState)
                }
            }
        } else {
            // User not authenticated - show sign-in prompt
            Text("Please sign in to access this feature")
                .bodyMedium()
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
        }
    }
    
    /// Get destination view for School Run navigation
    @ViewBuilder
    private func schoolRunDestinationView(for route: SchoolRunRoute) -> some View {
        // Ensure user is authenticated before showing protected content
        if authService.isAuthenticated {
            switch route {
        case .dashboard:
            SchoolRunView()
                .environmentObject(appState)
            
        case .scheduleNew:
            ScheduleNewRunView()
                .environmentObject(appState)
            
        case .scheduledList:
            ScheduledRunsListView()
                .environmentObject(appState)
            
        case .runDetail(let run):
            RunDetailView(run: run)
                .environmentObject(appState)
            
            case .runExecution(let run):
                RunExecutionView(run: run)
                    .environmentObject(appState)
            }
        } else {
            // User not authenticated - show sign-in prompt
            Text("Please sign in to access School Run features")
                .bodyMedium()
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
        }
    }
    
    // MARK: - Prototype App Initialization
    
    private func initializePrototypeApp() {
        Task {
            // Show enhanced splash screen for better demo experience
            let minimumSplashDuration: TimeInterval = 3.0
            let startTime = Date()
            
            // Initialize mock services (no database or CloudKit setup required)
            await initializeMockServices()
            
            // Calculate remaining time to show splash screen
            let elapsedTime = Date().timeIntervalSince(startTime)
            let remainingTime = max(0, minimumSplashDuration - elapsedTime)
            
            if remainingTime > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remainingTime * 1_000_000_000))
            }
            
            // Hide splash screen with smooth animation
            await MainActor.run {
                withAnimation(AnimationUtilities.smooth) {
                    showSplashScreen = false
                }
                
                // Trigger haptic feedback for app launch completion
                HapticManager.shared.success()
            }
        }
    }
    
    private func initializeMockServices() async {
        await MainActor.run {
            guard !servicesInitialized else { return }
            
            // Initialize MockServiceCoordinator - no database or CloudKit dependencies
            let mockServices = MockServiceCoordinator()
            self.mockServiceCoordinator = mockServices
            
            // Set mock services in AppState
            appState.setMockServiceCoordinator(mockServices)
            
            // Services are now initialized and ready
            servicesInitialized = true
        }
    }
    
    // MARK: - Authentication State Management
    
    private func handleAuthenticationStateChange(_ isAuthenticated: Bool) {
        if !isAuthenticated {
            // User signed out - reset app state and provide haptic feedback
            Task {
                await appState.signOut()
            }
            HapticManager.shared.lightImpact()
            
            // Clear any navigation state
            appState.navigationPath = NavigationPath()
            appState.selectedNavigationTab = .dashboard
        } else {
            // User signed in - provide success haptic feedback
            HapticManager.shared.success()
            
            // If we have a current user from AuthService, update AppState
            if let currentUser = authService.currentUser {
                appState.signIn(user: currentUser)
            }
        }
    }

}

// MARK: - Placeholder Views (TODO: Replace with real views in later tasks)









/// Placeholder for role selection view
struct RoleSelectionPlaceholderView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Select Role")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.brandPrimary)
            
            Text("This will be the role selection view")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            AnimatedPrimaryButton(
                title: "Mock Select Role",
                action: {
                    // Mock role selection
                    let mockData = MockDataGenerator.mockFamilyWithMembers()
                    let mockFamily = mockData.family
                    let mockMembership = mockData.memberships[1] // Use the adult membership
                    appState.setFamily(mockFamily, membership: mockMembership)
                },
                icon: "person.crop.circle.badge.checkmark"
            )
            
            Spacer()
        }
        .padding()
        .navigationTitle("Select Role")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
    }
}

/// Placeholder for onboarding view
struct OnboardingPlaceholderView: View {
    @EnvironmentObject var appState: AppState
    @State private var isSigningIn: Bool = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Logo and branding
            VStack(spacing: 24) {
                TribeBoardLogo(size: .large, showBackground: true)
                
                VStack(spacing: 8) {
                    Text("TribeBoard")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.brandPrimary)
                    
                    Text("Family Together")
                        .font(.headline)
                        .foregroundColor(.brandSecondary)
                }
            }
            
            Spacer()
            
            // Sign in section
            VStack(spacing: 20) {
                Text("Welcome to your family's digital home")
                    .font(.title2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.primary)
                
                VStack(spacing: 16) {
                    AnimatedPrimaryButton(
                        title: "Continue with Apple",
                        action: signInWithApple,
                        isLoading: isSigningIn,
                        icon: "applelogo"
                    )
                    
                    AnimatedSecondaryButton(
                        title: "Continue with Google",
                        action: signInWithGoogle,
                        isLoading: isSigningIn,
                        icon: "globe"
                    )
                    
                    if isSigningIn {
                        LoadingStateView(
                            style: .inline,
                            mockScenario: .authentication
                        )
                        .transition(AnimationUtilities.fadeTransition)
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
        .padding()
    }
    
    private func signInWithApple() {
        performMockSignIn()
    }
    
    private func signInWithGoogle() {
        performMockSignIn()
    }
    
    private func performMockSignIn() {
        withAnimation(AnimationUtilities.standard) {
            isSigningIn = true
        }
        
        // Haptic feedback for sign-in start
        HapticManager.shared.success()
        
        Task {
            // Simulate sign in delay with realistic timing
            try? await Task.sleep(nanoseconds: 2_200_000_000) // 2.2 seconds
            
            await MainActor.run {
                // Create mock user and sign in
                let mockUser = UserProfile(displayName: "Demo User", appleUserIdHash: "demo_user_hash")
                
                withAnimation(AnimationUtilities.smooth) {
                    appState.signIn(user: mockUser)
                    isSigningIn = false
                }
                
                // Success haptic feedback
                HapticManager.shared.success()
                
                // Show success toast
                ToastManager.shared.success("Authentication successful!")
            }
        }
    }
}

/// Placeholder for create family view
struct CreateFamilyPlaceholderView: View {
    @EnvironmentObject var appState: AppState
    @State private var familyName: String = ""
    @State private var isCreating: Bool = false
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Create Family")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.brandPrimary)
            
            VStack(spacing: 20) {
                TextField("Family Name", text: $familyName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                AnimatedPrimaryButton(
                    title: "Create Family",
                    action: createMockFamily,
                    isLoading: isCreating,
                    isEnabled: !familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    icon: "house.badge.plus"
                )
                
                if isCreating {
                    LoadingStateView(
                        style: .inline,
                        mockScenario: .familyCreation
                    )
                    .transition(AnimationUtilities.fadeTransition)
                }
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("Create Family")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
    }
    
    private func createMockFamily() {
        guard !familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        withAnimation(AnimationUtilities.standard) {
            isCreating = true
        }
        
        // Haptic feedback for family creation start
        HapticManager.shared.success()
        
        Task {
            // Simulate family creation delay with realistic timing
            try? await Task.sleep(nanoseconds: 1_800_000_000) // 1.8 seconds
            
            await MainActor.run {
                // Create mock family and membership
                let mockData = MockDataGenerator.mockFamilyWithMembers()
                let family = Family(name: familyName, code: "DEMO\(Int.random(in: 1000...9999))", createdByUserId: mockData.users[0].id)
                let membership = Membership(family: family, user: mockData.users[0], role: .parentAdmin)
                
                withAnimation(AnimationUtilities.smooth) {
                    appState.setFamily(family, membership: membership)
                    isCreating = false
                }
                
                // Success haptic feedback
                HapticManager.shared.success()
                
                // Show success toast with family code
                ToastManager.shared.showMockFamilyCreated()
            }
        }
    }
}

/// Placeholder for tasks view when user data is not available
struct TasksPlaceholderView: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 64))
                .foregroundColor(.brandPrimary)
                .accessibilityHidden(true)
            
            Text("Tasks")
                .headlineLarge()
                .foregroundColor(.primary)
            
            Text("Sign in to view your family tasks")
                .bodyMedium()
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Tasks")
        .navigationBarTitleDisplayMode(.inline)
    }
}



/// Placeholder for family dashboard view
struct FamilyDashboardPlaceholderView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject private var authService: AuthService
    
    var body: some View {
        VStack(spacing: 30) {
            if let family = appState.currentFamily {
                Text(family.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.brandPrimary)
            }
            
            if let membership = appState.currentMembership {
                Text("Your role: \(membership.role.displayName)")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            
            Text("This will be the family dashboard view")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            AnimatedSecondaryButton(
                title: "Leave Family",
                action: {
                    appState.leaveFamily()
                },
                icon: "house.badge.minus"
            )
            
            Spacer()
        }
        .padding()
        .navigationTitle("Family Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: settingsView) {
                    Image(systemName: "gearshape")
                        .foregroundColor(.brandPrimary)
                }
                .accessibilityLabel("Settings")
                .accessibilityHint("Open app settings")
            }
        }
    }
    
    @ViewBuilder
    private var settingsView: some View {
        if let user = appState.currentUser,
           let membership = appState.currentMembership {
            SettingsView(
                currentUserId: user.id,
                currentUserRole: membership.role,
                authService: authService
            )
        } else {
            Text("Settings unavailable")
                .foregroundColor(.secondary)
        }
    }
}





#Preview {
    MainNavigationView()
        .previewEnvironment()
}