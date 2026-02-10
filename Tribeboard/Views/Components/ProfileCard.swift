//
//  ProfileCard.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/07.
//

import SwiftUI

/// Reusable card wrapper for profile sections
/// Provides consistent styling across all profile cards
struct ProfileCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.spacing12) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.cardPadding)
        .background(DesignSystem.Colors.cardBackground)
        .cornerRadius(DesignSystem.CornerRadius.large)
        .shadow(
            color: DesignSystem.Shadow.card.color,
            radius: DesignSystem.Shadow.card.radius,
            x: DesignSystem.Shadow.card.x,
            y: DesignSystem.Shadow.card.y
        )
        .shadow(
            color: DesignSystem.Shadow.cardSecondary.color,
            radius: DesignSystem.Shadow.cardSecondary.radius,
            x: DesignSystem.Shadow.cardSecondary.x,
            y: DesignSystem.Shadow.cardSecondary.y
        )
    }
}
