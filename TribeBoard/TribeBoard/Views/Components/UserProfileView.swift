import SwiftUI

/// User profile display component showing current user information and authentication status
struct UserProfileView: View {
    @State private var showProfileEditor = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    let userProfile: UserProfile?
    let authService: AuthService?
    let onProfileUpdate: ((UserProfile) -> Void)?
    
    init(userProfile: UserProfile? = nil, authService: AuthService? = nil, onProfileUpdate: ((UserProfile) -> Void)? = nil) {
        self.userProfile = userProfile
        self.authService = authService
        self.onProfileUpdate = onProfileUpdate
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Profile header section
            profileHeaderSection
            
            // Authentication status section
            authenticationStatusSection
            
            // Profile actions section
            profileActionsSection
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .sheet(isPresented: $showProfileEditor) {
            ProfileEditorView(
                userProfile: currentUserProfile,
                onSave: handleProfileUpdate
            )
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - View Components
    
    private var profileHeaderSection: some View {
        HStack(spacing: 16) {
            // Profile avatar
            MemberAvatarView(userProfile: currentUserProfile)
                .scaleEffect(1.8) // Scale up to approximate 80pt size
            
            VStack(alignment: .leading, spacing: 8) {
                // Display name
                Text(currentUserProfile?.displayName ?? "Unknown User")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                // Apple ID indicator
                HStack(spacing: 6) {
                    Image(systemName: "applelogo")
                        .font(.caption)
                        .foregroundColor(.primary)
                    
                    Text("Apple ID")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Account creation date
                if let profile = currentUserProfile {
                    Text("Member since \(formatDate(profile.createdAt))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Edit button
            Button("Edit") {
                showProfileEditor = true
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.brandPrimary)
        }
    }
    
    private var authenticationStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Authentication Status")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                // Status indicator
                Circle()
                    .fill(isAuthenticated ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(isAuthenticated ? "Signed In" : "Not Signed In")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isAuthenticated ? .green : .red)
                    
                    Text(isAuthenticated ? "Your account is secure and authenticated" : "Please sign in to access your account")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isAuthenticated {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
    }
    
    private var profileActionsSection: some View {
        VStack(spacing: 12) {
            // Edit profile action
            ProfileActionRow(
                title: "Edit Profile",
                subtitle: "Update your display name and information",
                icon: "pencil",
                action: {
                    showProfileEditor = true
                }
            )
            
            // Privacy settings action
            ProfileActionRow(
                title: "Privacy Settings",
                subtitle: "Manage your privacy and data sharing preferences",
                icon: "eye.slash",
                action: {
                    // Navigate to privacy settings
                }
            )
            
            // Account security action
            ProfileActionRow(
                title: "Account Security",
                subtitle: "Review your account security settings",
                icon: "lock.shield",
                action: {
                    // Navigate to security settings
                }
            )
        }
    }
    
    // MARK: - Computed Properties
    
    private var currentUserProfile: UserProfile? {
        return userProfile ?? authService?.currentUser
    }
    
    private var isAuthenticated: Bool {
        return authService?.isAuthenticated ?? (userProfile != nil)
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func handleProfileUpdate(_ updatedProfile: UserProfile) {
        onProfileUpdate?(updatedProfile)
    }
}

// MARK: - Profile Action Row

struct ProfileActionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.brandPrimary)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    let mockUser = UserProfile(displayName: "John Doe", appleUserIdHash: "hash_john")
    let mockAuthService = AuthService()
    
    UserProfileView(userProfile: mockUser, authService: mockAuthService)
        .padding()
}