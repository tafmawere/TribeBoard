import SwiftUI

/// Family selection view that allows users to choose between creating or joining a family
struct FamilySelectionView: View {
    @EnvironmentObject private var appState: AppState
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background gradient
                LinearGradient.brandGradientSubtle
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 40) {
                        Spacer(minLength: geometry.size.height * 0.1)
                        
                        // Header section
                        VStack(spacing: 24) {
                            // Welcome message with user name if available
                            VStack(spacing: 12) {
                                if let user = appState.currentUser {
                                    Text("Welcome, \(user.displayName)!")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.brandPrimary)
                                } else {
                                    Text("Welcome!")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.brandPrimary)
                                }
                                
                                Text("Family Setup")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                
                                Text("Create a new family or join an existing one to get started with TribeBoard")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                            }
                        }
                        
                        // Action buttons section
                        VStack(spacing: 24) {
                            // Create Family option
                            FamilyOptionCard(
                                icon: "plus.circle.fill",
                                title: "Create Family",
                                description: "Start a new family group and invite others to join",
                                buttonText: "Create New Family",
                                action: {
                                    appState.navigateTo(.createFamily)
                                }
                            )
                            
                            // Join Family option
                            FamilyOptionCard(
                                icon: "person.2.fill",
                                title: "Join Family",
                                description: "Enter a family code or scan a QR code to join an existing family",
                                buttonText: "Join Existing Family",
                                action: {
                                    appState.navigateTo(.joinFamily)
                                }
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: geometry.size.height * 0.1)
                    }
                    .padding(.vertical, 20)
                }
            }
        }
        .navigationTitle("Family Setup")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Sign Out") {
                    appState.signOut()
                }
                .foregroundColor(.brandPrimary)
            }
        }
    }
}

// MARK: - Family Option Card

/// Reusable card component for family selection options
struct FamilyOptionCard: View {
    let icon: String
    let title: String
    let description: String
    let buttonText: String
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Icon and title
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(.brandPrimary)
                
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
            }
            
            // Description
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 16)
            
            // Action button
            Button(action: action) {
                Text(buttonText)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        LinearGradient.brandGradient
                    )
                    .cornerRadius(BrandStyle.cornerRadius)
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusLarge)
                .fill(Color(.systemBackground))
                .shadow(
                    color: BrandStyle.standardShadow,
                    radius: BrandStyle.shadowRadius,
                    x: BrandStyle.shadowOffset.width,
                    y: BrandStyle.shadowOffset.height
                )
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        FamilySelectionView()
            .environmentObject({
                let appState = AppState()
                appState.currentUser = MockDataGenerator.mockAuthenticatedUser()
                return appState
            }())
    }
}

#Preview("Without User") {
    NavigationStack {
        FamilySelectionView()
            .environmentObject(AppState())
    }
}