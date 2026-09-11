// ActivitiesScene.swift
// Sunny day sports pitch: blue sky, white clouds, green grass,
// goal posts, animated ball bounce, two floating kids in kit.

import SwiftUI

struct ActivitiesScene: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .bottom) {

                // ── Sky ──────────────────────────────────────────────
                LinearGradient(
                    colors: [Color(tribeHex: "#93C5FD"), Color(tribeHex: "#BFDBFE")],
                    startPoint: .top, endPoint: .bottom
                )

                // ── Sun ───────────────────────────────────────────────
                ZStack {
                    Circle()
                        .fill(Color(tribeHex: "#FDE68A").opacity(0.2))
                        .frame(width: w * 0.28, height: w * 0.28)
                    Circle()
                        .fill(Color(tribeHex: "#FDE68A").opacity(0.85))
                        .frame(width: w * 0.18, height: w * 0.18)
                }
                .position(x: w * 0.84, y: h * 0.17)

                // ── Clouds ────────────────────────────────────────────
                Cloud(x: w * 0.23, y: h * 0.15, scale: 1.0)
                Cloud(x: w * 0.64, y: h * 0.11, scale: 0.8)

                // ── Grass ─────────────────────────────────────────────
                LinearGradient(
                    colors: [Color(tribeHex: "#16A34A"), Color(tribeHex: "#15803D")],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: h * 0.45)
                .frame(maxWidth: .infinity)
                .frame(maxHeight: .infinity, alignment: .bottom)

                // ── Pitch stripes ─────────────────────────────────────
                HStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { i in
                        if i % 2 == 0 {
                            Color(tribeHex: "#166534").opacity(0.35)
                        } else {
                            Color.clear
                        }
                    }
                }
                .frame(height: h * 0.45)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .allowsHitTesting(false)

                // ── Centre line & circle ──────────────────────────────
                Rectangle()
                    .fill(.white.opacity(0.35))
                    .frame(width: 1.5, height: h * 0.45)
                    .padding(.bottom, 0)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                Circle()
                    .stroke(.white.opacity(0.3), lineWidth: 1.5)
                    .frame(width: w * 0.35, height: w * 0.35)
                    .position(x: w * 0.5, y: h * 0.78)

                // ── Goal posts ────────────────────────────────────────
                GoalPost(side: .left, w: w, h: h)
                GoalPost(side: .right, w: w, h: h)

                // ── Activity badge chips ───────────────────────────────
                VStack(spacing: 5) {
                    ActivityBadge(label: "Soccer", color: Color(tribeHex: "#FEF3C7"), dot: Color(tribeHex: "#F59E0B"))
                    ActivityBadge(label: "Swimming", color: Color(tribeHex: "#EDE9FE"), dot: Color(tribeHex: "#7C3AED"))
                }
                .position(x: w * 0.83, y: h * 0.28)

                // ── Animated soccer ball ──────────────────────────────
                SoccerBall()
                    .frame(width: w * 0.10, height: w * 0.10)
                    .position(x: w * 0.50, y: h * 0.53)
                    .floats(range: 6, duration: 0.9, delay: 0.2)

                // ── Kid 1 — green jersey ──────────────────────────────
                KidFigure(
                    skinColor: Color(tribeHex: "#FBBF24"),
                    topColor: Color(tribeHex: "#16A34A"),
                    bottomColor: Color(tribeHex: "#1D4ED8"),
                    bagColor: .clear,
                    hasBag: false,
                    style: .boy
                )
                .frame(width: w * 0.14, height: h * 0.35)
                .position(x: w * 0.33, y: h * 0.57)
                .floats(range: 5, duration: 1.8, delay: 0)

                // ── Kid 2 — purple jersey ─────────────────────────────
                KidFigure(
                    skinColor: Color(tribeHex: "#F9A8D4"),
                    topColor: Color(tribeHex: "#7C3AED"),
                    bottomColor: Color(tribeHex: "#1D4ED8"),
                    bagColor: .clear,
                    hasBag: false,
                    style: .girl
                )
                .frame(width: w * 0.13, height: h * 0.33)
                .position(x: w * 0.67, y: h * 0.55)
                .floats(range: 4, duration: 2.1, delay: 0.6)

                // ── Bottom fade ───────────────────────────────────────
                LinearGradient(
                    colors: [.clear, Color(tribeHex: "#052010").opacity(0.60)],
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

private struct Cloud: View {
    let x: CGFloat, y: CGFloat, scale: CGFloat
    var body: some View {
        ZStack {
            Ellipse().fill(.white.opacity(0.85)).frame(width: 44 * scale, height: 20 * scale)
            Ellipse().fill(.white.opacity(0.85)).frame(width: 28 * scale, height: 18 * scale)
                .offset(x: -14 * scale, y: 4 * scale)
            Ellipse().fill(.white.opacity(0.85)).frame(width: 32 * scale, height: 18 * scale)
                .offset(x: 14 * scale, y: 3 * scale)
        }
        .position(x: x, y: y)
    }
}

enum GoalSide { case left, right }

private struct GoalPost: View {
    let side: GoalSide, w: CGFloat, h: CGFloat
    var body: some View {
        let x: CGFloat = side == .left ? w * 0.04 : w * 0.76
        let postW: CGFloat = w * 0.14
        let postH: CGFloat = h * 0.17
        let baseY: CGFloat = h * 0.617
        ZStack {
            // Crossbar
            RoundedRectangle(cornerRadius: 1.5)
                .fill(.white.opacity(0.9))
                .frame(width: postW, height: h * 0.018)
                .position(x: x + postW / 2, y: baseY)
            // Left post
            RoundedRectangle(cornerRadius: 1.5)
                .fill(.white.opacity(0.9))
                .frame(width: w * 0.015, height: postH)
                .position(x: x, y: baseY + postH / 2)
            // Right post
            RoundedRectangle(cornerRadius: 1.5)
                .fill(.white.opacity(0.9))
                .frame(width: w * 0.015, height: postH)
                .position(x: x + postW, y: baseY + postH / 2)
        }
    }
}

private struct SoccerBall: View {
    var body: some View {
        ZStack {
            Circle().fill(.white)
            Circle().stroke(Color(tribeHex: "#1F2937"), lineWidth: 0.5)
            Circle().fill(Color(tribeHex: "#1F2937"))
                .frame(width: 10, height: 10)
        }
    }
}

private struct ActivityBadge: View {
    let label: String, color: Color, dot: Color
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(dot).frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(dot.opacity(0.8))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(color.opacity(0.9))
        .clipShape(Capsule())
    }
}

#Preview {
    ActivitiesScene()
        .frame(width: 220, height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 18))
}
