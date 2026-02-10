//
//  RoleBadge.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/07.
//

import SwiftUI

/// Reusable role badge component
struct RoleBadge: View {
    let name: String
    let color: Color
    
    var body: some View {
        Text(name.uppercased())
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(color)
            .cornerRadius(DesignSystem.CornerRadius.small)
    }
}
