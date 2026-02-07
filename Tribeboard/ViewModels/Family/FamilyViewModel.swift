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
    @Published var isLoading = false
    
    private let roleManagementService: RoleManagementService
    private let firebaseService: MockFirebaseRunService
    private let homeDashboardViewModel: HomeDashboardViewModel
    private var cancellables = Set<AnyCancellable>()
    
    init(
        roleManagementService: RoleManagementService,
        firebaseService: MockFirebaseRunService,
        homeDashboardViewModel: HomeDashboardViewModel
    ) {
        self.roleManagementService = roleManagementService
        self.firebaseService = firebaseService
        self.homeDashboardViewModel = homeDashboardViewModel
    }
    
    /// Load family members from demo seed data
    func loadFamilyMembers() {
        isLoading = true
        
        // Build family members from demo seed data
        familyMembers = [
            FamilyMemberDisplay.from(
                userId: DemoSeedDataService.rueId,
                displayName: "Rue Mawere",
                role: .observer,
                phone: "+1-555-0101"
            ),
            FamilyMemberDisplay.from(
                userId: DemoSeedDataService.tafadzwaId,
                displayName: "Tafadzwa Mawere",
                role: .driver,
                phone: "+1-555-0102"
            ),
            FamilyMemberDisplay.from(
                userId: DemoSeedDataService.tjId,
                displayName: "TJ",
                role: .observer,
                phone: nil
            ),
            FamilyMemberDisplay.from(
                userId: DemoSeedDataService.tawanaId,
                displayName: "Tawana",
                role: .observer,
                phone: nil
            )
        ]
        
        isLoading = false
    }
    
    /// Get run statistics for a member
    func getRunStats(for userId: String) -> (assignedRuns: Int, visibleRuns: Int) {
        let allRuns = homeDashboardViewModel.getDisplayRuns()
        
        let assignedRuns = allRuns.filter { $0.driverId == userId }.count
        let visibleRuns = allRuns.filter { $0.familyId == DemoSeedDataService.demoFamilyId }.count
        
        return (assignedRuns, visibleRuns)
    }
    
    /// Switch to a different user (demo only)
    func switchToUser(_ userId: String) {
        let (displayName, role) = getUserInfo(for: userId)
        
        roleManagementService.setCurrentUser(
            userId: userId,
            displayName: displayName,
            role: role,
            familyId: DemoSeedDataService.demoFamilyId
        )
        
        // Update HomeDashboardViewModel with new role context
        homeDashboardViewModel.updateRoleContext(
            userId: userId,
            displayName: displayName,
            role: role,
            familyId: DemoSeedDataService.demoFamilyId
        )
        
        print("🔄 Switched to user: \(displayName) (role: \(role.displayName))")
    }
    
    // MARK: - Private Helpers
    
    private func getUserInfo(for userId: String) -> (displayName: String, role: FamilyRole) {
        switch userId {
        case DemoSeedDataService.rueId:
            return ("Rue Mawere", .observer)
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
}
