//
//  FamilyViewModel.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/07.
//

import Foundation
import Combine

/// ViewModel for Family list and member management
@MainActor
class FamilyViewModel: ObservableObject {
    @Published var familyMembers: [FamilyMemberDisplay] = []
    @Published var familyName: String = "Mawere Family"
    @Published var familyId: String = DemoSeedDataService.demoFamilyId
    @Published var isLoading = false
    
    private let roleManagementService: RoleManagementService
    private let firebaseService: MockFirebaseRunService
    private let homeDashboardViewModel: HomeDashboardViewModel
    private var cancellables = Set<AnyCancellable>()
    
    // Track member roles for role management
    private var memberRoles: [String: FamilyRole] = [:]
    
    var isAdmin: Bool {
        let currentRole = roleManagementService.currentUserRole
        return currentRole == .admin || isParentUser
    }
    
    var currentUserId: String {
        return roleManagementService.currentUserId
    }
    
    private var isParentUser: Bool {
        let userId = roleManagementService.currentUserId
        return userId == DemoSeedDataService.rueId || userId == DemoSeedDataService.tafadzwaId
    }
    
    init(
        roleManagementService: RoleManagementService,
        firebaseService: MockFirebaseRunService,
        homeDashboardViewModel: HomeDashboardViewModel
    ) {
        self.roleManagementService = roleManagementService
        self.firebaseService = firebaseService
        self.homeDashboardViewModel = homeDashboardViewModel
        
        // Initialize member roles
        memberRoles = [
            DemoSeedDataService.rueId: .observer,
            DemoSeedDataService.tafadzwaId: .driver,
            DemoSeedDataService.tjId: .observer,
            DemoSeedDataService.tawanaId: .observer
        ]
    }
    
    /// Load family members from demo seed data
    func loadFamilyMembers() {
        isLoading = true
        
        // Build family members from demo seed data with current roles
        familyMembers = [
            FamilyMemberDisplay.from(
                userId: DemoSeedDataService.rueId,
                displayName: "Rue Mawere",
                role: memberRoles[DemoSeedDataService.rueId] ?? .observer,
                phone: "+1-555-0101"
            ),
            FamilyMemberDisplay.from(
                userId: DemoSeedDataService.tafadzwaId,
                displayName: "Tafadzwa Mawere",
                role: memberRoles[DemoSeedDataService.tafadzwaId] ?? .driver,
                phone: "+1-555-0102"
            ),
            FamilyMemberDisplay.from(
                userId: DemoSeedDataService.tjId,
                displayName: "TJ",
                role: memberRoles[DemoSeedDataService.tjId] ?? .observer,
                phone: nil
            ),
            FamilyMemberDisplay.from(
                userId: DemoSeedDataService.tawanaId,
                displayName: "Tawana",
                role: memberRoles[DemoSeedDataService.tawanaId] ?? .observer,
                phone: nil
            )
        ]
        
        isLoading = false
    }
    
    /// Update family name
    func updateFamilyName(_ newName: String) {
        familyName = newName
        print("✏️ Family name updated to: \(newName)")
    }
    
    /// Add a new family member
    func addFamilyMember(name: String, phone: String?, role: FamilyRole, isParent: Bool) {
        let newId = "demo-\(UUID().uuidString.prefix(8))"
        
        // Store role
        memberRoles[newId] = role
        
        // Create new member
        let newMember = FamilyMemberDisplay.from(
            userId: newId,
            displayName: name,
            role: role,
            phone: phone
        )
        
        familyMembers.append(newMember)
        
        print("➕ Added family member: \(name) (role: \(role.displayName))")
    }
    
    /// Remove a family member
    func removeMember(_ memberId: String) {
        guard memberId != currentUserId else {
            print("❌ Cannot remove yourself")
            return
        }
        
        guard familyMembers.count > 1 else {
            print("❌ Cannot remove last family member")
            return
        }
        
        if let index = familyMembers.firstIndex(where: { $0.id == memberId }) {
            let member = familyMembers[index]
            familyMembers.remove(at: index)
            memberRoles.removeValue(forKey: memberId)
            print("➖ Removed family member: \(member.displayName)")
        }
    }
    
    /// Change a member's role
    func changeMemberRole(memberId: String, newRole: FamilyRole) {
        guard memberId != currentUserId else {
            print("❌ Cannot change your own role")
            return
        }
        
        // Update stored role
        memberRoles[memberId] = newRole
        
        // Reload members to reflect new role
        loadFamilyMembers()
        
        // If this is the current user being switched, update their role context
        if memberId == roleManagementService.currentUserId {
            let (displayName, _) = getUserInfo(for: memberId)
            roleManagementService.setCurrentUser(
                userId: memberId,
                displayName: displayName,
                role: newRole,
                familyId: familyId
            )
            
            homeDashboardViewModel.updateRoleContext(
                userId: memberId,
                displayName: displayName,
                role: newRole,
                familyId: familyId
            )
        }
        
        print("🔄 Changed role for member \(memberId) to \(newRole.displayName)")
    }
    
    /// Get run statistics for a member
    func getRunStats(for userId: String) -> (assignedRuns: Int, visibleRuns: Int) {
        let allRuns = homeDashboardViewModel.getDisplayRuns()
        
        let assignedRuns = allRuns.filter { $0.driverId == userId }.count
        let visibleRuns = allRuns.filter { $0.familyId == familyId }.count
        
        return (assignedRuns, visibleRuns)
    }
    
    /// Switch to a different user (demo only)
    func switchToUser(_ userId: String) {
        let (displayName, role) = getUserInfo(for: userId)
        
        roleManagementService.setCurrentUser(
            userId: userId,
            displayName: displayName,
            role: role,
            familyId: familyId
        )
        
        // Update HomeDashboardViewModel with new role context
        homeDashboardViewModel.updateRoleContext(
            userId: userId,
            displayName: displayName,
            role: role,
            familyId: familyId
        )
        
        print("🔄 Switched to user: \(displayName) (role: \(role.displayName))")
    }
    
    // MARK: - Private Helpers
    
    private func getUserInfo(for userId: String) -> (displayName: String, role: FamilyRole) {
        // Get role from stored roles or default
        let role = memberRoles[userId] ?? .observer
        
        // Get display name
        let displayName: String
        switch userId {
        case DemoSeedDataService.rueId:
            displayName = "Rue Mawere"
        case DemoSeedDataService.tafadzwaId:
            displayName = "Tafadzwa Mawere"
        case DemoSeedDataService.tjId:
            displayName = "TJ"
        case DemoSeedDataService.tawanaId:
            displayName = "Tawana"
        default:
            // For dynamically added members, find in familyMembers
            if let member = familyMembers.first(where: { $0.id == userId }) {
                displayName = member.displayName
            } else {
                displayName = "Unknown"
            }
        }
        
        return (displayName, role)
    }
}
