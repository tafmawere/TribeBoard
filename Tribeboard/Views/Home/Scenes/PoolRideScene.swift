// PoolRideScene.swift
// Warm dusk suburb: gradient sky, house silhouettes, animated orange SUV
// packed with kids, three more floating kids waiting on the pavement.

import SwiftUI

struct PoolRideScene: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .bottom) {

                // ── Dusk sky ──────────────────────────────────────────
                LinearGradient(
                    colors: [
                        Color(tribeHex: "#1E3A5F"),
                        Color(tribeHex: "#2D4A70"),
                        Color(tribeHex: "#F97316").opacity(0.35),
                    ],
                    startPoint: .top, endPoint: .bottom
                )

                // ── Sunset glow ───────────────────────────────────────
                Ellipse()
                    .fill(Color(tribeHex: "#F97316").opacity(0.12))
                    .frame(width: w * 0.9, height: h * 0.25)
                    .position(x: w * 0.5, y: h * 0.62)
                Ellipse()
                    .fill(Color(tribeHex: "#FBBF24").opacity(0.08))
                    .frame(width: w * 0.6, height: h * 0.16)
                    .position(x: w * 0.5, y: h * 0.65)

                // ── Stars ─────────────────────────────────────────────
                ForEach([
                    CGPoint(x: 0.09, y: 0.09), CGPoint(x: 0.25, y: 0.05),
                    CGPoint(x: 0.41, y: 0.12), CGPoint(x: 0.73, y: 0.07),
                    CGPoint(x: 0.91, y: 0.11), CGPoint(x: 0.64, y: 0.15),
                ], id: \.x) { pt in
                    Circle()
                        .fill(.white.opacity(0.5))
                        .frame(width: 2, height: 2)
                        .position(x: pt.x * w, y: pt.y * h)
                }

                // ── House silhouettes ─────────────────────────────────
                SuburbHouses(w: w, h: h)

                // ── Trees ─────────────────────────────────────────────
                ForEach([0.35, 0.45, 0.55], id: \.self) { xFrac in
                    Tree(x: xFrac * w, groundY: h * 0.64)
                }

                // ── Road ──────────────────────────────────────────────
                Color(tribeHex: "#0f0f25")
                    .frame(height: h * 0.38)
                    .frame(maxHeight: .infinity, alignment: .bottom)

                // ── Kerb ──────────────────────────────────────────────
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(tribeHex: "#2D2560"))
                    .frame(width: w, height: h * 0.03)
                    .padding(.bottom, h * 0.35)

                // ── Route dots ────────────────────────────────────────
                HStack(spacing: w * 0.10) {
                    ForEach(0..<7, id: \.self) { i in
                        Circle()
                            .fill(Color(tribeHex: "#5B6BE5").opacity(i == 3 ? 1.0 : 0.35))
                            .frame(width: 5, height: 5)
                    }
                }
                .padding(.bottom, h * 0.11)

                // ── Road dashes ───────────────────────────────────────
                HStack(spacing: w * 0.065) {
                    ForEach(0..<6, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(tribeHex: "#3D3280").opacity(0.6))
                            .frame(width: w * 0.10, height: h * 0.018)
                    }
                }
                .padding(.bottom, h * 0.21)

                // ── Animated SUV ──────────────────────────────────────
                PoolSUV()
                    .frame(width: w * 0.68, height: h * 0.38)
                    .position(x: w * 0.47, y: h * 0.66)
                    .sways(range: 4, duration: 2.8)

                // ── Waiting kid 1 — red ───────────────────────────────
                KidFigure(
                    skinColor: Color(tribeHex: "#FBBF24"),
                    topColor: Color(tribeHex: "#EF4444"),
                    bottomColor: Color(tribeHex: "#1E3A5F"),
                    bagColor: Color(tribeHex: "#F59E0B"),
                    hasBag: true, style: .boy
                )
                .frame(width: w * 0.11, height: h * 0.24)
                .position(x: w * 0.085, y: h * 0.55)
                .floats(range: 4, duration: 2.0, delay: 0)

                // ── Waiting kid 2 — purple ────────────────────────────
                KidFigure(
                    skinColor: Color(tribeHex: "#F9A8D4"),
                    topColor: Color(tribeHex: "#7C3AED"),
                    bottomColor: Color(tribeHex: "#1D4ED8"),
                    bagColor: Color(tribeHex: "#8B5CF6"),
                    hasBag: true, style: .girl
                )
                .frame(width: w * 0.10, height: h * 0.22)
                .position(x: w * 0.88, y: h * 0.53)
                .floats(range: 3.5, duration: 1.7, delay: 0.5)

                // ── Waiting kid 3 — teal, small ───────────────────────
                KidFigure(
                    skinColor: Color(tribeHex: "#6EE7B7"),
                    topColor: Color(tribeHex: "#0F766E"),
                    bottomColor: Color(tribeHex: "#1F2937"),
                    bagColor: .clear,
                    hasBag: false, style: .boy
                )
                .frame(width: w * 0.09, height: h * 0.20)
                .position(x: w * 0.95, y: h * 0.57)
                .floats(range: 4.5, duration: 2.2, delay: 0.9)

                // ── Bottom fade ───────────────────────────────────────
                LinearGradient(
                    colors: [.clear, Color(tribeHex: "#0f0a23").opacity(0.68)],
                    startPoint: .init(x: 0.5, y: 0.55),
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

private struct SuburbHouses: View {
    let w: CGFloat, h: CGFloat
    var body: some View {
        let houses: [(x: CGFloat, y: CGFloat, bw: CGFloat, bh: CGFloat)] = [
            (0.09, 0.37, 0.16, 0.28),
            (0.22, 0.42, 0.14, 0.25),
            (0.68, 0.34, 0.17, 0.31),
            (0.83, 0.39, 0.17, 0.27),
        ]
        ZStack {
            ForEach(houses.indices, id: \.self) { i in
                let b = houses[i]
                ZStack(alignment: .bottom) {
                    Rectangle()
                        .fill(Color(tribeHex: "#112240"))
                        .frame(width: b.bw * w, height: b.bh * h)
                    // Roof triangle
                    Triangle()
                        .fill(Color(tribeHex: "#0D1B33"))
                        .frame(width: b.bw * w + 6, height: b.bh * h * 0.4)
                        .offset(y: -b.bh * h)
                    // Windows
                    HStack(spacing: 5) {
                        ForEach(0..<2, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color(tribeHex: "#FDE68A").opacity(0.55))
                                .frame(width: 7, height: 9)
                        }
                    }
                    .padding(.top, 8)
                    .frame(maxHeight: .infinity, alignment: .top)
                    // Door
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(tribeHex: "#0D1B33"))
                        .frame(width: 8, height: 14)
                        .padding(.bottom, 0)
                }
                .position(x: b.x * w, y: h - b.bh * h / 2)
            }
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

private struct Tree: View {
    let x: CGFloat, groundY: CGFloat
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(tribeHex: "#1a3a2a"))
                .frame(width: 5, height: 20)
                .position(x: x, y: groundY - 5)
            Ellipse()
                .fill(Color(tribeHex: "#064E3B"))
                .frame(width: 20, height: 28)
                .position(x: x, y: groundY - 22)
            Ellipse()
                .fill(Color(tribeHex: "#065F46"))
                .frame(width: 14, height: 20)
                .position(x: x, y: groundY - 26)
        }
    }
}

private struct PoolSUV: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                // Body
                RoundedRectangle(cornerRadius: 9)
                    .fill(Color(tribeHex: "#F97316"))
                    .frame(width: w * 0.92, height: h * 0.42)
                    .position(x: w * 0.5, y: h * 0.56)
                // Roof
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color(tribeHex: "#FB923C"))
                    .frame(width: w * 0.68, height: h * 0.30)
                    .position(x: w * 0.53, y: h * 0.30)
                // Roof rack
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(tribeHex: "#EA7A1A"))
                    .frame(width: w * 0.68, height: h * 0.05)
                    .position(x: w * 0.53, y: h * 0.16)
                // Windshield
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(tribeHex: "#93C5FD").opacity(0.82))
                    .frame(width: w * 0.23, height: h * 0.22)
                    .position(x: w * 0.32, y: h * 0.31)
                // Side windows
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(tribeHex: "#93C5FD").opacity(0.75))
                    .frame(width: w * 0.20, height: h * 0.20)
                    .position(x: w * 0.56, y: h * 0.31)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(tribeHex: "#93C5FD").opacity(0.60))
                    .frame(width: w * 0.11, height: h * 0.18)
                    .position(x: w * 0.73, y: h * 0.31)
                // Kid heads in windows
                ForEach(zip([0.52, 0.62, 0.71], [
                    Color(tribeHex: "#FBBF24"),
                    Color(tribeHex: "#F9A8D4"),
                    Color(tribeHex: "#6EE7B7"),
                ]).map { ($0, $1) }, id: \.0) { pair in
                    Circle()
                        .fill(pair.1)
                        .frame(width: w * 0.09, height: w * 0.09)
                        .position(x: pair.0 * w, y: h * 0.31)
                }
                // Headlight
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(tribeHex: "#FCD34D"))
                    .frame(width: w * 0.10, height: h * 0.10)
                    .position(x: w * 0.07, y: h * 0.55)
                // Taillight
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(tribeHex: "#EF4444").opacity(0.9))
                    .frame(width: w * 0.10, height: h * 0.10)
                    .position(x: w * 0.93, y: h * 0.55)
                // Door divider
                Rectangle()
                    .fill(Color(tribeHex: "#E86916"))
                    .frame(width: 1.2, height: h * 0.36)
                    .position(x: w * 0.52, y: h * 0.56)
                // Wheels
                ForEach([0.17, 0.79], id: \.self) { xFrac in
                    ZStack {
                        Circle().fill(Color(tribeHex: "#1a1440"))
                            .frame(width: w * 0.20, height: w * 0.20)
                        Circle().fill(Color(tribeHex: "#F97316").opacity(0.5))
                            .frame(width: w * 0.11, height: w * 0.11)
                        Circle().fill(Color(tribeHex: "#ddd"))
                            .frame(width: w * 0.05, height: w * 0.05)
                    }
                    .position(x: xFrac * w, y: h * 0.86)
                }
            }
        }
    }
}

#Preview {
    PoolRideScene()
        .frame(width: 220, height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 18))
}
