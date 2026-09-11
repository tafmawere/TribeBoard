// HeroSceneCardView.swift
// Animated illustrated card with press-scale and bottom label overlay.

import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Model
// ─────────────────────────────────────────────────────────────────────────────

enum SceneCardID: String, CaseIterable {
    case schoolRun  = "school-run"
    case activities = "activities"
    case poolRide   = "pool-ride"
}

struct SceneCard: Identifiable {
    let id: SceneCardID
    let title: String
    let subtitle: String
}

// Defined in sceneCards.swift — here for reference
extension SceneCard {
    static let all: [SceneCard] = [
        SceneCard(id: .schoolRun,  title: "School Run",   subtitle: "Plan & track pickups"),
        SceneCard(id: .activities, title: "Activities",   subtitle: "Soccer · Swimming · More"),
        SceneCard(id: .poolRide,   title: "Pool a Ride",  subtitle: "Share the school run"),
    ]
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Card View
// ─────────────────────────────────────────────────────────────────────────────

struct HeroSceneCardView: View {
    let card: SceneCard
    var onTap: () -> Void = {}

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottomLeading) {
                // Illustrated scene
                sceneView(for: card.id)
                    .frame(width: 220, height: 170)

                // Label overlay
                VStack(alignment: .leading, spacing: 3) {
                    Text(card.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    Text(card.subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
                .padding(.top, 32)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.6)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            }
        }
        .buttonStyle(PressScaleButtonStyle())
        .frame(width: 220, height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.tribeIndigo.opacity(0.18), radius: 12, x: 0, y: 6)
        .accessibilityLabel("\(card.title): \(card.subtitle)")
    }

    @ViewBuilder
    private func sceneView(for id: SceneCardID) -> some View {
        switch id {
        case .schoolRun:  SchoolRunScene()
        case .activities: ActivitiesScene()
        case .poolRide:   PoolRideScene()
        }
    }
}

#Preview("All Cards") {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
            ForEach(SceneCard.all) { card in
                HeroSceneCardView(card: card)
            }
        }
        .padding(.horizontal, 20)
    }
    .padding(.vertical, 20)
    .background(Color.tribeBg)
}
