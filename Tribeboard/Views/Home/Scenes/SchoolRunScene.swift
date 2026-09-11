// SchoolRunScene.swift
// Night city scene: indigo sky, glowing streetlights,
// animated car + two floating kids waiting at the kerb.

import SwiftUI

struct SchoolRunScene: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack(alignment: .bottom) {

                // ── Sky background ──────────────────────────────────
                LinearGradient(
                    colors: [Color(tribeHex: "#1a0f3d"), Color(tribeHex: "#2D1B69")],
                    startPoint: .top, endPoint: .bottom
                )

                // ── Stars ───────────────────────────────────────────
                ForEach([
                    CGPoint(x: 0.07, y: 0.07), CGPoint(x: 0.20, y: 0.05),
                    CGPoint(x: 0.36, y: 0.12), CGPoint(x: 0.55, y: 0.04),
                    CGPoint(x: 0.73, y: 0.09), CGPoint(x: 0.89, y: 0.06),
                    CGPoint(x: 0.15, y: 0.18), CGPoint(x: 0.63, y: 0.16),
                    CGPoint(x: 0.80, y: 0.21),
                ], id: \.x) { pt in
                    Circle()
                        .fill(.white.opacity(0.65))
                        .frame(width: 2.5, height: 2.5)
                        .position(x: pt.x * w, y: pt.y * h)
                }

                // ── Moon ────────────────────────────────────────────
                ZStack {
                    Circle()
                        .fill(Color(tribeHex: "#e8e0ff"))
                        .frame(width: w * 0.11, height: w * 0.11)
                    Circle()
                        .fill(Color(tribeHex: "#2D1B69"))
                        .frame(width: w * 0.09, height: w * 0.09)
                        .offset(x: w * 0.025, y: -w * 0.02)
                }
                .position(x: w * 0.84, y: h * 0.13)

                // ── Building silhouettes ─────────────────────────────
                BuildingSilhouettes(w: w, h: h)

                // ── Streetlights ─────────────────────────────────────
                ForEach([0.13, 0.80], id: \.self) { xFrac in
                    StreetLight(x: xFrac * w, baseY: h * 0.33, poleH: h * 0.32)
                }

                // ── Road ──────────────────────────────────────────────
                VStack(spacing: 0) {
                    Color(tribeHex: "#3D2A80").frame(height: h * 0.05)
                    Color(tribeHex: "#1E1050").frame(height: h * 0.45)
                }
                .frame(width: w)
                .frame(maxHeight: .infinity, alignment: .bottom)

                // ── Road dashes ───────────────────────────────────────
                HStack(spacing: w * 0.07) {
                    ForEach(0..<6, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(tribeHex: "#5B4FA0").opacity(0.5))
                            .frame(width: w * 0.10, height: h * 0.018)
                    }
                }
                .padding(.bottom, h * 0.16)

                // ── Animated car ──────────────────────────────────────
                SchoolRunCar()
                    .frame(width: w * 0.60, height: h * 0.34)
                    .position(x: w * 0.42, y: h * 0.67)
                    .sways(range: 4, duration: 2.4)

                // ── Pavement ──────────────────────────────────────────
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(tribeHex: "#4A3890"))
                    .frame(width: w, height: h * 0.04)
                    .padding(.bottom, h * 0.38)

                // ── Kid 1: red jacket ─────────────────────────────────
                KidFigure(
                    skinColor: Color(tribeHex: "#FBBF24"),
                    topColor: Color(tribeHex: "#EF4444"),
                    bottomColor: Color(tribeHex: "#1E3A5F"),
                    bagColor: Color(tribeHex: "#F97316"),
                    hasBag: true,
                    style: .boy
                )
                .frame(width: w * 0.14, height: h * 0.28)
                .position(x: w * 0.80, y: h * 0.56)
                .floats(range: 4, duration: 2.0, delay: 0)

                // ── Kid 2: purple jacket ───────────────────────────────
                KidFigure(
                    skinColor: Color(tribeHex: "#F9A8D4"),
                    topColor: Color(tribeHex: "#7C3AED"),
                    bottomColor: Color(tribeHex: "#1D4ED8"),
                    bagColor: Color(tribeHex: "#8B5CF6"),
                    hasBag: true,
                    style: .girl
                )
                .frame(width: w * 0.12, height: h * 0.25)
                .position(x: w * 0.92, y: h * 0.55)
                .floats(range: 3, duration: 1.8, delay: 0.4)

                // ── Bottom fade overlay ───────────────────────────────
                LinearGradient(
                    colors: [.clear, Color(tribeHex: "#0a051e").opacity(0.65)],
                    startPoint: .init(x: 0.5, y: 0.5),
                    endPoint: .bottom
                )
                .allowsHitTesting(false)
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Sub-views
// ─────────────────────────────────────────────────────────────────────────────

private struct BuildingSilhouettes: View {
    let w: CGFloat; let h: CGFloat
    var body: some View {
        let buildings: [(x: CGFloat, y: CGFloat, bw: CGFloat, bh: CGFloat)] = [
            (0.59, 0.33, 0.14, 0.32),
            (0.70, 0.38, 0.11, 0.26),
            (0.80, 0.26, 0.09, 0.39),
            (0.87, 0.35, 0.13, 0.29),
        ]
        ZStack {
            ForEach(buildings.indices, id: \.self) { i in
                let b = buildings[i]
                ZStack(alignment: .bottom) {
                    Rectangle()
                        .fill(Color(tribeHex: "#1a0f3d").opacity(0.85))
                        .frame(width: b.bw * w, height: b.bh * h)
                    // Windows
                    VStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { row in
                            HStack(spacing: 4) {
                                ForEach(0..<2, id: \.self) { col in
                                    RoundedRectangle(cornerRadius: 1)
                                        .fill(Color(tribeHex: "#FDE68A")
                                            .opacity([0.65, 0.4, 0.3, 0.1, 0.7, 0.5][min((row*2+col), 5)]))
                                        .frame(width: 6, height: 8)
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                    .frame(maxHeight: .infinity, alignment: .top)
                }
                .position(x: b.x * w, y: h - b.bh * h / 2)
            }
        }
    }
}

private struct StreetLight: View {
    let x: CGFloat, baseY: CGFloat, poleH: CGFloat
    var body: some View {
        ZStack {
            // Glow halo
            Circle()
                .fill(Color(tribeHex: "#FDE68A").opacity(0.07))
                .frame(width: 50, height: 50)
                .position(x: x, y: baseY - poleH * 0.02)
            // Arm
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(tribeHex: "#8B7BB0"))
                .frame(width: 22, height: 5)
                .position(x: x, y: baseY - poleH)
            // Lamp housing
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(tribeHex: "#FDE68A"))
                .frame(width: 18, height: 5)
                .position(x: x, y: baseY - poleH + 3)
            // Pole
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(tribeHex: "#8B7BB0"))
                .frame(width: 4, height: poleH)
                .position(x: x, y: baseY - poleH / 2)
        }
    }
}

private struct SchoolRunCar: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                // Body
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(tribeHex: "#5B6BE5"))
                    .frame(width: w * 0.9, height: h * 0.44)
                    .position(x: w * 0.5, y: h * 0.55)
                // Roof
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(tribeHex: "#7B8CF0"))
                    .frame(width: w * 0.66, height: h * 0.32)
                    .position(x: w * 0.52, y: h * 0.30)
                // Windshield
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(tribeHex: "#B8C4FF").opacity(0.85))
                    .frame(width: w * 0.24, height: h * 0.24)
                    .position(x: w * 0.38, y: h * 0.31)
                // Side window
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(tribeHex: "#B8C4FF").opacity(0.78))
                    .frame(width: w * 0.28, height: h * 0.22)
                    .position(x: w * 0.64, y: h * 0.31)
                // Headlight
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(tribeHex: "#FCD34D"))
                    .frame(width: w * 0.10, height: h * 0.09)
                    .position(x: w * 0.07, y: h * 0.54)
                // Taillight
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(tribeHex: "#EF4444").opacity(0.9))
                    .frame(width: w * 0.10, height: h * 0.09)
                    .position(x: w * 0.93, y: h * 0.54)
                // Door divider
                Rectangle()
                    .fill(Color(tribeHex: "#4A5DD4"))
                    .frame(width: 1, height: h * 0.38)
                    .position(x: w * 0.52, y: h * 0.54)
                // Wheels
                ForEach([0.18, 0.78], id: \.self) { xFrac in
                    ZStack {
                        Circle().fill(Color(tribeHex: "#1a1440"))
                            .frame(width: w * 0.19, height: w * 0.19)
                        Circle().fill(Color(tribeHex: "#7B8CF0"))
                            .frame(width: w * 0.10, height: w * 0.10)
                        Circle().fill(Color(tribeHex: "#B8C4FF"))
                            .frame(width: w * 0.05, height: w * 0.05)
                    }
                    .position(x: xFrac * w, y: h * 0.86)
                }
            }
        }
    }
}

enum KidStyle { case boy, girl }

struct KidFigure: View {
    let skinColor: Color
    let topColor: Color
    let bottomColor: Color
    let bagColor: Color
    var hasBag: Bool = false
    var style: KidStyle = .boy

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                // Legs
                RoundedRectangle(cornerRadius: 3)
                    .fill(bottomColor)
                    .frame(width: w * 0.25, height: h * 0.28)
                    .position(x: w * 0.33, y: h * 0.84)
                RoundedRectangle(cornerRadius: 3)
                    .fill(bottomColor)
                    .frame(width: w * 0.25, height: h * 0.28)
                    .position(x: w * 0.67, y: h * 0.84)
                // Body / jacket
                RoundedRectangle(cornerRadius: 5)
                    .fill(topColor)
                    .frame(width: w * 0.70, height: h * 0.32)
                    .position(x: w * 0.5, y: h * 0.58)
                // Arms
                RoundedRectangle(cornerRadius: 3)
                    .fill(skinColor)
                    .frame(width: w * 0.22, height: h * 0.22)
                    .position(x: w * 0.12, y: h * 0.60)
                RoundedRectangle(cornerRadius: 3)
                    .fill(skinColor)
                    .frame(width: w * 0.22, height: h * 0.22)
                    .position(x: w * 0.88, y: h * 0.60)
                // Head
                Circle()
                    .fill(skinColor)
                    .frame(width: w * 0.55, height: w * 0.55)
                    .position(x: w * 0.5, y: h * 0.23)
                // Hair
                if style == .boy {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(tribeHex: "#92400E"))
                        .frame(width: w * 0.60, height: h * 0.09)
                        .position(x: w * 0.5, y: h * 0.14)
                } else {
                    // Pigtails
                    Circle().fill(skinColor)
                        .frame(width: w * 0.28, height: w * 0.28)
                        .position(x: w * 0.20, y: h * 0.17)
                    Circle().fill(skinColor)
                        .frame(width: w * 0.28, height: w * 0.28)
                        .position(x: w * 0.80, y: h * 0.17)
                }
                // Schoolbag
                if hasBag {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(bagColor)
                        .frame(width: w * 0.35, height: h * 0.30)
                        .position(x: w * 0.88, y: h * 0.56)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.4))
                        .frame(width: w * 0.18, height: h * 0.07)
                        .position(x: w * 0.88, y: h * 0.44)
                }
            }
        }
    }
}

#Preview {
    SchoolRunScene()
        .frame(width: 220, height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 18))
}
