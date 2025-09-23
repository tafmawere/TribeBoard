import SwiftUI

/// View for editing a family member's role
struct EditMemberRoleView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRole: Role
    @State private var isLoading = false
    
    let member: MockFamilyMember
    let onSave: (Role) -> Void
    
    // MARK: - Initialization
    
    init(member: MockFamilyMember, onSave: @escaping (Role) -> Void) {
        self.member = member
        self.onSave = onSave
        self._selectedRole = State(initialValue: member.role)
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    LoadingStateView(
                        message: "Updating role...",
                        style: .card
                    )
                    .padding()
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Member info section
                            memberInfoSection
                            
                            // Current role section
                            currentRoleSection
                            
                            // Role selection section
                            roleSelectionSection
                            
                            // Role permissions section
                            rolePermissionsSection
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Edit Role")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveRole()
                    }
                    .disabled(selectedRole == member.role || isLoading)
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var memberInfoSection: some View {
        VStack(spacing: 16) {
            // Member avatar and info
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.brandPrimary.opacity(0.1))
                        .frame(width: 60, height: 60)
                    
                    Text(member.displayName.prefix(1).uppercased())
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.brandPrimary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(member.displayName)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(member.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Joined \(member.joinedDate, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var currentRoleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.badge.key")
                    .foregroundColor(.brandPrimary)
                
                Text("Current Role")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 4)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    RoleBadge(role: member.role)
                    
                    Spacer()
                    
                    Text("Since \(member.joinedDate, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(member.role.description)
                    .font(.subheadline)
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
    
    private var roleSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.2.badge.gearshape")
                    .foregroundColor(.brandPrimary)
                
                Text("Select New Role")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 4)
            
            VStack(spacing: 8) {
                ForEach(Role.allCases, id: \.self) { role in
                    RoleEditCard(
                        role: role,
                        isSelected: selectedRole == role,
                        isCurrent: role == member.role,
                        isDisabled: shouldDisableRole(role),
                        onSelect: {
                            selectedRole = role
                        }
                    )
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
    
    private var rolePermissionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "key")
                    .foregroundColor(.brandPrimary)
                
                Text("Role Permissions")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 4)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("What \(selectedRole.displayName) can do:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(getPermissions(for: selectedRole), id: \.self) { permission in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                            
                            Text(permission)
                                .font(.caption)
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                if !getRestrictions(for: selectedRole).isEmpty {
                    Divider()
                        .padding(.vertical, 4)
                    
                    Text("Restrictions:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(getRestrictions(for: selectedRole), id: \.self) { restriction in
                            HStack(spacing: 8) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                
                                Text(restriction)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
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
    
    // MARK: - Helper Methods
    
    private func shouldDisableRole(_ role: Role) -> Bool {
        // Disable Parent Admin role for now (would require special handling)
        return role == .parentAdmin && member.role != .parentAdmin
    }
    
    private func getPermissions(for role: Role) -> [String] {
        switch role {
        case .parentAdmin:
            return [
                "Manage all family members",
                "Create and assign tasks",
                "Manage family settings",
                "View all family data",
                "Send and receive messages",
                "Manage calendar events",
                "Coordinate school runs"
            ]
        case .adult:
            return [
                "Create and assign tasks",
                "Send and receive messages",
                "View family calendar",
                "Participate in school runs",
                "View family activities"
            ]
        case .kid:
            return [
                "Complete assigned tasks",
                "Send messages (if allowed)",
                "View family calendar",
                "Participate in activities"
            ]
        case .visitor:
            return [
                "View limited family information",
                "Send messages (if allowed)",
                "View public calendar events"
            ]
        }
    }
    
    private func getRestrictions(for role: Role) -> [String] {
        switch role {
        case .parentAdmin:
            return []
        case .adult:
            return [
                "Cannot manage family members",
                "Cannot change family settings"
            ]
        case .kid:
            return [
                "Cannot manage other members",
                "Cannot create tasks for others",
                "Limited messaging permissions"
            ]
        case .visitor:
            return [
                "Cannot manage family data",
                "Cannot create or assign tasks",
                "Limited access to family information"
            ]
        }
    }
    
    // MARK: - Actions
    
    private func saveRole() {
        isLoading = true
        
        Task {
            // Simulate save delay
            try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
            
            await MainActor.run {
                onSave(selectedRole)
                isLoading = false
                dismiss()
            }
        }
    }
}

// MARK: - Role Edit Card

struct RoleEditCard: View {
    let role: Role
    let isSelected: Bool
    let isCurrent: Bool
    let isDisabled: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: isDisabled ? {} : onSelect) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .brandPrimary : .secondary)
                    .font(.title3)
                
                // Role info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(role.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(isDisabled ? .secondary : .primary)
                        
                        if isCurrent {
                            Text("Current")
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(role.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                if isDisabled {
                    Text("Restricted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                Group {
                    if isSelected {
                        Color.brandPrimary.opacity(0.05)
                    } else if isCurrent {
                        Color.blue.opacity(0.05)
                    } else {
                        Color(.systemGray6)
                    }
                }
            )
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? Color.brandPrimary : (isCurrent ? Color.blue : Color.clear),
                        lineWidth: 2
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
    }
}

// MARK: - Preview

#Preview {
    let mockMember = MockFamilyMember(
        id: UUID(),
        displayName: "John Doe",
        email: "john@example.com",
        role: .adult,
        joinedDate: Calendar.current.date(byAdding: .month, value: -3, to: Date()) ?? Date(),
        isCurrentUser: false
    )
    
    EditMemberRoleView(member: mockMember) { newRole in
        print("New role: \(newRole.displayName)")
    }
}