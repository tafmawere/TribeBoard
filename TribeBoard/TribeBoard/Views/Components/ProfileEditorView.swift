import SwiftUI

/// Profile editor view for updating user information
struct ProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    let userProfile: UserProfile?
    let onSave: (UserProfile) -> Void
    
    // MARK: - Initialization
    
    init(userProfile: UserProfile?, onSave: @escaping (UserProfile) -> Void) {
        self.userProfile = userProfile
        self.onSave = onSave
        self._displayName = State(initialValue: userProfile?.displayName ?? "")
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    LoadingStateView(
                        message: "Updating profile...",
                        style: .card
                    )
                    .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Profile avatar section
                            profileAvatarSection
                            
                            // Profile form section
                            profileFormSection
                            
                            // Additional info section
                            additionalInfoSection
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                }
            }
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
    
    private var profileAvatarSection: some View {
        VStack(spacing: 16) {
            // Large avatar
            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.1))
                    .frame(width: 120, height: 120)
                
                if let profile = userProfile {
                    Text(profile.displayName.prefix(1).uppercased())
                        .font(.system(size: 48, weight: .semibold))
                        .foregroundColor(.brandPrimary)
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.brandPrimary)
                }
                
                // Camera overlay
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: changeProfilePhoto) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.brandPrimary)
                                .clipShape(Circle())
                        }
                        .offset(x: -8, y: -8)
                    }
                }
            }
            
            Button("Change Photo") {
                changeProfilePhoto()
            }
            .font(.subheadline)
            .foregroundColor(.brandPrimary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var profileFormSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Profile Information")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal, 4)
            
            VStack(spacing: 16) {
                // Display name field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Display Name")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    TextField("Enter your display name", text: $displayName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.words)
                        .disableAutocorrection(true)
                }
                
                // Email field (read-only for prototype)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Text((userProfile?.appleUserIdHash.replacingOccurrences(of: "hash_", with: "") ?? "user") + "@example.com")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("Verified")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .foregroundColor(.green)
                            .cornerRadius(8)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                // Phone number field (mock)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Phone Number")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    HStack {
                        TextField("Add phone number", text: .constant(""))
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disabled(true)
                        
                        Button("Add") {
                            // Mock add phone functionality
                        }
                        .font(.subheadline)
                        .foregroundColor(.brandPrimary)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
    
    private var additionalInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Additional Settings")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal, 4)
            
            VStack(spacing: 12) {
                // Notification preferences
                ProfileSettingRow(
                    title: "Notification Preferences",
                    subtitle: "Manage how you receive notifications",
                    icon: "bell",
                    action: {
                        // Navigate to notification preferences
                    }
                )
                
                // Privacy settings
                ProfileSettingRow(
                    title: "Privacy Settings",
                    subtitle: "Control who can see your information",
                    icon: "eye.slash",
                    action: {
                        // Navigate to privacy settings
                    }
                )
                
                // Account security
                ProfileSettingRow(
                    title: "Account Security",
                    subtitle: "Manage your account security settings",
                    icon: "lock.shield",
                    action: {
                        // Navigate to security settings
                    }
                )
                
                Divider()
                
                // Dangerous actions
                ProfileSettingRow(
                    title: "Delete Account",
                    subtitle: "Permanently delete your account and data",
                    icon: "trash",
                    isDestructive: true,
                    action: {
                        // Show delete account confirmation
                    }
                )
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
    
    // MARK: - Actions
    
    private func changeProfilePhoto() {
        // Mock photo change functionality - would show photo picker in real app
    }
    
    private func saveProfile() {
        guard !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Display name cannot be empty"
            return
        }
        
        isLoading = true
        
        Task {
            // Simulate save delay
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            await MainActor.run {
                // Create updated profile
                let updatedProfile = UserProfile(
                    displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                    appleUserIdHash: userProfile?.appleUserIdHash ?? "mock_hash"
                )
                // Preserve the original ID if updating existing profile
                if let existingId = userProfile?.id {
                    updatedProfile.id = existingId
                }
                
                onSave(updatedProfile)
                isLoading = false
                dismiss()
            }
        }
    }
}

// MARK: - Profile Setting Row

struct ProfileSettingRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let isDestructive: Bool
    let action: () -> Void
    
    init(
        title: String,
        subtitle: String,
        icon: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.isDestructive = isDestructive
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(isDestructive ? .red : .brandPrimary)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isDestructive ? .red : .primary)
                    
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
    
    ProfileEditorView(
        userProfile: mockUser,
        onSave: { _ in }
    )
}