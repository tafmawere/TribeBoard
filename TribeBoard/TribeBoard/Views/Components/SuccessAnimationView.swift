import SwiftUI

/// Success animation component for celebrating completed actions
struct SuccessAnimationView: View {
    let message: String
    let isVisible: Bool
    let onComplete: (() -> Void)?
    
    @State private var checkmarkVisible = false
    @State private var textVisible = false
    @State private var confettiVisible = false
    @State private var scale: CGFloat = 0
    @State private var rotation: Double = 0
    @State private var particles: [ConfettiParticle] = []
    
    init(
        message: String,
        isVisible: Bool,
        onComplete: (() -> Void)? = nil
    ) {
        self.message = message
        self.isVisible = isVisible
        self.onComplete = onComplete
    }
    
    var body: some View {
        ZStack {
            // Background overlay
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .opacity(isVisible ? 1 : 0)
            
            VStack(spacing: 24) {
                // Success checkmark with celebration animation
                ZStack {
                    // Pulsing background circle
                    Circle()
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .scaleEffect(scale)
                        .opacity(checkmarkVisible ? 1 : 0)
                    
                    // Main success circle
                    Circle()
                        .fill(LinearGradient(
                            gradient: Gradient(colors: [Color.green, Color.green.opacity(0.8)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 80, height: 80)
                        .scaleEffect(checkmarkVisible ? 1 : 0)
                        .rotationEffect(.degrees(rotation))
                    
                    // Animated checkmark
                    AnimatedCheckmark(
                        isVisible: checkmarkVisible,
                        size: 32,
                        color: .white
                    )
                }
                
                // Success message
                Text(message)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .opacity(textVisible ? 1 : 0)
                    .scaleEffect(textVisible ? 1 : 0.8)
                
                // Confetti particles
                ZStack {
                    ForEach(particles.indices, id: \.self) { index in
                        ConfettiParticleView(particle: particles[index])
                            .opacity(confettiVisible ? 1 : 0)
                    }
                }
                .frame(width: 200, height: 100)
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusLarge)
                    .fill(Color(.systemBackground))
                    .shadow(
                        color: BrandStyle.standardShadow,
                        radius: 20,
                        x: 0,
                        y: 10
                    )
            )
            .scaleEffect(isVisible ? 1 : 0.8)
            .opacity(isVisible ? 1 : 0)
        }
        .onChange(of: isVisible) { _, newValue in
            if newValue {
                startSuccessAnimation()
            } else {
                resetAnimation()
            }
        }
    }
    
    private func startSuccessAnimation() {
        // Generate confetti particles
        particles = generateConfettiParticles()
        
        // Step 1: Show checkmark with celebration
        withAnimation(AnimationUtilities.spring.delay(0.1)) {
            checkmarkVisible = true
            scale = 1.2
        }
        
        // Step 2: Rotate and scale back
        withAnimation(AnimationUtilities.celebration.delay(0.3)) {
            rotation = 360
            scale = 1.0
        }
        
        // Step 3: Show text
        withAnimation(AnimationUtilities.smooth.delay(0.6)) {
            textVisible = true
        }
        
        // Step 4: Show confetti
        withAnimation(AnimationUtilities.spring.delay(0.8)) {
            confettiVisible = true
        }
        
        // Haptic feedback sequence
        HapticManager.shared.success()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            HapticManager.shared.lightImpact()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            HapticManager.shared.lightImpact()
        }
        
        // Auto-dismiss after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation(AnimationUtilities.smooth) {
                onComplete?()
            }
        }
    }
    
    private func resetAnimation() {
        checkmarkVisible = false
        textVisible = false
        confettiVisible = false
        scale = 0
        rotation = 0
        particles = []
    }
    
    private func generateConfettiParticles() -> [ConfettiParticle] {
        let colors: [Color] = [.red, .blue, .green, .yellow, .orange, .purple, .pink]
        var particles: [ConfettiParticle] = []
        
        for _ in 0..<20 {
            particles.append(ConfettiParticle(
                color: colors.randomElement() ?? .blue,
                x: Double.random(in: -100...100),
                y: Double.random(in: -50...50),
                rotation: Double.random(in: 0...360),
                scale: Double.random(in: 0.5...1.5)
            ))
        }
        
        return particles
    }
}

/// Individual confetti particle
struct ConfettiParticle {
    let color: Color
    let x: Double
    let y: Double
    let rotation: Double
    let scale: Double
}

/// Confetti particle view
struct ConfettiParticleView: View {
    let particle: ConfettiParticle
    
    @State private var animatedY: Double = 0
    @State private var animatedRotation: Double = 0
    @State private var animatedScale: Double = 1
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(particle.color)
            .frame(width: 8, height: 8)
            .scaleEffect(animatedScale * particle.scale)
            .rotationEffect(.degrees(animatedRotation + particle.rotation))
            .offset(x: particle.x, y: animatedY + particle.y)
            .onAppear {
                withAnimation(
                    .easeOut(duration: 2.0)
                    .delay(Double.random(in: 0...0.5))
                ) {
                    animatedY = 100
                    animatedRotation = 720
                    animatedScale = 0
                }
            }
    }
}

/// Quick success toast animation
struct QuickSuccessAnimation: View {
    let isVisible: Bool
    let message: String
    
    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundColor(.green)
            
            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .shadow(
                    color: BrandStyle.standardShadow,
                    radius: 8,
                    x: 0,
                    y: 4
                )
        )
        .scaleEffect(scale)
        .opacity(opacity)
        .onChange(of: isVisible) { _, newValue in
            if newValue {
                withAnimation(AnimationUtilities.spring) {
                    scale = 1.0
                    opacity = 1.0
                }
                
                HapticManager.shared.success()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(AnimationUtilities.smooth) {
                        scale = 0.8
                        opacity = 0
                    }
                }
            } else {
                withAnimation(AnimationUtilities.smooth) {
                    scale = 0
                    opacity = 0
                }
            }
        }
    }
}

/// Loading to success animation
struct LoadingToSuccessAnimation: View {
    let isLoading: Bool
    let isSuccess: Bool
    let loadingMessage: String
    let successMessage: String
    
    @State private var showSuccess = false
    
    var body: some View {
        ZStack {
            if isLoading && !showSuccess {
                LoadingStateView(
                    message: loadingMessage,
                    style: .card,
                    mockScenario: .familyCreation
                )
                .transition(AnimationUtilities.fadeTransition)
            }
            
            if showSuccess {
                QuickSuccessAnimation(
                    isVisible: showSuccess,
                    message: successMessage
                )
                .transition(AnimationUtilities.scaleTransition)
            }
        }
        .onChange(of: isSuccess) { _, newValue in
            if newValue && isLoading {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(AnimationUtilities.smooth) {
                        showSuccess = true
                    }
                }
            } else if !newValue {
                showSuccess = false
            }
        }
    }
}

/// Pulsing success indicator
struct PulsingSuccessIndicator: View {
    let isActive: Bool
    let size: CGFloat
    
    @State private var pulseScale: CGFloat = 1.0
    @State private var pulseOpacity: Double = 1.0
    
    init(isActive: Bool, size: CGFloat = 20) {
        self.isActive = isActive
        self.size = size
    }
    
    var body: some View {
        ZStack {
            // Outer pulse ring
            Circle()
                .stroke(Color.green.opacity(0.3), lineWidth: 2)
                .frame(width: size * 2, height: size * 2)
                .scaleEffect(pulseScale)
                .opacity(pulseOpacity)
            
            // Inner success circle
            Circle()
                .fill(Color.green)
                .frame(width: size, height: size)
            
            // Checkmark
            Image(systemName: "checkmark")
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundColor(.white)
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                withAnimation(AnimationUtilities.pulse) {
                    pulseScale = 1.5
                    pulseOpacity = 0
                }
                
                HapticManager.shared.success()
            } else {
                pulseScale = 1.0
                pulseOpacity = 1.0
            }
        }
    }
}

// MARK: - Preview

#Preview("Success Animations") {
    struct SuccessAnimationDemo: View {
        @State private var showFullSuccess = false
        @State private var showQuickSuccess = false
        @State private var isLoading = false
        @State private var isSuccess = false
        @State private var pulsingActive = false
        
        var body: some View {
            ScrollView {
                VStack(spacing: 30) {
                    Text("Success Animations")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Full Success Animation")
                            .font(.headline)
                        
                        AnimatedPrimaryButton(
                            title: "Show Full Success",
                            action: {
                                showFullSuccess = true
                            },
                            icon: "star.fill"
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Quick Success Toast")
                            .font(.headline)
                        
                        AnimatedSecondaryButton(
                            title: "Show Quick Success",
                            action: {
                                showQuickSuccess = true
                            },
                            icon: "checkmark.circle"
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Loading to Success")
                            .font(.headline)
                        
                        LoadingToSuccessAnimation(
                            isLoading: isLoading,
                            isSuccess: isSuccess,
                            loadingMessage: "Creating family...",
                            successMessage: "Family created successfully!"
                        )
                        
                        HStack(spacing: 12) {
                            AnimatedSecondaryButton(
                                title: "Start Loading",
                                action: {
                                    isLoading = true
                                    isSuccess = false
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                        isSuccess = true
                                        
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                            isLoading = false
                                            isSuccess = false
                                        }
                                    }
                                },
                                icon: "play.fill"
                            )
                            
                            AnimatedSecondaryButton(
                                title: "Reset",
                                action: {
                                    isLoading = false
                                    isSuccess = false
                                },
                                icon: "arrow.clockwise"
                            )
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Pulsing Success Indicator")
                            .font(.headline)
                        
                        HStack(spacing: 20) {
                            PulsingSuccessIndicator(isActive: pulsingActive)
                            
                            AnimatedSecondaryButton(
                                title: pulsingActive ? "Stop Pulse" : "Start Pulse",
                                action: {
                                    pulsingActive.toggle()
                                },
                                icon: pulsingActive ? "stop.fill" : "play.fill"
                            )
                        }
                    }
                }
                .padding()
            }
            .overlay {
                // Full success animation overlay
                if showFullSuccess {
                    SuccessAnimationView(
                        message: "🎉 Family created successfully!\nWelcome to TribeBoard!",
                        isVisible: showFullSuccess,
                        onComplete: {
                            showFullSuccess = false
                        }
                    )
                }
                
                // Quick success animation
                VStack {
                    Spacer()
                    QuickSuccessAnimation(
                        isVisible: showQuickSuccess,
                        message: "Task completed successfully!"
                    )
                    .padding(.bottom, 100)
                }
                .onChange(of: showQuickSuccess) { _, newValue in
                    if newValue {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            showQuickSuccess = false
                        }
                    }
                }
            }
        }
    }
    
    return SuccessAnimationDemo()
}