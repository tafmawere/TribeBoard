// TribeAnimations.swift
// Shared animation helpers for TribeBoard illustrated scenes.
// Mirrors the React Native useFloatAnimation / useCarDriveAnimation hooks.

import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Float modifier
// ─────────────────────────────────────────────────────────────────────────────

/// Applies an infinite gentle vertical float to any View.
struct FloatModifier: ViewModifier {
    var range: CGFloat
    var duration: Double
    var delay: Double

    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(
                        .easeInOut(duration: duration)
                        .repeatForever(autoreverses: true)
                    ) {
                        offset = range
                    }
                }
            }
    }
}

extension View {
    /// Infinite gentle vertical bob.
    func floats(range: CGFloat = 4, duration: Double = 2.0, delay: Double = 0) -> some View {
        modifier(FloatModifier(range: range, duration: duration, delay: delay))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Horizontal sway modifier
// ─────────────────────────────────────────────────────────────────────────────

/// Applies an infinite gentle horizontal sway to any View (car driving feel).
struct SwayModifier: ViewModifier {
    var range: CGFloat
    var duration: Double
    var delay: Double

    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(
                        .easeInOut(duration: duration)
                        .repeatForever(autoreverses: true)
                    ) {
                        offset = range
                    }
                }
            }
    }
}

extension View {
    /// Infinite gentle horizontal sway.
    func sways(range: CGFloat = 5, duration: Double = 2.4, delay: Double = 0) -> some View {
        modifier(SwayModifier(range: range, duration: duration, delay: delay))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Pulse modifier
// ─────────────────────────────────────────────────────────────────────────────

struct PulseModifier: ViewModifier {
    var minOpacity: Double
    var duration: Double
    var delay: Double

    @State private var opacity: Double = 1.0

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    withAnimation(
                        .easeInOut(duration: duration)
                        .repeatForever(autoreverses: true)
                    ) {
                        opacity = minOpacity
                    }
                }
            }
    }
}

extension View {
    func pulses(minOpacity: Double = 0.3, duration: Double = 1.5, delay: Double = 0) -> some View {
        modifier(PulseModifier(minOpacity: minOpacity, duration: duration, delay: delay))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Press scale
// ─────────────────────────────────────────────────────────────────────────────

struct PressScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Design tokens
// ─────────────────────────────────────────────────────────────────────────────

extension Color {
    static let tribeIndigo    = Color(tribeHex: "#5B6BE5")
    static let tribeIndigoLight = Color(tribeHex: "#EEF0FF")
    static let tribeBg        = Color(tribeHex: "#F5F4FA")
    static let tribeSurface   = Color.white
    static let tribeBorder    = Color(tribeHex: "#E8E6F5")
    static let tribeMuted     = Color(tribeHex: "#9591B8")
    static let tribeText      = Color(tribeHex: "#1a1a2e")
    static let tribeSuccess   = Color(tribeHex: "#22C55E")
    static let tribeWarning   = Color(tribeHex: "#F59E0B")

    init(tribeHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleaned.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
