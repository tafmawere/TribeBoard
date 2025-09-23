import SwiftUI

/// Animation utilities for consistent and production-quality animations throughout the app
struct AnimationUtilities {
    
    // MARK: - Standard Animations
    
    /// Quick and snappy animation for button presses and immediate feedback
    static let quickResponse = Animation.easeInOut(duration: 0.15)
    
    /// Standard animation for most UI transitions
    static let standard = Animation.easeInOut(duration: 0.3)
    
    /// Smooth animation for page transitions and major UI changes
    static let smooth = Animation.easeInOut(duration: 0.5)
    
    /// Gentle animation for subtle state changes
    static let gentle = Animation.easeInOut(duration: 0.8)
    
    /// Spring animation for bouncy, natural feeling interactions
    static let spring = Animation.spring(response: 0.6, dampingFraction: 0.8)
    
    /// Bouncy spring for playful interactions
    static let bouncySpring = Animation.spring(response: 0.4, dampingFraction: 0.6)
    
    /// Smooth spring for natural feeling transitions
    static let smoothSpring = Animation.spring(response: 0.8, dampingFraction: 0.9)
    
    // MARK: - Page Transitions
    
    /// Slide transition for navigation between screens
    static let slideTransition = AnyTransition.asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .move(edge: .leading).combined(with: .opacity)
    )
    
    /// Fade transition for overlay presentations
    static let fadeTransition = AnyTransition.opacity.combined(with: .scale(scale: 0.95))
    
    /// Scale transition for modal presentations
    static let scaleTransition = AnyTransition.scale(scale: 0.8).combined(with: .opacity)
    
    /// Push transition for hierarchical navigation
    static let pushTransition = AnyTransition.asymmetric(
        insertion: .move(edge: .bottom).combined(with: .opacity),
        removal: .move(edge: .top).combined(with: .opacity)
    )
    
    // MARK: - Loading Animations
    
    /// Pulsing animation for loading states
    static let pulse = Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)
    
    /// Rotation animation for spinners
    static let rotation = Animation.linear(duration: 1.0).repeatForever(autoreverses: false)
    
    /// Shimmer animation for skeleton loading
    static let shimmer = Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)
    
    /// Breathing animation for subtle loading indicators
    static let breathing = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)
    
    // MARK: - Success Animations
    
    /// Celebration animation for successful actions
    static let celebration = Animation.spring(response: 0.4, dampingFraction: 0.5)
    
    /// Checkmark animation for completion states
    static let checkmark = Animation.spring(response: 0.3, dampingFraction: 0.7)
    
    /// Pop animation for notifications and alerts
    static let pop = Animation.spring(response: 0.5, dampingFraction: 0.6)
    
    // MARK: - Micro-interactions
    
    /// Button press animation
    static let buttonPress = Animation.easeInOut(duration: 0.1)
    
    /// Toggle switch animation
    static let toggle = Animation.spring(response: 0.3, dampingFraction: 0.8)
    
    /// Card flip animation
    static let cardFlip = Animation.easeInOut(duration: 0.6)
    
    /// Slide up animation for sheets
    static let slideUp = Animation.spring(response: 0.5, dampingFraction: 0.8)
    
    // MARK: - Error Animations
    
    /// Shake animation for validation errors
    static let shake = Animation.easeInOut(duration: 0.1).repeatCount(3, autoreverses: true)
    
    /// Error highlight animation
    static let errorHighlight = Animation.easeInOut(duration: 0.3)
    
    // MARK: - Custom Animation Functions
    
    /// Creates a delayed animation
    static func delayed(_ delay: TimeInterval, animation: Animation = .easeInOut) -> Animation {
        return animation.delay(delay)
    }
    
    /// Creates a staggered animation for multiple elements
    static func staggered(index: Int, delay: TimeInterval = 0.1, animation: Animation = .spring) -> Animation {
        return animation.delay(Double(index) * delay)
    }
    
    /// Creates a sequence of animations
    static func sequence(_ animations: [(animation: Animation, delay: TimeInterval)]) -> [Animation] {
        var totalDelay: TimeInterval = 0
        return animations.map { item in
            let delayedAnimation = item.animation.delay(totalDelay)
            totalDelay += item.delay
            return delayedAnimation
        }
    }
}

// MARK: - Animation View Modifiers

/// Button press animation modifier
struct ButtonPressAnimation: ViewModifier {
    let isPressed: Bool
    let hapticStyle: HapticStyle?
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .opacity(isPressed ? 0.8 : 1.0)
            .animation(AnimationUtilities.buttonPress, value: isPressed)
            .onChange(of: isPressed) { _, newValue in
                if newValue {
                    hapticStyle?.trigger()
                }
            }
    }
}

/// Shake animation modifier for validation errors
struct ShakeAnimation: ViewModifier {
    let trigger: Bool
    @State private var offset: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    withAnimation(AnimationUtilities.shake) {
                        offset = 10
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(AnimationUtilities.standard) {
                            offset = 0
                        }
                    }
                    
                    HapticManager.shared.validationError()
                }
            }
    }
}

/// Pulse animation modifier for loading states
struct PulseAnimation: ViewModifier {
    let isAnimating: Bool
    @State private var scale: CGFloat = 1.0
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                if isAnimating {
                    withAnimation(AnimationUtilities.pulse) {
                        scale = 1.1
                    }
                }
            }
            .onChange(of: isAnimating) { _, newValue in
                if newValue {
                    withAnimation(AnimationUtilities.pulse) {
                        scale = 1.1
                    }
                } else {
                    withAnimation(AnimationUtilities.standard) {
                        scale = 1.0
                    }
                }
            }
    }
}

/// Slide in animation modifier for list items
struct SlideInAnimation: ViewModifier {
    let index: Int
    let isVisible: Bool
    @State private var offset: CGFloat = 50
    @State private var opacity: Double = 0
    
    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .opacity(opacity)
            .onAppear {
                if isVisible {
                    withAnimation(AnimationUtilities.staggered(index: index)) {
                        offset = 0
                        opacity = 1
                    }
                }
            }
            .onChange(of: isVisible) { _, newValue in
                if newValue {
                    withAnimation(AnimationUtilities.staggered(index: index)) {
                        offset = 0
                        opacity = 1
                    }
                } else {
                    withAnimation(AnimationUtilities.standard) {
                        offset = 50
                        opacity = 0
                    }
                }
            }
    }
}

/// Success celebration animation modifier
struct CelebrationAnimation: ViewModifier {
    let trigger: Bool
    @State private var scale: CGFloat = 1.0
    @State private var rotation: Double = 0
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .onChange(of: trigger) { _, newValue in
                if newValue {
                    // Scale up and rotate
                    withAnimation(AnimationUtilities.celebration) {
                        scale = 1.2
                        rotation = 360
                    }
                    
                    // Return to normal
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        withAnimation(AnimationUtilities.smooth) {
                            scale = 1.0
                            rotation = 0
                        }
                    }
                    
                    HapticManager.shared.celebration()
                }
            }
    }
}

/// Floating animation modifier for subtle movement
struct FloatingAnimation: ViewModifier {
    let isAnimating: Bool
    @State private var offset: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .offset(y: offset)
            .onAppear {
                if isAnimating {
                    withAnimation(AnimationUtilities.breathing) {
                        offset = -5
                    }
                }
            }
            .onChange(of: isAnimating) { _, newValue in
                if newValue {
                    withAnimation(AnimationUtilities.breathing) {
                        offset = -5
                    }
                } else {
                    withAnimation(AnimationUtilities.standard) {
                        offset = 0
                    }
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    /// Applies button press animation
    func buttonPressAnimation(isPressed: Bool, hapticStyle: HapticStyle? = .medium) -> some View {
        modifier(ButtonPressAnimation(isPressed: isPressed, hapticStyle: hapticStyle))
    }
    
    /// Applies shake animation for validation errors
    func shakeAnimation(trigger: Bool) -> some View {
        modifier(ShakeAnimation(trigger: trigger))
    }
    
    /// Applies pulse animation for loading states
    func pulseAnimation(isAnimating: Bool) -> some View {
        modifier(PulseAnimation(isAnimating: isAnimating))
    }
    
    /// Applies slide in animation for list items
    func slideInAnimation(index: Int, isVisible: Bool) -> some View {
        modifier(SlideInAnimation(index: index, isVisible: isVisible))
    }
    
    /// Applies celebration animation for success states
    func celebrationAnimation(trigger: Bool) -> some View {
        modifier(CelebrationAnimation(trigger: trigger))
    }
    
    /// Applies floating animation for subtle movement
    func floatingAnimation(isAnimating: Bool) -> some View {
        modifier(FloatingAnimation(isAnimating: isAnimating))
    }
    
    /// Applies standard page transition
    func pageTransition() -> some View {
        transition(AnimationUtilities.slideTransition)
    }
    
    /// Applies fade transition
    func fadeTransition() -> some View {
        transition(AnimationUtilities.fadeTransition)
    }
    
    /// Applies scale transition
    func scaleTransition() -> some View {
        transition(AnimationUtilities.scaleTransition)
    }
    
    /// Applies push transition
    func pushTransition() -> some View {
        transition(AnimationUtilities.pushTransition)
    }
}

// MARK: - Animated Components

/// Animated checkmark for success states
struct AnimatedCheckmark: View {
    let isVisible: Bool
    let size: CGFloat
    let color: Color
    
    @State private var trimEnd: CGFloat = 0
    @State private var scale: CGFloat = 0
    
    init(isVisible: Bool, size: CGFloat = 24, color: Color = .green) {
        self.isVisible = isVisible
        self.size = size
        self.color = color
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.1))
                .frame(width: size * 1.5, height: size * 1.5)
                .scaleEffect(scale)
            
            Path { path in
                path.move(to: CGPoint(x: size * 0.3, y: size * 0.5))
                path.addLine(to: CGPoint(x: size * 0.45, y: size * 0.65))
                path.addLine(to: CGPoint(x: size * 0.7, y: size * 0.35))
            }
            .trim(from: 0, to: trimEnd)
            .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
        }
        .onChange(of: isVisible) { _, newValue in
            if newValue {
                withAnimation(AnimationUtilities.spring.delay(0.1)) {
                    scale = 1.0
                }
                
                withAnimation(AnimationUtilities.smooth.delay(0.2)) {
                    trimEnd = 1.0
                }
                
                HapticManager.shared.success()
            } else {
                withAnimation(AnimationUtilities.standard) {
                    scale = 0
                    trimEnd = 0
                }
            }
        }
    }
}

/// Animated loading dots
struct AnimatedLoadingDots: View {
    let count: Int
    let color: Color
    let size: CGFloat
    
    @State private var animatingIndex = 0
    
    init(count: Int = 3, color: Color = .brandPrimary, size: CGFloat = 8) {
        self.count = count
        self.color = color
        self.size = size
    }
    
    var body: some View {
        HStack(spacing: size * 0.5) {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: size, height: size)
                    .scaleEffect(animatingIndex == index ? 1.3 : 1.0)
                    .opacity(animatingIndex == index ? 1.0 : 0.6)
                    .animation(AnimationUtilities.spring, value: animatingIndex)
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
            withAnimation(AnimationUtilities.spring) {
                animatingIndex = (animatingIndex + 1) % count
            }
        }
    }
}

// MARK: - Preview

#Preview("Animation Utilities") {
    ScrollView {
        VStack(spacing: 30) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Button Animations")
                    .font(.headline)
                
                HStack(spacing: 16) {
                    Button("Press Me") {}
                        .buttonStyle(PrimaryButtonStyle())
                        .buttonPressAnimation(isPressed: false)
                    
                    Button("Shake Me") {}
                        .buttonStyle(SecondaryButtonStyle())
                        .shakeAnimation(trigger: false)
                }
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Loading Animations")
                    .font(.headline)
                
                HStack(spacing: 20) {
                    AnimatedLoadingDots()
                    
                    Circle()
                        .fill(Color.brandPrimary)
                        .frame(width: 20, height: 20)
                        .pulseAnimation(isAnimating: true)
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient.brandGradient)
                        .frame(width: 60, height: 20)
                        .floatingAnimation(isAnimating: true)
                }
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("Success Animations")
                    .font(.headline)
                
                HStack(spacing: 20) {
                    AnimatedCheckmark(isVisible: true, size: 30)
                    
                    Button("Celebrate") {}
                        .buttonStyle(PrimaryButtonStyle())
                        .celebrationAnimation(trigger: false)
                }
            }
            
            VStack(alignment: .leading, spacing: 16) {
                Text("List Animations")
                    .font(.headline)
                
                VStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                            .frame(height: 44)
                            .slideInAnimation(index: index, isVisible: true)
                    }
                }
            }
        }
        .padding()
    }
}