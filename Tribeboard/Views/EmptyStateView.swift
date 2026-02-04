//
//  EmptyStateView.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/04.
//

import SwiftUI

/// Empty state view shown when no active run exists in Active Run Only mode
struct EmptyStateView: View {
    @State private var isRefreshing = false
    let onRefresh: (() async -> Void)?
    
    init(onRefresh: (() async -> Void)? = nil) {
        self.onRefresh = onRefresh
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // TribeBoard Logo/Icon
            Image(systemName: "car.2.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            VStack(spacing: 12) {
                Text("TribeBoard")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("No active run right now.")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            // Optional refresh button
            if let onRefresh = onRefresh {
                Button(action: {
                    Task {
                        isRefreshing = true
                        await onRefresh()
                        isRefreshing = false
                    }
                }) {
                    HStack {
                        if isRefreshing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("Refresh")
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .disabled(isRefreshing)
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    EmptyStateView(onRefresh: {
        // Mock refresh action
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    })
}