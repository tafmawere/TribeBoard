import SwiftUI

/// Enhanced loading overlay with animations and micro-interactions
struct LoadingOverlay: View {
    let message: String
    let showProgress: Bool
    let progress: Double
    
    @State private var isAnimating = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var rotationAngle: Double = 0
    
    init(
        message: String = "Loading...",
        showProgress: Bool = false,
        progress: Double = 0.0
    ) {
        self.message = message
        self.showProgress = showProgress
        self.progress = progress
    }
    
    var body: some View {
        ZStack {
            // Animated background overlay
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    // Haptic feedback when user taps overlay
                    HapticManager.shared.lightImpact()
                }
            
            VStack(spacing: 20) {
                // Enhanced loading indicator
                ZStack {
                    if showProgress {
                        // Progress circle
                        Circle()
                            .stroke(Color.brandPrimary.opacity(0.2), lineWidth: 4)
                            .frame(width: 60, height: 60)
                        
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(
                                LinearGradient.brandGradient,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(-90))
                            .animation(AnimationUtilities.smooth, value: progress)
                        
                        Text("\(Int(progress * 100))%")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.brandPrimary)
                    } else {
                        // Animated spinner with pulsing effect
                        Circle()
                            .stroke(Color.brandPrimary.opacity(0.2), lineWidth: 4)
                            .frame(width: 60, height: 60)
                            .scaleEffect(pulseScale)
                        
                        Circle()
                            .trim(from: 0, to: 0.7)
                            .stroke(
                                LinearGradient.brandGradient,
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .frame(width: 60, height: 60)
                            .rotationEffect(.degrees(rotationAngle))
                    }
                }
                
                // Animated message
                Text(message)
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.brandPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(isAnimating ? 1.0 : 0.7)
                    .animation(AnimationUtilities.breathing, value: isAnimating)
                
                // Animated loading dots
                if !showProgress {
                    AnimatedLoadingDots(
                        count: 3,
                        color: .brandPrimary,
                        size: 6
                    )
                }
            }
            .padding(32)
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
            .scaleEffect(isAnimating ? 1.0 : 0.9)
            .animation(AnimationUtilities.spring, value: isAnimating)
        }
        .onAppear {
            startAnimations()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading: \(message)")
        .accessibilityHint("Please wait while the operation completes")
        .accessibilityAddTraits([.updatesFrequently, .causesPageTurn])
    }
    
    private func startAnimations() {
        // Initial appearance animation
        withAnimation(AnimationUtilities.spring) {
            isAnimating = true
        }
        
        if !showProgress {
            // Continuous rotation for spinner
            withAnimation(AnimationUtilities.rotation) {
                rotationAngle = 360
            }
            
            // Pulsing effect
            withAnimation(AnimationUtilities.pulse) {
                pulseScale = 1.1
            }
        }
        
        // Haptic feedback on appearance
        HapticManager.shared.lightImpact()
    }
}

/// Quick loading overlay for brief operations
struct QuickLoadingOverlay: View {
    let message: String
    
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 0.8
    
    init(message: String = "Processing...") {
        self.message = message
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
            
            HStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .brandPrimary))
                    .scaleEffect(0.8)
                
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
        }
        .onAppear {
            withAnimation(AnimationUtilities.spring) {
                opacity = 1.0
                scale = 1.0
            }
            
            HapticManager.shared.lightImpact()
        }
    }
}

/// Skeleton loading overlay for content placeholders
struct SkeletonLoadingOverlay: View {
    let itemCount: Int
    let showAvatar: Bool
    
    @State private var isAnimating = false
    
    init(itemCount: Int = 5, showAvatar: Bool = true) {
        self.itemCount = itemCount
        self.showAvatar = showAvatar
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(0..<itemCount, id: \.self) { index in
                    HStack(spacing: 12) {
                        if showAvatar {
                            Circle()
                                .fill(Color(.systemGray5))
                                .frame(width: 44, height: 44)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(height: 16)
                                .frame(maxWidth: .infinity)
                            
                            Rectangle()
                                .fill(Color(.systemGray5))
                                .frame(height: 12)
                                .frame(maxWidth: .infinity)
                                .scaleEffect(x: 0.7, anchor: .leading)
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                            .fill(Color(.systemBackground))
                    )
                    .opacity(isAnimating ? 0.6 : 1.0)
                    .slideInAnimation(index: index, isVisible: true)
                }
            }
            .padding()
        }
        .onAppear {
            withAnimation(AnimationUtilities.shimmer) {
                isAnimating = true
            }
        }
    }
}

#Preview("Loading Overlays") {
    struct LoadingOverlayDemo: View {
        @State private var showStandard = false
        @State private var showProgress = false
        @State private var showQuick = false
        @State private var showSkeleton = false
        @State private var progress: Double = 0.0
        
        var body: some View {
            VStack(spacing: 20) {
                Text("Loading Overlay Demo")
                    .font(.title)
                    .fontWeight(.bold)
                
                VStack(spacing: 16) {
                    AnimatedPrimaryButton(
                        title: "Show Standard Loading",
                        action: { showStandard = true },
                        icon: "arrow.clockwise"
                    )
                    
                    AnimatedSecondaryButton(
                        title: "Show Progress Loading",
                        action: {
                            showProgress = true
                            startProgressAnimation()
                        },
                        icon: "percent"
                    )
                    
                    AnimatedSecondaryButton(
                        title: "Show Quick Loading",
                        action: { showQuick = true },
                        icon: "bolt.fill"
                    )
                    
                    AnimatedSecondaryButton(
                        title: "Show Skeleton Loading",
                        action: { showSkeleton = true },
                        icon: "rectangle.3.group"
                    )
                }
                
                Spacer()
            }
            .padding()
            .overlay {
                if showStandard {
                    LoadingOverlay(message: "Loading family data...")
                        .onTapGesture {
                            showStandard = false
                        }
                }
                
                if showProgress {
                    LoadingOverlay(
                        message: "Syncing data...",
                        showProgress: true,
                        progress: progress
                    )
                    .onTapGesture {
                        showProgress = false
                        progress = 0.0
                    }
                }
                
                if showQuick {
                    QuickLoadingOverlay(message: "Saving changes...")
                        .onTapGesture {
                            showQuick = false
                        }
                }
                
                if showSkeleton {
                    SkeletonLoadingOverlay(itemCount: 4)
                        .onTapGesture {
                            showSkeleton = false
                        }
                }
            }
        }
        
        private func startProgressAnimation() {
            progress = 0.0
            
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
                progress += 0.05
                
                if progress >= 1.0 {
                    timer.invalidate()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showProgress = false
                        progress = 0.0
                    }
                }
            }
        }
    }
    
    return LoadingOverlayDemo()
}