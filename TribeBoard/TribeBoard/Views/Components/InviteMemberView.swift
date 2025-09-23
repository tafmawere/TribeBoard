import SwiftUI

/// View for inviting new family members
struct InviteMemberView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var selectedRole: Role = .adult
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    let onInvite: (String, Role) -> Void
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    LoadingStateView(
                        message: "Sending invitation...",
                        style: .card
                    )
                    .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header section
                            headerSection
                            
                            // Email input section
                            emailInputSection
                            
                            // Role selection section
                            roleSelectionSection
                            
                            // Invitation preview section
                            invitationPreviewSection
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Invite Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send") {
                        sendInvitation()
                    }
                    .disabled(email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
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
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.badge.person.crop")
                .font(.system(size: 60))
                .foregroundColor(.brandPrimary)
            
            VStack(spacing: 8) {
                Text("Invite Family Member")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Send an invitation to join your family on TribeBoard")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var emailInputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "envelope")
                    .foregroundColor(.brandPrimary)
                
                Text("Email Address")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 4)
            
            VStack(alignment: .leading, spacing: 12) {
                TextField("Enter email address", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                Text("We'll send them an invitation link to join your family")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
    
    private var roleSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.badge.key")
                    .foregroundColor(.brandPrimary)
                
                Text("Select Role")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 4)
            
            VStack(spacing: 8) {
                ForEach(Role.allCases.filter { $0 != .parentAdmin }, id: \.self) { role in
                    RoleSelectionCard(
                        role: role,
                        isSelected: selectedRole == role,
                        onSelect: {
                            selectedRole = role
                        }
                    )
                }
                
                // Note about parent admin role
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    
                    Text("Parent Admin role can only be transferred, not assigned to new members")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 8)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
    
    private var invitationPreviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "eye")
                    .foregroundColor(.brandPrimary)
                
                Text("Invitation Preview")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 4)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Subject: You're invited to join our family on TribeBoard!")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hi there!")
                        .font(.subheadline)
                    
                    Text("You've been invited to join our family on TribeBoard as a \(selectedRole.displayName).")
                        .font(.subheadline)
                    
                    Text("TribeBoard helps families stay organized with shared calendars, tasks, messaging, and more.")
                        .font(.subheadline)
                    
                    Text("Tap the link below to accept the invitation and get started:")
                        .font(.subheadline)
                    
                    Text("[Join Family - TribeBoard]")
                        .font(.subheadline)
                        .foregroundColor(.brandPrimary)
                        .underline()
                }
                
                Divider()
                
                Text("This invitation will expire in 7 days.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
    
    // MARK: - Actions
    
    private func sendInvitation() {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedEmail.isEmpty else {
            errorMessage = "Please enter an email address"
            return
        }
        
        guard isValidEmail(trimmedEmail) else {
            errorMessage = "Please enter a valid email address"
            return
        }
        
        isLoading = true
        
        Task {
            // Simulate sending delay
            try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
            
            await MainActor.run {
                onInvite(trimmedEmail, selectedRole)
                isLoading = false
                dismiss()
            }
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

// MARK: - Role Selection Card

struct RoleSelectionCard: View {
    let role: Role
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .brandPrimary : .secondary)
                    .font(.title3)
                
                // Role info
                VStack(alignment: .leading, spacing: 4) {
                    Text(role.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(role.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            .padding()
            .background(isSelected ? Color.brandPrimary.opacity(0.05) : Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.brandPrimary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Preview

#Preview {
    InviteMemberView { email, role in
        print("Inviting \(email) as \(role.displayName)")
    }
}