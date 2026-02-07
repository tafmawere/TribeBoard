//
//  FamilyMemberDisplay.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/07.
//

import Foundation

/// UI-safe display model for family members
/// Lightweight struct for presenting family member information in the UI
struct FamilyMemberDisplay: Identifiable, Hashable {
    let id: String
    let displayName: String
    let avatarInitials: String
    let isParent: Bool
    let phone: String?
    let roleBadges: [RoleBadge]
    let capabilities: [String]
    
    /// Role badge for display
    struct RoleBadge: Hashable {
        let name: String
        let color: BadgeColor
        
        enum BadgeColor {
            case blue, green, orange, purple
        }
    }
    
    /// Create display model from user data
    static func from(userId: String, displayName: String, role: FamilyRole, phone: String? = nil) -> FamilyMemberDisplay {
        let isParent = userId == DemoSeedDataService.rueId || userId == DemoSeedDataService.tafadzwaId
        let initials = makeInitials(from: displayName)
        let badges = makeBadges(for: userId, role: role, isParent: isParent)
        let capabilities = makeCapabilities(for: userId, role: role, isParent: isParent)
        
        return FamilyMemberDisplay(
            id: userId,
            displayName: displayName,
            avatarInitials: initials,
            isParent: isParent,
            phone: phone,
            roleBadges: badges,
            capabilities: capabilities
        )
    }
    
    // MARK: - Private Helpers
    
    private static func makeInitials(from name: String) -> String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            let first = components[0].prefix(1)
            let last = components[1].prefix(1)
            return "\(first)\(last)".uppercased()
        } else if let first = components.first {
            return String(first.prefix(2)).uppercased()
        }
        return "??"
    }
    
    private static func makeBadges(for userId: String, role: FamilyRole, isParent: Bool) -> [RoleBadge] {
        var badges: [RoleBadge] = []
        
        // Parent badge
        if isParent {
            badges.append(RoleBadge(name: "Parent", color: .purple))
        } else {
            badges.append(RoleBadge(name: "Child", color: .blue))
        }
        
        // Role-specific badges
        switch role {
        case .driver:
            badges.append(RoleBadge(name: "Driver", color: .blue))
            if isParent {
                badges.append(RoleBadge(name: "Admin", color: .orange))
            }
        case .observer:
            badges.append(RoleBadge(name: "Observer", color: .green))
            if isParent {
                badges.append(RoleBadge(name: "Admin", color: .orange))
            }
        case .admin:
            badges.append(RoleBadge(name: "Admin", color: .orange))
        }
        
        // Passenger badge for children
        if !isParent {
            badges.append(RoleBadge(name: "Passenger", color: .green))
        }
        
        return badges
    }
    
    private static func makeCapabilities(for userId: String, role: FamilyRole, isParent: Bool) -> [String] {
        var capabilities: [String] = []
        
        // All family members can create runs
        capabilities.append("Can create runs")
        
        // Role-specific capabilities
        switch role {
        case .driver:
            capabilities.append("Can start/drive runs")
            capabilities.append("Can track runs")
            if isParent {
                capabilities.append("Can manage family")
                capabilities.append("Can cancel/reassign runs")
            }
        case .observer:
            capabilities.append("Can track runs")
            if isParent {
                capabilities.append("Can manage family")
                capabilities.append("Can cancel/reassign runs")
            }
        case .admin:
            capabilities.append("Can start/drive runs")
            capabilities.append("Can track runs")
            capabilities.append("Can manage family")
            capabilities.append("Can cancel/reassign runs")
        }
        
        return capabilities
    }
}
