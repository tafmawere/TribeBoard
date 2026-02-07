//
//  FamilySettingsView.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/07.
//

import SwiftUI

/// Family settings screen for admins to manage family name and settings
struct FamilySettingsView: View {
    @ObservedObject var viewModel: FamilyViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var editedFamilyName: String = ""
    @State private var showingSaveConfirmation = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Family Information") {
                    HStack {
                        Text("Family Name")
                        Spacer()
                        TextField("Enter name", text: $editedFamilyName)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        Text("Members")
                        Spacer()
                        Text("\(viewModel.familyMembers.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Family ID")
                        Spacer()
                        Text(viewModel.familyId)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Family Management") {
                    NavigationLink(destination: ManageMembersView(viewModel: viewModel)) {
                        Label("Manage Members", systemImage: "person.3")
                    }
                    
                    NavigationLink(destination: ManageRolesView(viewModel: viewModel)) {
                        Label("Manage Roles", systemImage: "person.badge.key")
                    }
                }
                
                Section {
                    Button(action: {
                        showingSaveConfirmation = true
                    }) {
                        HStack {
                            Spacer()
                            Text("Save Changes")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                    }
                    .disabled(editedFamilyName == viewModel.familyName)
                }
            }
            .navigationTitle("Family Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                editedFamilyName = viewModel.familyName
            }
            .alert("Save Changes", isPresented: $showingSaveConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    viewModel.updateFamilyName(editedFamilyName)
                    dismiss()
                }
            } message: {
                Text("Update family name to \"\(editedFamilyName)\"?")
            }
        }
    }
}

/// Manage members view for adding/removing members
struct ManageMembersView: View {
    @ObservedObject var viewModel: FamilyViewModel
    
    var body: some View {
        List {
            Section("Current Members") {
                ForEach(viewModel.familyMembers) { member in
                    HStack {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(avatarColor(for: member))
                                .frame(width: 40, height: 40)
                            
                            Text(member.avatarInitials)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(member.displayName)
                                .font(.headline)
                            
                            HStack(spacing: 4) {
                                ForEach(Array(member.roleBadges.prefix(2)), id: \.self) { badge in
                                    Text(badge.name)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(badgeColor(for: badge.color).opacity(0.2))
                                        .foregroundColor(badgeColor(for: badge.color))
                                        .cornerRadius(4)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // Remove button (can't remove self or if only 1 member)
                        if viewModel.familyMembers.count > 1 && member.id != viewModel.currentUserId {
                            Button(action: {
                                viewModel.removeMember(member.id)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            Section {
                Button(action: {
                    // This would open add member flow
                }) {
                    Label("Add Family Member", systemImage: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
            }
        }
        .navigationTitle("Manage Members")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func avatarColor(for member: FamilyMemberDisplay) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .indigo]
        let index = abs(member.id.hashValue) % colors.count
        return colors[index]
    }
    
    private func badgeColor(for color: FamilyMemberDisplay.RoleBadge.BadgeColor) -> Color {
        switch color {
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .purple: return .purple
        }
    }
}

/// Manage roles view for changing member roles
struct ManageRolesView: View {
    @ObservedObject var viewModel: FamilyViewModel
    @State private var selectedMemberId: String?
    @State private var selectedRole: FamilyRole?
    @State private var showingRoleChangeConfirmation = false
    
    var body: some View {
        List {
            Section("Change Member Roles") {
                ForEach(viewModel.familyMembers) { member in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            // Avatar
                            ZStack {
                                Circle()
                                    .fill(avatarColor(for: member))
                                    .frame(width: 40, height: 40)
                                
                                Text(member.avatarInitials)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(member.displayName)
                                    .font(.headline)
                                
                                Text(getCurrentRole(for: member))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        // Role picker
                        Picker("Role", selection: Binding(
                            get: { getRoleForMember(member.id) },
                            set: { newRole in
                                selectedMemberId = member.id
                                selectedRole = newRole
                                showingRoleChangeConfirmation = true
                            }
                        )) {
                            Text("Driver").tag(FamilyRole.driver)
                            Text("Observer").tag(FamilyRole.observer)
                            Text("Admin").tag(FamilyRole.admin)
                        }
                        .pickerStyle(.segmented)
                        .disabled(member.id == viewModel.currentUserId) // Can't change own role
                    }
                    .padding(.vertical, 8)
                }
            }
            
            Section {
                Text("Note: Changing a member's role will update their permissions immediately.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .navigationTitle("Manage Roles")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Change Role", isPresented: $showingRoleChangeConfirmation) {
            Button("Cancel", role: .cancel) {
                selectedMemberId = nil
                selectedRole = nil
            }
            Button("Change") {
                if let memberId = selectedMemberId, let role = selectedRole {
                    viewModel.changeMemberRole(memberId: memberId, newRole: role)
                }
                selectedMemberId = nil
                selectedRole = nil
            }
        } message: {
            if let memberId = selectedMemberId,
               let member = viewModel.familyMembers.first(where: { $0.id == memberId }),
               let role = selectedRole {
                Text("Change \(member.displayName)'s role to \(role.displayName)?")
            }
        }
    }
    
    private func getCurrentRole(for member: FamilyMemberDisplay) -> String {
        // Get primary role from badges
        if member.roleBadges.contains(where: { $0.name == "Driver" }) {
            return "Current: Driver"
        } else if member.roleBadges.contains(where: { $0.name == "Admin" }) {
            return "Current: Admin"
        } else {
            return "Current: Observer"
        }
    }
    
    private func getRoleForMember(_ memberId: String) -> FamilyRole {
        guard let member = viewModel.familyMembers.first(where: { $0.id == memberId }) else {
            return .observer
        }
        
        if member.roleBadges.contains(where: { $0.name == "Driver" }) {
            return .driver
        } else if member.roleBadges.contains(where: { $0.name == "Admin" }) {
            return .admin
        } else {
            return .observer
        }
    }
    
    private func avatarColor(for member: FamilyMemberDisplay) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .indigo]
        let index = abs(member.id.hashValue) % colors.count
        return colors[index]
    }
}
