import SwiftUI
import SwiftData

/// Main navigation view that handles app-wide navigation and state management
struct MainNavigationView: View {
    @StateObject private var appState = AppState()
    @Environment(\.modelContext) private var modelContext
    
    // Services - will be initialized in onAppear
    @State private var authService: AuthService?
    @State private var dataService: DataService?
    @State private var servicesInitialized = false
    @State private var showSplashScreen = true
    
    var body: some View {
        ZStack {
            if showSplashScreen {
                // Show splash screen during initial loading
                AnimatedSplashScreenView(message: "Initializing TribeBoard...")
                    .transition(.opacity)
            } else {
                // Main app content
                NavigationStack(path: $appState.navigationPath) {
                    Group {
                        if servicesInitialized {
                            switch appState.currentFlow {
                            case .onboarding:
                                if let authService = authService {
                                    OnboardingView(authService: authService)
                                } else {
                                    LoadingStateView()
                                }
                            case .familySelection:
                                FamilySelectionView()
                            case .createFamily:
                                CreateFamilyView()
                            case .joinFamily:
                                JoinFamilyView()
                            case .roleSelection:
                                if let user = appState.currentUser,
                                   let family = appState.currentFamily {
                                    RoleSelectionView(family: family, user: user)
                                } else {
                                    RoleSelectionPlaceholderView()
                                }
                            case .familyDashboard:
                                if let user = appState.currentUser,
                                   let family = appState.currentFamily,
                                   let membership = appState.currentMembership {
                                    FamilyDashboardView(
                                        family: family,
                                        currentUserId: user.id,
                                        currentUserRole: membership.role
                                    )
                                } else {
                                    FamilyDashboardPlaceholderView()
                                }
                            }
                        } else {
                            SplashScreenView(message: "Setting up services...")
                        }
                    }
                    .environmentObject(appState)
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            initializeApp()
        }
        .overlay {
            // Global loading overlay
            if appState.isLoading {
                LoadingOverlay()
            }
        }
        .alert("Error", isPresented: .constant(appState.errorMessage != nil)) {
            Button("OK") {
                appState.clearError()
            }
        } message: {
            if let errorMessage = appState.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - App Initialization
    
    private func initializeApp() {
        Task {
            // Show splash screen for minimum duration for better UX
            let minimumSplashDuration: TimeInterval = 2.0
            let startTime = Date()
            
            // Initialize services
            await initializeServices()
            
            // Calculate remaining time to show splash screen
            let elapsedTime = Date().timeIntervalSince(startTime)
            let remainingTime = max(0, minimumSplashDuration - elapsedTime)
            
            if remainingTime > 0 {
                try? await Task.sleep(nanoseconds: UInt64(remainingTime * 1_000_000_000))
            }
            
            // Hide splash screen with animation
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showSplashScreen = false
                }
            }
        }
    }
    
    private func initializeServices() async {
        await MainActor.run {
            guard !servicesInitialized else { return }
            
            // Initialize DataService with the environment model context
            let dataService = DataService(modelContext: modelContext)
            self.dataService = dataService
            
            // Initialize AuthService and set DataService
            let authService = AuthService()
            authService.setDataService(dataService)
            self.authService = authService
            
            // Services are now initialized and ready
            servicesInitialized = true
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
            
            Button("Mock Select Role") {
                // Mock role selection
                let mockData = MockDataGenerator.mockFamilyWithMembers()
                let mockFamily = mockData.family
                let mockMembership = mockData.memberships[1] // Use the adult membership
                appState.setFamily(mockFamily, membership: mockMembership)
            }
            .buttonStyle(PrimaryButtonStyle())
            
            Spacer()
        }
        .padding()
        .navigationTitle("Select Role")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
    }
}

/// Placeholder for family dashboard view
struct FamilyDashboardPlaceholderView: View {
    @EnvironmentObject var appState: AppState
    
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
            
            Button("Leave Family") {
                appState.leaveFamily()
            }
            .buttonStyle(SecondaryButtonStyle())
            
            Spacer()
        }
        .padding()
        .navigationTitle("Family Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Sign Out") {
                    Task {
                        await appState.signOut()
                    }
                }
            }
        }
    }
}





#Preview {
    MainNavigationView()
}