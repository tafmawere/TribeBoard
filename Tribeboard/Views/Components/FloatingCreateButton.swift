//
//  FloatingCreateButton.swift
//  Tribeboard
//
//  Created by Kiro on 2026/02/07.
//

import SwiftUI

/// Floating action button for creating new runs
/// Displays a circular button with a "+" icon that floats above content
/// Requirements: 5.1, 5.2, 5.3, 5.4, 5.5
struct FloatingCreateButton: View {
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            // Trigger haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            // Call the tap handler
            onTap()
        }) {
            ZStack {
                // Background circle
                Circle()
                    .fill(DesignSystem.Colors.primaryBrand)
                    .frame(width: 60, height: 60)
                    .shadow(
                        color: DesignSystem.Shadow.floating.color,
                        radius: DesignSystem.Shadow.floating.radius,
                        x: DesignSystem.Shadow.floating.x,
                        y: DesignSystem.Shadow.floating.y
                    )
                
                // Plus icon
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .accessibilityLabel("Create Run")
        .accessibilityHint("Opens the run creation screen")
        .accessibilityAddTraits(.isButton)
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

// MARK: - FloatingCreateButton Previews

#Preview("Floating Create Button") {
    ZStack {
        Color.gray.opacity(0.1)
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            HStack {
                Spacer()
                FloatingCreateButton {
                    print("Create button tapped")
                }
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
        }
    }
}

#Preview("Floating Create Button - Pressed State") {
    ZStack {
        Color.gray.opacity(0.1)
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            HStack {
                Spacer()
                FloatingCreateButton {
                    print("Create button tapped")
                }
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
        }
    }
}

#Preview("Floating Create Button - Dark Mode") {
    ZStack {
        Color.black
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            HStack {
                Spacer()
                FloatingCreateButton {
                    print("Create button tapped")
                }
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
        }
    }
    .preferredColorScheme(.dark)
}
