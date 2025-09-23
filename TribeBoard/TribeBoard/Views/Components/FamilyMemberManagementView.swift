import SwiftUI

/// Family member management view with mock add/remove operations
struct FamilyMemberManagementView: View {
    @StateObject private var viewModel: FamilyMemberManagementViewModel
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Initialization
    
    init(familyId: UUID, currentUserRole: Role) {
        self._viewModel = StateObject(wrappedValue: FamilyMemberManagementViewModel(
            familyId: familyId,
            currentUserRole: currentUserRole
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if viewModel.isLoading {
                    LoadingStateView(
                        message: "Loading family members...",
                        style: .card
                    )
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            // Add member section
                            addMemberSection
                            
                            // Current members section
                            currentMembersSection
                            
                            // Pending invitations section
                            if !viewModel.pendingInvitations.isEmpty {
                                pendingInvitationsSection
                            }
                            
                            // Family statistics section
                            familyStatisticsSection
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Manage Members")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Invite") {
                        viewModel.showInviteMember = true
                    }
                    .disabled(!viewModel.canManageMembers)
                }
            }
        }
        .task {
            await viewModel.loadMembers()
        }
        .withToast()
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
            }
        }
        .sheet(isPresented: $viewModel.showInviteMember) {
            InviteMemberView(
                onInvite: { email, role in
                    viewModel.inviteMember(email: email, role: role)
                }
            )
        }
        .sheet(isPresented: $viewModel.showRoleEditor) {
            if let member = viewModel.selectedMember {
                EditMemberRoleView(
                    member: member,
                    onSave: { newRole in
                        viewModel.updateMemberRole(member, newRole: newRole)
                    }
                )
            }
        }
        .confirmationDialog(
            "Remove Member",
            isPresented: $viewModel.showRemoveConfirmation,
            titleVisibility: .visible
        ) {
            if let member = viewModel.memberToRemove {
                Button("Remove \(member.displayName)", role: .destructive) {
                    viewModel.removeMember(member)
                }
                Button("Cancel", role: .cancel) {
                    viewModel.memberToRemove = nil
                }
            }
        } message: {
            if let member = viewModel.memberToRemove {
                Text("Are you sure you want to remove \(member.displayName) from the family? This action cannot be undone.")
            }
        }
    }
    
    // MARK: - View Components
    
    private var addMemberSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.badge.plus")
                    .foregroundColor(.brandPrimary)
                    .font(.headline)
                
                Text("Add New Member")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 4)
            
            VStack(spacing: 12) {
                // Quick invite button
                Button(action: {
                    viewModel.showInviteMember = true
                }) {
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(.white)
                        
                        Text("Send Invitation")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.brandPrimary)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!viewModel.canManageMembers)
                
                // Share family code
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Family Code")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Share this code for others to join")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack {
                        Text(viewModel.familyCode)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.brandPrimary)
                        
                        Button(action: {
                            viewModel.copyFamilyCode()
                        }) {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.brandPrimary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
    
    private var currentMembersSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "person.2")
                    .foregroundColor(.brandPrimary)
                    .font(.headline)
                
                Text("Current Members")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(viewModel.members.count)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.brandPrimary.opacity(0.1))
                    .foregroundColor(.brandPrimary)
                    .cornerRadius(8)
            }
            .padding(.horizontal, 4)
            
            LazyVStack(spacing: 8) {
                ForEach(viewModel.members) { member in
                    MemberManagementRow(
                        member: member,
                        canEdit: viewModel.canManageMembers && member.id != viewModel.currentUserId,
                        onEditRole: {
                            viewModel.editMemberRole(member)
                        },
                        onRemove: {
                            viewModel.showRemoveConfirmation(for: member)
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
    
    private var pendingInvitationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.orange)
                    .font(.headline)
                
                Text("Pending Invitations")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(viewModel.pendingInvitations.count)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .foregroundColor(.orange)
                    .cornerRadius(8)
            }
            .padding(.horizontal, 4)
            
            LazyVStack(spacing: 8) {
                ForEach(viewModel.pendingInvitations) { invitation in
                    PendingInvitationRow(
                        invitation: invitation,
                        onResend: {
                            viewModel.resendInvitation(invitation)
                        },
                        onCancel: {
                            viewModel.cancelInvitation(invitation)
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
    
    private var familyStatisticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "chart.bar")
                    .foregroundColor(.brandPrimary)
                    .font(.headline)
                
                Text("Family Statistics")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 4)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                StatisticCard(
                    title: "Total Members",
                    value: "\(viewModel.members.count)",
                    icon: "person.2",
                    color: .blue
                )
                
                StatisticCard(
                    title: "Admins",
                    value: "\(viewModel.adminCount)",
                    icon: "crown",
                    color: .red
                )
                
                StatisticCard(
                    title: "Adults",
                    value: "\(viewModel.adultCount)",
                    icon: "person",
                    color: .green
                )
                
                StatisticCard(
                    title: "Children",
                    value: "\(viewModel.childCount)",
                    icon: "figure.child",
                    color: .orange
                )
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
    }
}

// MARK: - Member Management Row

struct MemberManagementRow: View {
    let member: MockFamilyMember
    let canEdit: Bool
    let onEditRole: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Text(member.displayName.prefix(1).uppercased())
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.brandPrimary)
            }
            
            // Member info
            VStack(alignment: .leading, spacing: 4) {
                Text(member.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    RoleBadge(role: member.role)
                    
                    if member.isCurrentUser {
                        Text("You")
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
            
            // Management controls
            if canEdit {
                HStack(spacing: 8) {
                    Button(action: onEditRole) {
                        Image(systemName: "pencil")
                            .foregroundColor(.brandPrimary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: onRemove) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Pending Invitation Row

struct PendingInvitationRow: View {
    let invitation: MockPendingInvitation
    let onResend: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "envelope")
                .foregroundColor(.orange)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(invitation.email)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    RoleBadge(role: invitation.role)
                    
                    Text("Sent \(invitation.sentDate, style: .relative) ago")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button("Resend") {
                    onResend()
                }
                .font(.caption)
                .foregroundColor(.brandPrimary)
                
                Button("Cancel") {
                    onCancel()
                }
                .font(.caption)
                .foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Statistic Card

struct StatisticCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    FamilyMemberManagementView(
        familyId: UUID(),
        currentUserRole: .parentAdmin
    )
}