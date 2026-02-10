//
//  PermissionRow.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/09.
//

import SwiftUI

/// Reusable row component for displaying permissions
/// Shows a checkmark icon with permission text
struct PermissionRow: View {
    let permission: String
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.spacing8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(DesignSystem.Colors.successGreen)
            
            Text(permission)
                .font(.system(size: 15))
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        PermissionRow(permission: "Can create runs")
        PermissionRow(permission: "Can start/drive runs")
        PermissionRow(permission: "Can manage family")
    }
    .padding()
}
