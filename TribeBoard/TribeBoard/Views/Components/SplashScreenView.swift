import SwiftUI

/// Splash screen view that shows the TribeBoard logo and app name during app loading
struct SplashScreenView: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0.0
    @State private var textOpacity: Double = 0.0
    @State private var showProgressIndicator = false
    
    let message: String
    
    init(message: String = "Loading...") {
        self.message = message
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.brandPrimary.opacity(0.1),
                    Color.brandSecondary.opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Logo section
                VStack(spacing: 24) {
                    // TribeBoard Logo
                    TribeBoardLogo(size: .extraLarge, showBackground: true)
                        .scaleEffect(logoScale)
                        .opacity(logoOpacity)
                        .shadow(
                            color: BrandStyle.standardShadow,
                            radius: 20,
                            x: 0,
                            y: 10
                        )
                    
                    // App Name
                    VStack(spacing: 8) {
                        Text("TribeBoard")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundColor(.brandPrimary)
                            .opacity(textOpacity)
                        
                        Text("Family Together")
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(.brandSecondary)
                            .opacity(textOpacity)
                    }
                }
                
                Spacer()
                
                // Loading indicator section
                VStack(spacing: 16) {
                    if showProgressIndicator {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .brandPrimary))
                            .scaleEffect(1.2)
                            .transition(.opacity.combined(with: .scale))
                    }
                    
                    Text(message)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .opacity(showProgressIndicator ? 1.0 : 0.0)
                        .transition(.opacity)
                }
                .padding(.bottom, 60)
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Animations
    
    private func startAnimations() {
        // Logo fade in and scale animation
        withAnimation(.easeOut(duration: 0.8)) {
            logoOpacity = 1.0
            logoScale = 1.0
        }
        
        // Text fade in with delay
        withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
            textOpacity = 1.0
        }
        
        // Progress indicator with delay
        withAnimation(.easeIn(duration: 0.4).delay(1.2)) {
            showProgressIndicator = true
        }
    }
}

/// Enhanced prototype splash screen with advanced branded animations
struct PrototypeSplashScreenView: View {
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0.0
    @State private var logoRotation: Double = 0.0
    @State private var textOpacity: Double = 0.0
    @State private var pulseScale: CGFloat = 1.0
    @State private var gradientRotation: Double = 0.0
    @State private var showProgressIndicator = false
    @State private var progressValue: Double = 0.0
    
    let message: String
    
    init(message: String = "Loading...") {
        self.message = message
    }
    
    var body: some View {
        ZStack {
            // Animated gradient background
            AngularGradient(
                gradient: Gradient(colors: [
                    Color.brandPrimary.opacity(0.3),
                    Color.brandSecondary.opacity(0.2),
                    Color.brandPrimary.opacity(0.1),
                    Color.brandSecondary.opacity(0.3)
                ]),
                center: .center,
                angle: .degrees(gradientRotation)
            )
            .ignoresSafeArea()
            
            // Radial pulse effect
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.brandPrimary.opacity(0.15),
                    Color.brandSecondary.opacity(0.08),
                    Color.clear
                ]),
                center: .center,
                startRadius: 50,
                endRadius: 300
            )
            .scaleEffect(pulseScale)
            .opacity(0.8)
            .ignoresSafeArea()
            
            VStack(spacing: 50) {
                Spacer()
                
                // Enhanced logo section with multiple animation layers
                ZStack {
                    // Background glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.brandPrimary.opacity(0.2),
                                    Color.brandSecondary.opacity(0.1),
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 0,
                                endRadius: 200
                            )
                        )
                        .frame(width: 400, height: 400)
                        .scaleEffect(pulseScale)
                        .opacity(0.6)
                    
                    // Rotating accent rings
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.brandPrimary.opacity(0.3),
                                        Color.clear,
                                        Color.brandSecondary.opacity(0.3),
                                        Color.clear
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: CGFloat(200 + index * 40), height: CGFloat(200 + index * 40))
                            .rotationEffect(.degrees(logoRotation + Double(index * 120)))
                            .opacity(logoOpacity * 0.5)
                    }
                    
                    VStack(spacing: 32) {
                        // TribeBoard Logo with enhanced effects
                        TribeBoardLogo(size: .extraLarge, showBackground: true)
                            .scaleEffect(logoScale)
                            .opacity(logoOpacity)
                            .rotationEffect(.degrees(logoRotation * 0.1))
                            .shadow(
                                color: BrandStyle.standardShadow,
                                radius: 30,
                                x: 0,
                                y: 20
                            )
                            .overlay(
                                // Shimmer effect
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [
                                                Color.clear,
                                                Color.white.opacity(0.3),
                                                Color.clear
                                            ]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .opacity(logoOpacity * 0.5)
                                    .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: logoOpacity)
                            )
                        
                        // Enhanced app name with gradient text
                        VStack(spacing: 12) {
                            Text("TribeBoard")
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            .brandPrimary,
                                            .brandSecondary,
                                            .brandPrimary
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .opacity(textOpacity)
                                .shadow(
                                    color: BrandStyle.standardShadow,
                                    radius: 10,
                                    x: 0,
                                    y: 5
                                )
                            
                            Text("Family Together")
                                .font(.system(size: 20, weight: .medium, design: .rounded))
                                .foregroundColor(.brandSecondary)
                                .opacity(textOpacity)
                                .tracking(2)
                        }
                    }
                }
                
                Spacer()
                
                // Enhanced loading section with progress
                VStack(spacing: 20) {
                    if showProgressIndicator {
                        // Custom progress indicator
                        ZStack {
                            Circle()
                                .stroke(Color.brandPrimary.opacity(0.2), lineWidth: 4)
                                .frame(width: 50, height: 50)
                            
                            Circle()
                                .trim(from: 0, to: progressValue)
                                .stroke(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.brandPrimary, .brandSecondary]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                )
                                .frame(width: 50, height: 50)
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut(duration: 0.5), value: progressValue)
                        }
                        .transition(.opacity.combined(with: .scale))
                    }
                    
                    Text(message)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.secondary)
                        .opacity(showProgressIndicator ? 1.0 : 0.0)
                        .transition(.opacity)
                    
                    // Prototype indicator
                    Text("UI/UX Prototype")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundColor(.brandSecondary.opacity(0.7))
                        .opacity(showProgressIndicator ? 1.0 : 0.0)
                        .transition(.opacity)
                }
                .padding(.bottom, 80)
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            startPrototypeAnimations()
        }
    }
    
    // MARK: - Enhanced Animations
    
    private func startPrototypeAnimations() {
        // Start background gradient rotation
        withAnimation(.linear(duration: 20.0).repeatForever(autoreverses: false)) {
            gradientRotation = 360
        }
        
        // Start pulsing background
        withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.2
        }
        
        // Logo entrance with spring animation
        withAnimation(.spring(response: 1.2, dampingFraction: 0.6, blendDuration: 0.3)) {
            logoOpacity = 1.0
            logoScale = 1.0
        }
        
        // Start logo rotation
        withAnimation(.linear(duration: 15.0).repeatForever(autoreverses: false).delay(0.5)) {
            logoRotation = 360
        }
        
        // Text fade in with delay
        withAnimation(.easeOut(duration: 0.8).delay(0.8)) {
            textOpacity = 1.0
        }
        
        // Progress indicator with delay
        withAnimation(.easeIn(duration: 0.6).delay(1.5)) {
            showProgressIndicator = true
        }
        
        // Animate progress
        withAnimation(.easeInOut(duration: 2.0).delay(2.0)) {
            progressValue = 1.0
        }
    }
}

/// Animated splash screen with pulsing effect
struct AnimatedSplashScreenView: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0.0
    @State private var textOpacity: Double = 0.0
    @State private var pulseScale: CGFloat = 1.0
    @State private var showProgressIndicator = false
    
    let message: String
    
    init(message: String = "Loading...") {
        self.message = message
    }
    
    var body: some View {
        ZStack {
            // Animated background
            RadialGradient(
                gradient: Gradient(colors: [
                    Color.brandPrimary.opacity(0.15),
                    Color.brandSecondary.opacity(0.08),
                    Color.clear
                ]),
                center: .center,
                startRadius: 100,
                endRadius: 400
            )
            .scaleEffect(pulseScale)
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Logo section with pulsing background
                ZStack {
                    // Pulsing background circle
                    Circle()
                        .fill(
                            RadialGradient(
                                gradient: Gradient(colors: [
                                    Color.brandPrimary.opacity(0.1),
                                    Color.clear
                                ]),
                                center: .center,
                                startRadius: 0,
                                endRadius: 150
                            )
                        )
                        .frame(width: 300, height: 300)
                        .scaleEffect(pulseScale)
                        .opacity(0.6)
                    
                    VStack(spacing: 24) {
                        // TribeBoard Logo
                        TribeBoardLogo(size: .extraLarge, showBackground: true)
                            .scaleEffect(logoScale)
                            .opacity(logoOpacity)
                            .shadow(
                                color: BrandStyle.standardShadow,
                                radius: 25,
                                x: 0,
                                y: 15
                            )
                        
                        // App Name
                        VStack(spacing: 8) {
                            Text("TribeBoard")
                                .font(.system(size: 42, weight: .bold, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.brandPrimary, .brandSecondary]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .opacity(textOpacity)
                            
                            Text("Family Together")
                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                .foregroundColor(.brandSecondary)
                                .opacity(textOpacity)
                        }
                    }
                }
                
                Spacer()
                
                // Loading indicator section
                VStack(spacing: 16) {
                    if showProgressIndicator {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .brandPrimary))
                            .scaleEffect(1.2)
                            .transition(.opacity.combined(with: .scale))
                    }
                    
                    Text(message)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                        .opacity(showProgressIndicator ? 1.0 : 0.0)
                        .transition(.opacity)
                }
                .padding(.bottom, 60)
            }
            .padding(.horizontal, 40)
        }
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Animations
    
    private func startAnimations() {
        // Start pulsing background
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.1
        }
        
        // Logo fade in and scale animation
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
            logoOpacity = 1.0
            logoScale = 1.0
        }
        
        // Text fade in with delay
        withAnimation(.easeOut(duration: 0.6).delay(0.5)) {
            textOpacity = 1.0
        }
        
        // Progress indicator with delay
        withAnimation(.easeIn(duration: 0.4).delay(1.0)) {
            showProgressIndicator = true
        }
    }
}

// MARK: - Preview

#Preview("Simple Splash") {
    SplashScreenView(message: "Initializing TribeBoard...")
}

#Preview("Animated Splash") {
    AnimatedSplashScreenView(message: "Setting up your family space...")
}

#Preview("Prototype Splash") {
    PrototypeSplashScreenView(message: "Initializing TribeBoard...")
}