import SwiftUI

/// Main navigation view that handles app-wide navigation and state management
struct MainNavigationView: View {
    @StateObject private var appState = AppState()
    
    var body: some View {
        NavigationStack(path: $appState.navigationPath) {
            Group {
                switch appState.currentFlow {
                case .onboarding:
                    OnboardingView()
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
            }
            .environmentObject(appState)
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
                let mockFamily = Family.mock()
                let mockMembership = Membership.mock(
                    familyId: mockFamily.id,
                    userId: appState.currentUser?.id ?? UUID(),
                    role: .adult
                )
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
                    appState.signOut()
                }
            }
        }
    }
}





#Preview {
    MainNavigationView()
}