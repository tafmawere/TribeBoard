//
//  ModernHeaderView.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/07.
//

import SwiftUI

/// Modern header component for the home dashboard
/// Displays user profile avatar, TribeBoard logo, and settings button
/// Requirements: 1.1, 1.2, 1.3, 1.4, 1.5
struct ModernHeaderView: View {
    let userDisplayName: String
    let profileImageURL: String?
    let onSettingsTap: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            // Profile Avatar (left)
            ProfileAvatarView(
                displayName: userDisplayName,
                imageURL: profileImageURL
            )
            
            Spacer()
            
            // TribeBoard Logo (center)
            TribeBoardLogoView()
            
            Spacer()
            
            // Settings Button (right)
            SettingsButtonView(onTap: onSettingsTap)
        }
        .padding(.horizontal, DesignSystem.Spacing.spacing16)
        .frame(height: 60)
    }
}

// MARK: - Profile Avatar View

/// Circular profile avatar with border
/// 40x40pt with 2pt border
private struct ProfileAvatarView: View {
    let displayName: String
    let imageURL: String?
    
    var body: some View {
        ZStack {
            if let imageURL = imageURL, !imageURL.isEmpty {
                // TODO: Load actual image from URL
                // For now, show initials
                initialsView
            } else {
                initialsView
            }
        }
        .frame(width: 40, height: 40)
        .background(DesignSystem.Colors.primaryBrand.opacity(0.1))
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color(.separator), lineWidth: 2)
        )
        .accessibilityLabel("Profile picture for \(displayName)")
    }
    
    private var initialsView: some View {
        Text(initials)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(DesignSystem.Colors.primaryBrand)
    }
    
    private var initials: String {
        let components = displayName.split(separator: " ")
        if components.count >= 2 {
            let first = components[0].prefix(1)
            let last = components[1].prefix(1)
            return "\(first)\(last)".uppercased()
        } else if let first = components.first {
            return String(first.prefix(1)).uppercased()
        }
        return "U"
    }
}

// MARK: - TribeBoard Logo View

/// TribeBoard logo/icon for header
/// 32x32pt centered
private struct TribeBoardLogoView: View {
    var body: some View {
        Image(systemName: "square.grid.2x2.fill")
            .font(.system(size: 20))
            .foregroundColor(DesignSystem.Colors.primaryBrand)
            .frame(width: 32, height: 32)
            .accessibilityLabel("TribeBoard")
            .accessibilityAddTraits(.isImage)
    }
}

// MARK: - Settings Button View

/// Settings button with SF Symbol
/// 24x24pt icon with 44x44pt tap target
private struct SettingsButtonView: View {
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 20))
                .foregroundColor(DesignSystem.Colors.textSecondary)
                .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Settings")
        .accessibilityHint("Opens app settings")
    }
}

// MARK: - Previews

#Preview("Modern Header") {
    ModernHeaderView(
        userDisplayName: "John Smith",
        profileImageURL: nil,
        onSettingsTap: { print("Settings tapped") }
    )
    .padding()
    .background(DesignSystem.Colors.screenBackground)
}

#Preview("Modern Header - Single Name") {
    ModernHeaderView(
        userDisplayName: "John",
        profileImageURL: nil,
        onSettingsTap: { print("Settings tapped") }
    )
    .padding()
    .background(DesignSystem.Colors.screenBackground)
}

#Preview("Modern Header - Long Name") {
    ModernHeaderView(
        userDisplayName: "Alexander Montgomery",
        profileImageURL: nil,
        onSettingsTap: { print("Settings tapped") }
    )
    .padding()
    .background(DesignSystem.Colors.screenBackground)
}
