import SwiftUI

/// Main navigation view that handles app-wide navigation and state management for UI/UX prototype
struct MainNavigationView: View {
    @StateObject private var appState = AppState()
    
    // Mock Services for prototype - no real database or CloudKit dependencies
    @State private var mockServiceCoordinator: MockServiceCoordinator?
    @State private var servicesInitialized = false
    @State private var showSplashScreen = true
    
    var body: some View {
        ZStack {
            if showSplashScreen {
                // Enhanced branded splash screen for prototype
                PrototypeSplashScreenView(message: "Initializing TribeBoard...")
                    .transition(.opacity)
            } else {
                // Main app content with mock services
                NavigationStack(path: $appState.navigationPath) {
                    Group {
                        if servicesInitialized {
                            switch appState.currentFlow {
                            case .onboarding:
                                // Enhanced onboarding view with mock authentication
                                if let mockServices = mockServiceCoordinator {
                                    MockOnboardingView(mockAuthService: mockServices.mockAuthService)
                                } else {
                                    OnboardingPlaceholderView()
                                        .environmentObject(mockServiceCoordinator ?? MockServiceCoordinator())
                                }
                            case .familySelection:
                                FamilySelectionView()
                            case .createFamily:
                                // For prototype, use a placeholder view instead of real CreateFamilyView
                                CreateFamilyPlaceholderView()
                                    .environmentObject(mockServiceCoordinator ?? MockServiceCoordinator())
                            case .joinFamily:
                                JoinFamilyView()
                            case .roleSelection:
                                if let user = appState.currentUser,
                                   let family = appState.currentFamily {
                                    MockRoleSelectionView(family: family, user: user)
                                } else {
                                    RoleSelectionPlaceholderView()
                                }
                            case .familyDashboard:
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
                            }
                        } else {
                            // Show loading state during mock service initialization
                            LoadingStateView()
                        }
                    }
                    .environmentObject(appState)
                    .environmentObject(mockServiceCoordinator ?? MockServiceCoordinator())
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            initializePrototypeApp()
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
                withAnimation(.easeInOut(duration: 0.8)) {
                    showSplashScreen = false
                }
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
                    Button(action: signInWithApple) {
                        HStack {
                            Image(systemName: "applelogo")
                            Text("Continue with Apple")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isSigningIn)
                    
                    Button(action: signInWithGoogle) {
                        HStack {
                            Image(systemName: "globe")
                            Text("Continue with Google")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isSigningIn)
                    
                    if isSigningIn {
                        ProgressView("Signing in...")
                            .progressViewStyle(CircularProgressViewStyle(tint: .brandPrimary))
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
        isSigningIn = true
        
        Task {
            // Simulate sign in delay
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            await MainActor.run {
                // Create mock user and sign in
                let mockUser = UserProfile(displayName: "Demo User", appleUserIdHash: "demo_user_hash")
                appState.signIn(user: mockUser)
                isSigningIn = false
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
                
                Button("Create Family") {
                    createMockFamily()
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(familyName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreating)
                
                if isCreating {
                    ProgressView("Creating family...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .brandPrimary))
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
        
        isCreating = true
        
        Task {
            // Simulate family creation delay
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            
            await MainActor.run {
                // Create mock family and membership
                let mockData = MockDataGenerator.mockFamilyWithMembers()
                let family = Family(name: familyName, code: "DEMO\(Int.random(in: 1000...9999))", createdByUserId: mockData.users[0].id)
                let membership = Membership(family: family, user: mockData.users[0], role: .parentAdmin)
                
                appState.setFamily(family, membership: membership)
                isCreating = false
            }
        }
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