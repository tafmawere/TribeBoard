//
//  MemberCardView.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/07.
//

import SwiftUI

/// Card view for displaying a family member in the grid
struct MemberCardView: View {
    let member: FamilyMemberDisplay
    
    var body: some View {
        VStack(spacing: 12) {
            // Avatar with initials
            ZStack {
                Circle()
                    .fill(avatarColor)
                    .frame(width: 60, height: 60)
                
                Text(member.avatarInitials)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            
            // Name
            Text(member.displayName)
                .font(.headline)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            // Role badges (show first 2)
            HStack(spacing: 4) {
                ForEach(Array(member.roleBadges.prefix(2)), id: \.self) { badge in
                    Text(badge.name)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(badgeColor(for: badge.color).opacity(0.2))
                        .foregroundColor(badgeColor(for: badge.color))
                        .cornerRadius(4)
                }
            }
            
            // Quick capability line
            if let firstCapability = member.capabilities.first {
                Text(firstCapability)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var avatarColor: Color {
        // Use consistent color based on member ID
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
