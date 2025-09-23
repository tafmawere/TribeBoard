import SwiftUI

/// Enhanced branded loading overlay with consistent design system
struct BrandedLoadingOverlay: View {
    let message: String
    let style: LoadingOverlayStyle
    let showProgress: Bool
    let progress: Double
    
    @State private var isAnimating = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var rotationAngle: Double = 0
    
    enum LoadingOverlayStyle {
        case standard
        case branded
        case minimal
        case progress
    }
    
    init(
        message: String = "Loading...",
        style: LoadingOverlayStyle = .branded,
        showProgress: Bool = false,
        progress: Double = 0.0
    ) {
        self.message = message
        self.style = style
        self.showProgress = showProgress
        self.progress = progress
    }
    
    var body: some View {
        ZStack {
            // Background overlay
            backgroundOverlay
            
            // Loading content
            loadingContent
        }
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Background Overlay
    
    private var backgroundOverlay: some View {
        Color.black.opacity(0.4)
            .ignoresSafeArea()
            .animation(DesignSystem.Animation.standard, value: isAnimating)
    }
    
    // MARK: - Loading Content
    
    @ViewBuilder
    private var loadingContent: some View {
        switch style {
        case .standard:
            standardLoadingView
        case .branded:
            brandedLoadingView
        case .minimal:
            minimalLoadingView
        case .progress:
            progressLoadingView
        }
    }
    
    private var standardLoadingView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .brandPrimary))
                .scaleEffect(1.5)
            
            Text(message)
                .titleMedium()
                .foregroundColor(.brandPrimary)
                .multilineTextAlignment(.center)
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
    
    private var brandedLoadingView: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // Enhanced branded loading indicator
            ZStack {
                // Pulsing background
                Circle()
                    .fill(LinearGradient.brandGradientSubtle)
                    .frame(width: 120, height: 120)
                    .scaleEffect(pulseScale)
                    .opacity(0.6)
                
                // Rotating outer ring
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.brandPrimary.opacity(0.8),
                                Color.brandSecondary.opacity(0.4),
                                Color.clear,
                                Color.clear
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(rotationAngle))
                
                // Inner progress indicator
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .brandPrimary))
                    .scaleEffect(2.0)
            }
            
            // Message with brand styling
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text(message)
                    .titleMedium()
                    .foregroundColor(.brandPrimary)
                    .multilineTextAlignment(.center)
                
                Text("Please wait...")
                    .bodySmall()
                    .foregroundColor(.secondary)
            }
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadiusLarge)
                .fill(Color(.systemBackground))
                .brandShadow()
        )
        .maxContentWidth()
        .screenPadding()
    }
    
    private var minimalLoadingView: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .brandPrimary))
                .scaleEffect(1.2)
            
            Text(message)
                .bodyMedium()
                .foregroundColor(.secondary)
        }
        .padding(DesignSystem.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .lightShadow()
        )
    }
    
    private var progressLoadingView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Progress circle with percentage
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.brandPrimary.opacity(0.2), lineWidth: 6)
                    .frame(width: 100, height: 100)
                
                // Progress circle
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient.brandGradient,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                    .animation(DesignSystem.Animation.smooth, value: progress)
                
                // Percentage text
                VStack(spacing: DesignSystem.Spacing.xs) {
                    Text("\(Int(progress * 100))%")
                        .titleMedium()
                        .fontWeight(.semibold)
                        .foregroundColor(.brandPrimary)
                    
                    Text("Complete")
                        .captionMedium()
                        .foregroundColor(.secondary)
                }
            }
            
            // Message
            Text(message)
                .bodyMedium()
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
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
    
    // MARK: - Animations
    
    private func startAnimations() {
        // Pulsing animation
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseScale = 1.1
        }
        
        // Rotation animation
        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
            rotationAngle = 360
        }
        
        // General animation state
        withAnimation(DesignSystem.Animation.standard) {
            isAnimating = true
        }
    }
}

/// Branded loading button with consistent styling
struct BrandedLoadingButton: View {
    let title: String
    let isLoading: Bool
    let action: () -> Void
    let style: ButtonStyle
    
    enum ButtonStyle {
        case primary
        case secondary
        case tertiary
    }
    
    init(
        title: String,
        isLoading: Bool,
        action: @escaping () -> Void,
        style: ButtonStyle = .primary
    ) {
        self.title = title
        self.isLoading = isLoading
        self.action = action
        self.style = style
    }
    
    var body: some View {
        Button(action: isLoading ? {} : action) {
            HStack(spacing: DesignSystem.Spacing.md) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: textColor))
                        .scaleEffect(0.8)
                } else {
                    Text(title)
                        .font(DesignSystem.Typography.buttonMedium)
                }
            }
            .foregroundColor(textColor)
            .frame(maxWidth: .infinity)
            .standardButtonHeight()
            .background(backgroundView)
            .cornerRadius(BrandStyle.cornerRadius)
            .opacity(isLoading ? 0.7 : 1.0)
        }
        .disabled(isLoading)
        .animation(DesignSystem.Animation.quick, value: isLoading)
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:
            LinearGradient.brandGradient
        case .secondary:
            Color.clear
                .overlay(
                    RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                        .stroke(Color.brandPrimary, lineWidth: 2)
                )
        case .tertiary:
            Color.brandPrimary.opacity(0.1)
        }
    }
    
    private var textColor: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return .brandPrimary
        case .tertiary:
            return .brandPrimary
        }
    }
}

/// Skeleton loading view with brand consistency
struct BrandedSkeletonView: View {
    let rows: Int
    let showAvatar: Bool
    let style: SkeletonStyle
    
    @State private var isAnimating = false
    
    enum SkeletonStyle {
        case standard
        case card
        case list
    }
    
    init(rows: Int = 3, showAvatar: Bool = false, style: SkeletonStyle = .standard) {
        self.rows = rows
        self.showAvatar = showAvatar
        self.style = style
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ForEach(0..<rows, id: \.self) { index in
                skeletonRow(index: index)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
        }
    }
    
    @ViewBuilder
    private func skeletonRow(index: Int) -> some View {
        switch style {
        case .standard:
            standardSkeletonRow
        case .card:
            cardSkeletonRow
        case .list:
            listSkeletonRow
        }
    }
    
    private var standardSkeletonRow: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            if showAvatar {
                Circle()
                    .fill(skeletonGradient)
                    .frame(width: 44, height: 44)
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Rectangle()
                    .fill(skeletonGradient)
                    .frame(height: 16)
                    .frame(maxWidth: .infinity)
                
                Rectangle()
                    .fill(skeletonGradient)
                    .frame(height: 12)
                    .frame(maxWidth: .infinity)
                    .scaleEffect(x: 0.7, anchor: .leading)
            }
        }
        .contentPadding()
    }
    
    private var cardSkeletonRow: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Rectangle()
                .fill(skeletonGradient)
                .frame(height: 20)
                .frame(maxWidth: .infinity)
            
            Rectangle()
                .fill(skeletonGradient)
                .frame(height: 14)
                .frame(maxWidth: .infinity)
                .scaleEffect(x: 0.8, anchor: .leading)
            
            Rectangle()
                .fill(skeletonGradient)
                .frame(height: 14)
                .frame(maxWidth: .infinity)
                .scaleEffect(x: 0.6, anchor: .leading)
        }
        .cardPadding()
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .lightShadow()
        )
    }
    
    private var listSkeletonRow: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Rectangle()
                .fill(skeletonGradient)
                .frame(width: 40, height: 40)
                .cornerRadius(BrandStyle.cornerRadiusSmall)
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Rectangle()
                    .fill(skeletonGradient)
                    .frame(height: 14)
                    .frame(maxWidth: .infinity)
                
                Rectangle()
                    .fill(skeletonGradient)
                    .frame(height: 12)
                    .frame(maxWidth: .infinity)
                    .scaleEffect(x: 0.6, anchor: .leading)
            }
            
            Spacer()
        }
        .contentPadding()
    }
    
    private var skeletonGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(.systemGray5),
                Color(.systemGray4).opacity(isAnimating ? 0.8 : 1.0),
                Color(.systemGray5)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Preview

#Preview("Loading Overlays") {
    ZStack {
        Color(.systemGroupedBackground)
            .ignoresSafeArea()
        
        VStack(spacing: DesignSystem.Spacing.xl) {
            Text("Background Content")
                .headlineMedium()
            
            Rectangle()
                .fill(Color.blue.opacity(0.3))
                .frame(height: 200)
                .cornerRadius(BrandStyle.cornerRadius)
        }
        .screenPadding()
        
        BrandedLoadingOverlay(
            message: "Creating your family...",
            style: .branded
        )
    }
}

#Preview("Loading Buttons") {
    VStack(spacing: DesignSystem.Spacing.lg) {
        BrandedLoadingButton(
            title: "Create Family",
            isLoading: true,
            action: {},
            style: .primary
        )
        
        BrandedLoadingButton(
            title: "Join Family",
            isLoading: false,
            action: {},
            style: .secondary
        )
        
        BrandedLoadingButton(
            title: "Skip",
            isLoading: false,
            action: {},
            style: .tertiary
        )
    }
    .screenPadding()
}

#Preview("Skeleton Views") {
    ScrollView {
        VStack(spacing: DesignSystem.Spacing.xl) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Standard Skeleton")
                    .headlineSmall()
                
                BrandedSkeletonView(rows: 3, showAvatar: true, style: .standard)
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Card Skeleton")
                    .headlineSmall()
                
                BrandedSkeletonView(rows: 2, style: .card)
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("List Skeleton")
                    .headlineSmall()
                
                BrandedSkeletonView(rows: 4, style: .list)
            }
        }
        .screenPadding()
    }
}