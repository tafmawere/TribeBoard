import SwiftUI

/// Main family dashboard view displaying members and management controls
struct FamilyDashboardView: View {
    @StateObject private var viewModel: FamilyDashboardViewModel
    @EnvironmentObject var appState: AppState
    
    // MARK: - Initialization
    
    init() {
        // Initialize with current family and user from AppState
        // The actual family and user will be set when the view appears
        let placeholderFamilyId = UUID()
        let placeholderUserId = UUID()
        
        self._viewModel = StateObject(wrappedValue: FamilyDashboardViewModel(
            familyId: placeholderFamilyId,
            currentUserId: placeholderUserId,
            dataManager: InMemoryFamilyDataManager.shared
        ))
    }
    
    init(familyId: UUID, currentUserId: UUID) {
        self._viewModel = StateObject(wrappedValue: FamilyDashboardViewModel(
            familyId: familyId,
            currentUserId: currentUserId,
            dataManager: InMemoryFamilyDataManager.shared
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            mainContentView
                .navigationTitle("Family Dashboard")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    toolbarContent
                }
        }
        .task {
            await handleViewAppearance()
        }
        .withToast()
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            errorAlertButtons
        } message: {
            errorAlertMessage
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Family Dashboard Screen")
        .sheet(isPresented: $viewModel.showRoleChangeSheet) {
            roleChangeSheet
        }
        .confirmationDialog(
            "Remove Member",
            isPresented: $viewModel.showRemovalConfirmation,
            titleVisibility: .visible
        ) {
            removalConfirmationButtons
        } message: {
            removalConfirmationMessage
        }
    }
    
    // MARK: - Main Content Views
    
    @ViewBuilder
    private var mainContentView: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            contentBasedOnState
        }
    }
    
    @ViewBuilder
    private var contentBasedOnState: some View {
        if viewModel.isLoading && viewModel.members.isEmpty {
            loadingStateView
        } else if viewModel.members.isEmpty && !viewModel.isLoading {
            emptyStateView
        } else {
            membersContentView
        }
    }
    
    @ViewBuilder
    private var loadingStateView: some View {
        VStack(spacing: 20) {
            LoadingStateView(
                message: "Loading family members...",
                style: .card
            )
            .accessibilityLabel("Loading family members")
            
            SkeletonLoadingView(rows: 3, showAvatar: true)
                .accessibilityLabel("Loading placeholder")
        }
        .padding()
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
                .accessibilityHidden(true)
            
            Text("No Family Members")
                .font(.headline)
                .foregroundColor(.primary)
                .accessibilityAddTraits([.isHeader])
            
            Text("Invite family members to get started")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .accessibilityLabel("Invite family members to get started")
            
            Button("Invite Members") {
                HapticManager.shared.selection()
                // TODO: Implement invite functionality in later tasks
                print("Invite functionality coming soon")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Invite Members")
            .accessibilityHint("Opens the member invitation screen")
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No family members. Invite family members to get started")
    }
    
    @ViewBuilder
    private var membersContentView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                familyHeaderView
                membersSection
                
                if viewModel.canManageMembers {
                    adminControlsSection
                }
            }
            .padding()
        }
        .refreshable {
            HapticManager.shared.lightImpact()
            await viewModel.loadMembers()
        }
        .accessibilityLabel("Family dashboard content")
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                Button("Refresh") {
                    HapticManager.shared.lightImpact()
                    Task {
                        await viewModel.loadMembers()
                    }
                }
                
                Divider()
                
                Button("Leave Family", role: .destructive) {
                    HapticManager.shared.warning()
                    appState.leaveFamily()
                }
                
                Button("Sign Out", role: .destructive) {
                    HapticManager.shared.warning()
                    Task {
                        await appState.signOut()
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("Family options")
            .accessibilityHint("Shows family management options")
        }
    }
    
    // MARK: - Alert and Sheet Content
    
    @ViewBuilder
    private var errorAlertButtons: some View {
        Button("OK") {
            viewModel.clearError()
        }
        Button("Retry") {
            Task {
                await viewModel.loadMembers()
            }
        }
    }
    
    @ViewBuilder
    private var errorAlertMessage: some View {
        if let errorMessage = viewModel.errorMessage {
            Text(errorMessage)
        }
    }
    
    @ViewBuilder
    private var roleChangeSheet: some View {
        if let member = viewModel.selectedMember {
            RoleChangeSheet(
                member: member,
                user: viewModel.user(for: member),
                onRoleChange: { newRole in
                    Task {
                        await viewModel.changeRole(for: member, to: newRole)
                    }
                }
            )
        }
    }
    
    @ViewBuilder
    private var removalConfirmationButtons: some View {
        if let member = viewModel.memberToRemove,
           let user = viewModel.user(for: member) {
            Button("Remove \(user.name)", role: .destructive) {
                Task {
                    await viewModel.removeMember(member)
                }
            }
            Button("Cancel", role: .cancel) {
                viewModel.memberToRemove = nil
            }
        }
    }
    
    @ViewBuilder
    private var removalConfirmationMessage: some View {
        if let member = viewModel.memberToRemove,
           let user = viewModel.user(for: member) {
            Text("Are you sure you want to remove \(user.name) from the family? This action cannot be undone.")
        }
    }
    
    // MARK: - Helper Functions
    
    private func handleViewAppearance() async {
        // Update ViewModel with current app state when view appears
        if let currentFamily = appState.currentFamily,
           let currentUser = appState.currentUser {
            // Update the ViewModel with actual IDs
            await viewModel.updateContext(familyId: currentFamily.id, currentUserId: currentUser.id)
        }
        await viewModel.loadMembers()
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
                    .accessibilityAddTraits([.isHeader])
                    .accessibilityLabel("Family name: \(family.name)")
            }
            
            // Current user role badge
            HStack {
                Text("Your Role:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                RoleBadge(role: viewModel.currentUserRole)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Your role: \(viewModel.currentUserRole.displayName)")
            
            // Member count
            Text("\(viewModel.members.count) \(viewModel.members.count == 1 ? "Member" : "Members")")
                .font(.caption)
                .foregroundColor(.secondary)
                .accessibilityLabel("\(viewModel.members.count) family \(viewModel.members.count == 1 ? "member" : "members")")
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Family header")
    }
    
    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Family Members")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal, 4)
                .accessibilityAddTraits([.isHeader])
            
            LazyVStack(spacing: 8) {
                ForEach(viewModel.members, id: \.member.id) { memberWithUser in
                    MemberRowView(
                        member: memberWithUser.member,
                        user: memberWithUser.user,
                        canManage: viewModel.canManageMembers && memberWithUser.member.userId != appState.currentUser?.id,
                        onRoleChange: {
                            HapticManager.shared.selection()
                            viewModel.showRoleChange(for: memberWithUser.member)
                        },
                        onRemove: {
                            HapticManager.shared.warning()
                            viewModel.showRemovalConfirmation(for: memberWithUser.member)
                        }
                    )
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Family members section")
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
                        ToastManager.shared.info("Invite functionality coming soon")
                    }
                )
                
                AdminControlButton(
                    title: "Family Settings",
                    icon: "gearshape",
                    action: {
                        // TODO: Implement settings functionality in later tasks
                        ToastManager.shared.info("Settings functionality coming soon")
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
    let member: InMemoryMember
    let user: InMemoryUser?
    let canManage: Bool
    let onRoleChange: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            MemberAvatarView(user: user)
            
            // Member info
            VStack(alignment: .leading, spacing: 4) {
                Text(user?.name ?? "Unknown Member")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .accessibilityLabel("Member name: \(user?.name ?? "Unknown Member")")
                
                HStack(spacing: 8) {
                    RoleBadge(role: member.role)
                }
            }
            
            Spacer()
            
            // Management controls
            if canManage {
                HStack(spacing: 8) {
                    // Role change button
                    if member.role != .parent {
                        Button(action: onRoleChange) {
                            Image(systemName: "person.crop.circle.badge.questionmark")
                                .foregroundColor(.brandPrimary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .accessibilityLabel("Change role")
                        .accessibilityHint("Changes the role for \(user?.name ?? "this member")")
                    }
                    
                    // Remove button
                    Button(action: onRemove) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("Remove member")
                    .accessibilityHint("Removes \(user?.name ?? "this member") from the family")
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Member management controls")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Family member: \(user?.name ?? "Unknown Member"), role: \(member.role.displayName)")
        .accessibilityHint(canManage ? "Double tap to manage this member" : "")
    }
}

// MARK: - Member Avatar View

struct MemberAvatarView: View {
    let user: InMemoryUser?
    let userProfile: UserProfile?
    
    // Initializer for InMemoryUser
    init(user: InMemoryUser?) {
        self.user = user
        self.userProfile = nil
    }
    
    // Initializer for UserProfile
    init(userProfile: UserProfile?) {
        self.user = nil
        self.userProfile = userProfile
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.brandPrimary.opacity(0.1))
                .frame(width: 44, height: 44)
            
            if let user = user {
                Text(user.name.prefix(1).uppercased())
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.brandPrimary)
            } else if let userProfile = userProfile {
                Text(userProfile.displayName.prefix(1).uppercased())
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
    let role: InMemoryRole
    
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
        case .parent:
            return .red.opacity(0.1)
        case .child:
            return .green.opacity(0.1)
        case .guardian:
            return .blue.opacity(0.1)
        case .helper:
            return .orange.opacity(0.1)
        }
    }
    
    private var textColor: Color {
        switch role {
        case .parent:
            return .red
        case .child:
            return .green
        case .guardian:
            return .blue
        case .helper:
            return .orange
        }
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
    let member: InMemoryMember
    let user: InMemoryUser?
    let onRoleChange: (InMemoryRole) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedRole: InMemoryRole
    
    init(member: InMemoryMember, user: InMemoryUser?, onRoleChange: @escaping (InMemoryRole) -> Void) {
        self.member = member
        self.user = user
        self.onRoleChange = onRoleChange
        self._selectedRole = State(initialValue: member.role)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Member info
                VStack(spacing: 12) {
                    MemberAvatarView(user: user)
                    
                    Text(user?.name ?? "Unknown Member")
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
                    
                    ForEach(InMemoryRole.allCases, id: \.self) { role in
                        RoleSelectionRow(
                            role: role,
                            isSelected: selectedRole == role,
                            isDisabled: role == .parent && member.role != .parent,
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
    let role: InMemoryRole
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
    FamilyDashboardView()
        .environmentObject(AppState())
}