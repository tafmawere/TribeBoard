import SwiftUI

// MARK: - Success Animation View

struct SuccessAnimation: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0.0
    @State private var checkmarkScale: CGFloat = 0.0
    @State private var showCheckmark: Bool = false
    
    let size: CGFloat
    let color: Color
    let onComplete: (() -> Void)?
    
    init(size: CGFloat = 80, color: Color = .green, onComplete: (() -> Void)? = nil) {
        self.size = size
        self.color = color
        self.onComplete = onComplete
    }
    
    var body: some View {
        ZStack {
            // Background Circle
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: size, height: size)
                .scaleEffect(scale)
                .opacity(opacity)
            
            // Checkmark
            Image(systemName: "checkmark")
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundColor(color)
                .scaleEffect(checkmarkScale)
                .opacity(showCheckmark ? 1.0 : 0.0)
        }
        .onAppear {
            performAnimation()
        }
    }
    
    private func performAnimation() {
        // Phase 1: Scale up background circle
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            scale = 1.0
            opacity = 1.0
        }
        
        // Phase 2: Show checkmark with bounce
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                showCheckmark = true
                checkmarkScale = 1.2
            }
            
            // Phase 3: Settle checkmark
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    checkmarkScale = 1.0
                }
                
                // Call completion handler
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onComplete?()
                }
            }
        }
    }
}

// MARK: - Pulsing Success Animation

struct PulsingSuccessAnimation: View {
    @State private var isPulsing: Bool = false
    
    let size: CGFloat
    let color: Color
    
    init(size: CGFloat = 60, color: Color = .green) {
        self.size = size
        self.color = color
    }
    
    var body: some View {
        ZStack {
            // Pulsing rings
            ForEach(0..<3) { index in
                Circle()
                    .stroke(color.opacity(0.3), lineWidth: 2)
                    .frame(width: size, height: size)
                    .scaleEffect(isPulsing ? 1.5 : 0.5)
                    .opacity(isPulsing ? 0.0 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: false)
                        .delay(Double(index) * 0.3),
                        value: isPulsing
                    )
            }
            
            // Center checkmark
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: size * 0.6, height: size * 0.6)
                
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.25, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            isPulsing = true
        }
    }
}

// MARK: - Confetti Animation

struct ConfettiAnimation: View {
    @State private var animate: Bool = false
    
    let colors: [Color] = [.red, .blue, .green, .yellow, .orange, .purple, .pink]
    
    var body: some View {
        ZStack {
            ForEach(0..<50, id: \.self) { index in
                ConfettiPiece(
                    color: colors.randomElement() ?? .blue,
                    delay: Double.random(in: 0...2)
                )
                .opacity(animate ? 1.0 : 0.0)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5)) {
                animate = true
            }
        }
    }
}

struct ConfettiPiece: View {
    let color: Color
    let delay: Double
    
    @State private var yOffset: CGFloat = -100
    @State private var xOffset: CGFloat = 0
    @State private var rotation: Double = 0
    
    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 8, height: 8)
            .rotationEffect(.degrees(rotation))
            .offset(x: xOffset, y: yOffset)
            .onAppear {
                let randomX = CGFloat.random(in: -200...200)
                let randomRotation = Double.random(in: 0...360)
                
                withAnimation(
                    .easeInOut(duration: 3.0)
                    .delay(delay)
                ) {
                    yOffset = 800
                    xOffset = randomX
                    rotation = randomRotation
                }
            }
    }
}

// MARK: - Success Overlay Modifier

struct SuccessOverlay: ViewModifier {
    @Binding var showSuccess: Bool
    let message: String
    let animationType: SuccessAnimationType
    let onComplete: () -> Void
    
    enum SuccessAnimationType {
        case checkmark
        case pulsing
        case confetti
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if showSuccess {
                        ZStack {
                            Color.black.opacity(0.3)
                                .ignoresSafeArea()
                            
                            VStack(spacing: 20) {
                                switch animationType {
                                case .checkmark:
                                    SuccessAnimation(onComplete: onComplete)
                                case .pulsing:
                                    PulsingSuccessAnimation()
                                case .confetti:
                                    ConfettiAnimation()
                                }
                                
                                Text(message)
                                    .font(.title2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.3), value: showSuccess)
            )
    }
}

extension View {
    func successOverlay(
        showSuccess: Binding<Bool>,
        message: String,
        animationType: SuccessOverlay.SuccessAnimationType = .checkmark,
        onComplete: @escaping () -> Void
    ) -> some View {
        modifier(SuccessOverlay(
            showSuccess: showSuccess,
            message: message,
            animationType: animationType,
            onComplete: onComplete
        ))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 40) {
        SuccessAnimation()
        
        PulsingSuccessAnimation()
        
        Text("Success Animations")
            .font(.title)
    }
    .padding()
}