import SwiftUI

/// Enhanced branded splash screen with consistent design system usage
struct BrandedSplashScreenView: View {
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0.0
    @State private var textOpacity: Double = 0.0
    @State private var showProgressIndicator = false
    @State private var pulseScale: CGFloat = 1.0
    
    let message: String
    let style: SplashStyle
    
    enum SplashStyle {
        case simple
        case animated
        case prototype
    }
    
    init(message: String = "Loading...", style: SplashStyle = .animated) {
        self.message = message
        self.style = style
    }
    
    var body: some View {
        ZStack {
            // Enhanced background
            backgroundView
            
            VStack(spacing: DesignSystem.Spacing.huge) {
                Spacer()
                
                // Logo section with enhanced branding
                logoSection
                
                Spacer()
                
                // Loading section with consistent spacing
                loadingSection
            }
            .screenPadding()
        }
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Background View
    
    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .simple:
            LinearGradient.brandGradientSubtle
                .ignoresSafeArea()
        case .animated:
            animatedBackground
        case .prototype:
            prototypeBackground
        }
    }
    
    private var animatedBackground: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.brandPrimary.opacity(0.1),
                    Color.brandSecondary.opacity(0.05)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Pulsing radial gradient
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
        }
    }
    
    private var prototypeBackground: some View {
        ZStack {
            // Animated gradient background
            AngularGradient(
                gradient: Gradient(colors: [
                    Color.brandPrimary.opacity(0.2),
                    Color.brandSecondary.opacity(0.15),
                    Color.brandPrimary.opacity(0.1),
                    Color.brandSecondary.opacity(0.2)
                ]),
                center: .center,
                angle: .degrees(0)
            )
            .ignoresSafeArea()
            
            // Subtle overlay
            LinearGradient.brandGradientSubtle
                .ignoresSafeArea()
        }
    }
    
    // MARK: - Logo Section
    
    private var logoSection: some View {
        VStack(spacing: DesignSystem.Spacing.xxl) {
            // Enhanced logo with brand styling
            logoView
            
            // App name with gradient text
            appNameView
        }
    }
    
    @ViewBuilder
    private var logoView: some View {
        switch style {
        case .simple:
            TribeBoardLogo(size: .extraLarge, showBackground: true)
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                .mediumShadow()
        case .animated:
            ZStack {
                // Pulsing background circle
                Circle()
                    .fill(LinearGradient.brandGradientSubtle)
                    .frame(width: 300, height: 300)
                    .scaleEffect(pulseScale * 0.8)
                    .opacity(0.3)
                
                TribeBoardLogo(size: .extraLarge, showBackground: true)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .brandShadow()
            }
        case .prototype:
            ZStack {
                // Multiple pulsing rings
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
                        .frame(width: CGFloat(280 + index * 40), height: CGFloat(280 + index * 40))
                        .opacity(logoOpacity * 0.5)
                }
                
                TribeBoardLogo(size: .extraLarge, showBackground: true)
                    .scaleEffect(logoScale)
                    .opacity(logoOpacity)
                    .heavyShadow()
            }
        }
    }
    
    private var appNameView: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Text("TribeBoard")
                .displayMedium()
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [.brandPrimary, .brandSecondary]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .opacity(textOpacity)
                .lightShadow()
            
            Text("Family Together")
                .titleMedium()
                .foregroundColor(.brandSecondary)
                .opacity(textOpacity)
                .tracking(1.5)
            
            if style == .prototype {
                Text("UI/UX Prototype")
                    .captionLarge()
                    .foregroundColor(.brandSecondary.opacity(0.7))
                    .opacity(textOpacity)
                    .tracking(1)
            }
        }
    }
    
    // MARK: - Loading Section
    
    private var loadingSection: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            if showProgressIndicator {
                enhancedProgressIndicator
                    .transition(.opacity.combined(with: .scale))
            }
            
            Text(message)
                .bodyMedium()
                .foregroundColor(.secondary)
                .opacity(showProgressIndicator ? 1.0 : 0.0)
                .transition(.opacity)
        }
        .padding(.bottom, DesignSystem.Spacing.gigantic)
    }
    
    @ViewBuilder
    private var enhancedProgressIndicator: some View {
        switch style {
        case .simple:
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .brandPrimary))
                .scaleEffect(1.2)
        case .animated:
            ZStack {
                Circle()
                    .stroke(Color.brandPrimary.opacity(0.2), lineWidth: 3)
                    .frame(width: 50, height: 50)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .brandPrimary))
                    .scaleEffect(1.4)
            }
        case .prototype:
            ZStack {
                Circle()
                    .stroke(Color.brandPrimary.opacity(0.2), lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .stroke(
                        LinearGradient.brandGradient,
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .clear))
                    .scaleEffect(1.6)
            }
        }
    }
    
    // MARK: - Animations
    
    private func startAnimations() {
        switch style {
        case .simple:
            startSimpleAnimations()
        case .animated:
            startAnimatedAnimations()
        case .prototype:
            startPrototypeAnimations()
        }
    }
    
    private func startSimpleAnimations() {
        // Logo entrance
        withAnimation(DesignSystem.Animation.smooth) {
            logoOpacity = 1.0
            logoScale = 1.0
        }
        
        // Text fade in
        withAnimation(DesignSystem.Animation.standard.delay(0.4)) {
            textOpacity = 1.0
        }
        
        // Progress indicator
        withAnimation(DesignSystem.Animation.standard.delay(1.0)) {
            showProgressIndicator = true
        }
    }
    
    private func startAnimatedAnimations() {
        // Start pulsing background
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            pulseScale = 1.1
        }
        
        // Logo entrance with spring
        withAnimation(DesignSystem.Animation.bouncy) {
            logoOpacity = 1.0
            logoScale = 1.0
        }
        
        // Text fade in
        withAnimation(DesignSystem.Animation.smooth.delay(0.5)) {
            textOpacity = 1.0
        }
        
        // Progress indicator
        withAnimation(DesignSystem.Animation.standard.delay(1.2)) {
            showProgressIndicator = true
        }
    }
    
    private func startPrototypeAnimations() {
        // Logo entrance with enhanced spring
        withAnimation(.spring(response: 1.2, dampingFraction: 0.6, blendDuration: 0.3)) {
            logoOpacity = 1.0
            logoScale = 1.0
        }
        
        // Text fade in with stagger
        withAnimation(DesignSystem.Animation.smooth.delay(0.8)) {
            textOpacity = 1.0
        }
        
        // Progress indicator with delay
        withAnimation(DesignSystem.Animation.standard.delay(1.5)) {
            showProgressIndicator = true
        }
    }
}

// MARK: - Preview

#Preview("Simple Splash") {
    BrandedSplashScreenView(
        message: "Initializing TribeBoard...",
        style: .simple
    )
}

#Preview("Animated Splash") {
    BrandedSplashScreenView(
        message: "Setting up your family space...",
        style: .animated
    )
}

#Preview("Prototype Splash") {
    BrandedSplashScreenView(
        message: "Loading prototype experience...",
        style: .prototype
    )
}