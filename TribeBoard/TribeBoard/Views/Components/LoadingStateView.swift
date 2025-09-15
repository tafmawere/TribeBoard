import SwiftUI

/// Enhanced loading state components with different styles and contexts
struct LoadingStateView: View {
    let message: String
    let style: LoadingStyle
    
    enum LoadingStyle {
        case overlay
        case inline
        case card
        case minimal
    }
    
    init(message: String = "Loading...", style: LoadingStyle = .overlay) {
        self.message = message
        self.style = style
    }
    
    var body: some View {
        switch style {
        case .overlay:
            overlayStyle
        case .inline:
            inlineStyle
        case .card:
            cardStyle
        case .minimal:
            minimalStyle
        }
    }
    
    // MARK: - Style Implementations
    
    private var overlayStyle: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .brandPrimary))
                
                Text(message)
                    .font(.headline)
                    .foregroundColor(.brandPrimary)
            }
            .padding(30)
            .background(Color(.systemBackground))
            .cornerRadius(BrandStyle.cornerRadius)
            .shadow(
                color: BrandStyle.standardShadow,
                radius: BrandStyle.shadowRadius,
                x: BrandStyle.shadowOffset.width,
                y: BrandStyle.shadowOffset.height
            )
        }
    }
    
    private var inlineStyle: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
                .progressViewStyle(CircularProgressViewStyle(tint: .brandPrimary))
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
    
    private var cardStyle: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .progressViewStyle(CircularProgressViewStyle(tint: .brandPrimary))
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: BrandStyle.cornerRadius)
                .fill(Color(.systemBackground))
                .shadow(
                    color: BrandStyle.standardShadow,
                    radius: 4,
                    x: 0,
                    y: 2
                )
        )
    }
    
    private var minimalStyle: some View {
        ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .brandPrimary))
            .scaleEffect(0.8)
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
        LoadingStateView(message: "Loading family data...", style: .card)
        
        LoadingStateView(message: "Searching...", style: .inline)
        
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
        
        LoadingStateView(message: "Creating your family...", style: .overlay)
    }
}