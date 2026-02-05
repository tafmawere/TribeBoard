//
//  DebugOverlayView.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/04.
//

import SwiftUI

/// Debug overlay component that displays system state information
/// Positioned in top-right corner with low opacity background
struct DebugOverlayView: View {
    @ObservedObject private var debugState = DebugStateManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("DEBUG")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Group {
                debugInfoRow("Launch:", debugState.launchMode.displayName)
                debugInfoRow("Demo:", debugState.isDemoPlaybackEnabled ? "ON" : "OFF")
                debugInfoRow("User:", debugState.currentUserId ?? "nil")
                debugInfoRow("Mode:", debugState.userMode)
                debugInfoRow("Run ID:", debugState.activeRunId ?? "nil")
                debugInfoRow("State:", debugState.activeRunState?.displayName ?? "nil")
                debugInfoRow("Stop:", debugState.currentStopIndex?.description ?? "nil")
                debugInfoRow("Location:", formatTimestamp(debugState.lastLocationUpdate))
                debugInfoRow("Playback:", debugState.isPlaybackRunning ? "ON" : "OFF")
                debugInfoRow("Tick:", formatTimestamp(debugState.lastPlaybackTick))
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.7))
        )
        .font(.caption2)
        .foregroundColor(.white)
    }
    
    // MARK: - Helper Views
    
    private func debugInfoRow(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .fontWeight(.medium)
            Text(value)
                .fontWeight(.regular)
            Spacer()
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatTimestamp(_ date: Date?) -> String {
        guard let date = date else { return "never" }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

// MARK: - LaunchMode Extension

extension LaunchMode {
    var displayName: String {
        switch self {
        case .activeRunOnly:
            return "ActiveOnly"
        case .fullApp:
            return "FullApp"
        case .demoFlow:
            return "DemoFlow"
        }
    }
}

// MARK: - ViewModifier

/// ViewModifier that attaches the debug overlay to any view
struct DebugOverlayModifier: ViewModifier {
    func body(content: Content) -> some View {
        #if DEBUG
        content
            .overlay(
                VStack {
                    HStack {
                        Spacer()
                        DebugOverlayView()
                    }
                    Spacer()
                }
                .padding(.top, 50) // Account for safe area
                .padding(.trailing, 16)
                .allowsHitTesting(false) // Prevent overlay from blocking interactions
            )
        #else
        content
        #endif
    }
}

// MARK: - View Extension

extension View {
    /// Attaches debug overlay to the view (DEBUG builds only)
    func debugOverlay() -> some View {
        self.modifier(DebugOverlayModifier())
    }
}

// MARK: - Preview

#if DEBUG
struct DebugOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.blue.ignoresSafeArea()
            
            VStack {
                Text("Sample Content View")
                    .font(.title)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding()
        }
        .debugOverlay()
        .previewDisplayName("Debug Overlay with ViewModifier")
    }
}
#endif