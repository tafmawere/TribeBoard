//
//  SettingsView.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/09.
//

import SwiftUI

/// Main settings screen with app information and demo tools
struct SettingsView: View {
    @Environment(\.dependencyContainer) private var dependencyContainer
    @State private var showingSwitchUserSheet = false
    
    var body: some View {
        NavigationView {
            List {
                // App Information Section
                Section("App Information") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (Demo)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Launch Mode")
                        Spacer()
                        Text(launchMode)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Current User")
                        Spacer()
                        Text(currentUserName)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Demo Tools Section (only visible in demo mode)
                if AppConfig.isDemoFlowEnabled {
                    Section("Demo Tools") {
                        Button(action: {
                            showingSwitchUserSheet = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "person.crop.circle.badge.checkmark")
                                    .font(.system(size: 20))
                                    .foregroundColor(.blue)
                                    .frame(width: 28)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Switch Active User")
                                        .foregroundColor(.primary)
                                    
                                    Text("Demo only")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingSwitchUserSheet) {
                SwitchUserSheet()
            }
        }
    }
    
    private var launchMode: String {
        if AppConfig.isActiveRunOnlyMode {
            return "Active Run Only"
        } else if AppConfig.isDemoFlowEnabled {
            return "Demo Flow"
        } else {
            return "Full App"
        }
    }
    
    private var currentUserName: String {
        let userId = dependencyContainer.roleManagementService.currentUserId
        switch userId {
        case DemoSeedDataService.rueId:
            return "Rue Mawere"
        case DemoSeedDataService.tafadzwaId:
            return "Tafadzwa Mawere"
        case DemoSeedDataService.tjId:
            return "TJ"
        case DemoSeedDataService.tawanaId:
            return "Tawana"
        default:
            return "Unknown"
        }
    }
}

/// Switch User modal sheet for demo mode
struct SwitchUserSheet: View {
    @Environment(\.dependencyContainer) private var dependencyContainer
    @Environment(\.dismiss) private var dismiss
    
    private let demoUsers: [(id: String, name: String, role: String, roleColor: Color)] = [
        (DemoSeedDataService.rueId, "Rue Mawere", "Admin", DesignSystem.Colors.adminBadge),
        (DemoSeedDataService.tafadzwaId, "Tafadzwa Mawere", "Driver", DesignSystem.Colors.driverBadge),
        (DemoSeedDataService.tjId, "TJ", "Observer", DesignSystem.Colors.observerBadge),
        (DemoSeedDataService.tawanaId, "Tawana", "Observer", DesignSystem.Colors.observerBadge)
    ]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(demoUsers, id: \.id) { user in
                    Button(action: {
                        switchToUser(userId: user.id)
                    }) {
                        HStack(spacing: 16) {
                            // Avatar
                            ZStack {
                                Circle()
                                    .fill(avatarColor(for: user.id))
                                    .frame(width: 50, height: 50)
                                
                                Text(getInitials(from: user.name))
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                            
                            // Name and role
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.name)
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                // Role badge
                                Text(user.role)
                                    .font(.system(size: 13, weight: .medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(user.roleColor.opacity(0.15))
                                    .foregroundColor(user.roleColor)
                                    .cornerRadius(6)
                            }
                            
                            Spacer()
                            
                            // Current user indicator
                            if user.id == dependencyContainer.roleManagementService.currentUserId {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Switch User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
    
    private func switchToUser(userId: String) {
        // Get user info
        let (displayName, role) = getUserInfo(for: userId)
        
        // Switch user using RoleManagementService
        dependencyContainer.roleManagementService.setCurrentUser(
            userId: userId,
            displayName: displayName,
            role: role,
            familyId: "demo_family_id"
        )
        
        // Update HomeDashboardViewModel with new role context
        dependencyContainer.homeDashboardViewModel.updateRoleContext(
            userId: userId,
            displayName: displayName,
            role: role,
            familyId: "demo_family_id"
        )
        
        print("🔄 Switched to user: \(displayName) (role: \(role.displayName))")
        
        // Dismiss the sheet
        dismiss()
    }
    
    private func getUserInfo(for userId: String) -> (displayName: String, role: FamilyRole) {
        switch userId {
        case DemoSeedDataService.rueId:
            return ("Rue Mawere", .admin)
        case DemoSeedDataService.tafadzwaId:
            return ("Tafadzwa Mawere", .driver)
        case DemoSeedDataService.tjId:
            return ("TJ", .observer)
        case DemoSeedDataService.tawanaId:
            return ("Tawana", .observer)
        default:
            return ("Unknown", .observer)
        }
    }
    
    private func getInitials(from name: String) -> String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            let first = components[0].prefix(1)
            let last = components[1].prefix(1)
            return "\(first)\(last)".uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }
    
    private func avatarColor(for userId: String) -> Color {
        let colors: [Color] = [
            DesignSystem.Colors.infoBlue,
            DesignSystem.Colors.successGreen,
            DesignSystem.Colors.warningOrange,
            DesignSystem.Colors.observerBadge,
            DesignSystem.Colors.parentBadge,
            DesignSystem.Colors.primaryBlue
        ]
        let index = abs(userId.hashValue) % colors.count
        return colors[index]
    }
}
