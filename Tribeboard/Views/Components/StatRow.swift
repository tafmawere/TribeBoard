//
//  StatRow.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/07.
//

import SwiftUI

/// Reusable stat row component for activity display
struct StatRow: View {
    let icon: String
    let iconColor: Color
    let text: String
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.spacing12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Spacer()
        }
    }
}
