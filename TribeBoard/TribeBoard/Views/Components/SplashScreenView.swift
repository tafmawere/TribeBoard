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