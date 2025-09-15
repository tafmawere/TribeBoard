import SwiftUI

/// Main family dashboard view displaying members and management controls
struct FamilyDashboardView: View {
    @StateObject private var viewModel: FamilyDashboardViewModel
    @EnvironmentObject var appState: AppState
    
    // MARK: - Initialization
    
    init(family: Family, currentUserId: UUID, currentUserRole: Role) {
        self._viewModel = StateObject(wrappedValue: FamilyDashboardViewModel(
            family: family,
            currentUserId: currentUserId,
            currentUserRole: currentUserRole
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.members.isEmpty {
                    // Initial loading state with skeleton
                    VStack(spacing: 20) {
                        LoadingStateView(
                            message: "Loading family members...",
                            style: .card
                        )
                        
                        SkeletonLoadingView(rows: 3, showAvatar: true)
                    }
                    .padding()
                } else if viewModel.members.isEmpty && !viewModel.isLoading {
                    // Empty state
                    EmptyStateView.noMembers {
                        // TODO: Implement invite functionality in later tasks
                        ToastManager.shared.info("Invite functionality coming soon")
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // Family header
                            familyHeaderView
                            
                            // Members section
                            membersSection
                            
                            // Admin controls section
                            if viewModel.canManageMembers {
                                adminControlsSection
                            }
                        }
                        .padding()
                    }
                    .refreshable {
                        await viewModel.loadMembers()
                    }
                }
            }
            .navigationTitle("Family Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Refresh") {
                            Task {
                                await viewModel.loadMembers()
                            }
                        }
                        
                        Divider()
                        
                        Button("Leave Family", role: .destructive) {
                            appState.leaveFamily()
                        }
                        
                        Button("Sign Out", role: .destructive) {
                            appState.signOut()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .task {
            await viewModel.loadMembers()
        }
        .withToast()
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearErrorMessage()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .sheet(isPresented: $viewModel.showRoleChangeSheet) {
            if let member = viewModel.selectedMember {
                RoleChangeSheet(
                    member: member,
                    userProfile: viewModel.userProfile(for: member),
                    onRoleChange: { newRole in
                        Task {
                            await viewModel.changeRole(for: member, to: newRole)
                        }
                    }
                )
            }
        }
        .confirmationDialog(
            "Remove Member",
            isPresented: $viewModel.showRemovalConfirmation,
            titleVisibility: .visible
        ) {
            if let member = viewModel.memberToRemove,
               let profile = viewModel.userProfile(for: member) {
                Button("Remove \(profile.displayName)", role: .destructive) {
                    Task {
                        await viewModel.removeMember(member)
                    }
                }
                Button("Cancel", role: .cancel) {
                    viewModel.memberToRemove = nil
                }
            }
        } message: {
            if let member = viewModel.memberToRemove,
               let profile = viewModel.userProfile(for: member) {
                Text("Are you sure you want to remove \(profile.displayName) from the family? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - View Components
    
    private var familyHeaderView: some View {
        VStack(spacing: 12) {
            // Family name
            if let family = appState.currentFamily {
                Text(family.name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.brandPrimary)
            }
            
            // Current user role badge
            HStack {
                Text("Your Role:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                RoleBadge(role: viewModel.currentUserRole)
            }
            
            // Member count
            Text("\(viewModel.members.count) \(viewModel.members.count == 1 ? "Member" : "Members")")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Family Members")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal, 4)
            
            LazyVStack(spacing: 8) {
                ForEach(viewModel.members) { member in
                    MemberRowView(
                        member: member,
                        userProfile: viewModel.userProfile(for: member),
                        canManage: viewModel.canManageMembers && member.userId != appState.currentUser?.id,
                        onRoleChange: {
                            viewModel.showRoleChange(for: member)
                        },
                        onRemove: {
                            viewModel.showRemovalConfirmation(for: member)
                        }
                    )
                }
            }
        }
    }
    
    private var adminControlsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Admin Controls")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal, 4)
            
            VStack(spacing: 8) {
                AdminControlButton(
                    title: "Invite New Member",
                    icon: "person.badge.plus",
                    action: {
                        // TODO: Implement invite functionality in later tasks
                        viewModel.errorMessage = "Invite functionality coming soon"
                    }
                )
                
                AdminControlButton(
                    title: "Family Settings",
                    icon: "gearshape",
                    action: {
                        // TODO: Implement settings functionality in later tasks
                        viewModel.errorMessage = "Settings functionality coming soon"
                    }
                )
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
}

// MARK: - Member Row View

struct MemberRowView: View {
    let member: Membership
    let userProfile: UserProfile?
    let canManage: Bool
    let onRoleChange: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            MemberAvatarView(userProfile: userProfile)
            
            // Member info
            VStack(alignment: .leading, spacing: 4) {
                Text(userProfile?.displayName ?? "Unknown Member")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    RoleBadge(role: member.role)
                    
                    if member.status == .invited {
                        StatusBadge(status: member.status)
                    }
                }
            }
            
            Spacer()
            
            // Management controls
            if canManage && member.status == .active {
                HStack(spacing: 8) {
                    // Role change button
                    if member.role != .parentAdmin {
                        Button(action: onRoleChange) {
                            Image(systemName: "person.crop.circle.badge.questionmark")
                                .foregroundColor(.brandPrimary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Remove button
                    Button(action: onRemove) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Member Avatar View

struct MemberAvatarView: View {
    let userProfile: UserProfile?
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.brandPrimary.opacity(0.1))
                .frame(width: 44, height: 44)
            
            if let profile = userProfile {
                Text(profile.displayName.prefix(1).uppercased())
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.brandPrimary)
            } else {
                Image(systemName: "person.fill")
                    .foregroundColor(.brandPrimary)
            }
        }
    }
}

// MARK: - Role Badge

struct RoleBadge: View {
    let role: Role
    
    var body: some View {
        Text(role.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(textColor)
            .cornerRadius(8)
    }
    
    private var backgroundColor: Color {
        switch role {
        case .parentAdmin:
            return .red.opacity(0.1)
        case .adult:
            return .blue.opacity(0.1)
        case .kid:
            return .green.opacity(0.1)
        case .visitor:
            return .orange.opacity(0.1)
        }
    }
    
    private var textColor: Color {
        switch role {
        case .parentAdmin:
            return .red
        case .adult:
            return .blue
        case .kid:
            return .green
        case .visitor:
            return .orange
        }
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: MembershipStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.1))
            .foregroundColor(.orange)
            .cornerRadius(6)
    }
}

// MARK: - Admin Control Button

struct AdminControlButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.brandPrimary)
                    .frame(width: 20)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
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

// MARK: - Role Change Sheet

struct RoleChangeSheet: View {
    let member: Membership
    let userProfile: UserProfile?
    let onRoleChange: (Role) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRole: Role
    
    init(member: Membership, userProfile: UserProfile?, onRoleChange: @escaping (Role) -> Void) {
        self.member = member
        self.userProfile = userProfile
        self.onRoleChange = onRoleChange
        self._selectedRole = State(initialValue: member.role)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Member info
                VStack(spacing: 12) {
                    MemberAvatarView(userProfile: userProfile)
                    
                    Text(userProfile?.displayName ?? "Unknown Member")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("Current Role: \(member.role.displayName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Role selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Select New Role")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(Role.allCases, id: \.self) { role in
                        RoleSelectionRow(
                            role: role,
                            isSelected: selectedRole == role,
                            isDisabled: role == .parentAdmin && member.role != .parentAdmin,
                            onSelect: {
                                selectedRole = role
                            }
                        )
                    }
                }
                
                Spacer()
            }
            .navigationTitle("Change Role")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onRoleChange(selectedRole)
                        dismiss()
                    }
                    .disabled(selectedRole == member.role)
                }
            }
        }
    }
}

// MARK: - Role Selection Row

struct RoleSelectionRow: View {
    let role: Role
    let isSelected: Bool
    let isDisabled: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: isDisabled ? {} : onSelect) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .brandPrimary : .secondary)
                
                // Role info
                VStack(alignment: .leading, spacing: 4) {
                    Text(role.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isDisabled ? .secondary : .primary)
                    
                    Text(role.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                if isDisabled {
                    Text("Unavailable")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.brandPrimary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isDisabled)
        .padding(.horizontal)
    }
}

// MARK: - Preview

#Preview {
    let mockFamily = Family.mock()
    let mockUserId = UUID()
    
    FamilyDashboardView(
        family: mockFamily,
        currentUserId: mockUserId,
        currentUserRole: .parentAdmin
    )
    .environmentObject(AppState())
}