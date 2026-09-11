import SwiftUI

/// Splash System v2 — gradient bloom, spring mark, rising wordmark.
/// Timings match `TribeBoard_Splash_v2.html` sections 03–04.
struct SplashScreenView: View {
    @EnvironmentObject private var flow: AppFlowState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: — Timing (section 03)

    private enum T {
        static let bgDelay: Duration = .milliseconds(160)
        static let bgDuration = 0.5

        static let markDelay: Duration = .milliseconds(320)
        static let markDuration = 0.92

        static let glowDelay: Duration = .milliseconds(700)
        static let glowDuration = 1.0

        static let wordmarkDelay: Duration = .milliseconds(980)
        static let wordmarkDuration = 0.68

        static let taglineDelay: Duration = .milliseconds(1380)
        static let taglineDuration = 0.6

        static let footerDelay: Duration = .milliseconds(1740)
        static let footerDuration = 0.6

        /// Minimum time on screen before dismiss (when app is ready).
        static let minVisible: Duration = .seconds(5)
        /// Hard cap — always dismiss by this point.
        static let maxVisible: Duration = .seconds(8)

        /// Crossfade duration when handing off to auth/home.
        static let transitionDuration = 0.55
        static let dismissFade = transitionDuration
    }

    // MARK: — Animation state

    @State private var bgOpacity: CGFloat = 0
    @State private var markOpacity: CGFloat = 0
    @State private var markScale: CGFloat = 0.5
    @State private var markOffsetY: CGFloat = 8

    @State private var glowOpacity: CGFloat = 0
    @State private var glowScale: CGFloat = 0.4

    @State private var wordmarkOpacity: CGFloat = 0
    @State private var wordmarkOffsetY: CGFloat = 16

    @State private var taglineOpacity: CGFloat = 0
    @State private var taglineOffsetY: CGFloat = 16

    @State private var footerOpacity: CGFloat = 0
    @State private var footerOffsetY: CGFloat = 16
    @State private var loadingBarActive = false

    @State private var screenOpacity: CGFloat = 1
    @State private var sequenceStarted = false

    private let theme = SplashTheme.gradient

    private var markSize: CGFloat {
        UIScreen.main.bounds.width < 375 ? 80 : 100
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                theme.background
                    .opacity(bgOpacity)
                    .ignoresSafeArea()

                RadialGradient(
                    colors: [Color.white.opacity(0.25), .clear],
                    center: UnitPoint(x: 0.5, y: 0.35),
                    startRadius: 0,
                    endRadius: max(proxy.size.width, proxy.size.height) * 0.55
                )
                .opacity(bgOpacity)
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer()

                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.white.opacity(0.24), .clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 120
                                )
                            )
                            .frame(width: 240, height: 240)
                            .scaleEffect(glowScale)
                            .opacity(glowOpacity)

                        SplashMarkView(color: .white)
                            .frame(width: markSize, height: markSize)
                            .opacity(markOpacity)
                            .scaleEffect(markScale)
                            .offset(y: markOffsetY)
                    }
                    .padding(.bottom, 26)

                    wordmark
                        .opacity(wordmarkOpacity)
                        .offset(y: wordmarkOffsetY)

                    Text("Your family, organised.")
                        .font(.system(size: 13, weight: .medium))
                        .tracking(-0.13)
                        .foregroundStyle(Color.white.opacity(0.65))
                        .padding(.top, 10)
                        .opacity(taglineOpacity)
                        .offset(y: taglineOffsetY)

                    Spacer()
                }
                .offset(y: -proxy.size.height * 0.10)

                VStack(spacing: 10) {
                    SplashLoadingBar(isActive: loadingBarActive, theme: theme)
                    Text("Made for families")
                        .font(.system(size: 9.5, weight: .semibold))
                        .tracking(1.14)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.white.opacity(0.32))
                }
                .padding(.bottom, 50)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .opacity(footerOpacity)
                .offset(y: footerOffsetY)
            }
        }
        .opacity(screenOpacity)
        .preferredColorScheme(.dark)
        .onAppear {
            guard !sequenceStarted else { return }
            sequenceStarted = true
            Task { await runSplash() }
        }
    }

    private var wordmark: some View {
        HStack(spacing: 0) {
            Text("Tribe")
                .foregroundStyle(.white)
            Text("Board")
                .foregroundStyle(Color.white.opacity(0.82))
        }
        .font(.system(size: 33, weight: .heavy))
        .tracking(-1.16)
    }

    // MARK: — Sequence

    @MainActor
    private func runSplash() async {
        let firstLaunch = SplashLaunchPreferences.isFirstLaunch

        if reduceMotion {
            applyEndState(animateLoadingBar: false)
        } else if firstLaunch {
            await runFullSequence()
        } else {
            await runReturningSequence()
        }

        let minWait = T.minVisible
        let maxWait = T.maxVisible
        let clock = ContinuousClock()
        let start = clock.now

        while !Task.isCancelled {
            let elapsed = start.duration(to: clock.now)
            if flow.isLaunchReady, elapsed >= minWait { break }
            if elapsed >= maxWait { break }
            try? await Task.sleep(for: .milliseconds(16))
        }

        flow.beginSplashTransition(reducedMotion: reduceMotion)

        withAnimation(.easeInOut(duration: T.transitionDuration)) {
            screenOpacity = 0
        }
        try? await Task.sleep(for: .milliseconds(Int(T.transitionDuration * 1000)))

        SplashLaunchPreferences.markFirstLaunchComplete()
        flow.endSplashOverlay()
    }

    @MainActor
    private func runFullSequence() async {
        try? await Task.sleep(for: T.bgDelay)
        withAnimation(.easeOut(duration: T.bgDuration)) {
            bgOpacity = 1
        }

        try? await Task.sleep(for: T.markDelay - T.bgDelay)
        animateMark(duration: T.markDuration)

        try? await Task.sleep(for: T.glowDelay - T.markDelay)
        animateGlow(duration: T.glowDuration)

        try? await Task.sleep(for: T.wordmarkDelay - T.glowDelay)
        withAnimation(.timingCurve(0.25, 0.46, 0.45, 0.94, duration: T.wordmarkDuration)) {
            wordmarkOpacity = 1
            wordmarkOffsetY = 0
        }

        try? await Task.sleep(for: T.taglineDelay - T.wordmarkDelay)
        withAnimation(.timingCurve(0.25, 0.46, 0.45, 0.94, duration: T.taglineDuration)) {
            taglineOpacity = 1
            taglineOffsetY = 0
        }

        try? await Task.sleep(for: T.footerDelay - T.taglineDelay)
        loadingBarActive = true
        withAnimation(.timingCurve(0.25, 0.46, 0.45, 0.94, duration: T.footerDuration)) {
            footerOpacity = 1
            footerOffsetY = 0
        }
    }

    /// Sub-1-second path for returning users — still animated, just compressed.
    @MainActor
    private func runReturningSequence() async {
        try? await Task.sleep(for: .milliseconds(40))
        withAnimation(.easeOut(duration: 0.28)) {
            bgOpacity = 1
        }

        try? await Task.sleep(for: .milliseconds(100))
        animateMark(duration: 0.55)

        try? await Task.sleep(for: .milliseconds(180))
        animateGlow(duration: 0.45)

        try? await Task.sleep(for: .milliseconds(120))
        withAnimation(.timingCurve(0.25, 0.46, 0.45, 0.94, duration: 0.38)) {
            wordmarkOpacity = 1
            wordmarkOffsetY = 0
            taglineOpacity = 1
            taglineOffsetY = 0
        }

        try? await Task.sleep(for: .milliseconds(80))
        loadingBarActive = true
        withAnimation(.easeOut(duration: 0.28)) {
            footerOpacity = 1
            footerOffsetY = 0
        }
    }

    @MainActor
    private func animateMark(duration: Double) {
        withAnimation(.timingCurve(0.22, 0.68, 0, 1.35, duration: duration)) {
            markOpacity = 1
            markOffsetY = 0
        }
        withAnimation(.spring(response: duration * 0.72, dampingFraction: 0.58)) {
            markScale = 1
        }
    }

    @MainActor
    private func animateGlow(duration: Double) {
        withAnimation(.timingCurve(0.25, 0.46, 0.45, 0.94, duration: duration * 0.6)) {
            glowOpacity = 1
            glowScale = 1.08
        }
        Task {
            try? await Task.sleep(for: .milliseconds(Int(duration * 600)))
            withAnimation(.timingCurve(0.25, 0.46, 0.45, 0.94, duration: duration * 0.4)) {
                glowScale = 1
            }
        }
    }

    @MainActor
    private func applyEndState(animateLoadingBar: Bool) {
        bgOpacity = 1
        markOpacity = 1
        markScale = 1
        markOffsetY = 0
        glowOpacity = 1
        glowScale = 1
        wordmarkOpacity = 1
        wordmarkOffsetY = 0
        taglineOpacity = 1
        taglineOffsetY = 0
        footerOpacity = 1
        footerOffsetY = 0
        loadingBarActive = animateLoadingBar
    }
}

// MARK: — Theme

private enum SplashTheme {
    case gradient

    var background: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: SplashPalette.indigoHi, location: 0),
                .init(color: SplashPalette.indigo, location: 0.45),
                .init(color: SplashPalette.indigoLo, location: 1),
            ],
            startPoint: UnitPoint(x: 0.18, y: 0),
            endPoint: UnitPoint(x: 0.82, y: 1)
        )
    }

    var loadingTrackColor: Color { Color.white.opacity(0.18) }
    var loadingSweepColor: Color { Color.white.opacity(0.9) }
}

private enum SplashPalette {
    static let indigo = Color(red: 91 / 255, green: 107 / 255, blue: 229 / 255)
    static let indigoHi = Color(red: 123 / 255, green: 139 / 255, blue: 245 / 255)
    static let indigoLo = Color(red: 74 / 255, green: 85 / 255, blue: 204 / 255)
}

// MARK: — Loading bar

private struct SplashLoadingBar: View {
    var isActive: Bool
    var theme: SplashTheme

    private let barWidth: CGFloat = 60
    private let barHeight: CGFloat = 2.5
    private let sweepPeriod: TimeInterval = 1.7

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isActive)) { context in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.loadingTrackColor)
                    .frame(width: barWidth, height: barHeight)

                if isActive {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.clear, theme.loadingSweepColor, .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: barWidth * 0.45, height: barHeight)
                        .offset(x: sweepOffset(at: context.date))
                }
            }
            .frame(width: barWidth, height: barHeight)
            .clipShape(Capsule())
        }
    }

    private func sweepOffset(at date: Date) -> CGFloat {
        let t = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: sweepPeriod) / sweepPeriod
        let travel = barWidth * 1.45
        return -barWidth * 0.45 + travel * t
    }
}

#Preview("First launch") {
    SplashScreenView()
        .environmentObject(AppFlowState())
}
