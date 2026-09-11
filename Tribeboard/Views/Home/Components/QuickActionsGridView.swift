// QuickActionsGridView.swift
// Three-button quick actions row.

import SwiftUI

struct QuickAction: Identifiable {
    let id: String
    let label: String
    let emoji: String
    let iconBg: Color
    let action: () -> Void
}

struct QuickActionsGridView: View {
    let actions: [QuickAction]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Actions")
                .font(.system(size: 18, weight: .heavy))
                .foregroundStyle(Color.tribeText)
                .padding(.horizontal, 20)

            HStack(spacing: 10) {
                ForEach(actions) { action in
                    QuickActionButton(action: action)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 20)
    }
}

private struct QuickActionButton: View {
    let action: QuickAction
    @State private var isPressed = false

    var body: some View {
        Button(action: action.action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(action.iconBg)
                        .frame(width: 40, height: 40)
                    Text(action.emoji).font(.system(size: 20))
                }
                Text(action.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.tribeText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.top, 14)
            .padding(.bottom, 12)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(Color.tribeSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.tribeBorder, lineWidth: 0.5)
            )
            .shadow(color: Color.tribeIndigo.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel(action.label)
    }
}

#Preview {
    QuickActionsGridView(actions: [
        QuickAction(id: "driver", label: "Driver Mode",  emoji: "🚗", iconBg: Color(tribeHex: "#EEF0FF"), action: {}),
        QuickAction(id: "create", label: "Create Run",   emoji: "➕", iconBg: Color(tribeHex: "#FFF7ED"), action: {}),
        QuickAction(id: "track",  label: "Track Live",   emoji: "📍", iconBg: Color(tribeHex: "#F0FFF4"), action: {}),
    ])
    .padding(.vertical)
    .background(Color.tribeBg)
}
