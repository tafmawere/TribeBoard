//
//  SectionHeader.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/07.
//

import SwiftUI

/// Reusable section header for profile cards
struct SectionHeader: View {
    let title: String
    let color: Color
    
    init(_ title: String, color: Color = DesignSystem.Colors.textPrimary) {
        self.title = title
        self.color = color
    }
    
    var body: some View {
        Text(title)
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(color)
    }
}
