//
//  ActivityPlaceholderView.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/07.
//

import SwiftUI

/// Placeholder activity screen for demo
struct ActivityPlaceholderView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                
                Image(systemName: "list.bullet.circle")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                
                Text("Activity Stream")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Coming soon")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text("View real-time updates and activity for all runs")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
            }
            .navigationTitle("Activity")
        }
    }
}
