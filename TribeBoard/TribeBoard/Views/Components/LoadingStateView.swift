import SwiftUI

/// Enhanced loading state components with different styles and contexts for prototype experience
struct LoadingStateView: View {
    let message: String
    let style: LoadingStyle
    let duration: TimeInterval?
    let onComplete: (() -> Void)?
    let mockScenario: MockLoadingScenario?
    
    @State private var progress: Double = 0.0
    @State private var isAnimating = false
    @State private var currentMessageIndex = 0
    @State private var currentMessage: String = ""
    @State private var showCheckmark = false
    
    enum LoadingStyle {
        case overlay
        case inline
        case card
        case minimal
        case progress
        case shimmer
        case pulse
    }
    
    enum MockLoadingScenario {
        case familyCreation
        case familyJoining
        case authentication
        case dataSync
        case qrGeneration
        case profileUpdate
        
        var messages: [String] {
            switch self {
            case .familyCreation:
                return [
                    "Creating your family...",
                    "Generating family code...",
                    "Setting up permissions...",
                    "Almost ready!"
                ]
            case .familyJoining:
                return [
                    "Searching for family...",
                    "Verifying code...",
                    "Joining family...",
                    "Welcome to the family!"
                ]
            case .authentication:
                return [
                    "Signing you in...",
                    "Verifying credentials...",
                    "Setting up your profile...",
                    "Welcome back!"
                ]
            case .dataSync:
                return [
                    "Syncing family data...",
                    "Loading messages...",
                    "Updating calendar...",
                    "Sync complete!"
                ]
            case .qrGeneration:
                return [
                    "Generating QR code...",
                    "Encoding family data...",
                    "Creating shareable link...",
                    "Ready to share!"
                ]
            case .profileUpdate:
                return [
                    "Updating profile...",
                    "Saving changes...",
                    "Syncing with family...",
                    "Profile updated!"
                ]
            }
        }
        
        var duration: TimeInterval {
            switch self {
            case .familyCreation: return 3.5
            case .familyJoining: return 2.8
            case .authentication: return 2.2
            case .dataSync: return 4.0
            case .qrGeneration: return 1.8
            case .profileUpdate: return 2.0
            }
        }
    }
    
    init(
        message: String = "Loading...",
        style: LoadingStyle = .overlay,
        duration: TimeInterval? = nil,
        mockScenario: MockLoadingScenario? = nil,
        onComplete: (() -> Void)? = nil
    ) {
        self.message = message
        self.style = style
        self.duration = duration
        self.mockScenario = mockScenario
        self.onComplete = onComplete
        self._currentMessage = State(initialValue: message)
    }
    
    var body: some View {
        Group {
            switch style {
            case .overlay:
                overlayStyle
            case .inline:
                inlineStyle
            case .card:
                cardStyle
            case .minimal:
                minimalStyle
            case .progress:
                progressStyle
            case .shimmer:
                shimmerStyle
            case .pulse:
                pulseStyle
            }
        }
        .onAppear {
            startAnimation()
            setupMockScenario()
        }
    }
    
    // MARK: - Style Implementations
    
    private var overlayStyle: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Enhanced progress indicator with brand styling
                ZStack {
                    Circle()
                        .stroke(Color.brandPrimary.opacity(0.2), lineWidth: 4)
                        .frame(width: 60, height: 60)
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .brandPrimary))
                        .scaleEffect(1.8)
                }
                
                Text(currentMessage)
                    .titleMedium()
                    .foregroundColor(.brandPrimary)
                    .multilineTextAlignment(.center)
                    .animation(DesignSystem.Animation.standard, value: currentMessage)
            }
            .cardPadding()
            .background(
                RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusLarge)
                    .fill(Color(.systemBackground))
                    .mediumShadow()
            )
            .maxContentWidth()
            .screenPadding()
        }
    }
    
    private var inlineStyle: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
                .progressViewStyle(CircularProgressViewStyle(tint: .brandPrimary))
            
            Text(currentMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .animation(.easeInOut(duration: 0.3), value: currentMessage)
        }
        .padding(.vertical, 8)
    }
    
    private var cardStyle: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Branded progress indicator
            ZStack {
                Circle()
                    .fill(LinearGradient.brandGradientSubtle)
                    .frame(width: 80, height: 80)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .brandPrimary))
                    .scaleEffect(1.4)
            }
            
            Text(currentMessage)
                .bodyMedium()
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .animation(DesignSystem.Animation.standard, value: currentMessage)
        }
        .cardPadding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusLarge)
                .fill(Color(.systemBackground))
                .lightShadow()
        )
    }
    
    private var minimalStyle: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .brandPrimary))
            .scaleEffect(0.8)
    }
    
    private var progressStyle: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Enhanced animated progress circle with brand styling
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.brandPrimary.opacity(0.15), lineWidth: 6)
                    .frame(width: 80, height: 80)
                
                // Progress circle with gradient
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient.brandGradient,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                    .animation(DesignSystem.Animation.smooth, value: progress)
                    .opacity(showCheckmark ? 0 : 1)
                
                // Success checkmark with brand styling
                if showCheckmark {
                    ZStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .scaleEffect(showCheckmark ? 1.0 : 0.3)
                    .animation(DesignSystem.Animation.bouncy, value: showCheckmark)
                } else {
                    // Percentage text
                    Text("\(Int(progress * 100))%")
                        .captionLarge()
                        .fontWeight(.semibold)
                        .foregroundColor(.brandPrimary)
                }
            }
            
            Text(currentMessage)
                .bodyMedium()
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .animation(DesignSystem.Animation.standard, value: currentMessage)
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusLarge)
                .fill(Color(.systemBackground))
                .mediumShadow()
        )
    }
    
    private var shimmerStyle: some View {
        VStack(spacing: 16) {
            // Animated shimmer effect
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(.systemGray5),
                            Color(.systemGray4),
                            Color(.systemGray5)
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 20)
                .scaleEffect(x: isAnimating ? 1.2 : 0.8, anchor: .leading)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isAnimating)
            
            Text(currentMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .animation(.easeInOut(duration: 0.3), value: currentMessage)
        }
        .padding()
    }
    
    private var pulseStyle: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(LinearGradient.brandGradient)
                .frame(width: 40, height: 40)
                .scaleEffect(isAnimating ? 1.2 : 0.8)
                .opacity(isAnimating ? 0.6 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnimating)
            
            Text(currentMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .animation(.easeInOut(duration: 0.3), value: currentMessage)
        }
    }
    
    // MARK: - Animation Methods
    
    private func startAnimation() {
        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
            isAnimating = true
        }
    }
    
    private func setupMockScenario() {
        if let mockScenario = mockScenario {
            let scenarioDuration = duration ?? mockScenario.duration
            startMockMessageSequence(messages: mockScenario.messages, totalDuration: scenarioDuration)
            startProgressAnimation(duration: scenarioDuration)
        } else if let duration = duration {
            startProgressAnimation(duration: duration)
        }
    }
    
    private func startMockMessageSequence(messages: [String], totalDuration: TimeInterval) {
        guard !messages.isEmpty else { return }
        
        let stepDuration = totalDuration / Double(messages.count)
        
        for (index, message) in messages.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(index)) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentMessage = message
                    currentMessageIndex = index
                }
                
                // Haptic feedback for message changes
                if index > 0 {
                    HapticManager.shared.lightImpact()
                }
            }
        }
    }
    
    private func startProgressAnimation(duration: TimeInterval) {
        let steps = 20
        let stepDuration = duration / Double(steps)
        
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                withAnimation(.easeInOut(duration: stepDuration * 0.8)) {
                    progress = Double(i) / Double(steps)
                }
                
                if i == steps {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showCheckmark = true
                        }
                        
                        // Success haptic feedback
                        HapticManager.shared.success()
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            onComplete?()
                        }
                    }
                }
            }
        }
    }
}

/// Skeleton loading view for content placeholders
struct SkeletonLoadingView: View {
    let rows: Int
    let showAvatar: Bool
    
    @State private var isAnimating = false
    
    init(rows: Int = 3, showAvatar: Bool = false) {
        self.rows = rows
        self.showAvatar = showAvatar
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<rows, id: \.self) { _ in
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
                .background(Color(.systemBackground))
                .cornerRadius(BrandStyle.cornerRadius)
                .opacity(isAnimating ? 0.6 : 1.0)
                .animation(
                    .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                    value: isAnimating
                )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

/// Button loading state component
struct LoadingButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void
    let style: ButtonStyleType
    
    enum ButtonStyleType {
        case primary
        case secondary
    }
    
    init(
        title: String,
        isLoading: Bool,
        action: @escaping () -> Void,
        style: ButtonStyleType = .primary
    ) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
        self.style = style
    }
    
    var body: some View {
        Button(action: isLoading ? {} : action) {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: textColor))
                        .scaleEffect(0.8)
                } else {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(backgroundColor)
            .cornerRadius(BrandStyle.cornerRadius)
            .opacity(isLoading ? 0.7 : 1.0)
        }
        .disabled(isLoading)
        .animation(.easeInOut(duration: 0.2), value: isLoading)
    }
    
    private var backgroundColor: some View {
        Group {
            switch style {
            case .primary:
                LinearGradient.brandGradient
            case .secondary:
                Color.clear
                    .overlay(
                        RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                            .stroke(Color.brandPrimary, lineWidth: 2)
                    )
            }
        }
    }
    
    private var textColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return .brandPrimary
        }
    }
}

// MARK: - Preview

#Preview("Loading Styles") {
    VStack(spacing: 20) {
        LoadingStateView(
            style: .card,
            mockScenario: .familyCreation
        )
        
        LoadingStateView(
            style: .inline,
            mockScenario: .authentication
        )
        
        LoadingStateView(
            style: .progress,
            mockScenario: .dataSync
        )
        
        LoadingStateView(
            style: .shimmer,
            mockScenario: .qrGeneration
        )
        
        LoadingStateView(
            style: .pulse,
            mockScenario: .profileUpdate
        )
        
        LoadingButton(
            title: "Create Family",
            isLoading: true,
            action: {},
            style: .primary
        )
        
        SkeletonLoadingView(rows: 3, showAvatar: true)
    }
    .padding()
}

#Preview("Loading Overlay") {
    ZStack {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()
        
        LoadingStateView(
            style: .overlay,
            mockScenario: .familyJoining
        )
    }
}

#Preview("Mock Loading Scenarios") {
    ScrollView {
        VStack(spacing: 30) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Family Creation")
                    .font(.headline)
                LoadingStateView(
                    style: .card,
                    mockScenario: .familyCreation
                )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Authentication")
                    .font(.headline)
                LoadingStateView(
                    style: .progress,
                    mockScenario: .authentication
                )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Data Sync")
                    .font(.headline)
                LoadingStateView(
                    style: .shimmer,
                    mockScenario: .dataSync
                )
            }
        }
        .padding()
    }
}